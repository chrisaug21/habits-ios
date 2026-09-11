//
//  SupabaseConfig.swift
//  Habits
//

import Foundation

// Same Supabase project as the web app (workout-tracker repo). This is the
// publishable (anon) key — safe to commit, same key already shipped inside
// the web app's public JS bundle. See README.md "Credentials".
enum SupabaseConfig {
    static let url = URL(string: "https://zgikmahauuykyrjqhqrz.supabase.co")!
    static let publishableKey = "sb_publishable_VAEH5EypGXX0FlVRj0uIeA_HUS266J3"
}
