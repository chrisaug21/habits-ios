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

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("Logged in as")
                .foregroundStyle(.secondary)
            Text(auth.session?.user.email ?? "")
                .font(.headline)

            Button("Log Out") {
                Task { await auth.signOut() }
            }
            .padding(.top)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
