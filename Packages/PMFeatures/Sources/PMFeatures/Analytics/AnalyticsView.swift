import SwiftUI
import PMDomain
import PMDesignSystem
import PMServices

/// Dashboard showing project analytics — estimate accuracy, completion rates, and patterns.
public struct AnalyticsView: View {
    var viewModel: AnalyticsViewModel
    let project: Project

    public init(viewModel: AnalyticsViewModel, project: Project) {
        self.viewModel = viewModel
        self.project = project
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    ProgressView("Loading analytics...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !viewModel.hasEnoughData {
                    PMEmptyState(
                        icon: "chart.bar",
                        title: "Not Enough Data",
                        message: "Complete more tasks to see analytics and estimate accuracy insights."
                    )
                } else {
                    summarySection
                    estimateAccuracySection
                    effortBreakdownSection
                    deferredTasksSection
                }

                errorSection
            }
            .padding()
        }
        .navigationTitle("Analytics: \(project.name)")
        .task { await viewModel.load(projectId: project.id) }
    }

    // MARK: - Summary

    @ViewBuilder
    private var summarySection: some View {
        if let summary = viewModel.summary {
            PMCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Project Summary")
                        .font(.headline)

                    HStack(spacing: 16) {
                        statCell(label: "Total Tasks", value: "\(summary.totalTasks)")
                        statCell(label: "Completed", value: "\(summary.completedTasks)")
                        if let rate = viewModel.completionRate {
                            statCell(label: "Completion", value: "\(Int(rate * 100))%")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Estimate Accuracy

    @ViewBuilder
    private var estimateAccuracySection: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Estimate Accuracy")
                    .font(.headline)

                if let accuracy = viewModel.estimateAccuracy {
                    HStack(spacing: 8) {
                        accuracyGauge(value: accuracy)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.accuracyDescription(accuracy))
                                .font(.subheadline)
                            if let multiplier = viewModel.suggestedMultiplier {
                                Text(viewModel.multiplierDescription(multiplier))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let trend = viewModel.accuracyTrend {
                        HStack(spacing: 4) {
                            Image(systemName: trend.newer >= trend.older ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(trend.newer >= trend.older ? .green : .orange)
                            Text("Trend: \(Int(trend.older * 100))% → \(Int(trend.newer * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Add time estimates to tasks to see accuracy data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Effort Breakdown

    @ViewBuilder
    private var effortBreakdownSection: some View {
        if !viewModel.accuracyByEffort.isEmpty {
            PMCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accuracy by Effort Type")
                        .font(.headline)

                    ForEach(Array(viewModel.accuracyByEffort.sorted(by: { $0.key.rawValue < $1.key.rawValue })), id: \.key) { effort, accuracy in
                        HStack {
                            effort.icon
                                .foregroundStyle(effort.color)
                            Text(effort.rawValue.camelCaseToWords)
                                .font(.subheadline)

                            Spacer()

                            Text("\(Int(accuracy * 100))%")
                                .font(.subheadline.monospacedDigit())

                            if let avg = viewModel.averageTimeByEffort[effort] {
                                Text("avg \(Int(avg))m")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Deferred Tasks

    @ViewBuilder
    private var deferredTasksSection: some View {
        if !viewModel.frequentlyDeferred.isEmpty {
            deferredTasksCard
        }
    }

    private var deferredTasksCard: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Frequently Deferred", systemImage: "arrow.uturn.backward")
                    .font(.headline)
                    .foregroundStyle(.orange)

                ForEach(viewModel.frequentlyDeferred) { task in
                    HStack {
                        Text(task.name)
                            .font(.subheadline)
                        Spacer()
                        Text("\(task.timesDeferred) deferrals")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.error {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func accuracyGauge(value: Float) -> some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(min(value, 1.0)))
                .stroke(
                    value > 0.8 ? Color.green : value > 0.5 ? Color.orange : Color.red,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(Int(value * 100))%")
                .font(.caption.monospacedDigit())
        }
        .frame(width: 50, height: 50)
    }
}
