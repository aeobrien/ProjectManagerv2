import SwiftUI
import PMDomain
import PMDesignSystem

/// Tab options for the cross-project roadmap.
enum RoadmapTab: String, CaseIterable {
    case upcoming = "Upcoming"
    case all = "All"
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case completed = "Completed"
    case noDeadline = "No Deadline"
}

/// Cross-project roadmap showing milestones across all projects with deadlines and status.
public struct CrossProjectRoadmapView: View {
    @Bindable var viewModel: CrossProjectRoadmapViewModel
    @State private var selectedTab: RoadmapTab = .upcoming

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
                    tabBar

                    // Overdue banner shown on Upcoming and All tabs
                    if selectedTab == .upcoming || selectedTab == .all {
                        overdueSection
                    }

                    milestoneList
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

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RoadmapTab.allCases, id: \.self) { tab in
                    FilterChip(
                        label: tab.rawValue,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
        }
    }

    // MARK: - Overdue

    @ViewBuilder
    private var overdueSection: some View {
        let overdue = viewModel.overdue
        if !overdue.isEmpty {
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

    // MARK: - Milestone List

    private var milestoneList: some View {
        let filtered = filteredMilestones
        return Group {
            if filtered.isEmpty {
                PMEmptyState(
                    icon: emptyIcon,
                    title: "No Milestones",
                    message: emptyMessage
                )
            } else {
                // Group by project
                let grouped = Dictionary(grouping: filtered, by: \.projectId)
                ForEach(Array(grouped.keys.sorted(by: { $0.uuidString < $1.uuidString })), id: \.self) { projectId in
                    if let projectMilestones = grouped[projectId] {
                        PMCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(SlotColour.forIndex(projectMilestones.first?.colorIndex))
                                        .frame(width: 10, height: 10)
                                    Text(projectMilestones.first?.projectName ?? "Project")
                                        .font(.headline)
                                }

                                ForEach(projectMilestones) { milestone in
                                    milestoneRow(milestone)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredMilestones: [CrossProjectMilestone] {
        switch selectedTab {
        case .upcoming:
            return viewModel.upcomingDeadlines
        case .all:
            return viewModel.milestones
        case .notStarted:
            return viewModel.milestones(with: .notStarted)
        case .inProgress:
            return viewModel.milestones(with: .inProgress)
        case .completed:
            return viewModel.milestones(with: .completed)
        case .noDeadline:
            return viewModel.unscheduled
        }
    }

    private var emptyIcon: String {
        switch selectedTab {
        case .upcoming: "calendar"
        case .all: "map"
        case .notStarted: "circle"
        case .inProgress: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle"
        case .noDeadline: "calendar.badge.minus"
        }
    }

    private var emptyMessage: String {
        switch selectedTab {
        case .upcoming: "No milestones with deadlines set."
        case .all: "No milestones found."
        case .notStarted: "No milestones waiting to start."
        case .inProgress: "No milestones in progress."
        case .completed: "No milestones completed yet."
        case .noDeadline: "All milestones have deadlines set."
        }
    }

    // MARK: - Row

    private func milestoneRow(_ milestone: CrossProjectMilestone) -> some View {
        let status = milestone.computedStatus
        return HStack(spacing: 8) {
            Image(systemName: status == .completed ? "diamond.fill" : "diamond")
                .font(.caption)
                .foregroundStyle(statusColor(status))

            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.milestoneName)
                    .font(.subheadline)
                HStack(spacing: 4) {
                    Text(milestone.projectName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if milestone.totalTasks > 0 {
                        Text("\(milestone.completedTasks)/\(milestone.totalTasks) tasks")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if let deadline = milestone.deadline {
                Text(deadline, style: .date)
                    .font(.caption)
                    .foregroundStyle(deadline < Date() && status != .completed ? .red : .secondary)
            }

            Text(status.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor(status).opacity(0.1), in: Capsule())
                .foregroundStyle(statusColor(status))
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
