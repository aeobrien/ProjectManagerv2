import SwiftUI
import PMDomain
import PMDesignSystem

/// The Focus Board — Kanban-style view of focused projects and their tasks.
public struct FocusBoardView: View {
    @Bindable var viewModel: FocusBoardViewModel
    var onSelectProject: ((Project) -> Void)?

    public init(viewModel: FocusBoardViewModel, onSelectProject: ((Project) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onSelectProject = onSelectProject
    }

    public var body: some View {
        VStack(spacing: 0) {
            effortFilterBar
            Divider()

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.focusedProjects.isEmpty {
                PMEmptyState(
                    icon: "square.grid.2x2",
                    title: "Focus Board Empty",
                    message: "Focus projects from the All Projects browser to see them here."
                )
            } else {
                boardContent
            }
        }
        .navigationTitle("Focus Board")
        .task { await viewModel.load() }
    }

    // MARK: - Effort Filter Bar

    private var effortFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All Types", isSelected: viewModel.effortTypeFilter == nil) {
                    viewModel.effortTypeFilter = nil
                }
                ForEach(EffortType.allCases, id: \.self) { effort in
                    FilterChip(
                        label: effort.rawValue.camelCaseToWords,
                        isSelected: viewModel.effortTypeFilter == effort,
                        tint: effort.color
                    ) {
                        viewModel.effortTypeFilter = effort
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Board Content

    private var boardContent: some View {
        ScrollView {
            // Diversity violations
            ForEach(viewModel.diversityViolations, id: \.categoryId) { violation in
                DiversityBanner(
                    categoryName: viewModel.categories.first { $0.id == violation.categoryId }?.name ?? "Unknown",
                    projectCount: violation.projectCount,
                    limit: violation.limit
                )
                .padding(.horizontal)
            }

            LazyVStack(spacing: 16) {
                ForEach(viewModel.focusedProjects) { project in
                    ProjectKanbanSection(project: project, viewModel: viewModel, onSelectProject: onSelectProject)
                }
            }
            .padding()
        }
    }
}

// MARK: - Project Kanban Section

struct ProjectKanbanSection: View {
    let project: Project
    let viewModel: FocusBoardViewModel
    var onSelectProject: ((Project) -> Void)?

    var body: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 10) {
                // Project Header
                HStack(spacing: 8) {
                    Circle()
                        .fill(SlotColour.forIndex(project.focusSlotIndex))
                        .frame(width: 10, height: 10)

                    NavigationLink(value: project) {
                        Text(project.name)
                            .font(.headline)
                    }
                    .buttonStyle(.plain)

                    Text(viewModel.categoryName(for: project))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Health badges
                    let badges = viewModel.healthBadges(for: project.id)
                    if !badges.isEmpty {
                        HealthBadgeRow(signals: badges)
                    }

                    Button {
                        Task { await viewModel.unfocusProject(project) }
                    } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove from Focus Board")
                }

                // Three-column Kanban
                HStack(alignment: .top, spacing: 12) {
                    kanbanColumn(title: "To Do", tasks: viewModel.toDoTasks(for: project.id), column: .toDo, projectId: project.id)
                    kanbanColumn(title: "In Progress", tasks: viewModel.inProgressTasks(for: project.id), column: .inProgress, projectId: project.id)
                    kanbanColumn(title: "Done", tasks: viewModel.doneTasks(for: project.id), column: .done, projectId: project.id)
                }

                // Show all toggle
                let totalToDo = viewModel.totalToDoCount(for: project.id)
                let visibleToDo = viewModel.toDoTasks(for: project.id).count
                if totalToDo > visibleToDo || viewModel.showAllTasks.contains(project.id) {
                    Button {
                        viewModel.toggleShowAll(for: project.id)
                    } label: {
                        Text(viewModel.showAllTasks.contains(project.id) ? "Show curated (\(viewModel.maxVisibleTasks))" : "Show all \(totalToDo) tasks")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
        }
    }

    private func kanbanColumn(title: String, tasks: [PMTask], column: KanbanColumn, projectId: UUID) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(tasks.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if tasks.isEmpty {
                Text("No tasks")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity, minHeight: 40)
            } else {
                ForEach(tasks) { task in
                    KanbanTaskCard(task: task, projectSlotIndex: project.focusSlotIndex) { targetColumn in
                        Task { await viewModel.moveTask(task, to: targetColumn) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(8)
        .background(column.color.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
        .dropDestination(for: String.self) { items, _ in
            guard let taskIdString = items.first,
                  let taskId = UUID(uuidString: taskIdString) else { return false }
            Task { await viewModel.moveTaskById(taskId, to: column) }
            return true
        }
    }
}

// MARK: - Kanban Task Card

struct KanbanTaskCard: View {
    let task: PMTask
    let projectSlotIndex: Int?
    let onMove: (KanbanColumn) -> Void

    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: task.status.iconName)
                    .font(.caption2)
                    .foregroundStyle(task.status.color)

                Text(task.name)
                    .font(.caption)
                    .lineLimit(2)

                Spacer()

                if task.priority == .high {
                    Image(systemName: Priority.high.iconName)
                        .font(.caption2)
                        .foregroundStyle(Priority.high.color)
                }
            }

            HStack(spacing: 4) {
                if let effort = task.effortType {
                    effort.icon
                        .font(.caption2)
                        .foregroundStyle(effort.color)
                }

                if let estimate = task.timeEstimateMinutes {
                    Text("\(estimate)m")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if task.isFrequentlyDeferred() {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption2)
                        .foregroundStyle(SemanticColour.deferred)
                }
            }
        }
        .padding(6)
        .background(.background, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(task.status == .blocked ? SemanticColour.blocked.opacity(0.5) : .clear, lineWidth: 1)
        )
        .onTapGesture { showDetail = true }
        .popover(isPresented: $showDetail) {
            TaskDetailPopover(task: task, onMove: onMove)
        }
        .contextMenu {
            ForEach(KanbanColumn.allCases, id: \.self) { col in
                if col != task.kanbanColumn {
                    Button("Move to \(col.rawValue.capitalized)") { onMove(col) }
                }
            }
        }
        .draggable(task.id.uuidString)
    }
}

// MARK: - Task Detail Popover

struct TaskDetailPopover: View {
    let task: PMTask
    let onMove: (KanbanColumn) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(task.name)
                .font(.headline)

            HStack {
                Image(systemName: task.status.iconName)
                    .foregroundStyle(task.status.color)
                Text(task.status.rawValue.capitalized)
                    .font(.subheadline)
            }

            if let effort = task.effortType {
                Label(effort.rawValue.camelCaseToWords, systemImage: effort.iconName)
                    .font(.caption)
                    .foregroundStyle(effort.color)
            }

            if let estimate = task.timeEstimateMinutes {
                Label("\(estimate) min estimate", systemImage: "clock")
                    .font(.caption)
            }

            if let timebox = task.timeboxMinutes {
                Label("\(timebox) min timebox", systemImage: "timer")
                    .font(.caption)
            }

            if task.status == .blocked, let reason = task.blockedReason {
                Label(reason, systemImage: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(SemanticColour.blocked)
            }

            if task.status == .waiting, let reason = task.waitingReason {
                Label(reason, systemImage: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(SemanticColour.warning)
            }

            Divider()

            HStack(spacing: 8) {
                ForEach(KanbanColumn.allCases, id: \.self) { col in
                    if col != task.kanbanColumn {
                        Button(col.rawValue.capitalized) { onMove(col) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding()
        .frame(width: 260)
    }
}

// MARK: - Preview

#Preview("Focus Board") {
    Text("Focus Board requires live dependencies")
        .frame(width: 800, height: 600)
}
