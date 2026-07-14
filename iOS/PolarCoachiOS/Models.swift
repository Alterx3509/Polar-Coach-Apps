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
            return "Recovery priority"
        case .yellow:
            return "Modify training"
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
        let calendar = Calendar.current
        let today = Date()
        let days = (-3...3).compactMap { offset -> TrainingDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let text = calendar.isDateInToday(date) ? "Import brief" : "No imported plan"
            return TrainingDay(date: date, am: text, pm: text)
        }

        return TrainingSnapshot(
            date: today,
            signal: .yellow,
            signalReason: "Import today's Mac brief or connect Apple Health before using this as guidance.",
            phase: "Waiting for today's sync",
            weightLine: "No current weight imported",
            am: WorkoutSummary(
                label: "AM",
                title: "No imported AM workout",
                details: [
                    "Import today's Mac brief to show the current plan."
                ]
            ),
            pm: WorkoutSummary(
                label: "PM",
                title: "No imported PM workout",
                details: [
                    "Import today's Mac brief to show the current plan."
                ]
            ),
            recovery: [
                "No current recovery data imported"
            ],
            recentLoad: "No current load data imported",
            calendarDays: days,
            brief: """
            Import today's Mac brief to replace this placeholder.
            """
        )
    }()
}
