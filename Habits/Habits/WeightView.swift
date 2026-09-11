//
//  WeightView.swift
//  Habits
//

import SwiftUI

struct WeightView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var viewModel: WeightViewModel
    @StateObject private var reminderViewModel = ReminderViewModel()

    @State private var manualDate = Date()
    @State private var manualWeight = ""
    @State private var showManualEntry = false

    init(userID: UUID) {
        _viewModel = StateObject(wrappedValue: WeightViewModel(userID: userID))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await viewModel.syncFromHealthKit() }
                    } label: {
                        Label(viewModel.isSyncing ? "Syncing..." : "Sync from Health", systemImage: "heart.fill")
                    }
                    .disabled(viewModel.isSyncing)

                    Button {
                        showManualEntry = true
                    } label: {
                        Label("Add Weight Manually", systemImage: "plus")
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Section("Daily Reminder") {
                    Toggle("Remind me to log my weight", isOn: reminderToggleBinding)

                    if reminderViewModel.reminderTime != nil {
                        DatePicker(
                            "Time",
                            selection: reminderTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }

                    if reminderViewModel.isAuthorizationDenied {
                        Text("Notifications are turned off for Habits. Enable them in Settings to get reminders.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if let error = reminderViewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Recent") {
                    if viewModel.entries.isEmpty && !viewModel.isLoading {
                        Text("No weight entries yet")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.entries) { entry in
                        HStack {
                            Text(entry.date)
                            Spacer()
                            Text("\(entry.value_lbs, specifier: "%.1f") lbs")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Weight")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log Out") {
                        Task { await auth.signOut() }
                    }
                }
            }
            .refreshable {
                await viewModel.loadEntries()
            }
            .task {
                await viewModel.loadEntries()
                await reminderViewModel.refreshAuthorizationStatus()
            }
            .sheet(isPresented: $showManualEntry) {
                manualEntrySheet
            }
        }
    }

    private var reminderToggleBinding: Binding<Bool> {
        Binding(
            get: { reminderViewModel.reminderTime != nil },
            set: { isOn in
                if isOn {
                    let defaultTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
                    Task { await reminderViewModel.setReminder(at: defaultTime) }
                } else {
                    reminderViewModel.clearReminder()
                }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { reminderViewModel.reminderTime ?? Date() },
            set: { newValue in
                Task { await reminderViewModel.setReminder(at: newValue) }
            }
        )
    }

    private var manualEntrySheet: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $manualDate, displayedComponents: .date)
                TextField("Weight (lbs)", text: $manualWeight)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Add Weight")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showManualEntry = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let pounds = Double(manualWeight) else { return }
                        let date = manualDate
                        Task {
                            await viewModel.addManualEntry(date: date, pounds: pounds)
                            showManualEntry = false
                            manualWeight = ""
                        }
                    }
                    .disabled(Double(manualWeight) == nil)
                }
            }
        }
    }
}
