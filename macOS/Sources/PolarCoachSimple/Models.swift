import Foundation
import SwiftUI

struct Recommendation {
    let signal: CoachSignal
    let title: String
    let action: String
    let adjustmentTitle: String
    let adjustmentDetail: String
}

enum CoachSignal: String, Codable {
    case red
    case yellow
    case green

    var color: Color {
        switch self {
        case .red: return .red
        case .yellow: return .yellow
        case .green: return .green
        }
    }

    var symbol: String {
        switch self {
        case .red: return "pause.fill"
        case .yellow: return "exclamationmark.triangle.fill"
        case .green: return "checkmark.circle.fill"
        }
    }

    var kicker: String {
        switch self {
        case .red: return "Recovery priority"
        case .yellow: return "Modified training"
        case .green: return "Ready"
        }
    }
}

enum DataConfidence: String {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
}

struct DailyCoach {
    let signal: CoachSignal
    let actionTitle: String
    let actionDetail: String
    let adjustmentTitle: String
    let adjustmentDetail: String
    let recoveryStatus: String
    let recoveryDetail: String
    let fuelingStatus: String
    let fuelingDetail: String
    let reason: String
    let confidence: DataConfidence
    let availableInputs: Int
    let missingInputs: [String]
    let sourceURL: URL?
    let sourceModifiedAt: Date?
    let sourceIsStale: Bool
    let weightLine: String

    var confidenceLabel: String { "\(confidence.rawValue) confidence" }
    var sourceFileName: String? { sourceURL?.lastPathComponent }
    var sourceUpdatedText: String { sourceModifiedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown" }
    var sourceFreshness: String {
        guard sourceURL != nil else { return "No Health Export loaded" }
        return sourceIsStale ? "Health Export may be stale" : "Health Export is current"
    }
    var inputSummary: String { "\(availableInputs) of 5 core inputs" }

    static let empty = DailyCoach(
        signal: .yellow,
        actionTitle: "Health Export needed",
        actionDetail: "Add a HealthAutoExport JSON file and refresh before using the recommendation.",
        adjustmentTitle: "Recommendation unavailable",
        adjustmentDetail: "No training adjustment can be calculated yet.",
        recoveryStatus: "Unknown",
        recoveryDetail: "No recovery data loaded.",
        fuelingStatus: "Unknown",
        fuelingDetail: "No fueling data loaded.",
        reason: "The app is waiting for a Health Export file.",
        confidence: .low,
        availableInputs: 0,
        missingInputs: ["sleep", "HRV", "resting HR", "protein", "calories"],
        sourceURL: nil,
        sourceModifiedAt: nil,
        sourceIsStale: true,
        weightLine: "Weight unavailable"
    )
}

struct HealthAutoExport: Decodable {
    let data: HealthExportData

    func metric(_ name: String) -> HealthMetric? {
        data.metrics.first { $0.name == name }
    }
}

struct HealthExportData: Decodable {
    let metrics: [HealthMetric]
}

struct HealthMetric: Decodable {
    let name: String
    let units: String
    let data: [HealthMetricPoint]

    func latest(onOrBefore date: Date) -> HealthMetricPoint? {
        let target = Self.dayFormatter.string(from: date)
        return data
            .filter { point in
                guard let dayKey = point.dayKey else { return false }
                return dayKey <= target
            }
            .max { ($0.dayKey ?? "") < ($1.dayKey ?? "") }
    }

    func baseline(before point: HealthMetricPoint?, count: Int) -> Double? {
        guard let day = point?.dayKey else { return nil }
        let values = data
            .filter { ($0.dayKey ?? "") < day }
            .sorted { ($0.dayKey ?? "") > ($1.dayKey ?? "") }
            .prefix(count)
            .compactMap(\.quantityValue)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct HealthMetricPoint: Decodable {
    let date: String?
    let source: String?
    let quantity: Double?
    let average: Double?
    let min: Double?
    let max: Double?
    let totalSleep: Double?
    let deep: Double?
    let rem: Double?

    var quantityValue: Double? { quantity ?? average ?? totalSleep }
    var dayKey: String? {
        guard let date, date.count >= 10 else { return nil }
        return String(date.prefix(10))
    }

    enum CodingKeys: String, CodingKey {
        case date
        case source
        case quantity = "qty"
        case average = "Avg"
        case min = "Min"
        case max = "Max"
        case totalSleep
        case deep
        case rem
    }
}
