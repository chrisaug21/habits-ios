//
//  ContentView.swift
//  Habits
//
//  Created by Chris Augustine on 9/11/26.
//

import SwiftUI
import Auth

struct ContentView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView()
            } else if auth.session != nil {
                SignedInView()
            } else {
                LoginView()
            }
        }
    }
}

private struct SignedInView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var showOnboarding = false
    @State private var showPasswordRecoverySheet = false
    @State private var recoveryPassword = ""
    @State private var isSavingRecoveryPassword = false
    @State private var recoveryPasswordErrorMessage: String?

    var body: some View {
        if let userID = auth.session?.user.id {
            TabView {
                TodayView(userID: userID)
                    .tabItem { Label("Today", systemImage: "sun.max.fill") }
                LogView(userID: userID)
                    .tabItem { Label("Log", systemImage: "calendar") }
                StatsView(userID: userID)
                    .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                SettingsView(userID: userID)
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            .onAppear {
                // Mirrors the web app's `hasPendingWelcome() && !hasDismissedWelcome()`
                // check on initApp — shows the FTUX once per account, right
                // after signup, the first time this device sees it signed in.
                showOnboarding = OnboardingStore.hasPendingWelcome(for: userID)
                    && !OnboardingStore.hasDismissedWelcome(for: userID)
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(userID: userID, mode: .firstRun) {
                    showOnboarding = false
                }
            }
            // Handled here rather than inside SettingsView: a `.passwordRecovery`
            // auth event (from tapping the reset-password email's deep link)
            // can fire before SettingsView has ever been mounted — TabView
            // only builds a tab's view the first time it's visited — and
            // `.onChange` doesn't fire retroactively for a value that was
            // already `true` when the modifier first attached. SignedInView
            // is guaranteed to exist the moment a session appears, so
            // `initial: true` here reliably catches a flag that flipped
            // before this view (or the Settings tab) ever appeared.
            .onChange(of: auth.passwordRecoveryPending, initial: true) {
                guard auth.passwordRecoveryPending else { return }
                auth.passwordRecoveryPending = false
                showPasswordRecoverySheet = true
            }
            .sheet(isPresented: $showPasswordRecoverySheet, onDismiss: {
                recoveryPassword = ""
                recoveryPasswordErrorMessage = nil
            }) {
                PasswordChangeSheet(
                    newPassword: $recoveryPassword,
                    isSaving: isSavingRecoveryPassword,
                    errorMessage: recoveryPasswordErrorMessage,
                    onSave: {
                        await saveRecoveryPassword()
                    },
                    onCancel: { showPasswordRecoverySheet = false }
                )
            }
        }
    }

    private func saveRecoveryPassword() async {
        guard recoveryPassword.count >= 8 else {
            recoveryPasswordErrorMessage = "Password must be at least 8 characters"
            return
        }
        recoveryPasswordErrorMessage = nil
        isSavingRecoveryPassword = true
        if await auth.updatePassword(recoveryPassword) {
            showPasswordRecoverySheet = false
        } else {
            recoveryPasswordErrorMessage = auth.errorMessage
        }
        isSavingRecoveryPassword = false
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
