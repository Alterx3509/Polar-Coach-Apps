import Foundation
import SwiftUI

@main
struct PolarCoachMacApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .frame(minWidth: 1040, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct DashboardView: View {
    @StateObject private var model = DashboardModel()

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 230, ideal: 260)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    todayGrid
                    briefSection
                    CalendarStripView(days: model.calendarDays)
                    bottomGrid
                }
                .padding(28)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .onAppear { model.refresh() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Polar Coach")
                    .font(.title2.weight(.semibold))
                Text("MTI + 2peak + Garmin + Strava")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button {
                model.refresh()
            } label: {
                Label(model.isRefreshing ? "Refreshing..." : "Refresh Dashboard", systemImage: model.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isRefreshing)

            if model.isRefreshing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading local files")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if let refreshedAt = model.lastRefreshedAt {
                Text("Updated \(refreshedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Sync")
                    .font(.headline)

                ForEach(model.scripts) { script in
                    Button {
                        model.run(script)
                    } label: {
                        Label(script.title, systemImage: script.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.runningScriptID != nil)
                }
            }

            if let status = model.runStatus {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text(status.title)
                        .font(.headline)
                    Text(status.message)
                        .font(.caption)
                        .foregroundStyle(status.ok ? .green : .red)
                        .textSelection(.enabled)
                }
            }

            Spacer()

            Text("Data folder\n\(model.syncDirectory.path)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(20)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.todayTitle)
                    .font(.largeTitle.weight(.semibold))
                Text(model.statusLine)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StoplightView(signal: model.trainingSignal)
            VStack(alignment: .trailing, spacing: 4) {
                Text(model.trainingPhase)
                    .font(.headline)
                Text(model.weightLine)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var todayGrid: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                MetricCard(title: "AM Cardio", value: model.todayAM.title, detail: model.todayAM.detail, symbol: "figure.run")
                MetricCard(title: "PM Strength", value: model.todayPM.title, detail: model.todayPM.detail, symbol: "dumbbell")
            }
            GridRow {
                MetricCard(title: "Recovery", value: model.recoveryTitle, detail: model.recoveryDetail, symbol: "heart")
                MetricCard(title: "Recent Load", value: model.recentLoadTitle, detail: model.recentLoadDetail, symbol: "chart.xyaxis.line")
            }
        }
    }

    private var briefSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Morning Brief", systemImage: "sun.max")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(model.briefTimestamp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(model.morningBrief)
                .font(.body)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var bottomGrid: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                FileStatusCard(title: "2peak Sessions", status: model.fileStatus("twopeak_sessions.json"))
                FileStatusCard(title: "Strava Activities", status: model.fileStatus("strava_activities.json"))
                FileStatusCard(title: "Training Plan", status: model.fileStatus("training_plan.ics"))
            }
            GridRow {
                FileStatusCard(title: "Garmin Activities", status: model.fileStatus("garmin_activities.json"))
                FileStatusCard(title: "Garmin Daily", status: model.fileStatus("garmin_daily_stats.json"))
                FileStatusCard(title: "Latest MTI", status: model.latestMTIStatus)
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.headline)
                Spacer()
            }
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 235, alignment: .topLeading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct StoplightView: View {
    let signal: TrainingSignal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                signalDot(.red, active: signal.level == .red)
                signalDot(.yellow, active: signal.level == .yellow)
                signalDot(.green, active: signal.level == .green)
            }
            Text(signal.title)
                .font(.headline)
            Text(signal.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 210, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func signalDot(_ level: TrainingSignal.Level, active: Bool) -> some View {
        Circle()
            .fill(level.color.opacity(active ? 1 : 0.18))
            .strokeBorder(level.color.opacity(active ? 0.9 : 0.25), lineWidth: 1)
            .frame(width: active ? 18 : 13, height: active ? 18 : 13)
    }
}

