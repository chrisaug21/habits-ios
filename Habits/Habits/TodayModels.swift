//
//  TodayModels.swift
//  Habits
//

import Foundation

struct WorkoutDefinition: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let icon: String
    let category: String
}

/// Mirrors the web app's hardcoded fallback (`WORKOUTS`/`ROTATION` in app.js),
/// used when the user has no custom rotation in `user_rotation`.
enum DefaultWorkouts {
    static let all: [WorkoutDefinition] = [
        WorkoutDefinition(id: "peloton", name: "Cardio — Peloton Ride", icon: "bicycle", category: "Cardio"),
        WorkoutDefinition(id: "upper_push", name: "Strength — Upper Push", icon: "dumbbell.fill", category: "Strength"),
        WorkoutDefinition(id: "upper_pull", name: "Strength — Upper Pull", icon: "dumbbell.fill", category: "Strength"),
        WorkoutDefinition(id: "lower", name: "Strength — Lower Body", icon: "dumbbell.fill", category: "Strength"),
        WorkoutDefinition(id: "yoga", name: "Flexibility — Yoga", icon: "figure.mind.and.body", category: "Flexibility"),
    ]

    private static let rotationIDs = [
        "peloton", "upper_push",
        "peloton", "yoga",
        "peloton", "upper_pull",
        "peloton", "yoga",
        "peloton", "lower",
        "peloton", "yoga",
    ]

    static let rotation: [WorkoutDefinition] = rotationIDs.compactMap { id in
        all.first { $0.id == id }
    }
}

/// `workout_library.icon` stores Lucide icon names (the set the web app writes —
/// see `iconByCategory` in `data.js` and the hardcoded fallback list in `app.js`),
/// not SF Symbol names, so they need translating before use in `Image(systemName:)`.
enum LucideIcon {
    private static let sfSymbolNames: [String: String] = [
        "bike": "bicycle",
        "dumbbell": "dumbbell.fill",
        "flower-2": "figure.mind.and.body",
        "sparkles": "sparkles",
        "moon": "moon.fill",
        "zap": "bolt.fill",
    ]

    static func sfSymbolName(_ lucideName: String?) -> String {
        guard let lucideName else { return "figure.strengthtraining.traditional" }
        return sfSymbolNames[lucideName] ?? "figure.strengthtraining.traditional"
    }
}

struct HistoryRow: Codable, Identifiable, Equatable {
    var id: Int?
    let type: String
    let date: String
    let advanced: Bool
    var note: String?
    var sequence: Int?
}

struct HistoryInsertPayload: Encodable {
    let type: String
    let date: String
    let advanced: Bool
    let note: String?
    let sequence: Int
    let user_id: UUID
}

struct HistoryUpdatePayload: Encodable {
    let type: String
    let note: String?
    let advanced: Bool
}

struct StateRow: Codable, Equatable {
    var id: Int?
    var rotation_index: Int
    var action_date: String?
}

struct StateUpsertPayload: Encodable {
    let user_id: UUID
    let rotation_index: Int
    let action_date: String?
}

struct JournalRow: Codable, Identifiable, Equatable {
    let date: String
    var intention: String?
    var gratitude: String?
    var one_thing: String?

    var id: String { date }
}

struct JournalUpsertPayload: Encodable {
    let date: String
    let intention: String?
    let gratitude: String?
    let one_thing: String?
    let user_id: UUID
}

struct UserPreferencesRow: Codable, Equatable {
    var show_workout_card: Bool
    var show_journal_card: Bool
    var show_weight_card: Bool

    static let defaults = UserPreferencesRow(show_workout_card: true, show_journal_card: true, show_weight_card: true)
}

struct UserPreferencesUpsertPayload: Encodable {
    let user_id: UUID
    let show_workout_card: Bool
    let show_journal_card: Bool
    let show_weight_card: Bool
}

struct WorkoutLibraryNested: Codable {
    let id: String
    let name: String
    let category: String?
    let icon: String?
}

struct UserRotationJoinRow: Codable {
    let position: Int
    let workout_id: String
    let workout_library: WorkoutLibraryNested?
}

enum TodayHeroState: Equatable {
    case defaultNext
    case done
    case skipped
    case other
}

/// Recently-used free-text values (skip reasons, "other" activity names),
/// remembered locally as quick-tap chips — matches the web app's localStorage behavior.
enum RecentChipsStore {
    static let skipReasonsKey = "habits_skip_reasons"
    static let otherActivitiesKey = "habits_other_activities"
    static let defaultSkipReasons = ["Sick", "Travel", "Vacation", "Social obligation"]

    static func load(_ key: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func remember(_ value: String, in key: String, limit: Int = 10) {
        var existing = load(key)
        existing.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        existing.insert(value, at: 0)
        if existing.count > limit { existing = Array(existing.prefix(limit)) }
        UserDefaults.standard.set(existing, forKey: key)
    }
}
