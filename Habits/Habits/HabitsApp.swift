//
//  HabitsApp.swift
//  Habits
//
//  Created by Chris Augustine on 9/11/26.
//

import SwiftUI

@main
struct HabitsApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
    }
}
