//
//  RotationBuilderModels.swift
//  Habits
//
//  Models for the Settings "Workout Sequence" builder (SPEC.md's Settings
//  addendum, pass 2) — mirrors the web app's rotation-builder and
//  program-picker data shapes in settings.js/data.js.
//

import Foundation

/// Matches the web app's `iconByCategory` in data.js — the fixed set of
/// categories a custom workout can be filed under, each with a derived
/// Lucide icon name (stored in `workout_library.icon`, same as every other
/// workout row).
enum WorkoutCategory: String, CaseIterable, Identifiable {
    case cardio = "Cardio"
    case strength = "Strength"
    case flexibility = "Flexibility"
    case rest = "Rest"

    var id: String { rawValue }

    var lucideIcon: String {
        switch self {
        case .cardio: return "bike"
        case .strength: return "dumbbell"
        case .flexibility: return "sparkles"
        case .rest: return "moon"
        }
    }
}

/// A full workout_library row (unlike `WorkoutLibraryNested`, which only
/// carries the fields Today/Stats need for a joined rotation row, this also
/// carries `is_global`/`created_by` so the builder can group "Global" vs
/// "Your Workouts" the same way the web app's library list does).
struct WorkoutLibraryRow: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let category: String?
    let icon: String?
    let is_global: Bool
    let created_by: String?
}

struct WorkoutLibraryInsertPayload: Encodable {
    let name: String
    let category: String
    let icon: String
    let is_global: Bool
    let created_by: UUID
}

/// A slot in the sequence being edited. Separate `id` from `workoutId`
/// because, like the web app's `stagedRotationSlots`, the same workout can
/// appear more than once in a sequence (e.g. cardio scheduled every other
/// day) — a List keyed only by workout id would collide on duplicates.
struct StagedRotationSlot: Identifiable, Equatable {
    let id: String
    let workoutId: String

    init(id: String = UUID().uuidString, workoutId: String) {
        self.id = id
        self.workoutId = workoutId
    }
}

struct SaveUserRotationParams: Encodable {
    let p_user_id: UUID
    let p_workout_ids: [String]
}

/// Resets rotation progress after a full sequence replacement (new custom
/// sequence saved, or a starter program applied) — matches the web app
/// zeroing `rotationIndex`/`actionDate` in `saveProgramAsUserRotation` and
/// whenever `saveUserRotation` changes what "next up" even means.
struct StateRotationResetPayload: Encodable {
    let rotation_index: Int
    let action_date: String?
}

/// Like `UserRotationJoinRow` (TodayModels.swift), but decodes the richer
/// `WorkoutLibraryRow` shape (including `is_global`/`created_by`) that the
/// builder needs to group the library into "Global" vs "Your Workouts".
struct UserRotationRichJoinRow: Decodable {
    let position: Int
    let workout_id: String
    let workout_library: WorkoutLibraryRow?
}

struct ProgramWorkoutJoinRow: Decodable {
    let position: Int?
    let workout_id: String
    let workout_library: WorkoutLibraryRow?
}

struct ProgramJoinRow: Decodable {
    let id: String
    let name: String
    let description: String?
    let is_global: Bool
    let created_by: String?
    let program_workouts: [ProgramWorkoutJoinRow]
}

/// Normalized program with its workouts resolved and ordered — mirrors the
/// web app's `normalizeProgramRow`.
struct StarterProgram: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let workouts: [WorkoutLibraryRow]

    static func == (lhs: StarterProgram, rhs: StarterProgram) -> Bool { lhs.id == rhs.id }

    init(row: ProgramJoinRow) {
        id = row.id
        name = row.name
        description = row.description ?? ""
        workouts = row.program_workouts
            .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
            .compactMap { $0.workout_library }
    }
}
