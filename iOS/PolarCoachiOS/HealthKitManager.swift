import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    @Published var authorizationStatus = "Health access not requested"
    @Published var latestWeight: String?
    @Published var latestHRV: String?
    @Published var latestRestingHR: String?

    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAccess() async {
        guard isAvailable else {
            authorizationStatus = "HealthKit is not available on this device"
            return
        }

        let readTypes = Set([
            HKQuantityType.quantityType(forIdentifier: .bodyMass),
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.workoutType()
        ].compactMap { $0 })

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            authorizationStatus = "Health access granted"
            await loadLatestMetrics()
        } catch {
            authorizationStatus = "Health access failed: \(error.localizedDescription)"
        }
    }

    func loadLatestMetrics() async {
        latestWeight = await latestQuantity(.bodyMass, unit: .pound(), suffix: "lb")
        latestHRV = await latestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), suffix: "ms")
        latestRestingHR = await latestQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), suffix: "bpm")
    }

    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, suffix: String) async -> String? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
            end: Date()
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let value = sample.quantity.doubleValue(for: unit)
                let formatted = identifier == .bodyMass
                    ? String(format: "%.1f %@", value, suffix)
                    : String(format: "%.0f %@", value, suffix)
                continuation.resume(returning: formatted)
            }
            store.execute(query)
        }
    }
}
