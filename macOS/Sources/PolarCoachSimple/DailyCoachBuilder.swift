import Foundation

struct DailyCoachBuilder {
    let export: HealthAutoExport
    let sourceURL: URL

    private let proteinTarget = 150.0
    private let calendar = Calendar.current

    func build() -> DailyCoach {
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let sleep = export.metric("sleep_analysis")?.latest(onOrBefore: today)
        let hrv = export.metric("heart_rate_variability")?.latest(onOrBefore: today)
        let restingHR = export.metric("resting_heart_rate")?.latest(onOrBefore: today)
        let protein = export.metric("protein")?.latest(onOrBefore: yesterday)
        let calories = export.metric("dietary_energy")?.latest(onOrBefore: yesterday)
        let activeEnergy = export.metric("active_energy")?.latest(onOrBefore: yesterday)
        let weight = export.metric("weight_body_mass")?.latest(onOrBefore: today)

        let hrvBaseline = export.metric("heart_rate_variability")?.baseline(before: hrv, count: 14)
        let restingBaseline = export.metric("resting_heart_rate")?.baseline(before: restingHR, count: 14)
        let calorieBaseline = export.metric("dietary_energy")?.baseline(before: calories, count: 7)
        let activeBaseline = export.metric("active_energy")?.baseline(before: activeEnergy, count: 7)

        var warnings: [String] = []
        var severe: [String] = []

        if let hours = sleep?.totalSleep ?? sleep?.quantityValue {
            if hours < 4.5 {
                severe.append("sleep was only \(hours.oneDecimal) hours")
            } else if hours < 6.5 {
                warnings.append("sleep was \(hours.oneDecimal) hours")
            }
        }

        if let value = hrv?.quantityValue, let baseline = hrvBaseline, baseline > 0 {
            let ratio = value / baseline
            if ratio < 0.75 {
                severe.append("HRV was well below your 14-day baseline")
            } else if ratio < 0.90 {
                warnings.append("HRV was below your 14-day baseline")
            }
        }

        if let value = restingHR?.quantityValue, let baseline = restingBaseline {
            let increase = value - baseline
            if increase >= 8 {
                severe.append("resting heart rate was \(increase.roundedInt) bpm above baseline")
            } else if increase >= 5 {
                warnings.append("resting heart rate was \(increase.roundedInt) bpm above baseline")
            }
        }

        if let grams = protein?.quantityValue {
            if grams < 90 {
                severe.append("protein was only \(grams.roundedInt) g")
            } else if grams < proteinTarget {
                warnings.append("protein was \(grams.roundedInt) g, below the \(proteinTarget.roundedInt) g target")
            }
        }

        if let energy = calories?.quantityValue,
           let baseline = calorieBaseline,
           baseline > 0,
           energy < baseline * 0.70 {
            warnings.append("calories were substantially below your recent average")
        }

        if let load = activeEnergy?.quantityValue,
           let baseline = activeBaseline,
           baseline > 0,
           load > baseline * 1.40 {
            warnings.append("yesterday's activity load was high")
        }

        let availableInputs = [sleep, hrv, restingHR, protein, calories].compactMap { $0 }.count
        let missingInputs = [
            sleep == nil ? "sleep" : nil,
            hrv == nil ? "HRV" : nil,
            restingHR == nil ? "resting HR" : nil,
            protein == nil ? "protein" : nil,
            calories == nil ? "calories" : nil
        ].compactMap { $0 }

        let modifiedAt = sourceURL.modificationDate
        let stale = modifiedAt.map { Date().timeIntervalSince($0) > 36 * 60 * 60 } ?? true
        if stale {
            warnings.append("the Health Export file may be stale")
        }

        let confidence: DataConfidence
        switch availableInputs {
        case 5 where !stale: confidence = .high
        case 3...5: confidence = .moderate
        default: confidence = .low
        }

        let recommendation = recommendation(severe: severe, warnings: warnings, availableInputs: availableInputs, sourceIsStale: stale)
        let recovery = recoverySummary(sleep: sleep, hrv: hrv, hrvBaseline: hrvBaseline, restingHR: restingHR, restingBaseline: restingBaseline)
        let fueling = fuelingSummary(protein: protein, calories: calories, calorieBaseline: calorieBaseline)
        let reason = recommendationReason(severe: severe, warnings: warnings, missingInputs: missingInputs)
        let weightUnits = export.metric("weight_body_mass")?.units ?? "lb"
        let weightLine = weight?.quantityValue.map { "Weight: \($0.oneDecimal) \(weightUnits)" } ?? "Weight unavailable"

        return DailyCoach(
            signal: recommendation.signal,
            actionTitle: recommendation.title,
            actionDetail: recommendation.action,
            adjustmentTitle: recommendation.adjustmentTitle,
            adjustmentDetail: recommendation.adjustmentDetail,
            recoveryStatus: recovery.status,
            recoveryDetail: recovery.detail,
            fuelingStatus: fueling.status,
            fuelingDetail: fueling.detail,
            reason: reason,
            confidence: confidence,
            availableInputs: availableInputs,
            missingInputs: missingInputs,
            sourceURL: sourceURL,
            sourceModifiedAt: modifiedAt,
            sourceIsStale: stale,
            weightLine: weightLine
        )
    }

