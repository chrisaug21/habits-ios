//
//  OnboardingViewModel.swift
//  Habits
//
//  Mirrors the web app's FTUX/tutorial tracking (`data.js`'s
//  hasPendingWelcome/hasDismissedWelcome/markWelcomePending/markWelcomeDismissed,
//  keyed `"<userId>:<BASE_WELCOMED_KEY>"` in localStorage) — same per-user
//  pending/dismissed states, stored in UserDefaults instead of localStorage
//  since this is a UI flag, not app data (no Supabase table for it, same as web).
//

import Combine
import Foundation

enum OnboardingStore {
    private static func key(for userID: UUID) -> String {
        "\(userID.uuidString):welcomed"
    }

    static func hasPendingWelcome(for userID: UUID) -> Bool {
        UserDefaults.standard.string(forKey: key(for: userID)) == "pending"
    }

    static func hasDismissedWelcome(for userID: UUID) -> Bool {
        UserDefaults.standard.string(forKey: key(for: userID)) == "1"
    }

    static func markPending(for userID: UUID) {
        UserDefaults.standard.set("pending", forKey: key(for: userID))
    }

    static func markDismissed(for userID: UUID) {
        UserDefaults.standard.set("1", forKey: key(for: userID))
    }
}

enum OnboardingMode {
    /// Shown automatically right after signup — includes the program-picker
    /// step, since there's no sequence saved yet.
    case firstRun
    /// Replayed from Settings' "Tutorial" row — skips the program-picker
    /// step, matching web's `getOnboardingVisibleSteps`.
    case tutorial
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step: Int

    let mode: OnboardingMode
    let userID: UUID

    /// Web's `getOnboardingVisibleSteps` — step 3 (program picker) only
    /// shows on first-run, not on a tutorial replay.
    var visibleSteps: [Int] {
        mode == .tutorial ? [1, 2, 4, 5, 6] : [1, 2, 3, 4, 5, 6]
    }

    var stepIndex: Int {
        (visibleSteps.firstIndex(of: step) ?? 0) + 1
    }

    var isFirstVisibleStep: Bool { stepIndex == 1 }
    var isLastVisibleStep: Bool { stepIndex == visibleSteps.count }

    init(userID: UUID, mode: OnboardingMode) {
        self.userID = userID
        self.mode = mode
        self.step = mode == .tutorial ? 1 : 1
    }

    func goNext() {
        guard let idx = visibleSteps.firstIndex(of: step), idx + 1 < visibleSteps.count else { return }
        step = visibleSteps[idx + 1]
    }

    func goBack() {
        guard let idx = visibleSteps.firstIndex(of: step), idx > 0 else { return }
        step = visibleSteps[idx - 1]
    }

    func finish() {
        OnboardingStore.markDismissed(for: userID)
    }
}
