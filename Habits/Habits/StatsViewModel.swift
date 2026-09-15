//
//  StatsViewModel.swift
//  Habits
//
//  Native port of the web app's stats.js: streaks/consistency/weight-trend
//  math over the same history/rotation/weight data Today and Log use.
//  Read-only — owns its own data fetch, same pattern as Today/Log/Settings.
//

import Foundation
import Combine
import Supabase

enum StatsRange: String, CaseIterable, Identifiable {
    case seven = "7"
    case thirty = "30"
    case all = "all"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .seven: return "Last 7 Days"
        case .thirty: return "Last 30 Days"
        case .all: return "All Time"
        }
    }

    /// Matches the web app's `getStatsRangeDays`.
    var days: Int? {
        switch self {
        case .seven: return 7
        case .thirty: return 30
        case .all: return nil
        }
    }
}

struct StatsTypeRow: Identifiable {
    let workout: WorkoutDefinition
    let count: Int
    let percent: Int
    let daysSinceLastDone: Int?

    var id: String { workout.id }
}

struct StatsOtherEntry: Identifiable {
    let id: Int
    let date: String
    let note: String?
}

struct WeightChartPoint: Identifiable {
    let date: Date
    /// Short "Sep 11"-style label. Used as the chart's x-axis *category*
    /// rather than plotting `date` on a real time scale — matches the web
    /// app's Chart.js config, which plots against evenly-spaced label
    /// strings (a category axis), not real calendar gaps. That's why the
    /// web line stays smooth even when entries are gappy: an interpolated
    /// curve over uneven real-world spacing (a true date axis) can loop or
    /// overshoot between distant points, which a real-time x-axis would.
    let dateLabel: String
    let raw: Double
    let rollingAverage: Double
    let trend: Double

