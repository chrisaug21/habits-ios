//
//  TodayView.swift
//  Habits
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var viewModel: TodayViewModel
    @StateObject private var weightViewModel: WeightViewModel

    @State private var showLogActivitySheet = false
    @State private var showSkipSheet = false
    @State private var showOtherActivitySheet = false
    @State private var showJournalSheet = false
    @State private var showWeightSheet = false

    init(userID: UUID) {
        _viewModel = StateObject(wrappedValue: TodayViewModel(userID: userID))
        _weightViewModel = StateObject(wrappedValue: WeightViewModel(userID: userID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dateLabel

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(HabitsColor.red)
                    }

                    if viewModel.preferences.show_workout_card {
                        workoutCard
                        if let tomorrow = viewModel.tomorrowWorkout, viewModel.todayEntry != nil {
                            tomorrowCard(tomorrow)
                        }
                    }
                    if viewModel.preferences.show_journal_card {
                        journalCard
                    }
                    if viewModel.preferences.show_weight_card {
                        weightCard
                    }
                }
                .padding(16)
            }
            .background(HabitsColor.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("Habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HabitsColor.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log Out") {
                        Task { await auth.signOut() }
                    }
                    .foregroundStyle(HabitsColor.textSecondary)
                }
            }
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
                    ProgressView()
                        .tint(HabitsColor.accent)
                }
            }
            .sheet(isPresented: $showLogActivitySheet) { logActivitySheet }
            .sheet(isPresented: $showSkipSheet) { skipSheet }
            .sheet(isPresented: $showOtherActivitySheet) { otherActivitySheet }
            .sheet(isPresented: $showJournalSheet) { journalSheet }
            .sheet(isPresented: $showWeightSheet) { weightSheet }
        }
        .tint(HabitsColor.accent)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var dateLabel: some View {
        Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(HabitsColor.textSecondary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    // MARK: - Workout card

    private var workoutCard: some View {
        VStack(spacing: 14) {
            switch viewModel.heroState {
            case .defaultNext:
                if let suggested = viewModel.suggested {
                    eyebrow("NEXT UP WORKOUT", color: HabitsColor.accent)
                    Image(systemName: suggested.icon)
                        .font(.system(size: 40))
                        .foregroundColor(HabitsColor.accent)
                        .frame(height: 48)
                    Text(suggested.name)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(HabitsColor.textPrimary)
                        .multilineTextAlignment(.center)
                    if let days = viewModel.daysSinceLastDone(suggested.id) {
                        HabitsPill(text: lastDoneText(days))
                    } else {
                        HabitsPill(text: "Never done")
                    }
                    VStack(spacing: 10) {
                        Button {
                            Task { await viewModel.markDone() }
                        } label: {
                            Text("Done!")
                        }
                        .buttonStyle(HabitsPrimaryButtonStyle())
                        .disabled(viewModel.isProcessing)

                        Button("Log activity") {
                            showLogActivitySheet = true
                        }
                        .buttonStyle(HabitsGhostButtonStyle())
                        .disabled(viewModel.isProcessing)
                    }
                    .padding(.top, 6)
                }
            case .done, .skipped, .other:
                eyebrow(heroEyebrow, color: heroAccentColor)
                Image(systemName: heroIcon)
                    .font(.system(size: 40))
                    .foregroundColor(heroAccentColor)
                    .frame(height: 48)
                Text(heroTitle)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(HabitsColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(heroSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(HabitsColor.textSecondary)
                if let label = viewModel.undoLabel {
                    Button {
                        Task { await viewModel.undoLastEntry() }
                    } label: {
                        Label("Undo \(label)", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(HabitsGhostButtonStyle())
                    .disabled(viewModel.isProcessing)
                    .padding(.top, 6)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(HabitsColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(HabitsColor.borderActive.opacity(0.5), lineWidth: 1)
        )
    }

    private func eyebrow(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(color)
    }

    private var heroEyebrow: String {
        switch viewModel.heroState {
        case .done: return "COMPLETED"
        case .skipped: return "DAY OFF"
        case .other: return "OTHER ACTIVITY"
        case .defaultNext: return ""
        }
    }

    private var heroIcon: String {
        switch viewModel.heroState {
        case .done: return "checkmark.circle.fill"
        case .skipped: return "moon.fill"
        case .other: return "bolt.fill"
        case .defaultNext: return "arrow.forward.circle"
        }
    }

    private var heroAccentColor: Color {
        switch viewModel.heroState {
        case .skipped: return HabitsColor.amber
        case .other: return HabitsColor.teal
        default: return HabitsColor.accent
        }
    }

    private var heroTitle: String {
        switch viewModel.heroState {
        case .skipped: return "Rest Day"
        case .other: return viewModel.todayEntry?.note ?? "Other Activity"
        case .done: return viewModel.heroWorkout?.name ?? "Workout"
        case .defaultNext: return ""
        }
    }

    private var heroSubtitle: String {
        switch viewModel.heroState {
        case .done: return "Completed today"
        case .skipped: return "Day off logged"
        case .other: return "Other activity logged"
        case .defaultNext: return ""
        }
    }

    private func lastDoneText(_ days: Int) -> String {
        days == 0 ? "Today" : "Last done \(days)d ago"
    }

    // MARK: - Tomorrow preview

    private func tomorrowCard(_ workout: WorkoutDefinition) -> some View {
        VStack(spacing: 6) {
            Text("TOMORROW")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(HabitsColor.textSecondary)
            HStack(spacing: 7) {
                Image(systemName: workout.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(HabitsColor.textSecondary)
                Text(workout.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(HabitsColor.textPrimary)
            }
            if let days = viewModel.daysSinceLastDone(workout.id) {
                HabitsPill(text: lastDoneText(days))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(HabitsColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(HabitsColor.border, lineWidth: 1)
        )
    }

    // MARK: - Journal card

    private var journalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("JOURNAL")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(HabitsColor.textSecondary)
            if let entry = viewModel.todayJournalEntry {
                VStack(alignment: .leading, spacing: 10) {
                    if let intention = entry.intention, !intention.isEmpty {
                        journalField("Intention", intention)
                    }
                    if let gratitude = entry.gratitude, !gratitude.isEmpty {
                        journalField("Gratitude", gratitude)
                    }
                    if let oneThing = entry.one_thing, !oneThing.isEmpty {
                        journalField("One thing", oneThing)
                    }
                }
                Button("Edit") { showJournalSheet = true }
                    .buttonStyle(HabitsGhostButtonStyle())
            } else {
                Button("Journal") { showJournalSheet = true }
                    .buttonStyle(HabitsPrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitsCard()
    }

    private func journalField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(HabitsColor.textDim)
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(HabitsColor.textPrimary)
        }
    }

    // MARK: - Weight card

    private var weightCard: some View {
        let today = TodayViewModel.todayStr()
        let entry = weightViewModel.entries.first { $0.date == today }
        return VStack(alignment: .leading, spacing: 14) {
            Text("WEIGHT")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(HabitsColor.textSecondary)
            if let entry {
                Text("\(entry.value_lbs, specifier: "%.1f") lbs")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(HabitsColor.textPrimary)
                Button("Edit") { showWeightSheet = true }
                    .buttonStyle(HabitsGhostButtonStyle())
            } else {
                Button("Log Weight") { showWeightSheet = true }
                    .buttonStyle(HabitsPrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .habitsCard()
    }

    // MARK: - Sheets

    private var logActivitySheet: some View {
        NavigationStack {
            List {
                let suggestedID = viewModel.suggested?.id
                ForEach(viewModel.activeWorkoutList.filter { $0.id != suggestedID }) { workout in
                    Button {
                        showLogActivitySheet = false
                        Task { await viewModel.logWorkout(workout) }
                    } label: {
                        Label(workout.name, systemImage: workout.icon)
                    }
                }
                Button {
                    showLogActivitySheet = false
                    showSkipSheet = true
                } label: {
                    Label("Rest Day", systemImage: "moon.fill")
                }
                Button {
                    showLogActivitySheet = false
                    showOtherActivitySheet = true
                } label: {
                    Label("Other activity…", systemImage: "bolt.fill")
                }
            }
            .navigationTitle("Log Activity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showLogActivitySheet = false }
                }
            }
        }
    }

    private var skipSheet: some View {
        SkipReasonSheet(
            defaultChips: RecentChipsStore.load(RecentChipsStore.skipReasonsKey).isEmpty
                ? RecentChipsStore.defaultSkipReasons
                : RecentChipsStore.load(RecentChipsStore.skipReasonsKey)
        ) { reason in
            showSkipSheet = false
            Task { await viewModel.logSkip(reason: reason) }
        } onCancel: {
            showSkipSheet = false
        }
    }

    private var otherActivitySheet: some View {
        OtherActivitySheet(
            chips: RecentChipsStore.load(RecentChipsStore.otherActivitiesKey)
        ) { name in
            showOtherActivitySheet = false
            Task { await viewModel.logOtherActivity(name) }
        } onCancel: {
            showOtherActivitySheet = false
        }
    }

    private var journalSheet: some View {
        JournalEditorSheet(
            existing: viewModel.todayJournalEntry,
            checkSimilarity: { viewModel.checkGratitudeSimilarity($0) },
            onSave: { intention, gratitude, oneThing, confirmed in
                await viewModel.saveJournal(intention: intention, gratitude: gratitude, oneThing: oneThing, confirmed: confirmed)
            },
            onDone: { showJournalSheet = false }
        )
    }

    private var weightSheet: some View {
        let today = TodayViewModel.todayStr()
        let existing = weightViewModel.entries.first { $0.date == today }
        return NavigationStack {
            WeightQuickEntryForm(existingValue: existing?.value_lbs) { pounds in
                Task {
                    await weightViewModel.addManualEntry(date: Date(), pounds: pounds)
                    showWeightSheet = false
                }
            }
            .navigationTitle("Log Weight")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showWeightSheet = false }
                }
            }
        }
    }
}

// MARK: - Skip reason sheet

private struct SkipReasonSheet: View {
    let defaultChips: [String]
    let onConfirm: (String?) -> Void
    let onCancel: () -> Void

    @State private var reason = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ChipFlow(chips: defaultChips) { reason = $0 }
                }
                Section("Reason (optional)") {
                    TextField("e.g. Sick", text: $reason)
                }
            }
            .navigationTitle("Rest Day")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log Day Off") {
                        onConfirm(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reason)
                    }
                }
            }
        }
    }
}

// MARK: - Other activity sheet

private struct OtherActivitySheet: View {
    let chips: [String]
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                if !chips.isEmpty {
                    Section {
                        ChipFlow(chips: chips) { name = $0 }
                    }
                }
                Section("Activity") {
                    TextField("e.g. Hiked", text: $name)
                }
            }
            .navigationTitle("Other Activity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { onConfirm(name) }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ChipFlow: View {
    let chips: [String]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(chips, id: \.self) { chip in
                    Button(chip) { onTap(chip) }
                        .buttonStyle(HabitsChipButtonStyle())
                }
            }
        }
    }
}

