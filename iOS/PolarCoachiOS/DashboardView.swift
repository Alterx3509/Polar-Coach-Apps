import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject private var store: TrainingStore
    @EnvironmentObject private var healthKit: HealthKitManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var importingBrief = false
    @State private var isRefreshing = false

    private var gridColumns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 2 : 1
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    todayGrid
                    morningBriefSection
                    CalendarStrip(days: store.snapshot.calendarDays)
                    dataStatusSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Polar Coach")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        importingBrief = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }

                    Button {
                        Task {
                            isRefreshing = true
                            store.refresh()
                            await healthKit.loadLatestMetrics()
                            isRefreshing = false
                        }
                    } label: {
                        Image(systemName: isRefreshing ? "hourglass" : "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                    .accessibilityLabel("Refresh training and health data")
                }
            }
            .fileImporter(
                isPresented: $importingBrief,
                allowedContentTypes: [.plainText, .json],
                allowsMultipleSelection: false
            ) { result in
                if case let .success(urls) = result, let url = urls.first {
                    store.importBrief(from: url)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(.title2.weight(.semibold))
                Text(store.snapshot.phase)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(store.snapshot.weightLine)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 8)

            StoplightCard(signal: store.snapshot.signal, reason: store.snapshot.signalReason)
        }
        .padding(.vertical, 4)
    }

    private var todayGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            MetricCard(
                title: "AM Cardio",
                value: store.snapshot.am.title,
                detail: store.snapshot.am.details.joined(separator: "\n"),
                symbol: "figure.run"
            )
            MetricCard(
                title: "PM Strength",
                value: store.snapshot.pm.title,
                detail: store.snapshot.pm.details.joined(separator: "\n"),
                symbol: "dumbbell"
            )
            MetricCard(
                title: "Recovery",
                value: recoveryTitle,
                detail: recoveryDetail,
                symbol: "heart"
            )
            MetricCard(
                title: "Recent Load",
                value: recentLoadTitle,
                detail: store.snapshot.recentLoad,
                symbol: "chart.xyaxis.line"
            )
        }
    }

    private var recoveryTitle: String {
        store.snapshot.recovery.first ?? "No recovery data"
    }

    private var recoveryDetail: String {
        let imported = store.snapshot.recovery.dropFirst().joined(separator: "\n")
        let healthLines = [
            healthKit.latestWeight.map { "Health weight: \($0)" },
            healthKit.latestHRV.map { "Health HRV: \($0)" },
            healthKit.latestRestingHR.map { "Health resting HR: \($0)" }
        ].compactMap { $0 }

        let lines = ([imported].filter { !$0.isEmpty } + healthLines)
        return lines.isEmpty ? healthKit.authorizationStatus : lines.joined(separator: "\n")
    }

    private var recentLoadTitle: String {
        let text = store.snapshot.recentLoad.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("no current") {
            return "No imported load"
        }
        return "Imported notes"
    }

    private var morningBriefSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Morning Brief", systemImage: "sun.max")
                    .font(.headline)
                Spacer()
                Text(store.importStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(store.snapshot.brief)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle()
    }

    private var dataStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Data", systemImage: "externaldrive")
                .font(.headline)

            HStack(spacing: 10) {
                StatusPill(title: "Brief", value: store.importStatus, symbol: "doc.text")
                StatusPill(title: "Updated", value: store.lastUpdated.formatted(date: .omitted, time: .shortened), symbol: "clock")
            }

            Button {
                Task { await healthKit.requestAccess() }
            } label: {
                Label("Connect Apple Health", systemImage: "heart.text.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text(healthKit.authorizationStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}

struct StoplightCard: View {
    let signal: TrainingSignal
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                dot(.red)
                dot(.yellow)
                dot(.green)
            }

            Text(signal.title)
                .font(.headline)
            Text(reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 150, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func dot(_ level: TrainingSignal) -> some View {
        Circle()
            .fill(level == signal ? level.color : level.color.opacity(0.18))
            .frame(width: level == signal ? 18 : 13, height: level == signal ? 18 : 13)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(3)

            Text(detail.isEmpty ? "No detail imported." : detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardStyle()
        .frame(minHeight: 210, alignment: .top)
    }
}

struct CalendarStrip: View {
    let days: [TrainingDay]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Training Calendar", systemImage: "calendar")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(days) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(day.weekday)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(day.dayNumber)
                                        .font(.title2.weight(.semibold))
                                }
                                Spacer()
                                if Calendar.current.isDateInToday(day.date) {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 8, height: 8)
                                }
                            }

                            Divider()

                            Text("AM \(day.am)")
                                .font(.caption)
                                .lineLimit(2)
                            Text("PM \(day.pm)")
                                .font(.caption)
                                .lineLimit(2)
                        }
                        .padding(12)
                        .frame(width: 132, alignment: .topLeading)
                        .frame(minHeight: 132, alignment: .topLeading)
                        .background(
                            Calendar.current.isDateInToday(day.date)
                            ? Color.accentColor.opacity(0.12)
                            : Color(.secondarySystemGroupedBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
        .cardStyle()
    }
}

struct StatusPill: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension View {
    func cardStyle() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