    var id: Date { date }
}

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var range: StatsRange = .thirty
    @Published var history: [HistoryRow] = []
    @Published var workoutLibrary: [WorkoutLibraryNested] = []
    @Published var userRotation: [WorkoutDefinition] = []
    @Published var weightEntries: [WeightEntry] = []

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userID: UUID

    init(userID: UUID) {
        self.userID = userID
    }

    // MARK: - Loading

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        do {
            async let historyRows: [HistoryRow] = SupabaseManager.client
                .from("history")
                .select("id, type, date, advanced, note, sequence")
                .eq("user_id", value: userID)
                .order("date", ascending: true)
                .execute()
                .value
            async let libraryRows: [WorkoutLibraryNested] = SupabaseManager.client
                .from("workout_library")
                .select("id, name, category, icon")
                .or("is_global.eq.true,created_by.eq.\(userID.uuidString)")
                .execute()
                .value
            async let rotationRows: [UserRotationJoinRow] = SupabaseManager.client
                .from("user_rotation")
                .select("position, workout_id, workout_library(id, name, category, icon)")
                .eq("user_id", value: userID)
                .order("position", ascending: true)
                .execute()
                .value
            async let weightRows: [WeightEntry] = SupabaseManager.client
                .from("weight")
                .select("date, value_lbs")
                .eq("user_id", value: userID)
                .order("date", ascending: true)
                .execute()
                .value

            self.history = try await historyRows
            self.workoutLibrary = try await libraryRows
            self.userRotation = try await rotationRows.map { row in
                WorkoutDefinition(
                    id: row.workout_id,
                    name: row.workout_library?.name ?? row.workout_id,
                    icon: LucideIcon.sfSymbolName(row.workout_library?.icon),
                    category: row.workout_library?.category ?? ""
                )
            }
            self.weightEntries = try await weightRows
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    // MARK: - Active rotation (mirrors TodayViewModel)

    private var hasCustomRotation: Bool { userRotation.count >= 2 }

    var activeWorkoutList: [WorkoutDefinition] {
        guard hasCustomRotation else { return DefaultWorkouts.all }
        var seen = Set<String>()
        return userRotation.filter { seen.insert($0.id).inserted }
    }

    func daysSinceLastDone(_ workoutID: String) -> Int? {
        guard let mostRecent = history.filter({ $0.type == workoutID }).map(\.date).max() else { return nil }
        return TodayViewModel.daysSince(mostRecent)
    }

    // MARK: - Streaks (always over all history, independent of `range` — matches the web app)

    var hasAnyWorkouts: Bool { history.contains { $0.type != "off" } }

    private var realWorkouts: [HistoryRow] { history.filter { $0.type != "off" } }

    private var workoutDates: Set<String> { Set(realWorkouts.map(\.date)) }

    var currentStreak: Int {
        let calendar = Calendar.current
        var cursor = calendar.startOfDay(for: Date())
        if !workoutDates.contains(TodayViewModel.todayStr()) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var streak = 0
        while workoutDates.contains(Self.localDateFormatter.string(from: cursor)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    var longestStreak: Int {
        guard !workoutDates.isEmpty else { return 0 }
        let sortedDates = workoutDates.sorted()
        var best = 1
        var run = 1
        for i in 1..<sortedDates.count {
            if Self.utcDayDiff(sortedDates[i - 1], sortedDates[i]) == 1 {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }

    // MARK: - Range-scoped totals

    private var cutoffDateString: String? {
        guard let days = range.days else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Date()) ?? Date()
        return Self.localDateFormatter.string(from: cutoff)
    }

    private var rangeEntries: [HistoryRow] {
        guard let cutoff = cutoffDateString else { return realWorkouts }
        return realWorkouts.filter { $0.date >= cutoff }
    }

    var totalWorkouts: Int { rangeEntries.count }

    var consistencyPercent: Int {
        let denominator = consistencyDenominator
        guard denominator > 0 else { return 0 }
        return Int((Double(consistencyDistinctDays) / Double(denominator) * 100).rounded())
    }

    var consistencyDistinctDays: Int { Set(rangeEntries.map(\.date)).count }

    var consistencyDenominator: Int {
        if let days = range.days { return days }
        guard let firstDateStr = realWorkouts.map(\.date).min(),
              let first = Self.localDateFormatter.date(from: firstDateStr) else { return 1 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: first), to: calendar.startOfDay(for: Date())).day ?? 0
        return days + 1
    }

    // MARK: - Workouts by type

    var typeRows: [StatsTypeRow] {
        let activeWorkouts = activeWorkoutList
        var counts: [String: Int] = [:]
        activeWorkouts.forEach { counts[$0.id] = 0 }
        for entry in rangeEntries where counts[entry.type] != nil {
            counts[entry.type, default: 0] += 1
        }
        let maxCount = max(counts.values.max() ?? 0, otherEntries.count, 1)
        return activeWorkouts.map { workout in
            let count = counts[workout.id] ?? 0
            return StatsTypeRow(
                workout: workout,
                count: count,
                percent: Int((Double(count) / Double(maxCount) * 100).rounded()),
                daysSinceLastDone: daysSinceLastDone(workout.id)
            )
        }
    }

    var otherEntries: [StatsOtherEntry] {
        return rangeEntries
            .filter { $0.type == "other" }
            .sorted { $0.date > $1.date }
            .map { StatsOtherEntry(id: $0.id ?? 0, date: $0.date, note: $0.note) }
    }

    var otherPercent: Int {
        let maxCount = max(typeRows.map(\.count).max() ?? 0, otherEntries.count, 1)
        return Int((Double(otherEntries.count) / Double(maxCount) * 100).rounded())
    }

    // MARK: - Weight chart

    /// Empty below 2 points, matching the web app's chart empty state.
    var weightChartPoints: [WeightChartPoint] {
        let cutoff = cutoffDateString
        let rows = weightEntries
            .filter { cutoff == nil || $0.date >= cutoff! }
            .sorted { $0.date < $1.date }
        guard rows.count >= 2 else { return [] }

        let dates = rows.map(\.date)
        let rawValues = rows.map(\.value_lbs)
        let rollingAverages = Self.computeRollingSeries(dates: dates, values: rawValues)
        let trend = Self.computeRollingSeries(dates: dates, values: rollingAverages)

        return rows.indices.map { idx in
            let date = Self.localDateFormatter.date(from: rows[idx].date) ?? Date()
            return WeightChartPoint(
                date: date,
                dateLabel: date.formatted(.dateTime.month(.abbreviated).day()),
                raw: rawValues[idx],
                rollingAverage: rollingAverages[idx],
                trend: trend[idx]
            )
        }
    }

    /// A trailing (up to) 7-day average, mirroring `computeRollingSeries` in
    /// the web app's app.js — used both for the "7-day average" line and,
    /// applied a second time, for the smoothed "trend" line.
    private static func computeRollingSeries(dates: [String], values: [Double]) -> [Double] {
        dates.indices.map { idx in
            var windowValues: [Double] = []
            var i = idx
            while i >= 0, utcDayDiff(dates[i], dates[idx]) <= 6 {
                windowValues.append(values[i])
                i -= 1
            }
            let average = windowValues.reduce(0, +) / Double(windowValues.count)
            return (average * 10).rounded() / 10
        }
    }

    // MARK: - Date helpers

    /// Local-calendar "yyyy-MM-dd" formatting/parsing — matches the web
    /// app's local-time date math used for "today" and streak stepping.
    private static let localDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        return formatter
    }()

    /// UTC-anchored parsing for day-count diffs — matches the web app's use
    /// of `Date.UTC` for longest-streak/rolling-window math, avoiding DST
    /// shifting a date string's day boundary.
    private static let utcDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static func utcDayDiff(_ start: String, _ end: String) -> Int {
        guard let startDate = utcDateFormatter.date(from: start), let endDate = utcDateFormatter.date(from: end) else { return .max }
        return Int((endDate.timeIntervalSince(startDate) / 86400).rounded())
    }
}
