import SwiftUI
import UniformTypeIdentifiers
import PMDomain
import PMDesignSystem
import PMServices
import PMUtilities

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

                // Three-column Kanban
                KanbanColumnsRow(project: project, viewModel: viewModel)

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

}

// MARK: - Kanban Columns Row

/// Wraps all three kanban columns with a single drop handler on the parent.
/// Works around a SwiftUI macOS bug where multiple sibling `.dropDestination`
/// or `.onDrop` modifiers only register the first one in the container.
struct KanbanColumnsRow: View {
    let project: Project
    let viewModel: FocusBoardViewModel

    /// Tracks which column the user is hovering over during a drag.
    @State private var highlightedColumn: KanbanColumn?

    /// Column boundary X positions, set by geometry preferences.
    @State private var columnFrames: [KanbanColumn: CGRect] = [:]

    var body: some View {
        #if os(macOS)
        kanbanHStack
            .coordinateSpace(name: "kanbanRow")
            .onDrop(of: [.text], delegate: KanbanRowDropDelegate(
                viewModel: viewModel,
                columnFrames: columnFrames,
                highlightedColumn: $highlightedColumn
            ))
        #else
        ScrollView(.horizontal, showsIndicators: false) {
            kanbanHStack
                .coordinateSpace(name: "kanbanRow")
                .onDrop(of: [.text], delegate: KanbanRowDropDelegate(
                    viewModel: viewModel,
                    columnFrames: columnFrames,
                    highlightedColumn: $highlightedColumn
                ))
        }
        #endif
    }

    private var kanbanHStack: some View {
        HStack(alignment: .top, spacing: 12) {
            kanbanColumnContent(title: "To Do", tasks: viewModel.toDoTasks(for: project.id), column: .toDo)
                .frame(minWidth: 200)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: ColumnFrameKey.self,
                                           value: [.toDo: geo.frame(in: .named("kanbanRow"))])
                })
            kanbanColumnContent(title: "In Progress", tasks: viewModel.inProgressTasks(for: project.id), column: .inProgress)
                .frame(minWidth: 200)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: ColumnFrameKey.self,
                                           value: [.inProgress: geo.frame(in: .named("kanbanRow"))])
                })
            kanbanColumnContent(title: "Done", tasks: viewModel.doneTasks(for: project.id), column: .done)
                .frame(minWidth: 200)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: ColumnFrameKey.self,
                                           value: [.done: geo.frame(in: .named("kanbanRow"))])
                })
        }
        .onPreferenceChange(ColumnFrameKey.self) { frames in
            columnFrames = frames
        }
    }

    private func kanbanColumnContent(title: String, tasks: [PMTask], column: KanbanColumn) -> some View {
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

            ForEach(tasks) { task in
                KanbanTaskCard(
                    task: task,
                    projectSlotIndex: project.focusSlotIndex,
                    milestoneName: viewModel.milestoneNameByTaskId[task.id],
                    viewModel: viewModel
                ) { targetColumn in
                    Task { await viewModel.moveTask(task, to: targetColumn) }
                }

                // Subtask cards indented under parent
                if let subtasks = viewModel.subtasksByTaskId[task.id] {
                    ForEach(subtasks) { subtask in
                        KanbanSubtaskCard(subtask: subtask, viewModel: viewModel)
                    }
                    .padding(.leading, 12)
                }
            }

            if tasks.isEmpty {
                Text("No tasks")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .top)
        .contentShape(Rectangle())
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(column.color.opacity(highlightedColumn == column ? 0.12 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(highlightedColumn == column ? column.color.opacity(0.4) : .clear, lineWidth: 2)
        )
    }
}

// MARK: - Column Frame Preference Key

/// Preference key that collects geometry frames for each kanban column.
struct ColumnFrameKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [KanbanColumn: CGRect] = [:]
    static func reduce(value: inout [KanbanColumn: CGRect], nextValue: () -> [KanbanColumn: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Kanban Row Drop Delegate

/// Single drop delegate for the entire kanban row. Uses column geometry
/// to determine which column the drop lands in, working around the SwiftUI
/// bug where only the first sibling drop target registers on macOS.
struct KanbanRowDropDelegate: DropDelegate {
    let viewModel: FocusBoardViewModel
    let columnFrames: [KanbanColumn: CGRect]
    @Binding var highlightedColumn: KanbanColumn?

    private func columnForLocation(_ location: CGPoint) -> KanbanColumn? {
        for (column, frame) in columnFrames {
            if frame.contains(location) {
                return column
            }
        }
        return nil
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.text])
    }

    func dropEntered(info: DropInfo) {
        let col = columnForLocation(info.location)
        Log.focus.debug("dropEntered row, column: \(col?.displayName ?? "none")")
        highlightedColumn = col
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let col = columnForLocation(info.location)
        if col != highlightedColumn {
            highlightedColumn = col
        }
        return DropProposal(operation: col != nil ? .move : .cancel)
    }

    func dropExited(info: DropInfo) {
        Log.focus.debug("dropExited row")
        highlightedColumn = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let targetColumn = columnForLocation(info.location) else {
            Log.focus.error("performDrop: drop location outside all columns")
            highlightedColumn = nil
            return false
        }

        Log.focus.info("performDrop on \(targetColumn.displayName) at x=\(Int(info.location.x)),y=\(Int(info.location.y))")
        highlightedColumn = nil

        let providers = info.itemProviders(for: [.text])
        guard let provider = providers.first else {
            Log.focus.error("performDrop: no item providers")
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, error in
            if let error {
                Log.focus.error("performDrop load error: \(error)")
                return
            }
            guard let data = data as? Data,
                  let taskIdString = String(data: data, encoding: .utf8),
                  let taskId = UUID(uuidString: taskIdString) else {
                Log.focus.error("performDrop: could not parse task ID")
                return
            }

            Log.focus.info("Moving task \(taskId) to \(targetColumn.displayName)")
            Task { @MainActor in
                await viewModel.moveTaskById(taskId, to: targetColumn)
            }
        }
        return true
    }
}

