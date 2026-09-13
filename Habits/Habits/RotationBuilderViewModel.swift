//
//  RotationBuilderViewModel.swift
//  Habits
//
//  Backs the Settings "Workout Sequence" card and its two sheets (the
//  builder, and the starter-program reset picker) — see SPEC.md's Settings
//  addendum, pass 2, and settings.js in the `habits` (web) repo for the
//  behavior this mirrors.
//

import Foundation
import Combine
import SwiftUI
import Supabase

@MainActor
final class RotationBuilderViewModel: ObservableObject {
    /// The saved sequence, as loaded from `user_rotation` — drives the
    /// Settings card's read-only summary. `nil` before the first load.
    @Published var currentRotation: [WorkoutLibraryRow]?
    @Published var workoutLibrary: [WorkoutLibraryRow] = []
    @Published var isLoading = false
    @Published var loadErrorMessage: String?

    /// The sequence being edited in the builder sheet — `nil` when the
    /// sheet isn't open. Separate from `currentRotation` so Cancel just
    /// discards it.
    @Published var stagedSlots: [StagedRotationSlot]?
    @Published var isSaving = false
    @Published var saveErrorMessage: String?
    @Published var lastAddedWorkoutID: String?

    @Published var customWorkoutName = ""
    @Published var customWorkoutCategory: WorkoutCategory = .cardio
    @Published var isSavingCustomWorkout = false
    @Published var customWorkoutErrorMessage: String?

    @Published var programs: [StarterProgram] = []
    @Published var isLoadingPrograms = false
    @Published var programsErrorMessage: String?
    @Published var isApplyingProgram = false
    @Published var applyProgramErrorMessage: String?

    private let userID: UUID
    private var lastAddedResetTask: Task<Void, Never>?

    init(userID: UUID) {
        self.userID = userID
    }

    var hasCustomRotation: Bool { (currentRotation?.count ?? 0) >= 2 }

    // MARK: - Loading

