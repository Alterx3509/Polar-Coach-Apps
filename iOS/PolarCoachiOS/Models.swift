import SwiftUI

enum TrainingSignal: String, Codable {
    case red
    case yellow
    case green

    var title: String {
        switch self {
        case .red:
            return "Red"
        case .yellow:
            return "Yellow"
        case .green:
            return "Green"
        }
    }

    var color: Color {
        switch self {
        case .red:
            return .red
        case .yellow:
            return .yellow
        case .green:
            return .green
        }
    }

    var guidance: String {
        switch self {
        case .red:
            return "Rest or active recovery"
        case .yellow:
            return "Train, but reduce volume"
        case .green:
            return "Train as planned"
        }
    }
}

struct WorkoutSummary: Identifiable, Codable {
    let id = UUID()
    var label: String
    var title: String
    var details: [String]

    enum CodingKeys: String, CodingKey {
        case label
        case title
        case details
    }
}

struct TrainingDay: Identifiable, Codable {
    let id = UUID()
    var date: Date
    var am: String
    var pm: String

    enum CodingKeys: String, CodingKey {
        case date
        case am
        case pm
    }

    var weekday: String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    var dayNumber: String {
        date.formatted(.dateTime.day())
    }
}

struct TrainingSnapshot: Codable {
    var date: Date
    var signal: TrainingSignal
    var signalReason: String
    var phase: String
    var weightLine: String
    var am: WorkoutSummary
    var pm: WorkoutSummary
    var recovery: [String]
    var recentLoad: String
    var calendarDays: [TrainingDay]
    var brief: String

    static let empty: TrainingSnapshot = {
        let today = Date()

        return TrainingSnapshot(
            date: today,
            signal: .yellow,
            signalReason: "Import the Health Export snapshot before using this as training guidance.",
            phase: "Low confidence · Health Export needed",
            weightLine: "Weight unavailable",
            am: WorkoutSummary(
                label: "TODAY",
                title: "Health Export needed",
                details: [
                    "Refresh the Mac app after adding a HealthAutoExport JSON file."
                ]
            ),
            pm: WorkoutSummary(
                label: "ADJUST",
                title: "Recommendation unavailable",
                details: [
                    "No training adjustment can be calculated yet."
                ]
            ),
            recovery: [
                "Unknown",
                "No recovery data loaded."
            ],
            recentLoad: "Unknown\nNo fueling data loaded.",
            calendarDays: [],
            brief: "The app is waiting for the shared Health Export snapshot from your Mac."
        )
    }()
}
