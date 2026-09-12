//
//  LogView.swift
//  Habits
//
//  Native mirror of the web app's log.js: a Calendar/List/Schedule view over
//  the same `history`/`journal`/`weight` data Today uses, plus a backfill
//  sheet for editing a past day. Reuses TodayViewModel rather than a
//  separate data layer, since it's the same rotation/history domain.
//

import SwiftUI

private enum LogSubTab: String, CaseIterable, Identifiable {
    case calendar = "Calendar"
    case list = "List"
    case schedule = "Schedule"
    var id: String { rawValue }
}

private struct BackfillTarget: Identifiable {
    let date: String
    var id: String { date }
}

struct LogView: View {
    @StateObject private var viewModel: TodayViewModel
    @StateObject private var weightViewModel: WeightViewModel

    @State private var subTab: LogSubTab = .calendar
    @State private var tabTransitionEdge: Edge = .trailing
    @State private var calendarMonth = Date()
    @State private var backfillTarget: BackfillTarget?

    /// Wraps `subTab` so switching tabs animates as a directional slide
    /// (forward into a later tab, backward into an earlier one) instead of
    /// an instant cut — `HabitsSegmentedControl` just sets this like any
    /// other binding and doesn't need to know about the animation.
    private var animatedSubTab: Binding<LogSubTab> {
        Binding(
            get: { subTab },
            set: { newValue in
                let cases = LogSubTab.allCases
                if let newIdx = cases.firstIndex(of: newValue), let oldIdx = cases.firstIndex(of: subTab) {
                    tabTransitionEdge = newIdx > oldIdx ? .trailing : .leading
                }
                withAnimation(.easeInOut(duration: 0.25)) {
                    subTab = newValue
                }
            }
        )
    }

