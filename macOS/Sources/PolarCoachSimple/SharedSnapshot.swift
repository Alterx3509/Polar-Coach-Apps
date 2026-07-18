import Foundation

struct SharedSnapshotWriter {
    static func write(_ coach: DailyCoach) {
        let snapshot = SharedTrainingSnapshot(coach)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(snapshot) else { return }

        for url in outputURLs {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
            } catch {
                continue
            }
        }
    }

    private static var outputURLs: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Documents/polar_coach_snapshot.json"),
            home.appendingPathComponent("Documents/polar_coach_snapshot.json")
        ]
    }
}

struct SharedTrainingSnapshot: Codable {
    let date: Date
    let signal: String
    let signalReason: String
    let phase: String
    let weightLine: String
    let am: SharedWorkoutSummary
    let pm: SharedWorkoutSummary
    let recovery: [String]
    let recentLoad: String
    let calendarDays: [SharedTrainingDay]
    let brief: String

    init(_ coach: DailyCoach) {
        date = Date()
        signal = coach.signal.rawValue
        signalReason = coach.reason
        phase = "\(coach.confidence.rawValue) confidence · Health Export"
        weightLine = coach.weightLine
        am = SharedWorkoutSummary(label: "TODAY", title: coach.actionTitle, details: coach.actionDetail.detailLines)
        pm = SharedWorkoutSummary(label: "ADJUST", title: coach.adjustmentTitle, details: coach.adjustmentDetail.detailLines)
        recovery = [coach.recoveryStatus] + coach.recoveryDetail.detailLines
        recentLoad = ([coach.fuelingStatus] + coach.fuelingDetail.detailLines).joined(separator: "\n")
        calendarDays = []
        brief = """
        Confidence: \(coach.confidence.rawValue)
        Source: \(coach.sourceFileName ?? "Health Export unavailable")
        Updated: \(coach.sourceUpdatedText)

        Why: \(coach.reason)

        Missing inputs: \(coach.missingInputs.isEmpty ? "None" : coach.missingInputs.joined(separator: ", "))
        """
    }
}

struct SharedWorkoutSummary: Codable {
    let label: String
    let title: String
    let details: [String]
}

struct SharedTrainingDay: Codable {
    let date: Date
    let am: String
    let pm: String
}

extension String {
    var detailLines: [String] {
        components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

extension Double {
    var roundedInt: Int { Int(rounded()) }
    var oneDecimal: String { String(format: "%.1f", self) }
}

extension URL {
    var modificationDate: Date? {
        try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
