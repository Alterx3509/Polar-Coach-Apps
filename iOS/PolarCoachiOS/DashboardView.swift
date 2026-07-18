import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var importingSnapshot = false
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
                    recommendationCard
                    actionGrid
                    recoveryAndFuelingGrid
                    whyCard
                    dataCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Polar Coach")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        importingSnapshot = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Import shared Health Export snapshot")

                    Button {
                        refresh()
                    } label: {
                        Image(systemName: isRefreshing ? "hourglass" : "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                    .accessibilityLabel("Refresh Health Export snapshot")
                }
            }
            .fileImporter(
                isPresented: $importingSnapshot,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                if case let .success(urls) = result, let url = urls.first {
                    store.importBrief(from: url)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.title2.weight(.semibold))
            Text("What should I do today?")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(store.snapshot.phase)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var recommendationCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: recommendationSymbol)
                .font(.title2)
                .foregroundStyle(store.snapshot.signal.color)
                .frame(width: 38, height: 38)
                .background(store.snapshot.signal.color.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(recommendationKicker)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(store.snapshot.signal.color)
                    .textCase(.uppercase)
                Text(store.snapshot.am.title)
                    .font(.title2.weight(.semibold))
                Text(store.snapshot.signalReason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(store.snapshot.signal.color.opacity(0.08))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(store.snapshot.signal.color.opacity(0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var actionGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            CoachCard(
                title: "Today",
                value: store.snapshot.am.title,
                detail: store.snapshot.am.details.joined(separator: "\n"),
                symbol: "figure.strengthtraining.traditional"
            )
            CoachCard(
                title: "Adjustment",
                value: store.snapshot.pm.title,
                detail: store.snapshot.pm.details.joined(separator: "\n"),
                symbol: "slider.horizontal.3"
            )
        }
    }

    private var recoveryAndFuelingGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            CoachCard(
                title: "Recovery",
                value: recoveryTitle,
                detail: recoveryDetail,
                symbol: "heart"
            )
            CoachCard(
                title: "Fueling",
                value: fuelingTitle,
                detail: fuelingDetail,
                symbol: "fork.knife"
            )
        }
    }

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Why this recommendation", systemImage: "text.bubble")
                .font(.headline)
            Text(store.snapshot.signalReason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            if !store.snapshot.brief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Divider()
                Text(store.snapshot.brief)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
        .coachCardStyle()
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Health Export", systemImage: "externaldrive")
                .font(.headline)

            HStack(spacing: 10) {
                StatusPill(title: "Source", value: "Mac Health Export", symbol: "folder")
                StatusPill(
                    title: "Updated",
                    value: store.lastUpdated.formatted(date: .abbreviated, time: .shortened),
                    symbol: "clock"
                )
            }

            Text(store.importStatus)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("The iPhone app uses the snapshot created from the newest HealthAutoExport JSON file on your Mac. It no longer reads a second copy directly from HealthKit.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .coachCardStyle()
    }

    private var recoveryTitle: String {
        store.snapshot.recovery.first ?? "Unknown"
    }

    private var recoveryDetail: String {
        let detail = store.snapshot.recovery.dropFirst().joined(separator: "\n")
        return detail.isEmpty ? "Sleep, HRV, and resting heart rate were not available." : detail
    }

    private var fuelingLines: [String] {
        store.snapshot.recentLoad
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var fuelingTitle: String {
        fuelingLines.first ?? "Unknown"
    }

    private var fuelingDetail: String {
        let detail = fuelingLines.dropFirst().joined(separator: "\n")
        return detail.isEmpty ? "Protein and calorie data were not available." : detail
    }

    private var recommendationKicker: String {
        switch store.snapshot.signal {
        case .red: return "Recovery priority"
        case .yellow: return "Modified training"
        case .green: return "Ready"
        }
    }

    private var recommendationSymbol: String {
        switch store.snapshot.signal {
        case .red: return "pause.fill"
        case .yellow: return "exclamationmark.triangle.fill"
        case .green: return "checkmark.circle.fill"
        }
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        store.refresh()
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            isRefreshing = false
        }
    }
}

struct CoachCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(3)
            Text(detail.isEmpty ? "No current data." : detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .coachCardStyle()
        .frame(minHeight: 185, alignment: .top)
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
                    .lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension View {
    func coachCardStyle() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