    /// Loads the library and the current saved sequence — enough to render
    /// the Settings card and to seed the builder sheet without another
    /// round trip.
    func loadInitial() async {
        isLoading = true
        loadErrorMessage = nil
        do {
            async let libraryRows: [WorkoutLibraryRow] = SupabaseManager.client
                .from("workout_library")
                .select("id, name, category, icon, is_global, created_by")
                .or("is_global.eq.true,created_by.eq.\(userID.uuidString)")
                .order("is_global", ascending: false)
                .order("name", ascending: true)
                .execute()
                .value
            async let rotationRows: [UserRotationRichJoinRow] = SupabaseManager.client
                .from("user_rotation")
                .select("position, workout_id, workout_library(id, name, category, icon, is_global, created_by)")
                .eq("user_id", value: userID)
                .order("position", ascending: true)
                .execute()
                .value

            workoutLibrary = try await libraryRows
            let rotation = try await rotationRows.compactMap(\.workout_library)
            currentRotation = rotation.count >= 2 ? rotation : nil
        } catch {
            if !(error is CancellationError) {
                loadErrorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    // MARK: - Builder sheet

    /// `nil` seeds the current saved sequence (or the app's default 5-workout
    /// rotation, if no custom one exists yet); `[]` seeds an empty sequence.
    func openBuilder(seed: [WorkoutLibraryRow]? = nil) {
        saveErrorMessage = nil
        hideCustomWorkoutForm()
        let base = seed ?? currentRotation ?? resolvedDefaultRotation()
        stagedSlots = base.map { StagedRotationSlot(workoutId: $0.id) }
    }

    /// `DefaultWorkouts`'s ids (e.g. "peloton") predate `workout_library` and
    /// never match a real row there — resolve each default against its
    /// matching global library row by name so staged slots carry real UUIDs
    /// instead of ids `workout(forID:)`/`save_user_rotation` can't recognize.
    /// Entries that can't be resolved (e.g. the library hasn't loaded yet)
    /// are dropped rather than staged broken.
    private static let defaultWorkoutLibraryNames: [String: String] = [
        "peloton": "Peloton Ride",
        "upper_push": "Upper Push",
        "upper_pull": "Upper Pull",
        "lower": "Lower Body",
        "yoga": "Yoga",
    ]

    private func resolvedDefaultRotation() -> [WorkoutLibraryRow] {
        DefaultWorkouts.rotation.compactMap { defaultWorkout in
            guard let libraryName = Self.defaultWorkoutLibraryNames[defaultWorkout.id] else { return nil }
            return workoutLibrary.first {
                $0.is_global && $0.name.caseInsensitiveCompare(libraryName) == .orderedSame
            }
        }
    }

    func closeBuilder() {
        guard !isSaving && !isSavingCustomWorkout else { return }
        stagedSlots = nil
        hideCustomWorkoutForm()
    }

    func workout(forID id: String) -> WorkoutLibraryRow? {
        workoutLibrary.first { $0.id == id }
    }

    func moveStagedSlots(fromOffsets source: IndexSet, toOffset destination: Int) {
        stagedSlots?.move(fromOffsets: source, toOffset: destination)
    }

    func addWorkoutToStage(_ workoutId: String) {
        guard stagedSlots != nil else { return }
        stagedSlots?.append(StagedRotationSlot(workoutId: workoutId))
        flashAdded(workoutId)
    }

    func removeStagedSlot(_ slotId: String) {
        guard let slots = stagedSlots, slots.count > 2 else { return }
        withAnimation(.easeOut(duration: 0.22)) {
            stagedSlots?.removeAll { $0.id == slotId }
        }
    }

    private func flashAdded(_ workoutId: String) {
        lastAddedWorkoutID = workoutId
        lastAddedResetTask?.cancel()
        lastAddedResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            self?.lastAddedWorkoutID = nil
        }
    }

    /// Saves the staged sequence via the same `save_user_rotation` RPC the
    /// web app calls — a single atomic replace of the user's rotation rows,
    /// rather than a client-side delete-then-insert that could race or
    /// partially fail. Returns whether the save succeeded.
    ///
    /// Resets progress *before* replacing the sequence: these are two
    /// separate writes, so if the second one fails partway, this ordering's
    /// worst case is progress reset against the still-current sequence,
    /// rather than the new sequence paired with a stale `rotation_index`
    /// (which could point `TodayViewModel.suggested` at the wrong workout).
    @discardableResult
    func saveStagedRotation() async -> Bool {
        guard let slots = stagedSlots, slots.count >= 2, !isSaving else { return false }
        isSaving = true
        saveErrorMessage = nil
        do {
            try await resetRotationProgress()
            let params = SaveUserRotationParams(p_user_id: userID, p_workout_ids: slots.map(\.workoutId))
            try await SupabaseManager.client.rpc("save_user_rotation", params: params).execute()
            await loadInitial()
            stagedSlots = nil
            hideCustomWorkoutForm()
            isSaving = false
            return true
        } catch {
            saveErrorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    // MARK: - Custom workouts

    func showCustomWorkoutForm() {
        customWorkoutName = ""
        customWorkoutCategory = .cardio
        customWorkoutErrorMessage = nil
    }

    func hideCustomWorkoutForm() {
        customWorkoutName = ""
        customWorkoutErrorMessage = nil
        isSavingCustomWorkout = false
    }

    /// Saves a new workout to the library and adds it straight into the
    /// staged sequence — matches the web app's builder flow, where "Add your
    /// own" both creates the library row and appends it to the sequence in
    /// one step.
    func saveCustomWorkout() async {
        let trimmedName = customWorkoutName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            customWorkoutErrorMessage = "Enter a workout name"
            return
        }
        guard !isSavingCustomWorkout else { return }
        isSavingCustomWorkout = true
        customWorkoutErrorMessage = nil
        do {
            let payload = WorkoutLibraryInsertPayload(
                name: trimmedName,
                category: customWorkoutCategory.rawValue,
                icon: customWorkoutCategory.lucideIcon,
                is_global: false,
                created_by: userID
            )
            let inserted: WorkoutLibraryRow = try await SupabaseManager.client
                .from("workout_library")
                .insert(payload)
                .select("id, name, category, icon, is_global, created_by")
                .single()
                .execute()
                .value
            workoutLibrary.append(inserted)
            addWorkoutToStage(inserted.id)
            customWorkoutName = ""
        } catch {
            customWorkoutErrorMessage = error.localizedDescription
        }
        isSavingCustomWorkout = false
    }

    // MARK: - Starter programs (reset)

    func loadPrograms() async {
        guard programs.isEmpty else { return }
        isLoadingPrograms = true
        programsErrorMessage = nil
        do {
            let rows: [ProgramJoinRow] = try await SupabaseManager.client
                .from("programs")
                .select("id, name, description, is_global, created_by, program_workouts(id, workout_id, position, workout_library(id, name, category, icon, is_global, created_by))")
                .or("is_global.eq.true,created_by.eq.\(userID.uuidString)")
                .order("is_global", ascending: false)
                .order("name", ascending: true)
                .execute()
                .value
            programs = rows.map(StarterProgram.init)
        } catch {
            programsErrorMessage = error.localizedDescription
        }
        isLoadingPrograms = false
    }

    /// Replaces the user's entire sequence with a starter program's — same
    /// two-step write as the web app's `saveProgramAsUserRotation`: swap the
    /// rotation, then zero out rotation progress so "next up" starts from
    /// the top of the new sequence.
    @discardableResult
    func applyProgram(_ program: StarterProgram) async -> Bool {
        guard !isApplyingProgram else { return false }
        isApplyingProgram = true
        applyProgramErrorMessage = nil
        do {
            try await resetRotationProgress()
            let params = SaveUserRotationParams(p_user_id: userID, p_workout_ids: program.workouts.map(\.id))
            try await SupabaseManager.client.rpc("save_user_rotation", params: params).execute()
            await loadInitial()
            isApplyingProgram = false
            return true
        } catch {
            applyProgramErrorMessage = error.localizedDescription
            isApplyingProgram = false
            return false
        }
    }

    private func resetRotationProgress() async throws {
        let payload = StateRotationResetPayload(rotation_index: 0, action_date: nil)
        try await SupabaseManager.client
            .from("state")
            .update(payload)
            .eq("user_id", value: userID)
            .execute()
    }
}
