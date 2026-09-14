//
//  AuthViewModel.swift
//  Habits
//

import Foundation
import Combine
import Supabase

/// The redirect Supabase sends the user back to after a password-reset
/// email link — a custom URL scheme registered in the Xcode target's Info
/// tab (URL Types) and added to Supabase's Auth "Additional Redirect URLs".
/// Mirrors the web app's `resetPasswordForEmail` redirect, just landing back
/// in the app instead of the browser.
let passwordRecoveryRedirectURL = URL(string: "com.chrisaug.habits://login-callback")!

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = true
    @Published var errorMessage: String?
    /// Set when a `.passwordRecovery` auth event fires (user tapped a
    /// password-reset email link). Settings watches this to auto-open the
    /// same password-change sheet used for a normal password change.
    @Published var passwordRecoveryPending = false

    private var authStateTask: Task<Void, Never>?

    init() {
        authStateTask = Task {
            for await (event, session) in SupabaseManager.client.auth.authStateChanges {
                self.session = session
                self.isLoading = false
                if event == .passwordRecovery {
                    self.passwordRecoveryPending = true
                }
            }
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            try await SupabaseManager.client.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = Self.authErrorMessage(error)
        }
    }

    /// Returns true when the account needs email confirmation before it can
    /// sign in (no session came back) — mirrors the web app's signup flow,
    /// which shows "check your email" in that case rather than an error.
    @discardableResult
    func signUp(email: String, password: String) async -> Bool {
        errorMessage = nil
        do {
            let response = try await SupabaseManager.client.auth.signUp(email: email, password: password)
            OnboardingStore.markPending(for: response.user.id)
            if case .session = response { return false }
            return true
        } catch {
            errorMessage = Self.authErrorMessage(error)
            return false
        }
    }

    @discardableResult
    func sendPasswordReset(email: String) async -> Bool {
        errorMessage = nil
        do {
            try await SupabaseManager.client.auth.resetPasswordForEmail(
                email,
                redirectTo: passwordRecoveryRedirectURL
            )
            return true
        } catch {
            errorMessage = Self.authErrorMessage(error)
            return false
        }
    }

    /// Consumes a `com.chrisaug.habits://` deep link (password-reset or
    /// magic-link redirect) and turns it into a session, same as the web
    /// app's browser-based redirect handling.
    func handleDeepLink(_ url: URL) async {
        do {
            try await SupabaseManager.client.auth.session(from: url)
        } catch {
            errorMessage = Self.authErrorMessage(error)
        }
    }

    /// Used for the password-recovery deep-link flow in `ContentView.swift`,
    /// which needs to update the password without a `SettingsViewModel`
    /// around (the recovery sheet can open before Settings is ever visited).
    /// Mirrors `SettingsViewModel.changePassword()`'s normal-change path.
    @discardableResult
    func updatePassword(_ newPassword: String) async -> Bool {
        do {
            _ = try await SupabaseManager.client.auth.update(user: UserAttributes(password: newPassword))
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func signOut() async {
        do {
            try await SupabaseManager.client.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Ports the web app's `authErrorMessage` (auth.js) so sign-in/signup
    /// errors read the same on both platforms instead of raw Supabase text.
    static func authErrorMessage(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("invalid login") || msg.contains("invalid credentials") || msg.contains("wrong password") {
            return "Incorrect email or password"
        }
        if msg.contains("already registered") || msg.contains("user already exists") || msg.contains("already been registered") {
            return "An account with this email already exists"
        }
        if msg.contains("unable to validate email") || (msg.contains("email") && msg.contains("invalid format")) {
            return "Enter a valid email address"
        }
        if msg.contains("password") && (msg.contains("character") || msg.contains("short")) {
            return "Password must be at least 8 characters"
        }
        if msg.contains("rate limit") || msg.contains("too many") || msg.contains("email send rate") {
            return "Too many attempts. Please wait a moment and try again."
        }
        return "Something went wrong. Please try again."
    }
}