// MARK: - Journal editor sheet

private struct JournalEditorSheet: View {
    let existing: JournalRow?
    let checkSimilarity: (String) -> Bool
    let onSave: (String, String, String, Bool) async -> TodayViewModel.JournalSaveResult
    let onDone: () -> Void

    @State private var intention = ""
    @State private var gratitude = ""
    @State private var oneThing = ""
    @State private var showNudge = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Intention") {
                    TextField("What's your intention today?", text: $intention, axis: .vertical)
                }
                Section("Gratitude") {
                    TextField("What are you grateful for?", text: $gratitude, axis: .vertical)
                }
                Section("One thing") {
                    TextField("One thing you want to remember", text: $oneThing, axis: .vertical)
                }
                if showNudge {
                    Section {
                        Text("You wrote something similar within the past week. Save anyway?")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Save anyway") { Task { await save(confirmed: true) } }
                            Button("Change it") { showNudge = false }
                        }
                    }
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDone)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save(confirmed: false) } }
                        .disabled(isSaving)
                }
            }
            .onAppear {
                intention = existing?.intention ?? ""
                gratitude = existing?.gratitude ?? ""
                oneThing = existing?.one_thing ?? ""
            }
        }
    }

    private func save(confirmed: Bool) async {
        isSaving = true
        let result = await onSave(intention, gratitude, oneThing, confirmed)
        isSaving = false
        switch result {
        case .saved:
            onDone()
        case .needsGratitudeConfirmation:
            showNudge = true
        case .failed:
            break
        }
    }
}

// MARK: - Weight quick entry

private struct WeightQuickEntryForm: View {
    let existingValue: Double?
    let onSave: (Double) -> Void

    @State private var text = ""

    var body: some View {
        Form {
            TextField("Weight (lbs)", text: $text)
                .keyboardType(.decimalPad)
        }
        .onAppear {
            if let existingValue { text = String(existingValue) }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if let pounds = Double(text) { onSave(pounds) }
                }
                .disabled(Double(text) == nil)
            }
        }
    }
}
