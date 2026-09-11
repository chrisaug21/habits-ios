//
//  AuthViewModel.swift
//  Habits
//

import Foundation
import Combine
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var session: Session?
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var authStateTask: Task<Void, Never>?

    init() {
        authStateTask = Task {
            for await (_, session) in SupabaseManager.client.auth.authStateChanges {
                self.session = session
                self.isLoading = false
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
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await SupabaseManager.client.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
