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
        if let userID = auth.session?.user.id {
            WeightView(userID: userID)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
