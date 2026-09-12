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

    // Mirrors the web app's actual fallback (see SPEC.md): the client's
    // publishable key can't call `auth.admin.deleteUser`, so this deletes the
    // user's rows and flags the account via metadata instead of a true
    // Auth-user delete, which needs a server-side Edge Function (tracked
    // separately under "Before public App Store submission").
    func deleteAccount(email: String?, displayName: String?, existingMetadata: [String: AnyJSON]) async -> Bool {
        isDeletingAccount = true
        deleteErrorMessage = nil
        defer { isDeletingAccount = false }
        do {
            try await SupabaseManager.client.from("history").delete().eq("user_id", value: userID).execute()
            try await SupabaseManager.client.from("journal").delete().eq("user_id", value: userID).execute()
            try await SupabaseManager.client.from("weight").delete().eq("user_id", value: userID).execute()
            try await SupabaseManager.client.from("state").delete().eq("user_id", value: userID).execute()
            try await SupabaseManager.client.from("user_preferences").delete().eq("user_id", value: userID).execute()

            var metadata = existingMetadata
            metadata["deletion_requested_at"] = .string(ISO8601DateFormatter().string(from: Date()))
            metadata["deletion_requested_email"] = email.map { .string($0) }
            metadata["deletion_requested_name"] = displayName.map { .string($0) }
            _ = try await SupabaseManager.client.auth.update(user: UserAttributes(data: metadata))
            return true
        } catch {
            deleteErrorMessage = error.localizedDescription
            return false
        }
    }
}
