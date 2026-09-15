//
//  SettingsViewModel.swift
//  Habits
//

import Foundation
import Combine
import Supabase
import Auth

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var isSavingProfile = false
    @Published var profileMessage: String?

    @Published var newPassword: String = ""
    @Published var isSavingPassword = false
    @Published var passwordErrorMessage: String?
    @Published var passwordSuccessMessage: String?

    @Published var preferences = UserPreferencesRow.defaults
    @Published var isLoadingPreferences = false
    @Published var preferencesErrorMessage: String?

    @Published var isDeletingAccount = false
    @Published var deleteErrorMessage: String?

    private let userID: UUID

    init(userID: UUID) {
        self.userID = userID
    }

    func loadProfile(from metadata: [String: AnyJSON]) {
        firstName = metadata["first_name"]?.stringValue ?? ""
        lastName = metadata["last_name"]?.stringValue ?? ""
    }

    // Auth's `data` field replaces the whole user_metadata object server-side
    // (no deep merge), so callers must pass the existing metadata to preserve
    // any fields this screen doesn't know about — matches the web app's
    // `{...deps.getUserMetadata(), first_name, last_name}` spread.
    func saveProfile(existingMetadata: [String: AnyJSON]) async {
        isSavingProfile = true
        profileMessage = nil
        var metadata = existingMetadata
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)
        metadata["first_name"] = trimmedFirst.isEmpty ? nil : .string(trimmedFirst)
        metadata["last_name"] = trimmedLast.isEmpty ? nil : .string(trimmedLast)
        do {
            _ = try await SupabaseManager.client.auth.update(user: UserAttributes(data: metadata))
            profileMessage = "Profile saved"
        } catch {
            profileMessage = error.localizedDescription
        }
        isSavingProfile = false
    }

    func changePassword() async {
        passwordErrorMessage = nil
        passwordSuccessMessage = nil
        guard newPassword.count >= 8 else {
            passwordErrorMessage = "Password must be at least 8 characters"
            return
        }
        isSavingPassword = true
        do {
            _ = try await SupabaseManager.client.auth.update(user: UserAttributes(password: newPassword))
            newPassword = ""
            passwordSuccessMessage = "Password updated"
        } catch {
            passwordErrorMessage = error.localizedDescription
        }
        isSavingPassword = false
    }

    /// Clears the password sheet's fields whenever it closes, however it
    /// closed (Cancel, a successful save, or swiping it away) — otherwise
    /// whatever was typed is still sitting there the next time it opens.
    func resetPasswordFields() {
        newPassword = ""
        passwordErrorMessage = nil
        passwordSuccessMessage = nil
    }

    func loadPreferences() async {
        isLoadingPreferences = true
        preferencesErrorMessage = nil
        do {
            let rows: [UserPreferencesRow] = try await SupabaseManager.client
                .from("user_preferences")
                .select("show_workout_card, show_journal_card, show_weight_card")
                .eq("user_id", value: userID)
                .limit(1)
                .execute()
                .value
            preferences = rows.first ?? .defaults
        } catch {
            preferencesErrorMessage = error.localizedDescription
        }
        isLoadingPreferences = false
    }

    /// Optimistically applies `change`, then persists it — reverting to the
    /// server's value if the upsert fails, same pattern as a toggle that
    /// shouldn't visually lag behind the tap that triggered it.
    func updatePreference(_ change: (inout UserPreferencesRow) -> Void) async {
        var updated = preferences
        change(&updated)
        preferences = updated
        let payload = UserPreferencesUpsertPayload(
            user_id: userID,
            show_workout_card: updated.show_workout_card,
            show_journal_card: updated.show_journal_card,
            show_weight_card: updated.show_weight_card
        )
        do {
            try await SupabaseManager.client
                .from("user_preferences")
                .upsert(payload, onConflict: "user_id")
                .execute()
        } catch {
            preferencesErrorMessage = error.localizedDescription
            await loadPreferences()
        }
    }

    private static let accountDeletionURL = URL(string: "https://habits.chrisaug.com/.netlify/functions/delete-account")!

    // True account deletion needs a server-side service-role key; the iOS app
    // only sends the user's normal access token to the Netlify function.
    func deleteAccount(accessToken: String?) async -> Bool {
        isDeletingAccount = true
        deleteErrorMessage = nil
        defer { isDeletingAccount = false }

        guard let accessToken, !accessToken.isEmpty else {
            deleteErrorMessage = "Could not confirm your signed-in session. Please sign in again and retry."
            return false
        }

        do {
            var request = URLRequest(url: Self.accountDeletionURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("0", forHTTPHeaderField: "Content-Length")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                deleteErrorMessage = "Could not delete account. Please try again."
                return false
            }

            guard (200..<300).contains(http.statusCode) else {
                deleteErrorMessage = Self.accountDeletionErrorMessage(from: data) ?? "Could not delete account. Please try again."
                return false
            }

            return true
        } catch {
            deleteErrorMessage = error.localizedDescription
            return false
        }
    }

    private static func accountDeletionErrorMessage(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = object["error"] as? String,
            !error.isEmpty
        else {
            return nil
        }
        return error
    }
}
