//
//  TodayView.swift
//  Habits
//

import SwiftUI

struct TodayView: View {
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
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 0).id(Self.topAnchor)

                    HabitsLogoHeader(showsDate: true)

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

                    HabitsVersionFooter()
                }
                .padding(16)
            }
            .background(HabitsColor.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await weightViewModel.syncFromHealthKit(requestAuthorizationIfNeeded: false)
                await viewModel.loadAll()
                await weightViewModel.loadEntries()
            }
            .task {
                await weightViewModel.syncFromHealthKit(requestAuthorizationIfNeeded: false)
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
            // TabView keeps each tab's ScrollView position across switches
            // (the view isn't recreated) — onAppear does fire every time the
            // tab becomes visible again, so use it to reset to the top
            // rather than leaving the user wherever they last scrolled.
            .onAppear { proxy.scrollTo(Self.topAnchor, anchor: .top) }
            }
        }
        .tint(HabitsColor.accent)
        .preferredColorScheme(.dark)
    }

    private static let topAnchor = "top"

    private func presentSheet(_ present: @escaping () -> Void) {
        runAfterTapFeedback(present)
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

                        Button("Log activity") { presentSheet { showLogActivitySheet = true } }
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
                Button("Edit") { presentSheet { showJournalSheet = true } }
                    .buttonStyle(HabitsGhostButtonStyle())
            } else {
                Button("Journal") { presentSheet { showJournalSheet = true } }
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
                Button("Edit") { presentSheet { showWeightSheet = true } }
                    .buttonStyle(HabitsGhostButtonStyle())
            } else {
                Button("Log Weight") { presentSheet { showWeightSheet = true } }
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
                        .buttonStyle(HabitsRowButtonStyle())
                    }
                    Button {
                        showLogActivitySheet = false
                        showSkipSheet = true
                    } label: {
                        logActivityRow(icon: "moon.fill", title: "Rest Day")
                    }
                    .buttonStyle(HabitsRowButtonStyle())
                    Button {
                        showLogActivitySheet = false
                        showOtherActivitySheet = true
                    } label: {
                        logActivityRow(icon: "bolt.fill", title: "Other activity…")
                    }
                    .buttonStyle(HabitsRowButtonStyle())
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
                    .buttonStyle(HabitsGhostButtonStyle(size: .large))
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
                    .buttonStyle(HabitsGhostButtonStyle(size: .large))
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
    private static let intentionHelpURL = URL(string: "https://health.clevelandclinic.org/how-to-set-intentions")!

    let existing: JournalRow?
    let checkSimilarity: (String) -> Bool
    let onSave: (String, String, String, Bool) async -> TodayViewModel.JournalSaveResult
    let onDone: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var intention = ""
    @State private var gratitude = ""
    @State private var oneThing = ""
    @State private var showNudge = false
    @State private var showIntentionHelp = false
    @State private var isSaving = false
    @FocusState private var focusedField: JournalField?

    private enum JournalField: Hashable {
        case intention, gratitude, oneThing
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Today's Journal")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(HabitsColor.textPrimary)

                journalField(
                    "What's your intention for today?",
                    text: $intention,
                    placeholder: "Enter your intention…",
                    field: .intention
                )
                journalField(
                    "What are you grateful for?",
                    text: $gratitude,
                    placeholder: "Enter what you're grateful for…",
                    field: .gratitude
                )
                journalField(
                    "What's the one thing you'll get done today?",
                    text: $oneThing,
                    placeholder: "Enter your one thing…",
                    field: .oneThing
                )

                if showNudge {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("You mentioned something similar recently — still want to use it?")
                            .font(.system(size: 13))
                            .foregroundStyle(HabitsColor.textSecondary)
                        HStack(spacing: 8) {
                            Button("Yes") { Task { await save(confirmed: true) } }
                                .buttonStyle(HabitsPrimaryButtonStyle())
                            Button("Change it") { showNudge = false }
                                .buttonStyle(HabitsGhostButtonStyle(size: .large))
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
                    Button("Cancel") { runAfterTapFeedback(onDone) }
                        .buttonStyle(HabitsGhostButtonStyle(size: .large))
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
        .sheet(isPresented: $showIntentionHelp) {
            IntentionHelpSheet {
                openURL(Self.intentionHelpURL)
            }
        }
        .onAppear {
            intention = existing?.intention ?? ""
            gratitude = existing?.gratitude ?? ""
            oneThing = existing?.one_thing ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if focusedField == nil {
                    focusedField = .intention
                }
            }
        }
    }

    private func journalField(_ label: String, text: Binding<String>, placeholder: String, field: JournalField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HabitsColor.textSecondary)
                if field == .intention {
                    Button {
                        showIntentionHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HabitsColor.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open intention setting suggestions")
                }
            }
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(3...6)
                .foregroundStyle(HabitsColor.textPrimary)
                .tint(HabitsColor.accent)
                .focused($focusedField, equals: field)
                .padding(14)
                .background(HabitsColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(HabitsColor.border, lineWidth: 1)
                )
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

private struct IntentionHelpSheet: View {
    let onOpenLearnMore: () -> Void

    private let examples = [
        "I will move through today with patience.",
        "I will focus on one meaningful thing at a time.",
        "I will be present with the people in front of me.",
        "I will notice what gives me energy.",
        "I will meet setbacks with curiosity instead of judgment.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(HabitsColor.accent)
                    Text("Intention ideas")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(HabitsColor.textPrimary)
                }

                Text("An intention is less about what you will finish and more about how you want to show up today.")
                    .font(.system(size: 14))
                    .foregroundStyle(HabitsColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(examples, id: \.self) { example in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(HabitsColor.accent)
                                .padding(.top, 1)
                            Text(example)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(HabitsColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(14)
                .background(HabitsColor.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(HabitsColor.border, lineWidth: 1)
                )

                Button {
                    onOpenLearnMore()
                } label: {
                    Label("Learn more", systemImage: "safari")
                }
                .buttonStyle(HabitsGhostButtonStyle(size: .large))
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .habitsSheet(detents: [.medium, .large])
    }
}

// MARK: - Weight quick entry

private struct WeightQuickEntryForm: View {
    let existingValue: Double?
    let onSave: (Double) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @FocusState private var isWeightFieldFocused: Bool

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
                    .focused($isWeightFieldFocused)
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
                Button("Cancel") { runAfterTapFeedback(onCancel) }
                    .buttonStyle(HabitsGhostButtonStyle(size: .large))
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
        .habitsSheet(detents: [.height(230)])
        .onAppear {
            if let existingValue { text = String(existingValue) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isWeightFieldFocused = true
            }
        }
    }
}