struct FileStatusCard: View {
    let title: String
    let status: FileStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: status.exists ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(status.exists ? .green : .orange)
            }
            Text(status.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 105, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct CalendarStripView: View {
    let days: [TrainingDay]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Training Calendar", systemImage: "calendar")
                .font(.title3.weight(.semibold))

            HStack(spacing: 10) {
                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.weekday)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(day.isToday ? .primary : .secondary)
                                Text(day.dayNumber)
                                    .font(.title3.weight(.semibold))
                            }
                            Spacer()
                            if day.isToday {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 8, height: 8)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 5) {
                            calendarLine(label: "AM", text: day.am)
                            calendarLine(label: "PM", text: day.pm)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
                    .background(day.isToday ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(18)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func calendarLine(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }
}

@MainActor
final class DashboardModel: ObservableObject {
    @Published private(set) var snapshot = TrainingSnapshot.empty
    @Published var runStatus: RunStatus?
    @Published var runningScriptID: UUID?
    @Published var lastRefreshedAt: Date?
    @Published var isRefreshing = false

    let syncDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/Garmin/sync")

    let scripts: [SyncScript] = [
        SyncScript(title: "Garmin", path: "/Users/patrickaltenburg/garmin_sync.py", symbol: "figure.walk.motion"),
        SyncScript(title: "Strava", path: "/Users/patrickaltenburg/strava_sync.py", symbol: "bolt.horizontal"),
        SyncScript(title: "2peak Calendar", path: "/Users/patrickaltenburg/twopeak_sync.py", symbol: "calendar"),
        SyncScript(title: "2peak Sessions", path: "/Users/patrickaltenburg/twopeak_sessions_sync.py", symbol: "list.bullet.rectangle"),
        SyncScript(title: "MTI", path: "/Users/patrickaltenburg/mti_sync.py", symbol: "figure.strengthtraining.traditional"),
        SyncScript(title: "Calendar", path: "/Users/patrickaltenburg/calendar_sync.py", symbol: "calendar.badge.clock"),
        SyncScript(title: "Morning Brief", path: "/Users/patrickaltenburg/morning_brief.py", symbol: "sun.max")
    ]

    var todayTitle: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    var statusLine: String {
        snapshot.isRestDay ? "Recovery day in the Polar X schedule" : "Training day in the Polar X schedule"
    }

    var trainingPhase: String { "Weight loss phase" }

    var weightLine: String { snapshot.weightLine }

    var todayAM: WorkoutSummary { snapshot.am }
    var todayPM: WorkoutSummary { snapshot.pm }
    var recoveryTitle: String { snapshot.recoveryTitle }
    var recoveryDetail: String { snapshot.recoveryDetail }
    var recentLoadTitle: String { snapshot.recentLoadTitle }
    var recentLoadDetail: String { snapshot.recentLoadDetail }
    var trainingSignal: TrainingSignal { snapshot.trainingSignal }
    var morningBrief: String { snapshot.morningBrief }
    var briefTimestamp: String { snapshot.briefTimestamp }
    var calendarDays: [TrainingDay] { snapshot.calendarDays }
    var latestMTIStatus: FileStatus { snapshot.latestMTIStatus }

    func fileStatus(_ fileName: String) -> FileStatus {
        snapshot.fileStatuses[fileName] ?? FileStatus.missing(fileName)
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        if runningScriptID == nil {
            runStatus = RunStatus(title: "Refreshing dashboard", message: "Loading local training files...", ok: true)
        }

        Task {
            let loaded = await Task.detached {
                TrainingDataLoader(syncDirectory: self.syncDirectory).load()
            }.value

            try? await Task.sleep(for: .milliseconds(350))

            snapshot = loaded
            SharedSnapshotWriter.write(loaded)
            lastRefreshedAt = Date()
            isRefreshing = false
            if runningScriptID == nil {
                runStatus = RunStatus(
                    title: "Dashboard refreshed",
                    message: "Loaded local training files at \(lastRefreshedAt?.formatted(date: .omitted, time: .standard) ?? "now").",
                    ok: true
                )
            }
        }
    }

    func run(_ script: SyncScript) {
        runningScriptID = script.id
        runStatus = RunStatus(title: "Running \(script.title)", message: "Started \(script.path)", ok: true)

        Task.detached {
            let result = ScriptRunner.run(script)
            await MainActor.run {
                self.runningScriptID = nil
                self.runStatus = result
                self.refresh()
            }
        }
    }
}

struct TrainingDataLoader {
    let syncDirectory: URL
    private let calendar = Calendar.current
    private var healthExportDirectory: URL {
        let documents = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents")
        let candidates = [
            documents.appendingPathComponent("health export"),
            documents.appendingPathComponent("Health Export")
        ]

        return candidates.first { FileManager.default.fileExists(atPath: $0.path) } ?? candidates[0]
    }

    func load() -> TrainingSnapshot {
        let today = Date()
        let todayKey = Self.isoDate.string(from: today)
        let schedule = PolarSchedule.entry(for: today)
        let twoPeak = loadTwoPeak(todayKey: todayKey)
        let latestMTI = latestMTIFile(todayKey: todayKey)
        let mtiText = latestMTI.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let brief = loadMorningBrief()

        let am = briefWorkout("AM", from: brief.text) ?? twoPeak.map { session in
            formatTwoPeakSession(session)
        } ?? WorkoutSummary(
            title: schedule == nil ? "Rest or unscheduled" : "2peak pending",
            detail: schedule == nil ? "No AM cardio is scheduled for today." : "Run 2peak Sessions sync to refresh today's prescription."
        )

        let pm = makePMSummary(schedule: schedule, mtiText: mtiText, briefText: brief.text)
        let strava = loadStravaSummary()
        let recovery = loadRecovery()
        let weightLine = loadWeightLine()
        let signal = makeTrainingSignal(from: brief.text)
        let calendarDays = makeCalendarDays(today: today)
        let statuses = makeFileStatuses()
        let latestMTIStatus = latestMTI.map { FileStatus.present($0) } ?? .missing("mti_polar_week*")

        return TrainingSnapshot(
            am: am,
            pm: pm,
            isRestDay: schedule == nil,
            recoveryTitle: recovery.title,
            recoveryDetail: recovery.detail,
            recentLoadTitle: strava.title,
            recentLoadDetail: strava.detail,
            trainingSignal: signal,
            morningBrief: brief.text,
            briefTimestamp: brief.timestamp,
            calendarDays: calendarDays,
            weightLine: weightLine,
            fileStatuses: statuses,
            latestMTIStatus: latestMTIStatus
        )
    }

    private func loadTwoPeak(todayKey: String) -> TwoPeakSession? {
        let url = syncDirectory.appendingPathComponent("twopeak_sessions.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([String: TwoPeakSession].self, from: data)[todayKey]
    }

    private func loadTwoPeakSessions() -> [String: TwoPeakSession] {
        let url = syncDirectory.appendingPathComponent("twopeak_sessions.json")
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: TwoPeakSession].self, from: data)) ?? [:]
    }

    private func makeCalendarDays(today: Date) -> [TrainingDay] {
        let sessions = loadTwoPeakSessions()
        return (-3...3).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let key = Self.isoDate.string(from: date)
            let tp = sessions[key]
            let schedule = PolarSchedule.entry(for: date)
            let isToday = calendar.isDate(date, inSameDayAs: today)

            let am: String
            if let tp {
                let sport = tp.summary.cleanedTrainingTitle(defaultValue: "Cardio")
                let duration = tp.duration.firstMatch(#"(\d{1,2}:\d{2}:\d{2})"#) ?? ""
                am = [sport.capitalized, shortDuration(duration)].filter { !$0.isEmpty }.joined(separator: " ")
            } else if schedule == nil {
                am = "Recovery"
            } else {
                am = "2peak pending"
            }

            let pm: String
            if let plan = planFile(dayKey: key), let title = pmTitle(from: plan) {
                pm = title
            } else if let schedule {
                pm = "Strength W\(schedule.week) S\(schedule.session)"
            } else {
                pm = "Rest"
            }

            return TrainingDay(
                date: date,
                weekday: date.formatted(.dateTime.weekday(.abbreviated)),
                dayNumber: date.formatted(.dateTime.day()),
                am: am,
                pm: pm,
                isToday: isToday
            )
        }
    }

    private func shortDuration(_ duration: String) -> String {
        let parts = duration.split(separator: ":")
        guard parts.count >= 2 else { return duration }
        let hours = Int(parts[0]) ?? 0
        let minutes = Int(parts[1]) ?? 0
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }

    private func formatTwoPeakSession(_ session: TwoPeakSession) -> WorkoutSummary {
        let lines = session.detail.cleanLines
        let sport = session.summary.cleanedTrainingTitle(defaultValue: lines.first ?? "2peak cardio")
        let duration = session.duration.firstMatch(#"(\d{1,2}:\d{2}:\d{2})"#)
            ?? value(after: "DURATION", in: lines)
            ?? ""
        let drills = valuesBetween("SPECIAL DRILLS", and: "Intensity breakdown", in: lines)
            .filter { !["Stretching"].contains($0) }
        let planned = plannedZones(from: lines)
        let intervals = intervals(from: lines)

        var detail: [String] = []
        if !duration.isEmpty { detail.append("Duration: \(duration)") }
        if !planned.isEmpty { detail.append("Intensity: \(planned.joined(separator: ", "))") }
        if !drills.isEmpty { detail.append("Drills: \(drills.joined(separator: ", "))") }
        if !intervals.isEmpty {
            detail.append("")
            detail.append("Workout:")
            detail.append(contentsOf: intervals.enumerated().map { index, interval in
                "\(index + 1). \(interval)"
            })
        }

        return WorkoutSummary(
            title: sport,
            detail: detail.joined(separator: "\n").summaryLines(maxLines: 18, fallback: session.detail.summaryLines(maxLines: 12, fallback: session.duration))
        )
    }

    private func makePMSummary(schedule: PolarSchedule.Entry?, mtiText: String, briefText: String) -> WorkoutSummary {
        if let briefPM = briefWorkout("PM", from: briefText) {
            return WorkoutSummary(title: briefPM.title, detail: briefPM.detail)
        }

        guard let schedule else {
            return WorkoutSummary(title: "Rest day", detail: "Light walk, mobility, or recovery only.")
        }

        let planTitle = mtiText.firstMatch(#"\*{2,4}\s*PM SESSION\s*-\s*([^\n]+)"#)
        let objective = mtiText.firstMatch(#"OBJ:\s*([^\n]+)"#) ?? "MTI Polar GenX"
        let session = mtiText.firstMatch(#"SESSION\s+(#?\d+[^\n]*)"#)
        let detail = mtiText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(12)
            .joined(separator: "\n")

        return WorkoutSummary(
            title: planTitle ?? "Week \(schedule.week), Session \(schedule.session)",
            detail: [objective, session, detail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n").summaryLines(maxLines: 8, fallback: "Run MTI sync to refresh today's strength work.")
        )
    }

    private func planFile(dayKey: String) -> URL? {
        glob(prefix: "mti_polar_week", suffix: "_\(dayKey).txt")
            .max(by: { $0.lastPathComponent < $1.lastPathComponent })
    }

    private func pmTitle(from url: URL) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return text.firstMatch(#"\*{2,4}\s*PM SESSION\s*-\s*([^\n]+)"#)
    }

    private func makeTrainingSignal(from briefText: String) -> TrainingSignal {
        let recommendation = briefSection("RECOMMENDATION", from: briefText)
        let lower = recommendation.lowercased()
        let level: TrainingSignal.Level
        if lower.contains("red:") || lower.contains("🔴") {
            level = .red
        } else if lower.contains("yellow:") || lower.contains("🟡") {
            level = .yellow
        } else if lower.contains("green:") || lower.contains("🟢") {
            level = .green
        } else {
            level = .yellow
        }

        let title: String
        switch level {
        case .red: title = "Red: recovery priority"
        case .yellow: title = "Yellow: modify training"
        case .green: title = "Green: train as planned"
        }

        let detail = recommendation
            .replacingOccurrences(of: "RECOMMENDATION:", with: "")
            .replacingOccurrences(of: "Yellow:", with: "")
            .replacingOccurrences(of: "Green:", with: "")
            .replacingOccurrences(of: "Red:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .summaryLines(maxLines: 1, fallback: "Use today's brief for training guidance.")

        return TrainingSignal(level: level, title: title, detail: detail)
    }

    private func briefWorkout(_ label: String, from briefText: String) -> WorkoutSummary? {
        let pattern = #"(?m)^\s*(?:-\s*)?\#(label)\s*[—-]\s*([^\n]+)"#
        guard let line = briefText.firstMatch(pattern) else { return nil }
        let cleaned = line
            .replacingOccurrences(of: #"^\s*(?:-\s*)?\#(label)\s*[—-]\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = cleaned.components(separatedBy: ". ")
        let title = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "\(label) workout"
        let detail = parts.dropFirst().joined(separator: ". ").trimmingCharacters(in: .whitespacesAndNewlines)
        return WorkoutSummary(title: title, detail: detail.isEmpty ? line : detail)
    }

    private func briefSection(_ label: String, from briefText: String) -> String {
        let lines = briefText.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("\(label):") }) else {
            return ""
        }

        var collected: [String] = []
        for line in lines[start...] {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !collected.isEmpty,
               trimmed.hasSuffix(":"),
               trimmed.uppercased() == trimmed {
                break
            }
            if !trimmed.isEmpty {
                collected.append(trimmed)
            }
        }
        return collected.joined(separator: " ")
    }

    private func value(after marker: String, in lines: [String]) -> String? {
        guard let index = lines.firstIndex(of: marker), lines.indices.contains(index + 1) else {
            return nil
        }
        return lines[index + 1]
    }

    private func valuesBetween(_ start: String, and end: String, in lines: [String]) -> [String] {
        guard let startIndex = lines.firstIndex(of: start) else { return [] }
        let endIndex = lines[startIndex...].firstIndex(of: end) ?? lines.endIndex
        guard startIndex + 1 < endIndex else { return [] }
        return Array(lines[(startIndex + 1)..<endIndex])
            .filter { !knownScrapeLabels.contains($0) }
    }

    private func plannedZones(from lines: [String]) -> [String] {
        guard let start = lines.firstIndex(of: "PLANNED") else { return [] }
        let end = lines[start...].firstIndex(of: "BREAKDOWN") ?? lines.endIndex
        var zones: [String] = []
        var i = start + 1
        while i < end {
            let zone = lines[i]
            if zone.isZoneLabel,
               lines.indices.contains(i + 2),
               lines[i + 1].contains(":"),
               lines[i + 2].contains("%") {
                zones.append("\(zone) \(lines[i + 1]) (\(lines[i + 2]))")
                i += 3
            } else {
                i += 1
            }
        }
        return zones
    }

    private func intervals(from lines: [String]) -> [String] {
        guard let hide = lines.lastIndex(of: "Hide") else { return [] }
        var result: [String] = []
        var i = hide + 1

        while i < lines.count {
            let zone = lines[i]
            if ["ABOUT", "SUPPORT", "LEGAL", "by Quevita AG"].contains(zone) { break }

            guard zone.isZoneLabel, lines.indices.contains(i + 1) else {
                i += 1
                continue
            }

            let duration = lines[i + 1]
            var metrics: [String] = []
            i += 2
            while i < lines.count,
                  !lines[i].isZoneLabel,
                  !["ABOUT", "SUPPORT", "LEGAL", "by Quevita AG"].contains(lines[i]) {
                if !knownScrapeLabels.contains(lines[i]) {
                    metrics.append(lines[i])
                }
                i += 1
            }

            let suffix = metrics.isEmpty ? "" : " - \(metrics.joined(separator: ", "))"
            result.append("\(zone) \(duration)\(suffix)")
        }

        return result
    }

    private var knownScrapeLabels: Set<String> {
        [
            "Cycling", "Running", "Swimming", "Intensity breakdown",
            "Intensity segments throughout the activity", "PLANNED",
            "BREAKDOWN", "Hide", "SPECIAL DRILLS", "Stretching"
        ]
    }

    private func loadStravaSummary() -> (title: String, detail: String) {
        let url = syncDirectory.appendingPathComponent("strava_activities.json")
        let modifiedAt = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        guard
            let data = try? Data(contentsOf: url),
            let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return ("No Strava data", "Run Strava sync to refresh recent completed workouts.")
        }

        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let staleCutoff = calendar.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        let recent = raw.filter { item in
            let value = (item["start_date_local"] ?? item["start_date"]) as? String
            guard let value, let date = Self.flexDate(value) else { return false }
            return date >= cutoff
        }

        if recent.isEmpty, let modifiedAt, modifiedAt < staleCutoff {
            let latestActivity = raw
                .compactMap { ($0["start_date_local"] ?? $0["start_date"]) as? String }
                .compactMap(Self.flexDate)
                .max()
            let latestText = latestActivity.map {
                "Latest activity in file: \($0.formatted(date: .abbreviated, time: .omitted))."
            } ?? "No dated activities found in file."
            return (
                "Strava sync stale",
                "Last Strava file update: \(modifiedAt.formatted(date: .abbreviated, time: .shortened)).\n\(latestText)\nRun Strava sync to pull recent workouts."
            )
        }

        let names = recent.prefix(4).compactMap { $0["name"] as? String }
        let title = "\(recent.count) activities in 7 days"
        let detail = names.isEmpty ? "Recent activity details are available after the next Strava sync." : names.joined(separator: "\n")
        return (title, detail)
    }

    private func loadRecovery() -> (title: String, detail: String) {
        let health = healthExportDirectory

        if let export = HealthAutoExport.latest(in: health) {
            let lines = export.healthSummaryLines()
            if !lines.isEmpty {
                return ("Health export loaded", lines.joined(separator: "\n"))
            }
        }

        let hrv = readTrimmed(health.appendingPathComponent("HRV.txt"))
        let resting = readTrimmed(health.appendingPathComponent("Resting HR.txt"))
        let sleep = readTrimmed(health.appendingPathComponent("Sleep.txt"))

        var lines: [String] = []
        if !hrv.isEmpty { lines.append("HRV: \(hrv.summaryLines(maxLines: 2, fallback: hrv))") }
        if !resting.isEmpty { lines.append("Resting HR: \(resting.summaryLines(maxLines: 2, fallback: resting))") }
        if !sleep.isEmpty { lines.append("Sleep: \(sleep.summaryLines(maxLines: 3, fallback: sleep))") }

        return lines.isEmpty
            ? ("Recovery data missing", "Add or refresh Health Export files for sleep, HRV, and resting heart rate.")
            : ("Health export loaded", lines.joined(separator: "\n"))
    }

    private func loadWeightLine() -> String {
        let health = healthExportDirectory

        if let export = HealthAutoExport.latest(in: health),
           let weight = export.latestQuantity(for: "weight_body_mass") {
            return formatWeightLine(weight)
        }

        let url = health.appendingPathComponent("Weight.txt")
        let text = readTrimmed(url)
        guard let weight = text.doubles.last else {
            return "Weight file not available"
        }

        return formatWeightLine(weight)
    }

    private func formatWeightLine(_ weight: Double) -> String {
        let lost = 239 - weight
        let to190 = weight - 190
        let to180 = weight - 180
        return String(format: "%.1f lb | %.1f down, %.1f to 190, %.1f to 180", weight, lost, to190, to180)
    }

    private func loadMorningBrief() -> (text: String, timestamp: String) {
        let todayName = "morning_brief_\(Self.isoDate.string(from: Date())).txt"
        let candidates = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/\(todayName)"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Documents/Morning Brief.txt")
        ]

        for url in candidates {
            if let text = try? String(contentsOf: url, encoding: .utf8), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (cleanBrief(text), FileStatus.present(url).summary)
            }
        }

        return ("No morning brief found for today. Run Morning Brief from the sidebar.", "Not generated")
    }

    private func makeFileStatuses() -> [String: FileStatus] {
        [
            "twopeak_sessions.json",
            "strava_activities.json",
            "training_plan.ics",
            "garmin_activities.json",
            "garmin_daily_stats.json"
        ].reduce(into: [:]) { result, file in
            result[file] = FileStatus.forURL(syncDirectory.appendingPathComponent(file), label: file)
        }
    }

    private func cleanBrief(_ text: String) -> String {
        var cleaned = stripDataMarkers(text)
            .components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespacesAndNewlines) != "---" }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let replacements = [
            "**": "",
            "*Note:": "Note:",
            "*": "",
            "🟡": "Yellow:"
        ]

        for (needle, replacement) in replacements {
            cleaned = cleaned.replacingOccurrences(of: needle, with: replacement)
        }

        return cleaned
    }

    private func latestMTIFile(todayKey: String) -> URL? {
        let todaySpecific = glob(prefix: "mti_polar_week", suffix: "_\(todayKey).txt")
        if let exact = todaySpecific.max(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            return exact
        }
        return glob(prefix: "mti_polar_week", suffix: ".txt")
            .max(by: { ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast) })
    }

    private func glob(prefix: String, suffix: String) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: syncDirectory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return items.filter { $0.lastPathComponent.hasPrefix(prefix) && $0.lastPathComponent.hasSuffix(suffix) }
    }

    private func readTrimmed(_ url: URL) -> String {
        stripDataMarkers((try? String(contentsOf: url, encoding: .utf8)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripDataMarkers(_ text: String) -> String {
        text
            .replacingOccurrences(of: "{x}", with: "")
            .replacingOccurrences(of: "{X}", with: "")
    }

    static let isoDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func flexDate(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        return isoDate.date(from: String(value.prefix(10)))
    }
}

struct HealthAutoExport: Decodable {
    let data: HealthExportData

    static func latest(in directory: URL) -> HealthAutoExport? {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []

        let candidates = files.filter {
            $0.lastPathComponent.hasPrefix("HealthAutoExport-")
                && $0.pathExtension.lowercased() == "json"
        }

        guard let url = candidates.max(by: {
            ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast)
        }) else {
            return nil
        }

        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(HealthAutoExport.self, from: data)
    }

    func latestQuantity(for metricName: String) -> Double? {
        metric(named: metricName)?.latestPoint?.quantityValue
    }

    func healthSummaryLines() -> [String] {
        let metricsByName = Dictionary(uniqueKeysWithValues: data.metrics.map { ($0.name, $0) })
        let priority = [
            "heart_rate_variability",
            "resting_heart_rate",
            "heart_rate",
            "sleep_analysis",
            "weight_body_mass",
            "active_energy",
            "step_count",
            "walking_running_distance",
            "dietary_energy",
            "protein",
            "carbohydrates",
            "total_fat"
        ]

        var used = Set<String>()
        var lines = priority.compactMap { name -> String? in
            used.insert(name)
            return metricsByName[name]?.summaryLine
        }

        let remaining = data.metrics
            .filter { !used.contains($0.name) }
            .sorted { $0.displayName < $1.displayName }
            .compactMap(\.summaryLine)

        lines.append(contentsOf: remaining)

        if let medicationCount = data.medications?.count, medicationCount > 0 {
            lines.append("Medications: \(medicationCount) scheduled entries")
        }

        return lines
    }

    private func metric(named name: String) -> HealthMetric? {
        data.metrics.first { $0.name == name }
    }
}

struct HealthExportData: Decodable {
    let metrics: [HealthMetric]
    let medications: [HealthMedication]?
}

struct HealthMetric: Decodable {
    let name: String
    let units: String
    let data: [HealthMetricPoint]

    var latestPoint: HealthMetricPoint? {
        data.max { ($0.date ?? "") < ($1.date ?? "") }
    }

    var displayName: String {
        let customNames = [
            "heart_rate_variability": "HRV",
            "resting_heart_rate": "Resting HR",
            "sleep_analysis": "Sleep",
            "weight_body_mass": "Weight",
            "dietary_energy": "Dietary Energy",
            "active_energy": "Active Energy",
            "step_count": "Steps",
            "walking_running_distance": "Walk/Run Distance",
            "vo2_max": "VO2 Max"
        ]

        if let customName = customNames[name] {
            return customName
        }

        return name
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    var summaryLine: String? {
        guard let point = latestPoint else { return nil }

        if name == "sleep_analysis", let totalSleep = point.totalSleep {
            return "\(displayName): \(format(totalSleep)) hr total, \(format(point.deep)) deep, \(format(point.rem)) REM"
        }

        if let average = point.average {
            var pieces = ["avg \(format(average))"]
            if let min = point.min { pieces.append("min \(format(min))") }
            if let max = point.max { pieces.append("max \(format(max))") }
            return "\(displayName): \(pieces.joined(separator: ", ")) \(units)"
        }

        guard let value = point.quantityValue else { return nil }
        return "\(displayName): \(format(value)) \(units)"
    }

    private func format(_ value: Double?) -> String {
        guard let value else { return "0" }
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        if abs(value) >= 100 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }
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

    var quantityValue: Double? {
        quantity ?? average ?? totalSleep
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

struct HealthMedication: Decodable {}

enum PolarSchedule {
    struct Entry {
        let week: Int
        let session: Int
    }

    static func entry(for date: Date) -> Entry? {
        let key = TrainingDataLoader.isoDate.string(from: date)
        return schedule[key].map { Entry(week: $0.0, session: $0.1) }
    }

    private static let schedule: [String: (Int, Int)] = [
        "2026-04-27": (1, 5), "2026-04-28": (1, 6), "2026-04-29": (1, 7),
        "2026-05-01": (2, 1), "2026-05-02": (2, 2), "2026-05-03": (2, 3),
        "2026-05-05": (2, 5), "2026-05-06": (2, 6), "2026-05-07": (2, 7),
        "2026-05-09": (3, 1), "2026-05-10": (3, 2), "2026-05-11": (3, 3),
        "2026-05-13": (3, 5), "2026-05-14": (3, 6), "2026-05-15": (3, 7),
        "2026-05-17": (4, 1), "2026-05-18": (4, 2), "2026-05-19": (4, 3),
        "2026-05-21": (4, 5), "2026-05-22": (4, 6), "2026-05-23": (4, 7),
        "2026-05-25": (5, 1), "2026-05-26": (5, 2), "2026-05-27": (5, 3),
        "2026-05-29": (5, 5), "2026-05-30": (5, 6), "2026-05-31": (5, 7),
        "2026-06-02": (6, 1), "2026-06-03": (6, 2), "2026-06-04": (6, 3),
        "2026-06-06": (6, 5), "2026-06-07": (6, 6), "2026-06-08": (6, 7),
        "2026-06-10": (7, 1), "2026-06-11": (7, 2), "2026-06-12": (7, 3),
        "2026-06-14": (7, 5), "2026-06-15": (7, 6), "2026-06-16": (7, 7),
        "2026-06-18": (8, 1), "2026-06-19": (8, 2), "2026-06-20": (8, 3),
        "2026-06-22": (8, 5), "2026-06-23": (8, 6), "2026-06-24": (8, 7)
    ]
}

struct TrainingSnapshot {
    let am: WorkoutSummary
    let pm: WorkoutSummary
    let isRestDay: Bool
    let recoveryTitle: String
    let recoveryDetail: String
    let recentLoadTitle: String
    let recentLoadDetail: String
    let trainingSignal: TrainingSignal
    let morningBrief: String
    let briefTimestamp: String
    let calendarDays: [TrainingDay]
    let weightLine: String
    let fileStatuses: [String: FileStatus]
    let latestMTIStatus: FileStatus

    static let empty = TrainingSnapshot(
        am: WorkoutSummary(title: "Loading", detail: ""),
        pm: WorkoutSummary(title: "Loading", detail: ""),
        isRestDay: false,
        recoveryTitle: "Loading",
        recoveryDetail: "",
        recentLoadTitle: "Loading",
        recentLoadDetail: "",
        trainingSignal: .unknown,
        morningBrief: "",
        briefTimestamp: "",
        calendarDays: [],
        weightLine: "",
        fileStatuses: [:],
        latestMTIStatus: .missing("mti_polar_week*")
    )
}

struct SharedSnapshotWriter {
    static func write(_ snapshot: TrainingSnapshot) {
        let shared = SharedTrainingSnapshot(snapshot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(shared) else { return }

        for url in outputURLs {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
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

    init(_ snapshot: TrainingSnapshot) {
        date = Date()
        signal = snapshot.trainingSignal.level.sharedValue
        signalReason = snapshot.trainingSignal.detail
        phase = snapshot.isRestDay ? "Recovery day in the Polar X schedule" : "Training day in the Polar X schedule"
        weightLine = snapshot.weightLine
        am = SharedWorkoutSummary(label: "AM", title: snapshot.am.title, details: snapshot.am.detail.detailLines(fallback: snapshot.am.detail))
        pm = SharedWorkoutSummary(label: "PM", title: snapshot.pm.title, details: snapshot.pm.detail.detailLines(fallback: snapshot.pm.detail))
        recovery = ([snapshot.recoveryTitle] + snapshot.recoveryDetail.detailLines(fallback: snapshot.recoveryDetail))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        recentLoad = [snapshot.recentLoadTitle, snapshot.recentLoadDetail]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
        calendarDays = snapshot.calendarDays.map(SharedTrainingDay.init)
        brief = snapshot.morningBrief
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

    init(_ day: TrainingDay) {
        date = day.date
        am = day.am
        pm = day.pm
    }
}

struct WorkoutSummary {
    let title: String
    let detail: String
}

struct TrainingDay: Identifiable {
    let id = UUID()
    let date: Date
    let weekday: String
    let dayNumber: String
    let am: String
    let pm: String
    let isToday: Bool
}

struct TrainingSignal {
    enum Level {
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
    }

    let level: Level
    let title: String
    let detail: String

    static let unknown = TrainingSignal(
        level: .yellow,
        title: "Awaiting brief",
        detail: "Run Morning Brief for today's training signal."
    )
}

extension TrainingSignal.Level {
    var sharedValue: String {
        switch self {
        case .red: return "red"
        case .yellow: return "yellow"
        case .green: return "green"
        }
    }
}

struct TwoPeakSession: Decodable {
    let url: String?
    let summary: String
    let duration: String
    let detail: String
}

struct FileStatus {
    let exists: Bool
    let summary: String

    static func forURL(_ url: URL, label: String) -> FileStatus {
        FileManager.default.fileExists(atPath: url.path) ? present(url) : missing(label)
    }

    static func present(_ url: URL) -> FileStatus {
        let date = url.modificationDate?.formatted(date: .abbreviated, time: .shortened) ?? "unknown date"
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return FileStatus(exists: true, summary: "\(url.lastPathComponent)\n\(date)\n\(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))")
    }

    static func missing(_ label: String) -> FileStatus {
        FileStatus(exists: false, summary: "\(label) not found")
    }
}

struct SyncScript: Identifiable {
    let id = UUID()
    let title: String
    let path: String
    let symbol: String
}

struct RunStatus {
    let title: String
    let message: String
    let ok: Bool
}

enum ScriptRunner {
    static func run(_ script: SyncScript) -> RunStatus {
        let process = Process()
        let python = firstExistingPath([
            "/Library/Frameworks/Python.framework/Versions/3.10/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ])
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = [script.path]
        process.environment = mergedEnvironment()

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let ok = process.terminationStatus == 0
            let message = friendlyMessage(for: output, script: script, exitCode: process.terminationStatus)
            return RunStatus(
                title: ok ? "\(script.title) complete" : "\(script.title) failed",
                message: message,
                ok: ok
            )
        } catch {
            return RunStatus(title: "\(script.title) failed", message: error.localizedDescription, ok: false)
        }
    }

    private static func firstExistingPath(_ paths: [String]) -> String {
        paths.first { FileManager.default.fileExists(atPath: $0) } ?? "/usr/bin/python3"
    }

    private static func mergedEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let extraPath = [
            "/Library/Frameworks/Python.framework/Versions/3.10/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ].joined(separator: ":")

        if let existing = environment["PATH"], !existing.isEmpty {
            environment["PATH"] = "\(extraPath):\(existing)"
        } else {
            environment["PATH"] = extraPath
        }

        environment["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        return environment
    }

    private static func friendlyMessage(for output: String, script: SyncScript, exitCode: Int32) -> String {
        if output.contains("Cookies.binarycookies") && output.contains("PermissionError") {
            return """
            macOS blocked access to Safari cookies.

            Garmin sync currently authenticates through your Safari Garmin session. To allow it, add Polar Coach and Python 3.10 to Full Disk Access, or refresh Garmin auth with a token-based flow.

            System Settings > Privacy & Security > Full Disk Access
            App: PolarCoach.app
            Python: /Library/Frameworks/Python.framework/Versions/3.10/bin/python3
            """
        }

        if output.contains("GarminConnectAuthenticationError") || output.contains("401 Client Error: Unauthorized") {
            return """
            Garmin auth is expired.

            Re-run Garmin login/token setup from Terminal, then try Garmin sync again.
            """
        }

        if output.contains("env: node: No such file or directory") {
            return """
            Claude could not find Node.

            The app has been updated to add /opt/homebrew/bin to PATH. Quit and reopen Polar Coach, then run Morning Brief again.
            """
        }

        if output.contains("ModuleNotFoundError: No module named 'playwright'") {
            return """
            This script ran with a Python that does not have Playwright.

            The app now prefers /Library/Frameworks/Python.framework/Versions/3.10/bin/python3. Quit and reopen Polar Coach, then run this sync again.
            """
        }

        if output.isEmpty {
            return "Exit code \(exitCode)"
        }

        return output
    }
}

extension URL {
    var modificationDate: Date? {
        try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}

extension String {
    var cleanLines: [String] {
        components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var isZoneLabel: Bool {
        ["Z1", "Z2", "Z3", "Z4", "Z5", "BR"].contains(self)
    }

    func cleanedTrainingTitle(defaultValue: String) -> String {
        let clean = replacingOccurrences(of: "2PEAK Training:", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? defaultValue : clean
    }

    func summaryLines(maxLines: Int, fallback: String) -> String {
        let lines = components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let summary = lines.prefix(maxLines).joined(separator: "\n")
        return summary.isEmpty ? fallback : summary
    }

    func detailLines(fallback: String) -> [String] {
        let lines = components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: " | ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty && !fallback.isEmpty ? [fallback] : lines
    }

    func firstMatch(_ pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, range: range), match.numberOfRanges > 1 else { return nil }
        let capture = match.range(at: match.numberOfRanges - 1)
        guard let swiftRange = Range(capture, in: self) else { return nil }
        return String(self[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var doubles: [Double] {
        let regex = try? NSRegularExpression(pattern: #"[-+]?\d*\.?\d+"#)
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex?.matches(in: self, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: self) else { return nil }
            return Double(self[swiftRange])
        } ?? []
    }
}
