//
//  LoginView.swift
//  Habits
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Habits")
                .font(.largeTitle.bold())

            TextField("Email", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if let error = auth.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Button {
                Task {
                    isSubmitting = true
                    await auth.signIn(email: email, password: password)
                    isSubmitting = false
                }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Log In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || isSubmitting)
        }
        .padding()
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
