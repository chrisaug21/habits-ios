//
//  ReminderViewModel.swift
//  Habits
//

import Foundation
import Combine
import UserNotifications

// Reminder time is a local, on-device preference (UserDefaults) — it only
// controls a local notification on this device, so it doesn't need to be
// synced through Supabase. See SPEC.md.
@MainActor
final class ReminderViewModel: ObservableObject {
    private static let defaultsKey = "weightReminderTime"

    @Published var reminderTime: Date?
    @Published var isAuthorizationDenied = false
    @Published var errorMessage: String?

    init() {
        if let stored = UserDefaults.standard.object(forKey: Self.defaultsKey) as? Date {
            reminderTime = stored
        }
    }

    func refreshAuthorizationStatus() async {
        let status = await ReminderManager.currentAuthorizationStatus()
        isAuthorizationDenied = (status == .denied)
    }

    func setReminder(at time: Date) async {
        errorMessage = nil
        do {
            let granted = try await ReminderManager.requestAuthorization()
            guard granted else {
                isAuthorizationDenied = true
                return
            }
            isAuthorizationDenied = false
            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
            try await ReminderManager.scheduleDailyReminder(at: components)
            reminderTime = time
            UserDefaults.standard.set(time, forKey: Self.defaultsKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearReminder() {
        ReminderManager.cancelReminder()
        reminderTime = nil
        UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
    }
}
