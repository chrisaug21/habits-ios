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
//  Styled to match Today/Log/Stats (HabitsColor cards on a dark background)
//  rather than a plain system List — see the web app's settings.js for the
//  interaction this mirrors: password change as its own sheet overlay
//  (`password-modal`), not inline fields on the main page.
//

import SwiftUI
import Auth

struct SettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var weightViewModel: WeightViewModel
    @StateObject private var reminderViewModel = ReminderViewModel()
    @StateObject private var rotationBuilderViewModel: RotationBuilderViewModel
    @State private var showDeleteConfirmation = false
    @State private var showPasswordSheet = false
    @State private var showSequenceBuilder = false
    @State private var showProgramReset = false
    @State private var showTutorial = false
    @State private var pendingBuildOwn = false
    @Environment(\.openURL) private var openURL
    private let userID: UUID

    init(userID: UUID) {
        self.userID = userID
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(userID: userID))
        _weightViewModel = StateObject(wrappedValue: WeightViewModel(userID: userID))
        _rotationBuilderViewModel = StateObject(wrappedValue: RotationBuilderViewModel(userID: userID))
    }

    private var currentUser: User? { auth.session?.user }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 0).id(Self.topAnchor)

                    HabitsLogoHeader()

                    accountCard
                    todayTabCard
                    WorkoutSequenceCard(
                        viewModel: rotationBuilderViewModel,
                        showBuilder: $showSequenceBuilder,
                        showProgramReset: $showProgramReset
                    )
                    weightCard
                    reminderCard
                    appCard
                    signOutButton
                    dangerZoneCard
                    HabitsVersionFooter()
                }
                .padding(16)
            }
            .background(HabitsColor.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { dismissKeyboard() }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                settingsViewModel.loadProfile(from: currentUser?.userMetadata ?? [:])
                await settingsViewModel.loadPreferences()
                await reminderViewModel.refreshAuthorizationStatus()
                await rotationBuilderViewModel.loadInitial()
            }
            .sheet(isPresented: $showPasswordSheet, onDismiss: settingsViewModel.resetPasswordFields) {
                passwordSheet
            }
            .fullScreenCover(isPresented: $showTutorial) {
                OnboardingView(userID: userID, mode: .tutorial) {
                    showTutorial = false
                }
            }
            .sheet(isPresented: $showSequenceBuilder, onDismiss: rotationBuilderViewModel.closeBuilder) {
                RotationBuilderSheet(viewModel: rotationBuilderViewModel) {
                    showSequenceBuilder = false
                }
            }
            .sheet(isPresented: $showProgramReset, onDismiss: {
                // Runs after the reset sheet's own dismiss animation
                // finishes — presenting the builder sheet before that
                // completes can drop its transition.
                guard pendingBuildOwn else { return }
                pendingBuildOwn = false
                rotationBuilderViewModel.openBuilder()
                showSequenceBuilder = true
            }) {
                ProgramResetSheet(
                    viewModel: rotationBuilderViewModel,
                    onDismiss: { showProgramReset = false },
                    onBuildOwn: {
                        pendingBuildOwn = true
                        showProgramReset = false
                    }
                )
            }
            .alert("Delete account?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Everything", role: .destructive) {
                    Task {
                        let deleted = await settingsViewModel.deleteAccount(accessToken: auth.session?.accessToken)
                        if deleted {
                            await auth.clearLocalSessionAfterAccountDeletion()
                        }
                    }
                }
            } message: {
                Text("This will permanently delete all your data. This cannot be undone.")
            }
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

    // MARK: - Keyboard

    /// Tapping anywhere outside a text field (the name fields are the only
    /// ones on this screen) should drop the keyboard — SwiftUI has no
    /// built-in "tap away to resign" for a plain `TextField`.
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - Section label

    private func sectionEyebrow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(HabitsColor.textSecondary)
    }

    // MARK: - Account

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                avatarView
                VStack(alignment: .leading, spacing: 2) {
                    Text("SIGNED IN AS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(HabitsColor.textDim)
                    Text(currentUser?.email ?? "-")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(HabitsColor.textPrimary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                HabitsTextField(placeholder: "First name", text: $settingsViewModel.firstName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                HabitsTextField(placeholder: "Last name", text: $settingsViewModel.lastName)
                    .textContentType(.familyName)
                    .textInputAutocapitalization(.words)
            }

            Button {
                Task { await settingsViewModel.saveProfile(existingMetadata: currentUser?.userMetadata ?? [:]) }
            } label: {
                Text(settingsViewModel.isSavingProfile ? "Saving..." : "Save Profile")
            }
            .buttonStyle(HabitsPrimaryButtonStyle())
            .disabled(settingsViewModel.isSavingProfile)

            if let message = settingsViewModel.profileMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(HabitsColor.textSecondary)
            }
        }
        .habitsCard()
    }

    private var avatarView: some View {
        Text(avatarInitial)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(HabitsColor.accent)
            .clipShape(Circle())
    }

    private var avatarInitial: String {
        guard let first = currentUser?.email?.first else { return "?" }
        return String(first).uppercased()
    }

    // MARK: - Today Tab toggles

    private var todayTabCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionEyebrow("TODAY TAB")
            VStack(spacing: 12) {
                Toggle("Show Workout card", isOn: workoutCardBinding)
                Toggle("Show Journal card", isOn: journalCardBinding)
                Toggle("Show Weight card", isOn: weightCardBinding)
            }
            .foregroundStyle(HabitsColor.textPrimary)
            .font(.system(size: 15, weight: .semibold))

            if let error = settingsViewModel.preferencesErrorMessage {
                Text(error).font(.system(size: 12)).foregroundStyle(HabitsColor.red)
            }
        }
        .habitsCard()
    }

    // MARK: - Weight (HealthKit sync)

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionEyebrow("WEIGHT")
            Button {
                Task { await weightViewModel.syncFromHealthKit() }
            } label: {
                Label(weightViewModel.isSyncing ? "Syncing..." : "Sync from Health", systemImage: "heart.fill")
            }
            .buttonStyle(HabitsGhostButtonStyle(size: .large))
            .disabled(weightViewModel.isSyncing)

            if let error = weightViewModel.errorMessage {
                Text(error).font(.system(size: 12)).foregroundStyle(HabitsColor.red)
            }
        }
        .habitsCard()
    }

    // MARK: - Daily Reminder

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionEyebrow("DAILY REMINDER")

            Toggle("Remind me to log my weight", isOn: reminderToggleBinding)
                .foregroundStyle(HabitsColor.textPrimary)
                .font(.system(size: 15, weight: .semibold))

            if reminderViewModel.reminderTime != nil {
                DatePicker(
                    "Time",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .foregroundStyle(HabitsColor.textPrimary)
                .font(.system(size: 15, weight: .semibold))
            }

            if reminderViewModel.isAuthorizationDenied {
                Text("Notifications are turned off for Ondoloop. Enable them in Settings to get reminders.")
                    .font(.system(size: 12))
                    .foregroundStyle(HabitsColor.red)
                Button("Open Settings") {
                    runAfterTapFeedback {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            openURL(settingsURL)
                        }
                    }
                }
                .buttonStyle(HabitsGhostButtonStyle(size: .large))
            }

            if let error = reminderViewModel.errorMessage {
                Text(error).font(.system(size: 12)).foregroundStyle(HabitsColor.red)
            }
        }
        .habitsCard()
    }

    // MARK: - App (password + feedback)

    private var appCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionEyebrow("APP")
            Button("Tutorial") { runAfterTapFeedback { showTutorial = true } }
                .buttonStyle(HabitsGhostButtonStyle(size: .large))
            Button("Change Password") { runAfterTapFeedback { showPasswordSheet = true } }
                .buttonStyle(HabitsGhostButtonStyle(size: .large))
            Button("Privacy Policy") { runAfterTapFeedback { openURL(Self.privacyPolicyURL) } }
                .buttonStyle(HabitsGhostButtonStyle(size: .large))
            Button("Send Feedback") { openURL(feedbackURL) }
                .buttonStyle(HabitsGhostButtonStyle(size: .large))
        }
        .habitsCard()
    }

    private static let privacyPolicyURL = URL(string: "https://habits.chrisaug.com/privacy")!

    private var feedbackURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "cg.augustine@gmail.com"
        components.queryItems = [URLQueryItem(name: "subject", value: "Ondoloop Feedback")]
        return components.url ?? URL(string: "mailto:cg.augustine@gmail.com")!
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        Button("Log Out") {
            Task { await auth.signOut() }
        }
        .buttonStyle(HabitsGhostButtonStyle(size: .large, tint: HabitsColor.red))
    }

    // MARK: - Danger Zone

    private var dangerZoneCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionEyebrow("DANGER ZONE")
                .foregroundStyle(HabitsColor.red.opacity(0.85))

            Text("This will permanently delete all your data. This cannot be undone.")
                .font(.system(size: 13))
                .foregroundStyle(HabitsColor.textPrimary)

            Button("Delete Account") { showDeleteConfirmation = true }
                .buttonStyle(HabitsPrimaryButtonStyle(tint: HabitsColor.red))
                .disabled(settingsViewModel.isDeletingAccount)

            if let error = settingsViewModel.deleteErrorMessage {
                Text(error).font(.system(size: 12)).foregroundStyle(HabitsColor.red)
            }
        }
        .padding(20)
        .background(HabitsColor.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(HabitsColor.red.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Password sheet

    private var passwordSheet: some View {
        PasswordChangeSheet(
            newPassword: $settingsViewModel.newPassword,
            isSaving: settingsViewModel.isSavingPassword,
            errorMessage: settingsViewModel.passwordErrorMessage,
            onSave: {
                await settingsViewModel.changePassword()
                if settingsViewModel.passwordErrorMessage == nil {
                    showPasswordSheet = false
                }
            },
            onCancel: { showPasswordSheet = false }
        )
    }

    // MARK: - Bindings

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

// MARK: - Password change sheet

/// Mirrors the web app's `password-modal` — a dedicated overlay for changing
/// password, rather than inline fields sitting on the main Settings page.
/// Not private: also used from `ContentView.swift`'s `SignedInView` for the
/// password-recovery deep-link flow, which needs to present it regardless of
/// which tab is currently active — see the comment there for why this
/// couldn't just live inside SettingsView.
struct PasswordChangeSheet: View {
    @Binding var newPassword: String
    let isSaving: Bool
    let errorMessage: String?
    let onSave: () async -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Change Password")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(HabitsColor.textPrimary)

            HabitsSecureField(placeholder: "At least 8 characters", text: $newPassword)
                .textContentType(.newPassword)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(HabitsColor.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(HabitsGhostButtonStyle(size: .large))
                Button("Update Password") { Task { await onSave() } }
                    .buttonStyle(HabitsPrimaryButtonStyle())
                    .disabled(isSaving || newPassword.isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        // Small, fixed-content form — a plain .medium detent leaves most of
        // the sheet empty below the buttons, so size it to the content
        // instead of the usual [.medium]/[.large] used by the bigger sheets.
        .habitsSheet(detents: [.height(300)])
    }
}
