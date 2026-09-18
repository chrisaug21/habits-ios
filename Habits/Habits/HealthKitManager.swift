//
//  HealthKitManager.swift
//  Habits
//

import Foundation
import HealthKit

struct HealthKitWeightSample {
    let date: Date
    let pounds: Double
}

enum HealthKitError: LocalizedError {
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Health data isn't available on this device."
        }
    }
}

// Read-only in phase 1 — never writes to Apple Health. See SPEC.md.
final class HealthKitManager {
    static let shared = HealthKitManager()

    private static let authorizationRequestedKey = "com.chrisaug.habits.healthKitAuthorizationRequested"

    private let store = HKHealthStore()
    private let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!

    private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var hasRequestedAuthorization: Bool {
        UserDefaults.standard.bool(forKey: Self.authorizationRequestedKey)
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        try await store.requestAuthorization(toShare: [], read: [bodyMassType])
        UserDefaults.standard.set(true, forKey: Self.authorizationRequestedKey)
    }

    /// Most recent body mass sample per day, looking back 14 days.
    /// Per SPEC.md: multiple samples in one day -> most recent wins.
    func fetchRecentBodyMassSamples() async throws -> [HealthKitWeightSample] {
        try await requestAuthorization()

        let startDate = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMassType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
        )

        let samples = try await descriptor.result(for: store)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"

        var latestPerDay: [String: HealthKitWeightSample] = [:]
        for sample in samples {
            let day = dayFormatter.string(from: sample.endDate)
            guard latestPerDay[day] == nil else { continue } // already have the latest for this day
            let pounds = sample.quantity.doubleValue(for: .pound())
            latestPerDay[day] = HealthKitWeightSample(date: sample.endDate, pounds: pounds)
        }

        return Array(latestPerDay.values)
    }
}
