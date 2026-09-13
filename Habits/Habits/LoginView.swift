//
//  LoginView.swift
//  Habits
//
//  Sign in / create account, styled to match the rest of the app
//  (HabitsColor dark theme) instead of default system styling. Fields,
//  validation, and error copy mirror the web app's auth.js/index.html
//  (login-panel/signup-panel, `authErrorMessage`) — one shared screen that
//  toggles between modes rather than two separate DOM panels, and without
//  web's marketing hero/feature-grid/quote card, which doesn't fit a screen
//  someone reaches only after already installing the app.
//

import SwiftUI

private enum AuthMode {
    case signIn, signUp
}

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var passwordFieldError: String?
    @State private var infoMessage: String?

    private var isPasswordTooShort: Bool {
        mode == .signUp && !password.isEmpty && password.count < 8
    }

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !isSubmitting && !isPasswordTooShort
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Vertical lockup-with-descriptor variant, tried here (ondark)
                // vs. the plain white variant on onboarding's last step, per
                // request, so both can be compared in context.
                Image("OndoloopLockupOndark")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 90)
                    .padding(.horizontal, 40)
                    .padding(.top, 32)

                if mode == .signUp {
                    Text("A personal daily habits tracker. Build the systems that make a healthy life feel automatic.")
                        .font(.system(size: 14))
                        .foregroundStyle(HabitsColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    HabitsTextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HabitsSecureField(
                        placeholder: mode == .signUp ? "Password (min 8 characters)" : "Password",
                        text: $password
                    )
                    .textContentType(mode == .signUp ? .newPassword : .password)

                    if isPasswordTooShort {
                        Text("Password must be at least 8 characters")
                            .font(.system(size: 12))
                            .foregroundStyle(HabitsColor.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if mode == .signIn {
                        HStack {
                            Spacer()
                            Button("Forgot password?") { Task { await sendPasswordReset() } }
                                .buttonStyle(.plain)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(HabitsColor.accent)
                        }
                    }

                    if let infoMessage {
                        Text(infoMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(HabitsColor.green)
                    }

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(HabitsColor.red)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text(mode == .signUp ? "Create Account" : "Sign In")
                        }
                    }
                    .buttonStyle(HabitsPrimaryButtonStyle())
                    .disabled(!canSubmit)
                    .padding(.top, 4)

                    Button(mode == .signUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                        switchMode()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HabitsColor.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

                HabitsVersionFooter()
            }
        }
        .background(HabitsColor.bg.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .preferredColorScheme(.dark)
    }

    private func switchMode() {
        mode = mode == .signUp ? .signIn : .signUp
        auth.errorMessage = nil
        infoMessage = nil
        password = ""
    }

    private func submit() async {
        auth.errorMessage = nil
        infoMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        if mode == .signIn {
            await auth.signIn(email: email, password: password)
        } else {
            let needsConfirmation = await auth.signUp(email: email, password: password)
            if needsConfirmation {
                infoMessage = "Account created! Check your email to confirm before signing in."
            }
        }
    }

    private func sendPasswordReset() async {
        auth.errorMessage = nil
        infoMessage = nil
        guard !email.isEmpty else {
            auth.errorMessage = "Enter your email first"
            return
        }
        if await auth.sendPasswordReset(email: email) {
            infoMessage = "Password reset email sent"
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