    private func recommendation(severe: [String], warnings: [String], availableInputs: Int, sourceIsStale: Bool) -> Recommendation {
        if availableInputs < 3 || sourceIsStale {
            return Recommendation(
                signal: .yellow,
                title: "Train conservatively",
                action: "Use the planned session, but reduce volume until current recovery data is available.",
                adjustmentTitle: "Low-confidence recommendation",
                adjustmentDetail: "Keep the session near RPE 7 and avoid max attempts or hard intervals."
            )
        }

        if severe.count >= 2 || severe.contains(where: { $0.hasPrefix("sleep was only") }) {
            return Recommendation(
                signal: .red,
                title: "Rest today",
                action: "Keep movement easy. A short walk and gentle mobility are enough.",
                adjustmentTitle: "Skip hard training",
                adjustmentDetail: "No intervals, heavy lifting, max attempts, or high-volume work."
            )
        }

        if severe.count == 1 || warnings.count >= 4 {
            return Recommendation(
                signal: .red,
                title: "Active recovery",
                action: "Do 30–45 minutes of easy Zone 1–2 movement plus mobility.",
                adjustmentTitle: "No demanding session",
                adjustmentDetail: "Postpone heavy strength work and hard intervals until recovery improves."
            )
        }

        if warnings.count >= 2 {
            return Recommendation(
                signal: .yellow,
                title: "Train, but reduce volume",
                action: "Complete the planned session at about 70–80% of normal volume.",
                adjustmentTitle: "Cap the effort",
                adjustmentDetail: "Keep work near RPE 7 and avoid max attempts or grinding repetitions."
            )
        }

        return Recommendation(
            signal: .green,
            title: "Train as planned",
            action: "Complete the planned session with normal intensity and volume.",
            adjustmentTitle: "No recovery reduction",
            adjustmentDetail: "Use normal warm-up progression and stop only if the session feels unexpectedly poor."
        )
    }

    private func recoverySummary(
        sleep: HealthMetricPoint?,
        hrv: HealthMetricPoint?,
        hrvBaseline: Double?,
        restingHR: HealthMetricPoint?,
        restingBaseline: Double?
    ) -> (status: String, detail: String) {
        var lines: [String] = []
        var flags = 0

        if let value = sleep?.totalSleep ?? sleep?.quantityValue {
            lines.append("Sleep: \(value.oneDecimal) hr")
            if value < 6.5 { flags += 1 }
        }

        if let value = hrv?.quantityValue {
            if let baseline = hrvBaseline {
                lines.append("HRV: \(value.roundedInt) ms (baseline \(baseline.roundedInt))")
                if value < baseline * 0.90 { flags += 1 }
            } else {
                lines.append("HRV: \(value.roundedInt) ms")
            }
        }

        if let value = restingHR?.quantityValue {
            if let baseline = restingBaseline {
                lines.append("Resting HR: \(value.roundedInt) bpm (baseline \(baseline.roundedInt))")
                if value >= baseline + 5 { flags += 1 }
            } else {
                lines.append("Resting HR: \(value.roundedInt) bpm")
            }
        }

        let status: String
        if lines.isEmpty { status = "Unknown" }
        else if flags >= 2 { status = "Low" }
        else if flags == 1 { status = "Mixed" }
        else { status = "Good" }

        return (status, lines.isEmpty ? "Sleep, HRV, and resting heart rate were not found." : lines.joined(separator: "\n"))
    }

    private func fuelingSummary(
        protein: HealthMetricPoint?,
        calories: HealthMetricPoint?,
        calorieBaseline: Double?
    ) -> (status: String, detail: String) {
        var lines: [String] = []
        var low = false

        if let grams = protein?.quantityValue {
            lines.append("Protein: \(grams.roundedInt) g of \(proteinTarget.roundedInt) g target")
            low = low || grams < proteinTarget
        }

        if let energy = calories?.quantityValue {
            if let baseline = calorieBaseline {
                lines.append("Calories: \(energy.roundedInt) kcal (7-day avg \(baseline.roundedInt))")
                low = low || energy < baseline * 0.70
            } else {
                lines.append("Calories: \(energy.roundedInt) kcal")
            }
        }

        let status: String
        if lines.isEmpty { status = "Unknown" }
        else if protein == nil || calories == nil { status = "Incomplete" }
        else if low { status = "Low" }
        else { status = "Adequate" }

        return (status, lines.isEmpty ? "Protein and calorie data were not found for yesterday." : lines.joined(separator: "\n"))
    }

    private func recommendationReason(severe: [String], warnings: [String], missingInputs: [String]) -> String {
        let findings = severe + warnings
        if !findings.isEmpty {
            return findings.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: ". ") + "."
        }
        if !missingInputs.isEmpty {
            return "The available recovery and fueling inputs do not show a reason to reduce training, but confidence is limited because \(missingInputs.joined(separator: ", ")) are missing."
        }
        return "Sleep, HRV, resting heart rate, protein, and calories do not show a meaningful reason to reduce today's training."
    }
}
