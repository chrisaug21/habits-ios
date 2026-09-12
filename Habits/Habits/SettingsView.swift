//
//  SettingsView.swift
//  Habits
//
//  Replaces the old Weight tab now that weight history lives in Log's
//  calendar and daily entry lives on Today's weight card. Keeps the pieces
//  that don't have a home yet — HealthKit sync, the reminder toggle, and
//  Sign Out — as a stub until a real Settings screen gets its own spec pass.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var weightViewModel: WeightViewModel
    @StateObject private var reminderViewModel = ReminderViewModel()

    init(userID: UUID) {
        _weightViewModel = StateObject(wrappedValue: WeightViewModel(userID: userID))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Weight") {
                    Button {
                        Task { await weightViewModel.syncFromHealthKit() }
                    } label: {
                        Label(weightViewModel.isSyncing ? "Syncing..." : "Sync from Health", systemImage: "heart.fill")
                    }
                    .buttonBorderShape(.roundedRectangle)
                    .disabled(weightViewModel.isSyncing)

                    if let error = weightViewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
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

                Section {
                    Button("Log Out") {
                        Task { await auth.signOut() }
                    }
                    .buttonBorderShape(.roundedRectangle)
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
            .task {
                await reminderViewModel.refreshAuthorizationStatus()
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
}
