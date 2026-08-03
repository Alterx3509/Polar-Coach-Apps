import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    @Published var authorizationStatus = "Health access not requested"
    @Published var latestWeight: String?
    @Published var latestHRV: String?
    @Published var latestRestingHR: String?
    @Published var lastNightSleep: String?
    @Published var activeCalories: String?
    @Published var dietaryCalories: String?
    @Published var protein: String?
    @Published var latestWorkout: String?
    @Published var lastSyncDate: Date?
    @Published var isSyncing = false

    private let store = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var readTypes: Set<HKObjectType> {
        Set([
            HKQuantityType.quantityType(forIdentifier: .bodyMass),
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            HKQuantityType.quantityType(forIdentifier: .dietaryProtein),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.workoutType()
        ].compactMap { $0 })
    }

    func requestAccess() async {
        guard isAvailable else {
            authorizationStatus = "HealthKit is not available on this device"
            return
        }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            authorizationStatus = "Apple Health connected"
            await enableBackgroundDelivery()
            startObservers()
            await refresh()
        } catch {
            authorizationStatus = "Health access failed: \(error.localizedDescription)"
        }
    }

    func refresh() async {
        guard isAvailable else { return }
        isSyncing = true
        defer { isSyncing = false }

        async let weight = latestQuantity(.bodyMass, unit: .pound(), suffix: "lb", decimals: 1)
        async let hrv = latestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), suffix: "ms")
        async let restingHR = latestQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), suffix: "bpm")
        async let sleep = sleepDurationLastNight()
        async let active = cumulativeQuantityToday(.activeEnergyBurned, unit: .kilocalorie(), suffix: "kcal", decimals: 0)
        async let calories = cumulativeQuantityYesterday(.dietaryEnergyConsumed, unit: .kilocalorie(), suffix: "kcal", decimals: 0)
        async let proteinValue = cumulativeQuantityYesterday(.dietaryProtein, unit: .gram(), suffix: "g", decimals: 0)
        async let workout = latestWorkoutSummary()

        latestWeight = await weight
        latestHRV = await hrv
        latestRestingHR = await restingHR
        lastNightSleep = await sleep
        activeCalories = await active
        dietaryCalories = await calories
        protein = await proteinValue
        latestWorkout = await workout
        lastSyncDate = Date()
        authorizationStatus = "Apple Health synced"
    }

    func loadLatestMetrics() async {
        await refresh()
    }

    private func enableBackgroundDelivery() async {
        for type in readTypes {
            do {
                try await store.enableBackgroundDelivery(for: type, frequency: .hourly)
            } catch {
                // Some types or sources may not support background delivery. Foreground refresh remains available.
            }
        }
    }

    private func startObservers() {
        guard observerQueries.isEmpty else { return }

        for type in readTypes {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
                guard let self else {
                    completion()
                    return
                }

                Task { @MainActor in
                    await self.refresh()
                    completion()
                }
            }
            observerQueries.append(query)
            store.execute(query)
        }
    }

    private func latestQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        suffix: String,
        decimals: Int
    ) async -> String? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let start = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictEndDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: String(format: "%.*f %@", decimals, value, suffix))
            }
            store.execute(query)
        }
    }

    private func cumulativeQuantityToday(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        suffix: String,
        decimals: Int
    ) async -> String? {
        let start = Calendar.current.startOfDay(for: Date())
        return await cumulativeQuantity(identifier, start: start, end: Date(), unit: unit, suffix: suffix, decimals: decimals)
    }

    private func cumulativeQuantityYesterday(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        suffix: String,
        decimals: Int
    ) async -> String? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }
        return await cumulativeQuantity(identifier, start: start, end: today, unit: unit, suffix: suffix, decimals: decimals)
    }

    private func cumulativeQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        start: Date,
        end: Date,
        unit: HKUnit,
        suffix: String,
        decimals: Int
    ) async -> String? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                guard let quantity = result?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = quantity.doubleValue(for: unit)
                continuation.resume(returning: String(format: "%.*f %@", decimals, value, suffix))
            }
            store.execute(query)
        }
    }

    private func sleepDurationLastNight() async -> String? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .hour, value: -18, to: end)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]

                let seconds = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                guard seconds > 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                let hours = Int(seconds) / 3600
                let minutes = (Int(seconds) % 3600) / 60
                continuation.resume(returning: String(format: "%dh %02dm", hours, minutes))
            }
            store.execute(query)
        }
    }

    private func latestWorkoutSummary() async -> String? {
        let type = HKObjectType.workoutType()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictEndDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let workout = samples?.first as? HKWorkout else {
                    continuation.resume(returning: nil)
                    return
                }

                let minutes = Int(workout.duration / 60)
                let name = workout.workoutActivityType.displayName
                continuation.resume(returning: "\(name) · \(minutes) min")
            }
            store.execute(query)
        }
    }
}

private extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .traditionalStrengthTraining: return "Strength"
        case .functionalStrengthTraining: return "Functional strength"
        case .running: return "Run"
        case .cycling: return "Ride"
        case .walking: return "Walk"
        case .swimming: return "Swim"
        case .elliptical: return "Elliptical"
        case .rowing: return "Row"
        case .highIntensityIntervalTraining: return "HIIT"
        default: return "Workout"
        }
    }
}
