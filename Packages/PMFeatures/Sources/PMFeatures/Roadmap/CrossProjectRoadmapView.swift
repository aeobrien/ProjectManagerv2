import SwiftUI
import PMDomain
import PMDesignSystem

/// Cross-project roadmap showing milestones across all projects with deadlines and status.
public struct CrossProjectRoadmapView: View {
    @Bindable var viewModel: CrossProjectRoadmapViewModel
    @State private var statusFilter: ItemStatus?

    public init(viewModel: CrossProjectRoadmapViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    ProgressView("Loading roadmap...")
                        .frame(maxWidth: .infinity)
                } else if viewModel.milestones.isEmpty {
                    PMEmptyState(
                        icon: "map",
                        title: "No Milestones",
                        message: "Create milestones in your projects to see them on the cross-project roadmap."
                    )
                } else {
                    statsBar
                    filterBar
                    overdueSection
                    upcomingSection
                    milestonesByProjectSection
                    unscheduledSection
                }

                errorSection
            }
            .padding()
        }
        .navigationTitle("Cross-Project Roadmap")
        .task { await viewModel.load() }
    }

    // MARK: - Stats

    private var statsBar: some View {
        HStack(spacing: 16) {
            statBadge(label: "Projects", value: "\(viewModel.projectCount)", color: .blue)
            statBadge(label: "Milestones", value: "\(viewModel.milestones.count)", color: .purple)
            statBadge(label: "Overdue", value: "\(viewModel.overdue.count)", color: viewModel.overdue.isEmpty ? .green : .red)
            statBadge(label: "Upcoming", value: "\(viewModel.upcomingDeadlines.count)", color: .orange)
        }
    }

    // MARK: - Filter

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: statusFilter == nil) {
                    statusFilter = nil
                }
                ForEach([ItemStatus.notStarted, .inProgress, .completed], id: \.self) { status in
                    FilterChip(
                        label: status.rawValue.camelCaseToWords,
                        isSelected: statusFilter == status
                    ) {
                        statusFilter = status
                    }
                }
            }
        }
    }

    // MARK: - Overdue

    @ViewBuilder
    private var overdueSection: some View {
        let overdue = viewModel.overdue
        if !overdue.isEmpty && statusFilter == nil {
            PMCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.red)

                    ForEach(overdue) { milestone in
                        milestoneRow(milestone)
                    }
                }
            }
        }
    }

    // MARK: - Upcoming

    @ViewBuilder
    private var upcomingSection: some View {
        let upcoming = viewModel.upcomingDeadlines
        if !upcoming.isEmpty && statusFilter == nil {
            PMCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Upcoming Deadlines", systemImage: "calendar.badge.clock")
                        .font(.headline)

                    ForEach(upcoming) { milestone in
                        milestoneRow(milestone)
                    }
                }
            }
        }
    }

    // MARK: - By Project

    private var milestonesByProjectSection: some View {
        let grouped = viewModel.milestonesByProject
        return ForEach(Array(grouped.keys.sorted(by: { $0.uuidString < $1.uuidString })), id: \.self) { projectId in
            if let projectMilestones = grouped[projectId] {
                let filtered = statusFilter.map { status in projectMilestones.filter { $0.status == status } } ?? projectMilestones
                if !filtered.isEmpty {
                    PMCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(SlotColour.forIndex(filtered.first?.colorIndex))
                                    .frame(width: 10, height: 10)
                                Text(filtered.first?.projectName ?? "Project")
                                    .font(.headline)
                            }

                            ForEach(filtered) { milestone in
                                milestoneRow(milestone)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Unscheduled

    @ViewBuilder
    private var unscheduledSection: some View {
        let unscheduled = viewModel.unscheduled
        if !unscheduled.isEmpty && statusFilter == nil {
            PMCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("No Deadline Set", systemImage: "calendar.badge.minus")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ForEach(unscheduled) { milestone in
                        milestoneRow(milestone)
                    }
                }
            }
        }
    }

    // MARK: - Row

    private func milestoneRow(_ milestone: CrossProjectMilestone) -> some View {
        HStack(spacing: 8) {
            Image(systemName: milestone.status == .completed ? "diamond.fill" : "diamond")
                .font(.caption)
                .foregroundStyle(statusColor(milestone.status))

            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.milestoneName)
                    .font(.subheadline)
                Text(milestone.projectName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let deadline = milestone.deadline {
                Text(deadline, style: .date)
                    .font(.caption)
                    .foregroundStyle(deadline < Date() && milestone.status != .completed ? .red : .secondary)
            }

            Text(milestone.status.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor(milestone.status).opacity(0.1), in: Capsule())
                .foregroundStyle(statusColor(milestone.status))
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

    private func statBadge(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func statusColor(_ status: ItemStatus) -> Color {
        switch status {
        case .notStarted: .secondary
        case .inProgress: .blue
        case .completed: .green
        case .blocked: .red
        case .waiting: .orange
        }
    }
}
