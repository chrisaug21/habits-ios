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
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
