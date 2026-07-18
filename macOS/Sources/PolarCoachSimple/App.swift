import AppKit
import Foundation
import SwiftUI

@main
struct PolarCoachMacApp: App {
    var body: some Scene {
        WindowGroup {
            CoachDashboardView()
                .frame(minWidth: 900, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct CoachDashboardView: View {
    @StateObject private var model = CoachViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    RecommendationCard(coach: model.coach)
                    actionGrid
                    recoveryGrid
                    explanationCard
                    dataCard
                }
                .padding(28)
                .frame(maxWidth: 1120)
                .frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle("Polar Coach")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        NSWorkspace.shared.open(model.healthExportDirectory)
                    } label: {
                        Label("Open Health Export", systemImage: "folder")
                    }

                    Button {
                        model.refresh()
                    } label: {
                        Label(model.isRefreshing ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isRefreshing)
                }
            }
        }
        .onAppear { model.refresh() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(.largeTitle.weight(.semibold))
                Text("What should I do today?")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(model.coach.confidenceLabel)
                    .font(.headline)
                Text(model.coach.sourceFreshness)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionGrid: some View {
        Grid(horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
                CoachCard(
                    title: "Today",
                    value: model.coach.actionTitle,
                    detail: model.coach.actionDetail,
                    symbol: "figure.strengthtraining.traditional"
                )
                CoachCard(
                    title: "Adjustment",
                    value: model.coach.adjustmentTitle,
                    detail: model.coach.adjustmentDetail,
                    symbol: "slider.horizontal.3"
                )
            }
        }
    }

    private var recoveryGrid: some View {
        Grid(horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
                CoachCard(
                    title: "Recovery",
                    value: model.coach.recoveryStatus,
                    detail: model.coach.recoveryDetail,
                    symbol: "heart"
                )
                CoachCard(
                    title: "Fueling",
                    value: model.coach.fuelingStatus,
                    detail: model.coach.fuelingDetail,
                    symbol: "fork.knife"
                )
            }
        }
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Why this recommendation", systemImage: "text.bubble")
                .font(.headline)
            Text(model.coach.reason)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .textSelection(.enabled)
        }
        .coachCardStyle()
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Health Export", systemImage: "externaldrive")
                    .font(.headline)
                Spacer()
                if model.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text(model.statusMessage)
                .font(.callout)
                .foregroundStyle(model.hasImportError ? .red : .secondary)

            if let fileName = model.coach.sourceFileName {
                LabeledContent("File", value: fileName)
                LabeledContent("Updated", value: model.coach.sourceUpdatedText)
                LabeledContent("Inputs", value: model.coach.inputSummary)
            }

            if !model.coach.missingInputs.isEmpty {
                Text("Missing: \(model.coach.missingInputs.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(model.healthExportDirectory.path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .coachCardStyle()
    }
}

struct RecommendationCard: View {
    let coach: DailyCoach

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: coach.signal.symbol)
                    .font(.title2)
                    .foregroundStyle(coach.signal.color)
                    .frame(width: 34, height: 34)
                    .background(coach.signal.color.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(coach.signal.kicker)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(coach.signal.color)
                        .textCase(.uppercase)
                    Text(coach.actionTitle)
                        .font(.title.weight(.semibold))
                    Text(coach.reason)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(coach.signal.color.opacity(0.08))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(coach.signal.color.opacity(0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            Text(detail.isEmpty ? "No current data." : detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .coachCardStyle()
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
    }
}

extension View {
    func coachCardStyle() -> some View {
        padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