// MARK: - Kanban Subtask Card

/// A small card representing a subtask within a Kanban column.
struct KanbanSubtaskCard: View {
    let subtask: Subtask
    let viewModel: FocusBoardViewModel

    var body: some View {
        HStack(spacing: 4) {
            Button {
                Task { await viewModel.toggleSubtask(subtask) }
            } label: {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                    .foregroundStyle(subtask.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(subtask.name)
                .font(.caption2)
                .strikethrough(subtask.isCompleted)
                .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
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
    @State private var showEdit = false

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

                // Deadline badge
                if let deadline = task.deadline {
                    let now = Date()
                    let isOverdue = deadline < now
                    let hoursUntil = Calendar.current.dateComponents([.hour], from: now, to: deadline).hour ?? 0
                    let isApproaching = !isOverdue && hoursUntil <= 48

                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                        Text(deadline, style: .date)
                    }
                    .font(.caption2)
                    .foregroundStyle(isOverdue ? .red : (isApproaching ? .orange : .secondary))
                }

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
            Button("Edit...") { showEdit = true }
            Divider()
            ForEach(KanbanColumn.allCases, id: \.self) { col in
                if col != task.kanbanColumn {
                    Button("Move to \(col.displayName)") { onMove(col) }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            FocusBoardTaskEditSheet(task: task, viewModel: viewModel)
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
    @State private var showEdit = false
    @State private var blockedType: BlockedType = .poorlyDefined
    @State private var blockedReason = ""
    @State private var waitingReason = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(task.name)
                    .font(.headline)
                Spacer()
                Button {
                    showEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Edit task")
            }

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
        .sheet(isPresented: $showEdit) {
            FocusBoardTaskEditSheet(task: task, viewModel: viewModel)
        }
    }
}

// MARK: - Focus Board Task Edit Sheet

/// Sheet for editing task properties from the Focus Board.
struct FocusBoardTaskEditSheet: View {
    let viewModel: FocusBoardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var priority: Priority
    @State private var effortType: EffortType?
    @State private var timeEstimate: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var isTimeboxed: Bool
    @State private var timeboxMinutes: String

    private let taskId: UUID
    private let milestoneId: UUID
    private let sortOrder: Int
    private let originalStatus: ItemStatus
    private let originalKanbanColumn: KanbanColumn

    init(task: PMTask, viewModel: FocusBoardViewModel) {
        self.viewModel = viewModel
        self.taskId = task.id
        self.milestoneId = task.milestoneId
        self.sortOrder = task.sortOrder
        self.originalStatus = task.status
        self.originalKanbanColumn = task.kanbanColumn
        _name = State(initialValue: task.name)
        _priority = State(initialValue: task.priority)
        _effortType = State(initialValue: task.effortType)
        _timeEstimate = State(initialValue: task.timeEstimateMinutes.map { String($0) } ?? "")
        _hasDeadline = State(initialValue: task.deadline != nil)
        _deadline = State(initialValue: task.deadline ?? Date().addingTimeInterval(86400 * 7))
        _isTimeboxed = State(initialValue: task.isTimeboxed)
        _timeboxMinutes = State(initialValue: task.timeboxMinutes.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Name", text: $name)
                }
                Section("Properties") {
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Text(p.rawValue.capitalized).tag(p)
                        }
                    }
                    Picker("Effort Type", selection: $effortType) {
                        Text("None").tag(EffortType?.none)
                        ForEach(EffortType.allCases, id: \.self) { e in
                            Text(e.rawValue.camelCaseToWords).tag(EffortType?.some(e))
                        }
                    }
                    TextField("Time Estimate (minutes)", text: $timeEstimate)
                        #if os(macOS)
                        .textFieldStyle(.roundedBorder)
                        #endif
                }
                Section("Timebox") {
                    Toggle("Timeboxed", isOn: $isTimeboxed)
                    if isTimeboxed {
                        TextField("Timebox (minutes)", text: $timeboxMinutes)
                            #if os(macOS)
                            .textFieldStyle(.roundedBorder)
                            #endif
                    }
                }
                Section("Deadline") {
                    Toggle("Set deadline", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let task = PMTask(
                            id: taskId,
                            milestoneId: milestoneId,
                            name: name.trimmingCharacters(in: .whitespaces),
                            sortOrder: sortOrder,
                            status: originalStatus,
                            isTimeboxed: isTimeboxed,
                            timeEstimateMinutes: Int(timeEstimate),
                            timeboxMinutes: isTimeboxed ? Int(timeboxMinutes) : nil,
                            deadline: hasDeadline ? deadline : nil,
                            priority: priority,
                            effortType: effortType,
                            kanbanColumn: originalKanbanColumn
                        )
                        Task {
                            await viewModel.updateTask(task)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        #endif
    }
}

// MARK: - Preview

#Preview("Focus Board") {
    Text("Focus Board requires live dependencies")
        .frame(width: 800, height: 600)
}
