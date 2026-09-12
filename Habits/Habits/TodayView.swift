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
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if viewModel.preferences.show_workout_card {
                        workoutCard
                    }
                    if viewModel.preferences.show_journal_card {
                        journalCard
                    }
                    if viewModel.preferences.show_weight_card {
                        weightCard
                    }
                }
                .padding()
            }
            .navigationTitle(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log Out") {
                        Task { await auth.signOut() }
                    }
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
                }
            }
            .sheet(isPresented: $showLogActivitySheet) { logActivitySheet }
            .sheet(isPresented: $showSkipSheet) { skipSheet }
            .sheet(isPresented: $showOtherActivitySheet) { otherActivitySheet }
            .sheet(isPresented: $showJournalSheet) { journalSheet }
            .sheet(isPresented: $showWeightSheet) { weightSheet }
        }
    }

    // MARK: - Workout card

    private var workoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch viewModel.heroState {
            case .defaultNext:
                if let suggested = viewModel.suggested {
                    Label("Next Up Workout", systemImage: "arrow.forward.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Image(systemName: suggested.icon)
                            .font(.title2)
                            .frame(width: 36)
                        VStack(alignment: .leading) {
                            Text(suggested.name).font(.headline)
                            if let days = viewModel.daysSinceLastDone(suggested.id) {
                                Text(lastDoneText(days)).font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("Never done").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    HStack {
                        Button {
                            Task { await viewModel.markDone() }
                        } label: {
                            Label("Done", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isProcessing)

                        Button("Log other activity…") {
                            showLogActivitySheet = true
                        }
                        .disabled(viewModel.isProcessing)
                    }
                }
            case .done, .skipped, .other:
                Label(heroEyebrow, systemImage: heroIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(heroTitle).font(.headline)
                if let label = viewModel.undoLabel {
                    Button {
                        Task { await viewModel.undoLastEntry() }
                    } label: {
                        Label("Undo \(label)", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(viewModel.isProcessing)
                }
            }

            if let tomorrow = viewModel.tomorrowWorkout, viewModel.todayEntry != nil {
                Divider()
                HStack {
                    Text("Tomorrow:").font(.caption).foregroundStyle(.secondary)
                    Image(systemName: tomorrow.icon).font(.caption)
                    Text(tomorrow.name).font(.caption)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var heroEyebrow: String {
        switch viewModel.heroState {
        case .done: return "Completed"
        case .skipped: return "Day Off"
        case .other: return "Other Activity"
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

    private var heroTitle: String {
        switch viewModel.heroState {
        case .skipped: return "Rest Day"
        case .other: return viewModel.todayEntry?.note ?? "Other Activity"
        case .done: return viewModel.heroWorkout?.name ?? "Workout"
        case .defaultNext: return ""
        }
    }

    private func lastDoneText(_ days: Int) -> String {
        days == 0 ? "Today" : "Last done \(days)d ago"
    }

    // MARK: - Journal card

    private var journalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Journal").font(.headline)
            if let entry = viewModel.todayJournalEntry {
                if let intention = entry.intention, !intention.isEmpty {
                    journalField("Intention", intention)
                }
                if let gratitude = entry.gratitude, !gratitude.isEmpty {
                    journalField("Gratitude", gratitude)
                }
                if let oneThing = entry.one_thing, !oneThing.isEmpty {
                    journalField("One thing", oneThing)
                }
                Button("Edit") { showJournalSheet = true }
            } else {
                Button("Journal") { showJournalSheet = true }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func journalField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label + ":").font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline)
        }
    }

    // MARK: - Weight card

    private var weightCard: some View {
        let today = TodayViewModel.todayStr()
        let entry = weightViewModel.entries.first { $0.date == today }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Weight").font(.headline)
            if let entry {
                Text("\(entry.value_lbs, specifier: "%.1f") lbs").font(.title3)
                Button("Edit") { showWeightSheet = true }
            } else {
                Button("Log Weight") { showWeightSheet = true }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
                        .buttonStyle(.bordered)
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
