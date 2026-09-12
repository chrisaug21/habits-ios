//
//  SettingsView.swift
//  Habits
//
//  Replaces the old Weight tab now that weight history lives in Log's
//  calendar and daily entry lives on Today's weight card. Phase 8 (see
//  SPEC.md's Settings addendum) filled this in with Account, Today Tab
//  toggles, feedback, and account deletion — HealthKit sync, the reminder
//  toggle, and Sign Out were already here. The workout sequence builder and
//  onboarding replay are later passes.
//

import SwiftUI
import Auth

struct SettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var weightViewModel: WeightViewModel
    @StateObject private var reminderViewModel = ReminderViewModel()
    @State private var showDeleteConfirmation = false

    init(userID: UUID) {
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(userID: userID))
        _weightViewModel = StateObject(wrappedValue: WeightViewModel(userID: userID))
    }

    private var currentUser: User? { auth.session?.user }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    LabeledContent("Email", value: currentUser?.email ?? "-")

                    TextField("First name", text: $settingsViewModel.firstName)
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)
                    TextField("Last name", text: $settingsViewModel.lastName)
                        .textContentType(.familyName)
                        .textInputAutocapitalization(.words)

                    Button {
                        Task { await settingsViewModel.saveProfile(existingMetadata: currentUser?.userMetadata ?? [:]) }
                    } label: {
                        Text(settingsViewModel.isSavingProfile ? "Saving..." : "Save Profile")
                    }
                    .buttonBorderShape(.roundedRectangle)
                    .disabled(settingsViewModel.isSavingProfile)

                    if let message = settingsViewModel.profileMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Change Password") {
                    SecureField("At least 8 characters", text: $settingsViewModel.newPassword)
                        .textContentType(.newPassword)

                    Button {
                        Task { await settingsViewModel.changePassword() }
                    } label: {
                        Text(settingsViewModel.isSavingPassword ? "Updating..." : "Update Password")
                    }
                    .buttonBorderShape(.roundedRectangle)
                    .disabled(settingsViewModel.isSavingPassword || settingsViewModel.newPassword.isEmpty)

                    if let error = settingsViewModel.passwordErrorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    if let success = settingsViewModel.passwordSuccessMessage {
                        Text(success).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("Today Tab") {
                    Toggle("Show Workout card", isOn: workoutCardBinding)
                    Toggle("Show Journal card", isOn: journalCardBinding)
                    Toggle("Show Weight card", isOn: weightCardBinding)

                    if let error = settingsViewModel.preferencesErrorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }

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

                Section("App") {
                    Link(destination: feedbackURL) {
                        Text("Send Feedback")
                    }
                }

                Section {
                    Button("Log Out") {
                        Task { await auth.signOut() }
                    }
                    .buttonBorderShape(.roundedRectangle)
                    .foregroundStyle(.red)
                }

                Section {
                    Button("Delete Account", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .disabled(settingsViewModel.isDeletingAccount)

                    if let error = settingsViewModel.deleteErrorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("This will permanently delete all your data. This cannot be undone.")
                }

                Section {
                    HabitsVersionFooter(color: .secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .navigationTitle("Settings")
            .task {
                settingsViewModel.loadProfile(from: currentUser?.userMetadata ?? [:])
                await settingsViewModel.loadPreferences()
                await reminderViewModel.refreshAuthorizationStatus()
            }
            .alert("Delete account?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Everything", role: .destructive) {
                    Task {
                        let displayName = [settingsViewModel.firstName, settingsViewModel.lastName]
                            .filter { !$0.isEmpty }
                            .joined(separator: " ")
                        let deleted = await settingsViewModel.deleteAccount(
                            email: currentUser?.email,
                            displayName: displayName.isEmpty ? nil : displayName,
                            existingMetadata: currentUser?.userMetadata ?? [:]
                        )
                        if deleted {
                            await auth.signOut()
                        }
                    }
                }
            } message: {
                Text("This will permanently delete all your data. This cannot be undone.")
            }
        }
    }

    private var feedbackURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "cg.augustine@gmail.com"
        components.queryItems = [URLQueryItem(name: "subject", value: "Ondoloop Feedback")]
        return components.url ?? URL(string: "mailto:cg.augustine@gmail.com")!
    }

    private var workoutCardBinding: Binding<Bool> {
        Binding(
            get: { settingsViewModel.preferences.show_workout_card },
            set: { newValue in
                Task { await settingsViewModel.updatePreference { $0.show_workout_card = newValue } }
            }
        )
    }

    private var journalCardBinding: Binding<Bool> {
        Binding(
            get: { settingsViewModel.preferences.show_journal_card },
            set: { newValue in
                Task { await settingsViewModel.updatePreference { $0.show_journal_card = newValue } }
            }
        )
    }

    private var weightCardBinding: Binding<Bool> {
        Binding(
            get: { settingsViewModel.preferences.show_weight_card },
            set: { newValue in
                Task { await settingsViewModel.updatePreference { $0.show_weight_card = newValue } }
            }
        )
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
