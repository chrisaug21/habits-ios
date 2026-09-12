//
//  TodayViewModel.swift
//  Habits
//

import Foundation
import Combine
import Supabase

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var history: [HistoryRow] = []
    @Published var rotationIndex = 0
    @Published var actionDate: String?
    @Published var workoutLibrary: [WorkoutLibraryNested] = []
    @Published var userRotation: [WorkoutDefinition] = []
    @Published var journal: [JournalRow] = []
    @Published var preferences = UserPreferencesRow.defaults

    @Published var isLoading = false
    @Published var isProcessing = false
    @Published var errorMessage: String?

    private let userID: UUID

    init(userID: UUID) {
        self.userID = userID
    }

    // MARK: - Derived state

    private var hasCustomRotation: Bool { userRotation.count >= 2 }

    var activeRotation: [WorkoutDefinition] {
        hasCustomRotation ? userRotation : DefaultWorkouts.rotation
    }

    var activeWorkoutList: [WorkoutDefinition] {
        guard hasCustomRotation else { return DefaultWorkouts.all }
        var seen = Set<String>()
        return userRotation.filter { seen.insert($0.id).inserted }
    }

    func workout(byID id: String) -> WorkoutDefinition? {
        if let match = activeWorkoutList.first(where: { $0.id == id }) { return match }
        if let libraryMatch = workoutLibrary.first(where: { $0.id == id }) {
            return WorkoutDefinition(id: libraryMatch.id, name: libraryMatch.name, icon: LucideIcon.sfSymbolName(libraryMatch.icon), category: libraryMatch.category ?? "")
        }
        return DefaultWorkouts.all.first { $0.id == id }
    }

    var suggested: WorkoutDefinition? {
        let rotation = activeRotation
        guard !rotation.isEmpty else { return DefaultWorkouts.all.first }
        return rotation[rotationIndex % rotation.count]
    }

    var todayEntry: HistoryRow? {
        let today = Self.todayStr()
        return history.last { $0.date == today }
    }

    var heroState: TodayHeroState {
        guard let entry = todayEntry else { return .defaultNext }
        if entry.type == "off" { return .skipped }
        if entry.type == "other" { return .other }
        return .done
    }

    var heroWorkout: WorkoutDefinition? {
        switch heroState {
        case .defaultNext: return suggested
        case .done: return todayEntry.flatMap { workout(byID: $0.type) } ?? suggested
        case .skipped, .other: return nil
        }
    }

    var tomorrowWorkout: WorkoutDefinition? {
        let rotation = activeRotation
        guard !rotation.isEmpty else { return nil }
        let idx = todayEntry != nil ? rotationIndex % rotation.count : (rotationIndex + 1) % rotation.count
        return rotation[idx]
    }

    var undoLabel: String? {
        guard let last = history.last else { return nil }
        switch last.type {
        case "off": return "Rest Day"
        case "other": return last.note ?? "Other Activity"
        default: return workout(byID: last.type)?.name ?? last.type
        }
    }

    func daysSinceLastDone(_ workoutID: String) -> Int? {
        guard let mostRecent = history.filter({ $0.type == workoutID }).map(\.date).max() else { return nil }
        return Self.daysSince(mostRecent)
    }

    var todayJournalEntry: JournalRow? {
        journal.first { $0.date == Self.todayStr() }
    }

    func checkGratitudeSimilarity(_ newGratitude: String) -> Bool {
        let needle = newGratitude.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return false }
        let today = Self.todayStr()
        guard let cutoff = Self.dateString(daysAgo: 7) else { return false }
        return journal.contains { entry in
            guard let gratitude = entry.gratitude, !gratitude.isEmpty else { return false }
            guard entry.date < today, entry.date >= cutoff else { return false }
            let haystack = gratitude.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return needle.contains(haystack) || haystack.contains(needle)
        }
    }

    // MARK: - Loading

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        do {
            async let stateRow = fetchOrCreateState()
            async let historyRows: [HistoryRow] = SupabaseManager.client
                .from("history")
                .select("id, type, date, advanced, note, sequence")
                .eq("user_id", value: userID)
                .order("sequence", ascending: true)
                .execute()
                .value
            async let libraryRows: [WorkoutLibraryNested] = SupabaseManager.client
                .from("workout_library")
                .select("id, name, category, icon")
                .or("is_global.eq.true,created_by.eq.\(userID.uuidString)")
                .execute()
                .value
            async let rotationRows: [UserRotationJoinRow] = SupabaseManager.client
                .from("user_rotation")
                .select("position, workout_id, workout_library(id, name, category, icon)")
                .eq("user_id", value: userID)
                .order("position", ascending: true)
                .execute()
                .value
            async let journalRows: [JournalRow] = SupabaseManager.client
                .from("journal")
                .select("date, intention, gratitude, one_thing")
                .eq("user_id", value: userID)
                .order("date", ascending: false)
                .execute()
                .value
            async let preferencesRow = fetchOrCreatePreferences()

            let resolvedState = try await stateRow
            self.rotationIndex = resolvedState.rotation_index
            self.actionDate = resolvedState.action_date
            self.history = try await historyRows
            self.workoutLibrary = try await libraryRows
            self.userRotation = try await rotationRows.map { row in
                WorkoutDefinition(
                    id: row.workout_id,
                    name: row.workout_library?.name ?? row.workout_id,
                    icon: LucideIcon.sfSymbolName(row.workout_library?.icon),
                    category: row.workout_library?.category ?? ""
                )
            }
            self.journal = try await journalRows
            self.preferences = try await preferencesRow
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func fetchOrCreateState() async throws -> StateRow {
        let rows: [StateRow] = try await SupabaseManager.client
            .from("state")
            .select("id, rotation_index, action_date")
            .eq("user_id", value: userID)
            .order("id", ascending: false)
            .limit(1)
            .execute()
            .value
        if let existing = rows.first { return existing }
        let payload = StateUpsertPayload(user_id: userID, rotation_index: 0, action_date: nil)
        return try await SupabaseManager.client
            .from("state")
            .upsert(payload, onConflict: "user_id")
            .select("id, rotation_index, action_date")
            .single()
            .execute()
            .value
    }

    private func fetchOrCreatePreferences() async throws -> UserPreferencesRow {
        let rows: [UserPreferencesRow] = try await SupabaseManager.client
            .from("user_preferences")
            .select("show_workout_card, show_journal_card, show_weight_card")
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value
        if let existing = rows.first { return existing }
        let payload = UserPreferencesUpsertPayload(
            user_id: userID,
            show_workout_card: UserPreferencesRow.defaults.show_workout_card,
            show_journal_card: UserPreferencesRow.defaults.show_journal_card,
            show_weight_card: UserPreferencesRow.defaults.show_weight_card
        )
        return try await SupabaseManager.client
            .from("user_preferences")
            .upsert(payload, onConflict: "user_id")
            .select("show_workout_card, show_journal_card, show_weight_card")
            .single()
            .execute()
            .value
    }

    // MARK: - Workout actions

    func markDone() async {
        guard !isProcessing, let suggested else { return }
        await runAction {
            let today = Self.todayStr()
            _ = try await self.insertHistoryEntry(type: suggested.id, date: today, advanced: true, note: nil)
            let newIndex = self.activeRotation.isEmpty ? 0 : (self.rotationIndex + 1) % self.activeRotation.count
            try await self.updateState(rotationIndex: newIndex, actionDate: today)
            self.rotationIndex = newIndex
            self.actionDate = today
        }
    }

    func logWorkout(_ workout: WorkoutDefinition) async {
        guard !isProcessing else { return }
        await runAction {
            let today = Self.todayStr()
            _ = try await self.insertHistoryEntry(type: workout.id, date: today, advanced: false, note: nil)
            try await self.updateState(rotationIndex: self.rotationIndex, actionDate: today)
            self.actionDate = today
        }
    }

    func logSkip(reason: String?) async {
        guard !isProcessing else { return }
        await runAction {
            let today = Self.todayStr()
            let trimmed = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
            let note = (trimmed?.isEmpty ?? true) ? nil : trimmed
            _ = try await self.insertHistoryEntry(type: "off", date: today, advanced: false, note: note)
            try await self.updateState(rotationIndex: self.rotationIndex, actionDate: today)
            self.actionDate = today
            if let note {
                RecentChipsStore.remember(note, in: RecentChipsStore.skipReasonsKey)
            }
        }
    }

    func logOtherActivity(_ name: String) async {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        guard !trimmed.isEmpty, !isProcessing else { return }
        await runAction {
            let today = Self.todayStr()
            _ = try await self.insertHistoryEntry(type: "other", date: today, advanced: false, note: trimmed)
            try await self.updateState(rotationIndex: self.rotationIndex, actionDate: today)
            self.actionDate = today
            RecentChipsStore.remember(trimmed, in: RecentChipsStore.otherActivitiesKey)
        }
    }

    func undoLastEntry() async {
        guard !isProcessing, let last = history.last else { return }
        let today = Self.todayStr()
        guard let yesterday = Self.dateString(daysAgo: 1) else { return }
        guard last.date == today || last.date == yesterday else { return }

        await runAction {
            let remaining = Array(self.history.dropLast())
            var newIndex = self.rotationIndex
            if last.advanced {
                let count = max(self.activeRotation.count, 1)
                newIndex = ((self.rotationIndex - 1) % count + count) % count
            }
            let stillLockedToday = remaining.contains { entry in
                entry.date == today && (entry.advanced || entry.type == "off" || entry.type == "other")
            }
            let newActionDate: String? = stillLockedToday ? today : nil

            if let id = last.id {
                try await SupabaseManager.client.from("history").delete().eq("id", value: id).execute()
            }
            try await self.updateState(rotationIndex: newIndex, actionDate: newActionDate)

            self.history = remaining
            self.rotationIndex = newIndex
            self.actionDate = newActionDate
        }
    }

    private func runAction(_ body: @escaping () async throws -> Void) async {
        isProcessing = true
        errorMessage = nil
        do {
            try await body()
        } catch {
            errorMessage = "Could not save — check your connection"
        }
        isProcessing = false
    }

    private func insertHistoryEntry(type: String, date: String, advanced: Bool, note: String?) async throws {
        let nextSequence = (history.compactMap(\.sequence).max() ?? -1) + 1
        let payload = HistoryInsertPayload(type: type, date: date, advanced: advanced, note: note, sequence: nextSequence, user_id: userID)
        let inserted: HistoryRow = try await SupabaseManager.client
            .from("history")
            .insert(payload)
            .select("id, type, date, advanced, note, sequence")
            .single()
            .execute()
            .value
        history.append(inserted)
    }

    private func updateState(rotationIndex: Int, actionDate: String?) async throws {
        try await SupabaseManager.client
            .from("state")
            .update(StateUpsertPayload(user_id: userID, rotation_index: rotationIndex, action_date: actionDate))
            .eq("user_id", value: userID)
            .execute()
    }

    // MARK: - Backfill (Log screen)

    /// Logs or edits a history entry for a past date. Mirrors the web app's
    /// `confirmBackfill` in log.js: the rotation index only advances when
    /// this is the most recent rotation-relevant entry — a later entry that
    /// already advanced the rotation means this backfill shouldn't advance
    /// it again — and editing an existing entry adjusts the index by
    /// whatever the advance/no-advance state changed to.
    func backfillLogEntry(date: String, type: String, note: String?) async -> Bool {
        guard !isProcessing else { return false }
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        let existing = history.last { $0.date == date }
        let rotationIDs = Set(activeWorkoutList.map(\.id))
        let isRotationWorkout = rotationIDs.contains(type)
        let hasLaterEntries = history.contains { $0.date > date && rotationIDs.contains($0.type) }
        let shouldAdvance = isRotationWorkout && !hasLaterEntries
        let count = max(activeRotation.count, 1)

        do {
            if let existing, let existingID = existing.id {
                let wasAdvanced = existing.advanced
                try await SupabaseManager.client
                    .from("history")
                    .update(HistoryUpdatePayload(type: type, note: note, advanced: shouldAdvance))
                    .eq("id", value: existingID)
                    .execute()

                if let idx = history.firstIndex(where: { $0.id == existingID }) {
                    history[idx] = HistoryRow(id: existingID, type: type, date: existing.date, advanced: shouldAdvance, note: note, sequence: existing.sequence)
                }

                if shouldAdvance && !wasAdvanced {
                    rotationIndex = (rotationIndex + 1) % count
                } else if !shouldAdvance && wasAdvanced {
                    rotationIndex = ((rotationIndex - 1) % count + count) % count
                }
            } else {
                try await insertHistoryEntry(type: type, date: date, advanced: shouldAdvance, note: note)
                if shouldAdvance {
                    rotationIndex = (rotationIndex + 1) % count
                }
            }

            try await updateState(rotationIndex: rotationIndex, actionDate: actionDate)

            if type == "other", let note, !note.isEmpty {
                RecentChipsStore.remember(note, in: RecentChipsStore.otherActivitiesKey)
            }
            if type == "off", let note, !note.isEmpty {
                RecentChipsStore.remember(note, in: RecentChipsStore.skipReasonsKey)
            }
            return true
        } catch {
            errorMessage = "Could not save — check your connection"
            return false
        }
    }

    // MARK: - Journal

    enum JournalSaveResult {
        case saved
        case needsGratitudeConfirmation
        case failed
    }

    func saveJournal(intention: String, gratitude: String, oneThing: String, confirmed: Bool) async -> JournalSaveResult {
        let intention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        let gratitude = gratitude.trimmingCharacters(in: .whitespacesAndNewlines)
        let oneThing = oneThing.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !intention.isEmpty || !gratitude.isEmpty || !oneThing.isEmpty else { return .saved }

        if !gratitude.isEmpty, !confirmed, checkGratitudeSimilarity(gratitude) {
            return .needsGratitudeConfirmation
        }

        let today = Self.todayStr()
        let payload = JournalUpsertPayload(
            date: today,
            intention: intention.isEmpty ? nil : intention,
            gratitude: gratitude.isEmpty ? nil : gratitude,
            one_thing: oneThing.isEmpty ? nil : oneThing,
            user_id: userID
        )
        do {
            try await SupabaseManager.client
                .from("journal")
                .upsert(payload, onConflict: "date,user_id")
                .execute()
            let entry = JournalRow(date: today, intention: payload.intention, gratitude: payload.gratitude, one_thing: payload.one_thing)
            if let idx = journal.firstIndex(where: { $0.date == today }) {
                journal[idx] = entry
            } else {
                journal.insert(entry, at: 0)
            }
            return .saved
        } catch {
            errorMessage = "Could not save — check your connection"
            return .failed
        }
    }

    // MARK: - Date helpers

    static func todayStr() -> String {
        dateFormatter.string(from: Date())
    }

    static func dateString(daysAgo: Int) -> String? {
        guard let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) else { return nil }
        return dateFormatter.string(from: date)
    }

    static func daysSince(_ dateStr: String) -> Int? {
        guard let then = dateFormatter.date(from: dateStr) else { return nil }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let startOfThen = Calendar.current.startOfDay(for: then)
        return Calendar.current.dateComponents([.day], from: startOfThen, to: startOfToday).day
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        return formatter
    }()
}
