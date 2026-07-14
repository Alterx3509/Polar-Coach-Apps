import Foundation
import UniformTypeIdentifiers

@MainActor
final class TrainingStore: ObservableObject {
    @Published var snapshot = TrainingSnapshot.empty
    @Published var lastUpdated = Date()
    @Published var importStatus = "Load Mac snapshot"

    init() {
        loadSharedSnapshot()
    }

    func refresh() {
        guard let loaded = SharedSnapshotReader.loadNewestAvailable() else {
            importStatus = "No shared snapshot found"
            return
        }
        snapshot = loaded.snapshot
        lastUpdated = loaded.modifiedAt ?? Date()
        importStatus = "Loaded \(loaded.url.lastPathComponent)"
    }

    func importBrief(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        do {
            if url.pathExtension.lowercased() == "json" {
                snapshot = try SharedSnapshotReader.decode(from: url)
            } else {
                let text = try String(contentsOf: url, encoding: .utf8)
                snapshot = BriefParser.apply(text: text, to: TrainingSnapshot.empty)
            }
            lastUpdated = Date()
            importStatus = "Imported \(url.lastPathComponent)"
        } catch {
            importStatus = "Import failed: \(error.localizedDescription)"
        }
    }

    private func loadSharedSnapshot() {
        guard let loaded = SharedSnapshotReader.loadNewestAvailable() else { return }
        snapshot = loaded.snapshot
        lastUpdated = loaded.modifiedAt ?? Date()
        importStatus = "Loaded \(loaded.url.lastPathComponent)"
    }
}

enum SharedSnapshotReader {
    struct Loaded {
        let snapshot: TrainingSnapshot
        let url: URL
        let modifiedAt: Date?
    }

    static func loadNewestAvailable() -> Loaded? {
        let loaded = candidateURLs.compactMap { url -> Loaded? in
            guard FileManager.default.fileExists(atPath: url.path),
                  let snapshot = try? decode(from: url) else {
                return nil
            }
            let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            return Loaded(snapshot: snapshot, url: url, modifiedAt: modifiedAt)
        }
        return loaded.max { lhs, rhs in
            (lhs.modifiedAt ?? .distantPast) < (rhs.modifiedAt ?? .distantPast)
        }
    }

    static func decode(from url: URL) throws -> TrainingSnapshot {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TrainingSnapshot.self, from: data)
    }

    private static var candidateURLs: [URL] {
        var urls: [URL] = []

        if let iCloud = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            urls.append(iCloud.appendingPathComponent("Documents/polar_coach_snapshot.json"))
        }

        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            urls.append(documents.appendingPathComponent("polar_coach_snapshot.json"))
        }

        if let bundled = Bundle.main.url(forResource: "polar_coach_snapshot", withExtension: "json") {
            urls.append(bundled)
        }

        return urls
    }
}

enum BriefParser {
    static func apply(text: String, to snapshot: TrainingSnapshot) -> TrainingSnapshot {
        let cleaned = clean(text)
        var updated = snapshot
        updated.brief = cleaned

        if let recommendation = section("RECOMMENDATION", in: cleaned) {
            updated.signal = signal(from: recommendation)
            updated.signalReason = recommendation
                .replacingOccurrences(of: "Yellow:", with: "")
                .replacingOccurrences(of: "Green:", with: "")
                .replacingOccurrences(of: "Red:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let weight = section("WEIGHT", in: cleaned) {
            updated.weightLine = weight
        }

        if let recovery = section("RECOVERY", in: cleaned) {
            updated.recovery = recoveryLines(from: recovery)
        } else if let sleep = section("SLEEP", in: cleaned) {
            updated.recovery = recoveryLines(from: sleep)
        }

        if let notes = section("NOTES", in: cleaned) {
            updated.recentLoad = notes
        }

        if let am = workoutLine("AM", in: cleaned) {
            updated.am = am
        }

        if let pm = workoutLine("PM", in: cleaned) {
            updated.pm = pm
        }

        return updated
    }

    private static func clean(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "{x}", with: "")
            .replacingOccurrences(of: "{X}", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*Note:", with: "Note:")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "🟢", with: "Green:")
            .replacingOccurrences(of: "🟡", with: "Yellow:")
            .replacingOccurrences(of: "🔴", with: "Red:")

        cleaned = cleaned
            .components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines) != "---" }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }

    private static func section(_ label: String, in text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: {
            isSectionHeader(label, line: $0)
        }) else {
            return nil
        }

        var collected: [String] = []
        for line in lines[start...] {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !collected.isEmpty, isDifferentTopLevelSection(line: trimmed, currentLabel: label) {
                break
            }
            if !trimmed.isEmpty { collected.append(trimmed) }
        }

        return collected
            .joined(separator: "\n")
            .replacingOccurrences(of: "\(label):", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isSectionHeader(_ label: String, line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(label) else { return false }
        let remainder = trimmed.dropFirst(label.count)
        return remainder.isEmpty
            || remainder.hasPrefix(":")
            || remainder.hasPrefix(" ")
            || remainder.hasPrefix("(")
            || remainder.hasPrefix("—")
            || remainder.hasPrefix("-")
    }

    private static func isDifferentTopLevelSection(line: String, currentLabel: String) -> Bool {
        let labels = ["TODAY", "AM", "PM", "SLEEP", "WEIGHT", "RECOVERY", "RECOMMENDATION", "NOTES"]
        return labels.contains { label in
            label != currentLabel && isSectionHeader(label, line: line)
        }
    }

    private static func signal(from recommendation: String) -> TrainingSignal {
        let lower = recommendation.lowercased()
        if lower.contains("red:") { return .red }
        if lower.contains("green:") { return .green }
        return .yellow
    }

    private static func recoveryLines(from text: String) -> [String] {
        let lines = text
            .components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: ";") }
            .map {
                $0.replacingOccurrences(of: "RECOVERY:", with: "")
                    .replacingOccurrences(of: "SLEEP:", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        return lines.isEmpty ? [text.trimmingCharacters(in: .whitespacesAndNewlines)] : lines
    }

    private static func workoutLine(_ label: String, in text: String) -> WorkoutSummary? {
        guard let body = text.components(separatedBy: .newlines).compactMap({ line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let unbulleted = trimmed.hasPrefix("- ")
                ? String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                : trimmed

            let prefixes = [
                "\(label) —",
                "\(label) -",
                "\(label):"
            ]

            for prefix in prefixes where unbulleted.hasPrefix(prefix) {
                return unbulleted.replacingOccurrences(of: prefix, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            return nil
        }).first else {
            return nil
        }

        let parts = body.components(separatedBy: ". ")
        let title = parts.first ?? "\(label) workout"
        let detailText = parts.dropFirst().joined(separator: ". ")
        let details = detailText.isEmpty
            ? [body]
            : detailText.components(separatedBy: ". ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        return WorkoutSummary(label: label, title: title, details: details)
    }
}

extension UTType {
    static let polarCoachBrief = UTType.plainText
}
