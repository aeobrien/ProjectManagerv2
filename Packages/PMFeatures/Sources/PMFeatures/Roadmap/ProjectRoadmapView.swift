import SwiftUI
import PMDomain
import PMDesignSystem

/// A vertical timeline view of a project's full hierarchy with dependency indicators.
public struct ProjectRoadmapView: View {
    @Bindable var viewModel: ProjectRoadmapViewModel

    public init(viewModel: ProjectRoadmapViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            roadmapHeader
            Divider()

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.items.isEmpty {
                PMEmptyState(
                    icon: "map",
                    title: "No Roadmap Items",
                    message: "Add phases and milestones to see them here."
                )
            } else {
                timelineContent
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Header

    private var roadmapHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.project.name)
                    .font(.title3)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    Text("\(viewModel.phaseCount) phases")
                    Text("\(viewModel.milestoneCount) milestones")
                    Text("\(viewModel.taskCount) tasks")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                PMProgressLabel(progress: viewModel.overallProgress)
                PMProgressBar(progress: viewModel.overallProgress, tint: .blue)
                    .frame(width: 100)
            }
        }
        .padding()
    }

    // MARK: - Timeline

    private var timelineContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.items) { item in
                    RoadmapItemRow(item: item, viewModel: viewModel)
                }
            }
            .padding()
        }
    }
}

// MARK: - Roadmap Item Row

struct RoadmapItemRow: View {
    let item: RoadmapItem
    let viewModel: ProjectRoadmapViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Timeline gutter
            timelineGutter
                .frame(width: gutterWidth)

            // Content
            itemContent
                .padding(.vertical, verticalPadding)
        }
    }

    private var gutterWidth: CGFloat {
        switch item.kind {
        case .phase: 24
        case .milestone: 48
        case .task: 72
        }
    }

    private var verticalPadding: CGFloat {
        switch item.kind {
        case .phase: 8
        case .milestone: 4
        case .task: 2
        }
    }

    private var timelineGutter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(timelineColor)
                .frame(width: timelineWidth)
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .center) {
            timelineNode
        }
    }

    private var timelineWidth: CGFloat {
        switch item.kind {
        case .phase: 3
        case .milestone: 2
        case .task: 1
        }
    }

    private var timelineColor: Color {
        switch item.kind {
        case .phase: .primary.opacity(0.2)
        case .milestone: .primary.opacity(0.1)
        case .task: .primary.opacity(0.05)
        }
    }

    private var timelineNode: some View {
        Group {
            switch item.kind {
            case .phase:
                Circle()
                    .fill(item.status.color)
                    .frame(width: 12, height: 12)
            case .milestone:
                Diamond()
                    .fill(item.status.color)
                    .frame(width: 10, height: 10)
            case .task:
                Circle()
                    .fill(item.status.color)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var itemContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                // Status icon
                Image(systemName: item.status.iconName)
                    .font(item.kind == .phase ? .subheadline : .caption)
                    .foregroundStyle(item.status.color)

                // Name
                Text(item.name)
                    .font(itemFont)
                    .fontWeight(item.kind == .phase ? .semibold : .regular)

                // Priority badge
                if item.priority == .high {
                    Image(systemName: Priority.high.iconName)
                        .font(.caption2)
                        .foregroundStyle(Priority.high.color)
                }

                // Effort type
                if let effort = item.effortType {
                    effort.icon
                        .font(.caption2)
                        .foregroundStyle(effort.color)
                }

                // Dependency warning
                if item.hasUnmetDependencies {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(SemanticColour.warning)
                        .help("Has unmet dependencies")
                }

                Spacer()

                // Deadline
                if let deadline = item.deadline {
                    Text(deadline, style: .date)
                        .font(.caption2)
                        .foregroundStyle(deadline < Date() && item.status != .completed ? SemanticColour.overdue : .secondary)
                }

                // Progress
                if item.kind != .task {
                    PMProgressLabel(progress: item.progress, style: .percent)
                }
            }

            // Dependency info line
            if item.hasUnmetDependencies {
                let depNames = viewModel.dependencySourceNames(for: item.id)
                if !depNames.isEmpty {
                    Text("Depends on: \(depNames.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(SemanticColour.warning)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private var itemFont: Font {
        switch item.kind {
        case .phase: .subheadline
        case .milestone: .caption
        case .task: .caption2
        }
    }
}

// MARK: - Diamond Shape

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.closeSubpath()
        }
    }
}

// MARK: - Preview

#Preview("Roadmap") {
    Text("Roadmap requires live dependencies")
        .frame(width: 600, height: 400)
}
