import SwiftUI
import PMDomain
import PMDesignSystem
import PMServices

/// The Focus Board — Kanban-style view of focused projects and their tasks.
public struct FocusBoardView: View {
    @Bindable var viewModel: FocusBoardViewModel
    var onSelectProject: ((Project) -> Void)?
    var reviewManager: ProjectReviewManager?
    @State private var showReview = false

    public init(viewModel: FocusBoardViewModel, onSelectProject: ((Project) -> Void)? = nil, reviewManager: ProjectReviewManager? = nil) {
        self.viewModel = viewModel
        self.onSelectProject = onSelectProject
        self.reviewManager = reviewManager
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
        .toolbar {
            if reviewManager != nil {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showReview = true
                    } label: {
                        Label("Portfolio Review", systemImage: "sparkles")
                    }
                    .help("Start an AI-powered review of your focused projects")
                }
            }
        }
        .sheet(isPresented: $showReview) {
            if let reviewManager {
                NavigationStack {
                    ProjectReviewView(manager: reviewManager)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showReview = false }
                            }
                        }
                }
                #if os(macOS)
                .frame(minWidth: 600, minHeight: 500)
                #endif
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Effort Filter Bar

    private var effortFilterBar: some View {
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
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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

    @State private var showCheckIn = false

    var body: some View {
        PMCard {
            VStack(alignment: .leading, spacing: 10) {
                // Check-in prompt banner
                checkInBanner

                // Project Header
                HStack(spacing: 8) {
                    Circle()
                        .fill(SlotColour.forIndex(project.focusSlotIndex))
                        .frame(width: 10, height: 10)

                    Button {
                        onSelectProject?(project)
                    } label: {
                        Text(project.name)
                            .font(.headline)
                    }
                    .buttonStyle(.plain)

                    Text(viewModel.categoryName(for: project))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Progress
                    let allTasks = viewModel.tasksByProject[project.id] ?? []
                    let completedCount = allTasks.filter { $0.status == .completed }.count
                    if !allTasks.isEmpty {
                        PMProgressLabel(
                            progress: Double(completedCount) / Double(allTasks.count),
                            style: .fraction(total: allTasks.count)
                        )
                    }

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

                // Three-column Kanban (horizontal scroll on iPhone)
                #if os(macOS)
                HStack(alignment: .top, spacing: 12) {
                    kanbanColumn(title: "To Do", tasks: viewModel.toDoTasks(for: project.id), column: .toDo, projectId: project.id)
                    kanbanColumn(title: "In Progress", tasks: viewModel.inProgressTasks(for: project.id), column: .inProgress, projectId: project.id)
                    kanbanColumn(title: "Done", tasks: viewModel.doneTasks(for: project.id), column: .done, projectId: project.id)
                }
                #else
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        kanbanColumn(title: "To Do", tasks: viewModel.toDoTasks(for: project.id), column: .toDo, projectId: project.id)
                            .frame(minWidth: 200)
                        kanbanColumn(title: "In Progress", tasks: viewModel.inProgressTasks(for: project.id), column: .inProgress, projectId: project.id)
                            .frame(minWidth: 200)
                        kanbanColumn(title: "Done", tasks: viewModel.doneTasks(for: project.id), column: .done, projectId: project.id)
                            .frame(minWidth: 200)
                    }
                }
                #endif

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
        .sheet(isPresented: $showCheckIn) {
            if let manager = viewModel.checkInFlowManager {
                NavigationStack {
                    CheckInView(manager: manager, project: project)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showCheckIn = false }
                            }
                        }
                }
                #if os(macOS)
                .frame(minWidth: 500, minHeight: 400)
                #endif
            }
        }
    }

    // MARK: - Check-In Banner

    @ViewBuilder
    private var checkInBanner: some View {
        let urgency = viewModel.urgencyByProject[project.id] ?? .none
        if urgency != .none {
            Button {
                showCheckIn = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: urgencyIcon(urgency))
                        .foregroundStyle(urgencyColor(urgency))
                    Text(urgencyLabel(urgency))
                        .font(.caption)
                        .foregroundStyle(urgencyColor(urgency))
                    Spacer()
                    Text("Check in")
                        .font(.caption)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .padding(8)
                .background(urgencyColor(urgency).opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
    }

    private func urgencyIcon(_ urgency: CheckInUrgency) -> String {
        switch urgency {
        case .none: "checkmark.circle"
        case .gentle: "info.circle"
        case .moderate: "exclamationmark.circle"
        case .prominent: "exclamationmark.triangle.fill"
        }
    }

    private func urgencyColor(_ urgency: CheckInUrgency) -> Color {
        switch urgency {
        case .none: .green
        case .gentle: .blue
        case .moderate: .orange
        case .prominent: .red
        }
    }

    private func urgencyLabel(_ urgency: CheckInUrgency) -> String {
        switch urgency {
        case .none: "Up to date"
        case .gentle: "Check-in suggested"
        case .moderate: "Check-in recommended"
        case .prominent: "Check-in overdue"
        }
    }

    @State private var dropTargetColumn: KanbanColumn?

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
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ForEach(tasks) { task in
                    KanbanTaskCard(
                        task: task,
                        projectSlotIndex: project.focusSlotIndex,
                        milestoneName: viewModel.milestoneNameByTaskId[task.id],
                        viewModel: viewModel
                    ) { targetColumn in
                        Task { await viewModel.moveTask(task, to: targetColumn) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(column.color.opacity(dropTargetColumn == column ? 0.12 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(dropTargetColumn == column ? column.color.opacity(0.4) : .clear, lineWidth: 2)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let taskIdString = items.first,
                  let taskId = UUID(uuidString: taskIdString) else { return false }
            Task { await viewModel.moveTaskById(taskId, to: column) }
            return true
        } isTargeted: { targeted in
            dropTargetColumn = targeted ? column : (dropTargetColumn == column ? nil : dropTargetColumn)
        }
    }
}

// MARK: - Kanban Task Card

struct KanbanTaskCard: View {
    let task: PMTask
    let projectSlotIndex: Int?
    var milestoneName: String?
    let viewModel: FocusBoardViewModel
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
                if let milestoneName {
                    Text(milestoneName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

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

                if task.status == .blocked {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.caption2)
                        .foregroundStyle(SemanticColour.blocked)
                }

                if task.status == .waiting {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(SemanticColour.warning)
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
            TaskDetailPopover(task: task, viewModel: viewModel, onMove: onMove)
        }
        .contextMenu {
            ForEach(KanbanColumn.allCases, id: \.self) { col in
                if col != task.kanbanColumn {
                    Button("Move to \(col.displayName)") { onMove(col) }
                }
            }
        }
        .draggable(task.id.uuidString)
    }
}

// MARK: - Task Detail Popover

struct TaskDetailPopover: View {
    let task: PMTask
    let viewModel: FocusBoardViewModel
    let onMove: (KanbanColumn) -> Void

    @State private var showBlockForm = false
    @State private var showWaitForm = false
    @State private var blockedType: BlockedType = .poorlyDefined
    @State private var blockedReason = ""
    @State private var waitingReason = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(task.name)
                .font(.headline)

            HStack {
                Image(systemName: task.status.iconName)
                    .foregroundStyle(task.status.color)
                Text(task.status.displayName)
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

            if task.status == .blocked, let type = task.blockedType {
                Label(type.displayName, systemImage: "xmark.octagon.fill")
                    .font(.caption)
                    .foregroundStyle(SemanticColour.blocked)
                if let reason = task.blockedReason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if task.status == .waiting, let reason = task.waitingReason {
                Label(reason, systemImage: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(SemanticColour.warning)
            }

            Divider()

            // Column movement
            Text("Move to")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(KanbanColumn.allCases, id: \.self) { col in
                    if col != task.kanbanColumn {
                        Button(col.displayName) { onMove(col) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }

            Divider()

            // Quick actions
            Text("Actions")
                .font(.caption)
                .foregroundStyle(.secondary)

            if showBlockForm {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Type", selection: $blockedType) {
                        ForEach(BlockedType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .controlSize(.small)
                    TextField("Reason (optional)", text: $blockedReason)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    HStack {
                        Button("Cancel") { showBlockForm = false }
                            .controlSize(.small)
                        Button("Block") {
                            Task { await viewModel.blockTask(task, type: blockedType, reason: blockedReason) }
                            showBlockForm = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            } else if showWaitForm {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("What are you waiting for?", text: $waitingReason)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    HStack {
                        Button("Cancel") { showWaitForm = false }
                            .controlSize(.small)
                        Button("Set Waiting") {
                            Task { await viewModel.setWaiting(task, reason: waitingReason) }
                            showWaitForm = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(waitingReason.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    if task.status == .blocked || task.status == .waiting {
                        Button("Unblock") {
                            Task { await viewModel.unblockTask(task) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    if task.status != .blocked {
                        Button("Block") {
                            blockedType = .poorlyDefined
                            blockedReason = ""
                            showBlockForm = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(SemanticColour.blocked)
                    }
                    if task.status != .waiting {
                        Button("Set Waiting") {
                            waitingReason = ""
                            showWaitForm = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(SemanticColour.warning)
                    }
                }
            }
        }
        .padding()
        .frame(width: 280)
    }
}

// MARK: - Preview

#Preview("Focus Board") {
    Text("Focus Board requires live dependencies")
        .frame(width: 800, height: 600)
}
