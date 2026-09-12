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
                        HabitsPill(text: lastDoneText(days), tone: .forDaysSince(days), showsCheck: days == 0)
                    } else {
                        HabitsPill(text: "Never done", tone: .forDaysSince(nil))
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
                HabitsPill(text: lastDoneText(days), tone: .forDaysSince(days), showsCheck: days == 0)
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
        let suggestedID = viewModel.suggested?.id
        return ScrollView {
            VStack(spacing: 16) {
                Text("Log activity")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(HabitsColor.textPrimary)
                VStack(spacing: 8) {
                    ForEach(viewModel.activeWorkoutList.filter { $0.id != suggestedID }) { workout in
                        Button {
                            showLogActivitySheet = false
                            Task { await viewModel.logWorkout(workout) }
                        } label: {
                            logActivityRow(icon: workout.icon, title: workout.name)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        showLogActivitySheet = false
                        showSkipSheet = true
                    } label: {
                        logActivityRow(icon: "moon.fill", title: "Rest Day")
                    }
                    .buttonStyle(.plain)
                    Button {
                        showLogActivitySheet = false
                        showOtherActivitySheet = true
                    } label: {
                        logActivityRow(icon: "bolt.fill", title: "Other activity…")
                    }
                    .buttonStyle(.plain)
                }
                Button("Cancel") { showLogActivitySheet = false }
                    .buttonStyle(HabitsGhostButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .habitsSheet(detents: [.medium, .large])
    }

    private func logActivityRow(icon: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(HabitsColor.textSecondary)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(HabitsColor.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(HabitsColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HabitsColor.border, lineWidth: 1)
        )
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
        return WeightQuickEntryForm(existingValue: existing?.value_lbs) { pounds in
            Task {
                await weightViewModel.addManualEntry(date: Date(), pounds: pounds)
                showWeightSheet = false
            }
        } onCancel: {
            showWeightSheet = false
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
        VStack(spacing: 16) {
            Image(systemName: "moon.fill")
                .font(.system(size: 28))
                .foregroundStyle(HabitsColor.amber)
            Text("Rest Day")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(HabitsColor.textPrimary)
            ChipFlow(chips: defaultChips) { reason = $0 }
            HabitsTextField(placeholder: "Reason (optional)", text: $reason)
            HStack(spacing: 10) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(HabitsGhostButtonStyle())
                Button("Skip Today") {
                    onConfirm(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reason)
                }
                .buttonStyle(HabitsPrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .habitsSheet()
    }
}

// MARK: - Other activity sheet

private struct OtherActivitySheet: View {
    let chips: [String]
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var name = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Log Other Activity")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(HabitsColor.textPrimary)
            if !chips.isEmpty {
                ChipFlow(chips: chips) { name = $0 }
            }
            HabitsTextField(placeholder: "Activity name…", text: $name)
            HStack(spacing: 10) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(HabitsGhostButtonStyle())
                Button("Log It") { onConfirm(name) }
                    .buttonStyle(HabitsPrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .habitsSheet()
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
        ScrollView {
            VStack(spacing: 16) {
                Text("Today's Journal")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(HabitsColor.textPrimary)

                journalField("What's your intention for today?", text: $intention, placeholder: "Enter your intention…")
                journalField("What are you grateful for?", text: $gratitude, placeholder: "Enter what you're grateful for…")
                journalField("What's the one thing you'll get done today?", text: $oneThing, placeholder: "Enter your one thing…")

                if showNudge {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("You mentioned something similar recently — still want to use it?")
                            .font(.system(size: 13))
                            .foregroundStyle(HabitsColor.textSecondary)
                        HStack(spacing: 8) {
                            Button("Yes") { Task { await save(confirmed: true) } }
                                .buttonStyle(HabitsPrimaryButtonStyle())
                            Button("Change it") { showNudge = false }
                                .buttonStyle(HabitsGhostButtonStyle())
                        }
                    }
                    .padding(14)
                    .background(HabitsColor.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(HabitsColor.accent.opacity(0.25), lineWidth: 1)
                    )
                }

                HStack(spacing: 10) {
                    Button("Cancel", action: onDone)
                        .buttonStyle(HabitsGhostButtonStyle())
                    Button("Save") { Task { await save(confirmed: false) } }
                        .buttonStyle(HabitsPrimaryButtonStyle())
                        .disabled(isSaving)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .habitsSheet(detents: [.large])
        .onAppear {
            intention = existing?.intention ?? ""
            gratitude = existing?.gratitude ?? ""
            oneThing = existing?.one_thing ?? ""
        }
    }

    private func journalField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HabitsColor.textSecondary)
            HabitsTextArea(placeholder: placeholder, text: text)
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
    let onCancel: () -> Void

    @State private var text = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Log Weight")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(HabitsColor.textPrimary)
            HStack(spacing: 10) {
                TextField("0.0", text: $text)
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
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(HabitsColor.border, lineWidth: 1)
            )
            HStack(spacing: 10) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(HabitsGhostButtonStyle())
                Button("Save") {
                    if let pounds = Double(text) { onSave(pounds) }
                }
                .buttonStyle(HabitsPrimaryButtonStyle())
                .disabled(Double(text) == nil)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .habitsSheet()
        .onAppear {
            if let existingValue { text = String(existingValue) }
        }
    }
}
