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

    @State private var itemPositions: [UUID: CGFloat] = [:]

    private var timelineContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.items) { item in
                    RoadmapItemRow(item: item, viewModel: viewModel)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: RoadmapPositionKey.self,
                                    value: [item.id: geo.frame(in: .named("roadmapTimeline")).midY]
                                )
                            }
                        )
                }
            }
            .padding()
            .overlay(alignment: .topLeading) {
                DependencyArrowsOverlay(
                    dependencyTargets: viewModel.dependencyTargets,
                    itemPositions: itemPositions,
                    items: viewModel.items
                )
            }
            .coordinateSpace(name: "roadmapTimeline")
            .onPreferenceChange(RoadmapPositionKey.self) { positions in
                itemPositions = positions
            }
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
                } else if item.progress > 0 && item.progress < 1 {
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

// MARK: - Position Preference Key

struct RoadmapPositionKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Dependency Arrows Overlay

struct DependencyArrowsOverlay: View {
    let dependencyTargets: [UUID: [UUID]]
    let itemPositions: [UUID: CGFloat]
    let items: [RoadmapItem]

    var body: some View {
        Canvas { context, size in
            for (targetId, sourceIds) in dependencyTargets {
                guard let targetY = itemPositions[targetId] else { continue }

                for sourceId in sourceIds {
                    guard let sourceY = itemPositions[sourceId] else { continue }
                    let sourceItem = items.first { $0.id == sourceId }
                    let isUnmet = sourceItem.map { $0.status != .completed } ?? false

                    // Arrow drawn in the left margin area
                    let x: CGFloat = 10
                    let arrowColor = isUnmet ? Color.orange : Color.green.opacity(0.6)

                    // Draw curved connecting line
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: sourceY))
                    let midY = (sourceY + targetY) / 2
                    path.addCurve(
                        to: CGPoint(x: x, y: targetY),
                        control1: CGPoint(x: x - 14, y: midY - (targetY - sourceY) * 0.1),
                        control2: CGPoint(x: x - 14, y: midY + (targetY - sourceY) * 0.1)
                    )

                    context.stroke(
                        path,
                        with: .color(arrowColor),
                        style: StrokeStyle(lineWidth: 1.5, dash: isUnmet ? [4, 3] : [])
                    )

                    // Arrow head at target
                    var arrowHead = Path()
                    arrowHead.move(to: CGPoint(x: x - 4, y: targetY - 4))
                    arrowHead.addLine(to: CGPoint(x: x, y: targetY))
                    arrowHead.addLine(to: CGPoint(x: x - 4, y: targetY + 4))
                    context.stroke(
                        arrowHead,
                        with: .color(arrowColor),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )

                    // Small dot at source
                    let dotRect = CGRect(x: x - 3, y: sourceY - 3, width: 6, height: 6)
                    context.fill(Circle().path(in: dotRect), with: .color(arrowColor))
                }
            }
        }
        .allowsHitTesting(false)
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