    private var subTabTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: tabTransitionEdge).combined(with: .opacity),
            removal: .move(edge: tabTransitionEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
        )
    }

    init(userID: UUID) {
        _viewModel = StateObject(wrappedValue: TodayViewModel(userID: userID))
        _weightViewModel = StateObject(wrappedValue: WeightViewModel(userID: userID))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HabitsSegmentedControl(items: LogSubTab.allCases, selection: animatedSubTab) { $0.rawValue }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 16) {
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(HabitsColor.red)
                        }
                        Group {
                            switch subTab {
                            case .calendar: calendarSection
                            case .list: listSection
                            case .schedule: scheduleSection
                            }
                        }
                        .id(subTab)
                        .transition(subTabTransition)

                        HabitsVersionFooter()
                    }
                    .padding(16)
                    .clipped()
                }
            }
            .background(HabitsColor.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HabitsColor.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable {
                await viewModel.loadAll()
                await weightViewModel.loadEntries()
            }
            .task {
                await viewModel.loadAll()
                await weightViewModel.loadEntries()
            }
            .overlay {
                if viewModel.isLoading && viewModel.history.isEmpty {
                    ProgressView().tint(HabitsColor.accent)
                }
            }
            .sheet(item: $backfillTarget) { target in
                backfillSheet(for: target.date)
            }
        }
        .tint(HabitsColor.accent)
        .preferredColorScheme(.dark)
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(spacing: 14) {
            monthHeader
            calendarGrid
            legend
        }
        .habitsCard()
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(HabitsIconButtonStyle())

            Spacer()

            Text(Self.monthTitleFormatter.string(from: calendarMonth))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(HabitsColor.textPrimary)

            Spacer()

            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(HabitsIconButtonStyle())
        }
    }

    private func shiftMonth(_ delta: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: delta, to: calendarMonth) {
            calendarMonth = newMonth
        }
    }

    private var calendarGrid: some View {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: calendarMonth)
        guard let firstOfMonth = cal.date(from: comps),
              let daysRange = cal.range(of: .day, in: .month, for: firstOfMonth) else {
            return AnyView(EmptyView())
        }
        let firstWeekday = cal.component(.weekday, from: firstOfMonth) - 1
        let today = Self.dateFormatter.string(from: Date())
        let projMap = projectionMap()
        let journalDates = Set(viewModel.journal.map(\.date))
        let weightDates = Set(weightViewModel.entries.map(\.date))
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return AnyView(
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"].indices, id: \.self) { idx in
                    Text(["S", "M", "T", "W", "T", "F", "S"][idx])
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(HabitsColor.textSecondary)
                }
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear.frame(height: 46)
                }
                ForEach(daysRange, id: \.self) { day in
                    let date = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) ?? firstOfMonth
                    let ds = Self.dateFormatter.string(from: date)
                    dayCell(DayCellInfo(
                        ds: ds,
                        day: day,
                        isToday: ds == today,
                        isPast: ds < today,
                        histEntry: viewModel.history.last { $0.date == ds },
                        projected: projMap[ds],
                        hasJournal: journalDates.contains(ds),
                        hasWeight: weightDates.contains(ds)
                    ))
                }
            }
        )
    }

    /// Groups `dayCell`'s inputs into one value instead of eight separate
    /// parameters.
    private struct DayCellInfo {
        let ds: String
        let day: Int
        let isToday: Bool
        let isPast: Bool
        let histEntry: HistoryRow?
        let projected: WorkoutDefinition?
        let hasJournal: Bool
        let hasWeight: Bool
    }

    private struct DayCellVisual {
        let icon: String
        let tint: Color
        let filled: Bool
    }

    @ViewBuilder
    private func dayCell(_ info: DayCellInfo) -> some View {
        let visual: DayCellVisual = {
            if let histEntry = info.histEntry {
                if histEntry.type == "off" { return DayCellVisual(icon: "moon.fill", tint: HabitsColor.amber, filled: true) }
                if histEntry.type == "other" { return DayCellVisual(icon: "bolt.fill", tint: HabitsColor.teal, filled: true) }
                let workout = viewModel.workout(byID: histEntry.type)
                return DayCellVisual(icon: workout?.icon ?? "dumbbell.fill", tint: HabitsColor.accent, filled: true)
            } else if let projected = info.projected {
                return DayCellVisual(icon: projected.icon, tint: HabitsColor.accent, filled: false)
            }
            return DayCellVisual(icon: "", tint: HabitsColor.textDim, filled: false)
        }()

        VStack(spacing: 3) {
            Group {
                if visual.icon.isEmpty {
                    Color.clear
                } else {
                    Image(systemName: visual.icon)
                        .foregroundStyle(visual.filled ? visual.tint : visual.tint.opacity(0.4))
                }
            }
            .font(.system(size: 13))
            .frame(height: 15)

            Text("\(info.day)")
                .font(.system(size: 12, weight: info.isToday ? .bold : .regular))
                .foregroundStyle(info.isToday ? HabitsColor.textPrimary : (info.isPast ? HabitsColor.textSecondary : HabitsColor.textDim))

            HStack(spacing: 2) {
                if info.hasJournal { Circle().fill(HabitsColor.green).frame(width: 4, height: 4) }
                if info.hasWeight { Circle().fill(HabitsColor.coral).frame(width: 4, height: 4) }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(info.isToday ? HabitsColor.accent.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(info.isToday ? HabitsColor.borderActive.opacity(0.6) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if info.isPast { backfillTarget = BackfillTarget(date: info.ds) }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: HabitsColor.green, label: "Journal")
            legendItem(color: HabitsColor.coral, label: "Weight")
            Spacer()
            Text("Tap a past day to backfill")
                .font(.system(size: 11))
                .foregroundStyle(HabitsColor.textDim)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 11)).foregroundStyle(HabitsColor.textSecondary)
        }
    }

    /// Mirrors the web app's `buildProjectionMap`: walks forward from today,
    /// assigning the next rotation workout to every day that has no history
    /// entry yet (including today, if not yet logged), without changing the
    /// stored rotation index.
    private func projectionMap() -> [String: WorkoutDefinition] {
        let rotation = viewModel.activeRotation
        guard !rotation.isEmpty else { return [:] }
        var map: [String: WorkoutDefinition] = [:]
        var rotIdx = viewModel.rotationIndex
        let historyDates = Set(viewModel.history.map(\.date))
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())

        for i in 0...365 {
            guard let d = cal.date(byAdding: .day, value: i, to: start) else { continue }
            let ds = Self.dateFormatter.string(from: d)
            if !historyDates.contains(ds) {
                map[ds] = rotation[rotIdx % rotation.count]
                rotIdx += 1
            }
        }
        return map
    }

    // MARK: - List

    private var listSection: some View {
        let entries = viewModel.history.sorted { $0.date > $1.date }
        return VStack(spacing: 10) {
            if entries.isEmpty {
                Text("No data yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(HabitsColor.textSecondary)
                    .padding(.vertical, 24)
            } else {
                ForEach(entries) { entry in
                    historyRow(entry)
                }
            }
        }
    }

    private func historyRow(_ entry: HistoryRow) -> some View {
        let isOff = entry.type == "off"
        let isOther = entry.type == "other"
        let workout = (isOff || isOther) ? nil : viewModel.workout(byID: entry.type)
        let icon = isOff ? "moon.fill" : isOther ? "bolt.fill" : (workout?.icon ?? "dumbbell.fill")
        let color = isOff ? HabitsColor.amber : isOther ? HabitsColor.teal : HabitsColor.accent
        let name = isOff ? "Rest Day" : isOther ? (entry.note ?? "Other Activity") : (workout?.name ?? entry.type)

        return HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedDate(entry.date))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HabitsColor.textPrimary)
                Text(weekdayName(entry.date))
                    .font(.system(size: 11))
                    .foregroundStyle(HabitsColor.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                if isOff, let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(HabitsColor.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(HabitsColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(HabitsColor.border, lineWidth: 1))
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        let upcoming = upcomingProjection()
        return VStack(alignment: .leading, spacing: 10) {
            Text("COMING UP")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(HabitsColor.textSecondary)
            if upcoming.isEmpty {
                Text("No upcoming workouts.")
                    .font(.system(size: 14))
                    .foregroundStyle(HabitsColor.textSecondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(upcoming, id: \.date) { row in
                    scheduleRow(date: row.date, workout: row.workout)
                }
            }
        }
    }

    private func upcomingProjection() -> [(date: String, workout: WorkoutDefinition)] {
        let map = projectionMap()
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        var rows: [(date: String, workout: WorkoutDefinition)] = []
        for i in 1...14 {
            guard let d = cal.date(byAdding: .day, value: i, to: start) else { continue }
            let ds = Self.dateFormatter.string(from: d)
            if let workout = map[ds] {
                rows.append((ds, workout))
            }
        }
        return rows
    }

    private func scheduleRow(date: String, workout: WorkoutDefinition) -> some View {
        HStack(spacing: 14) {
            Image(systemName: workout.icon)
                .font(.system(size: 16))
                .foregroundStyle(HabitsColor.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedDate(date))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HabitsColor.textPrimary)
                Text(weekdayName(date))
                    .font(.system(size: 11))
                    .foregroundStyle(HabitsColor.textSecondary)
            }
            Spacer()
            Text(workout.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HabitsColor.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(HabitsColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(HabitsColor.border, lineWidth: 1))
    }

    // MARK: - Backfill sheet wiring

    private func backfillSheet(for date: String) -> some View {
        BackfillSheet(
            date: date,
            dateLabel: formattedFullDate(date),
            existingEntry: viewModel.history.last { $0.date == date },
            existingWeight: weightViewModel.entries.first { $0.date == date },
            existingJournal: viewModel.journal.first { $0.date == date },
            workoutOptions: viewModel.activeWorkoutList,
            workout: { viewModel.workout(byID: $0) },
            skipChips: RecentChipsStore.load(RecentChipsStore.skipReasonsKey).isEmpty
                ? RecentChipsStore.defaultSkipReasons
                : RecentChipsStore.load(RecentChipsStore.skipReasonsKey),
            otherChips: RecentChipsStore.load(RecentChipsStore.otherActivitiesKey),
            onSaveExercise: { type, note in
                let ok = await viewModel.backfillLogEntry(date: date, type: type, note: note)
                if ok { backfillTarget = nil }
                return ok
            },
            onSaveWeight: { pounds in
                await weightViewModel.addManualEntry(dateString: date, pounds: pounds)
            }
        )
    }

    // MARK: - Date helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        return f
    }()

    private static let monthTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    private func formattedFullDate(_ ds: String) -> String {
        guard let d = Self.dateFormatter.date(from: ds) else { return ds }
        return d.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func formattedDate(_ ds: String) -> String {
        guard let d = Self.dateFormatter.date(from: ds) else { return ds }
        return d.formatted(.dateTime.month(.abbreviated).day())
    }

    private func weekdayName(_ ds: String) -> String {
        guard let d = Self.dateFormatter.date(from: ds) else { return "" }
        return d.formatted(.dateTime.weekday(.wide))
    }
}

// MARK: - Backfill sheet

private struct BackfillSheet: View {
    let date: String
    let dateLabel: String
    let existingEntry: HistoryRow?
    let existingWeight: WeightEntry?
    let existingJournal: JournalRow?
    let workoutOptions: [WorkoutDefinition]
    let workout: (String) -> WorkoutDefinition?
    let skipChips: [String]
    let otherChips: [String]
    let onSaveExercise: (String, String?) async -> Bool
    let onSaveWeight: (Double) async -> Void

    private enum Mode { case readonly, editExercise, editWeight }

    @State private var mode: Mode = .readonly
    @State private var selectedType: String?
    @State private var noteText = ""
    @State private var weightText = ""
    @State private var isSaving = false
    @State private var currentWeight: WeightEntry?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(dateLabel)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(HabitsColor.textPrimary)

                switch mode {
                case .readonly: readonlyContent
                case .editExercise: editExerciseContent
                case .editWeight: editWeightContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .habitsSheet(detents: [.medium, .large])
        .onAppear {
            currentWeight = existingWeight
            selectedType = existingEntry?.type
            if existingEntry?.type == "other" || existingEntry?.type == "off" {
                noteText = existingEntry?.note ?? ""
            }
        }
    }

    // MARK: Readonly

    private var readonlyContent: some View {
        VStack(spacing: 14) {
            exerciseSummary
            weightSummary
            if let existingJournal, hasJournalContent(existingJournal) {
                journalSummary(existingJournal)
            }
        }
    }

    private struct ExerciseDisplay {
        let icon: String
        let color: Color
        let name: String
    }

    private var exerciseDisplay: ExerciseDisplay {
        guard let entry = existingEntry else {
            return ExerciseDisplay(icon: "dumbbell.fill", color: HabitsColor.textDim, name: "No exercise logged")
        }
        if entry.type == "off" {
            let hasNote = !(entry.note ?? "").isEmpty
            return ExerciseDisplay(icon: "moon.fill", color: HabitsColor.amber, name: hasNote ? entry.note! : "Rest Day")
        }
        if entry.type == "other" {
            let hasNote = !(entry.note ?? "").isEmpty
            return ExerciseDisplay(icon: "bolt.fill", color: HabitsColor.teal, name: hasNote ? entry.note! : "Other Activity")
        }
        let matched = workout(entry.type)
        return ExerciseDisplay(icon: matched?.icon ?? "dumbbell.fill", color: HabitsColor.accent, name: matched?.name ?? entry.type)
    }

    private var exerciseSummary: some View {
        let display = exerciseDisplay
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: display.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(display.color)
                    .frame(width: 28)
                Text(display.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HabitsColor.textPrimary)
                Spacer()
            }
            Button(existingEntry != nil ? "Edit Exercise" : "Add Exercise") {
                mode = .editExercise
            }
            .buttonStyle(HabitsGhostButtonStyle())
        }
        .padding(14)
        .background(HabitsColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(HabitsColor.border, lineWidth: 1))
    }

    private var weightSummary: some View {
        VStack(spacing: 10) {
            HStack {
                Text("WEIGHT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(HabitsColor.textSecondary)
                Spacer()
            }
            HStack {
                if let currentWeight {
                    Text("\(currentWeight.value_lbs, specifier: "%.1f") lbs")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(HabitsColor.textPrimary)
                } else {
                    Text("No weight logged")
                        .font(.system(size: 14))
                        .foregroundStyle(HabitsColor.textSecondary)
                }
                Spacer()
            }
            Button(currentWeight != nil ? "Edit Weight" : "Add Weight") {
                weightText = currentWeight.map { String($0.value_lbs) } ?? ""
                mode = .editWeight
            }
            .buttonStyle(HabitsGhostButtonStyle())
        }
        .padding(14)
        .background(HabitsColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(HabitsColor.border, lineWidth: 1))
    }

    private func hasJournalContent(_ entry: JournalRow) -> Bool {
        !(entry.intention ?? "").isEmpty || !(entry.gratitude ?? "").isEmpty || !(entry.one_thing ?? "").isEmpty
    }

    private func journalSummary(_ entry: JournalRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("JOURNAL")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(HabitsColor.textSecondary)
            if let intention = entry.intention, !intention.isEmpty { journalField("Intention", intention) }
            if let gratitude = entry.gratitude, !gratitude.isEmpty { journalField("Gratitude", gratitude) }
            if let oneThing = entry.one_thing, !oneThing.isEmpty { journalField("One Thing", oneThing) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(HabitsColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(HabitsColor.border, lineWidth: 1))
    }

    private func journalField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(HabitsColor.textDim)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(HabitsColor.textPrimary)
        }
    }

    // MARK: Edit exercise

    private var editExerciseContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                ForEach(workoutOptions) { option in
                    optionRow(id: option.id, icon: option.icon, title: option.name, color: HabitsColor.accent)
                }
                optionRow(id: "off", icon: "moon.fill", title: "Rest Day", color: HabitsColor.amber)
                optionRow(id: "other", icon: "bolt.fill", title: "Other Activity", color: HabitsColor.teal)
            }

            if selectedType == "off" || selectedType == "other" {
                let chips = selectedType == "off" ? skipChips : otherChips
                if !chips.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(chips, id: \.self) { chip in
                                Button(chip) { noteText = chip }.buttonStyle(HabitsChipButtonStyle())
                            }
                        }
                    }
                }
                HabitsTextField(
                    placeholder: selectedType == "off" ? "Reason (optional)" : "Activity name (optional)",
                    text: $noteText
                )
            }

            HStack(spacing: 10) {
                Button("Cancel") { mode = .readonly }
                    .buttonStyle(HabitsGhostButtonStyle(size: .large))
                Button("Save") {
                    guard let selectedType else { return }
                    let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let note = (selectedType == "off" || selectedType == "other") && !trimmed.isEmpty ? trimmed : nil
                    Task {
                        isSaving = true
                        _ = await onSaveExercise(selectedType, note)
                        isSaving = false
                    }
                }
                .buttonStyle(HabitsPrimaryButtonStyle())
                .disabled(selectedType == nil || isSaving)
            }
        }
    }

    private func optionRow(id: String, icon: String, title: String, color: Color) -> some View {
        Button {
            selectedType = id
            if id != "off" && id != "other" { noteText = "" }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(selectedType == id ? color : HabitsColor.textSecondary)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HabitsColor.textPrimary)
                Spacer()
                if selectedType == id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(HabitsColor.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selectedType == id ? color.opacity(0.7) : HabitsColor.border, lineWidth: selectedType == id ? 1.5 : 1)
            )
        }
        .buttonStyle(HabitsRowButtonStyle())
    }

    // MARK: Edit weight

    private var editWeightContent: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                TextField("0.0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(HabitsColor.textPrimary)
                    .tint(HabitsColor.accent)
                Text("lbs")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HabitsColor.textSecondary)
            }
            .padding(14)
            .background(HabitsColor.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(HabitsColor.border, lineWidth: 1))

            HStack(spacing: 10) {
                Button("Cancel") { mode = .readonly }
                    .buttonStyle(HabitsGhostButtonStyle(size: .large))
                Button("Save") {
                    guard let pounds = Double(weightText) else { return }
                    Task {
                        isSaving = true
                        await onSaveWeight(pounds)
                        currentWeight = WeightEntry(date: date, value_lbs: pounds)
                        isSaving = false
                        mode = .readonly
                    }
                }
                .buttonStyle(HabitsPrimaryButtonStyle())
                .disabled(Double(weightText) == nil || isSaving)
            }
        }
    }
}
