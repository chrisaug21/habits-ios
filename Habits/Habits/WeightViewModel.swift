//
//  WeightViewModel.swift
//  Habits
//

import Foundation
import Combine
import Supabase

struct WeightEntry: Codable, Identifiable {
    let date: String
    let value_lbs: Double

    var id: String { date }
}

private struct WeightUpsertPayload: Encodable {
    let date: String
    let value_lbs: Double
    let user_id: UUID
}

@MainActor
final class WeightViewModel: ObservableObject {
    @Published var entries: [WeightEntry] = []
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var errorMessage: String?

    private let userID: UUID

    init(userID: UUID) {
        self.userID = userID
    }

    func loadEntries() async {
        isLoading = true
        errorMessage = nil
        do {
            let rows: [WeightEntry] = try await SupabaseManager.client
                .from("weight")
                .select("date, value_lbs")
                .eq("user_id", value: userID)
                .order("date", ascending: false)
                .execute()
                .value
            entries = rows
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    func addManualEntry(date: Date, pounds: Double) async {
        await addManualEntry(dateString: Self.dateFormatter.string(from: date), pounds: pounds)
    }

    /// Used by Log's backfill sheet, which already has a "yyyy-MM-dd" string
    /// for the day being edited — avoids a lossy string->Date->string round trip.
    func addManualEntry(dateString: String, pounds: Double) async {
        errorMessage = nil
        do {
            try await upsert(dateString: dateString, pounds: pounds)
            await loadEntries()
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    // Per SPEC.md: HealthKit always wins over a same-day manual entry.
    func syncFromHealthKit() async {
        isSyncing = true
        errorMessage = nil
        do {
            let samples = try await HealthKitManager.shared.fetchRecentBodyMassSamples()
            for sample in samples {
                try await upsert(dateString: Self.dateFormatter.string(from: sample.date), pounds: sample.pounds)
            }
            await loadEntries()
        } catch {
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
        isSyncing = false
    }

    private func upsert(dateString: String, pounds: Double) async throws {
        let payload = WeightUpsertPayload(date: dateString, value_lbs: pounds, user_id: userID)
        try await SupabaseManager.client
            .from("weight")
            .upsert(payload, onConflict: "date,user_id")
            .execute()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()
}
