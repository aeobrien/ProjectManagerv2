import SwiftUI
import PMDomain
import PMDesignSystem

/// The roadmap tab showing the full phase → milestone → task → subtask hierarchy.
struct RoadmapView: View {
    @Bindable var viewModel: ProjectDetailViewModel

    @State private var newPhaseName = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.phases) { phase in
                    PhaseRow(phase: phase, viewModel: viewModel,
                             isExpanded: viewModel.expandedPhases.contains(phase.id),
                             expandedMilestones: $viewModel.expandedMilestones,
                             expandedTasks: $viewModel.expandedTasks) {
                        toggleExpansion(phase.id, in: &viewModel.expandedPhases)
                    }
                }

                // Add phase row
                HStack {
                    TextField("New phase name...", text: $newPhaseName)
                        .textFieldStyle(.plain)
                    Button("Add Phase") {
                        let name = newPhaseName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        Task {
                            await viewModel.createPhase(name: name)
                            newPhaseName = ""
                        }
                    }
                    .disabled(newPhaseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
            }
        }
    }

    private func toggleExpansion(_ id: UUID, in set: inout Set<UUID>) {
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
    }
}

// MARK: - Phase Row

struct PhaseRow: View {
    let phase: Phase
    let viewModel: ProjectDetailViewModel
    let isExpanded: Bool
    @Binding var expandedMilestones: Set<UUID>
    @Binding var expandedTasks: Set<UUID>
    let onToggle: () -> Void

    @State private var isEditing = false
    @State private var editName: String = ""
    @State private var newMilestoneName = ""
    @State private var showRetrospective = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Phase header
            HStack(spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)

                if isEditing {
                    TextField("Phase name", text: $editName, onCommit: {
                        var updated = phase
                        updated.name = editName
                        Task { await viewModel.updatePhase(updated) }
                        isEditing = false
                    })
                    .textFieldStyle(.plain)
                } else {
                    Text(phase.name)
                        .font(.headline)
                        .onTapGesture(count: 2) {
                            editName = phase.name
                            isEditing = true
                        }
                }

                if phase.retrospectiveCompletedAt != nil {
                    Image(systemName: "text.bubble.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .help("Retrospective completed")
                }

                Spacer()

                Text(phase.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Progress
                let milestones = viewModel.milestonesByPhase[phase.id] ?? []
                let completed = milestones.filter { $0.status == .completed }.count
                if !milestones.isEmpty {
                    PMProgressLabel(
                        progress: Double(completed) / Double(milestones.count),
                        style: .fraction(total: milestones.count)
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.03))
            .contextMenu {
                if phase.retrospectiveCompletedAt == nil,
                   let manager = viewModel.retrospectiveManager {
                    let milestones = viewModel.milestonesByPhase[phase.id] ?? []
                    let allComplete = !milestones.isEmpty && milestones.allSatisfy { $0.status == .completed }
                    if allComplete {
                        Button {
                            manager.promptRetrospective(for: phase)
                            showRetrospective = true
                        } label: {
                            Label("Start Retrospective", systemImage: "text.bubble")
                        }
                        Divider()
                    }
                }
                if let notes = phase.retrospectiveNotes, !notes.isEmpty {
                    Button {
                        // Show notes — handled by sheet
                    } label: {
                        Label("View Retrospective Notes", systemImage: "doc.text")
                    }
                    Divider()
                }
                Button("Delete Phase", role: .destructive) {
                    Task { await viewModel.deletePhase(phase) }
                }
            }
            .sheet(isPresented: $showRetrospective) {
                if let manager = viewModel.retrospectiveManager {
                    NavigationStack {
                        RetrospectiveView(manager: manager, project: viewModel.project)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Close") { showRetrospective = false }
                                }
                            }
                    }
                    #if os(macOS)
                    .frame(minWidth: 500, minHeight: 400)
                    #endif
                }
            }

            if isExpanded {
                let milestones = viewModel.milestonesByPhase[phase.id] ?? []
                ForEach(milestones) { milestone in
                    MilestoneRow(
                        milestone: milestone,
                        viewModel: viewModel,
                        isExpanded: expandedMilestones.contains(milestone.id),
                        expandedTasks: $expandedTasks
                    ) {
                        if expandedMilestones.contains(milestone.id) {
                            expandedMilestones.remove(milestone.id)
                        } else {
                            expandedMilestones.insert(milestone.id)
                        }
                    }
                }

                // Add milestone
                HStack {
                    TextField("New milestone...", text: $newMilestoneName)
                        .textFieldStyle(.plain)
                    Button("Add") {
                        let name = newMilestoneName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        Task {
                            await viewModel.createMilestone(in: phase.id, name: name)
                            newMilestoneName = ""
                        }
                    }
                    .disabled(newMilestoneName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.leading, 40)
                .padding(.trailing)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Milestone Row

struct MilestoneRow: View {
    let milestone: Milestone
    let viewModel: ProjectDetailViewModel
    let isExpanded: Bool
    @Binding var expandedTasks: Set<UUID>
    let onToggle: () -> Void

    @State private var newTaskName = ""
    @State private var showEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)

                Image(systemName: milestone.status.iconName)
                    .font(.caption)
                    .foregroundStyle(milestone.status.color)

                Text(milestone.name)
                    .font(.subheadline)

                if milestone.priority == .high {
                    Image(systemName: Priority.high.iconName)
                        .font(.caption2)
                        .foregroundStyle(Priority.high.color)
                }

                if viewModel.hasUnmetDependencies(targetId: milestone.id) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(SemanticColour.warning)
                        .help("Has unmet dependencies")
                }

                Spacer()

                if let deadline = milestone.deadline {
                    Text(deadline, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                let tasks = viewModel.tasksByMilestone[milestone.id] ?? []
                let completed = tasks.filter { $0.status == .completed }.count
                if !tasks.isEmpty {
                    PMProgressLabel(
                        progress: Double(completed) / Double(tasks.count),
                        style: .fraction(total: tasks.count)
                    )
                }
            }
            .padding(.leading, 32)
            .padding(.trailing)
            .padding(.vertical, 6)
            .contextMenu {
                Button("Edit...") {
                    showEditSheet = true
                }
                Divider()
                Button("Delete Milestone", role: .destructive) {
                    Task { await viewModel.deleteMilestone(milestone) }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                MilestoneEditSheet(milestone: milestone, viewModel: viewModel)
            }

            if isExpanded {
                let tasks = viewModel.tasksByMilestone[milestone.id] ?? []
                ForEach(tasks) { task in
                    TaskRow(
                        task: task,
                        viewModel: viewModel,
                        isExpanded: expandedTasks.contains(task.id)
                    ) {
                        if expandedTasks.contains(task.id) {
                            expandedTasks.remove(task.id)
                        } else {
                            expandedTasks.insert(task.id)
                        }
                    }
                }

                // Add task
                HStack {
                    TextField("New task...", text: $newTaskName)
                        .textFieldStyle(.plain)
                    Button("Add") {
                        let name = newTaskName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        Task {
                            await viewModel.createTask(in: milestone.id, name: name)
                            newTaskName = ""
                        }
                    }
                    .disabled(newTaskName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.leading, 64)
                .padding(.trailing)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: PMTask
    let viewModel: ProjectDetailViewModel
    let isExpanded: Bool
    let onToggle: () -> Void

    @State private var newSubtaskName = ""
    @State private var showEditSheet = false
    @State private var showBlockedSheet = false
    @State private var showWaitingSheet = false
    @State private var blockedType: BlockedType = .poorlyDefined
    @State private var blockedReason = ""
    @State private var waitingReason = ""
    @State private var waitingCheckBackDate: Date? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onToggle) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)

                Image(systemName: task.status.iconName)
                    .font(.caption)
                    .foregroundStyle(task.status.color)

                Text(task.name)
                    .font(.subheadline)

                if let effort = task.effortType {
                    effort.icon
                        .font(.caption2)
                        .foregroundStyle(effort.color)
                }

                if task.priority == .high {
                    Image(systemName: Priority.high.iconName)
                        .font(.caption2)
                        .foregroundStyle(Priority.high.color)
                }

                if viewModel.hasUnmetDependencies(targetId: task.id) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(SemanticColour.warning)
                }

                if task.isFrequentlyDeferred() {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption2)
                        .foregroundStyle(SemanticColour.deferred)
                }

                Spacer()

                if let estimate = task.timeEstimateMinutes {
                    Text("\(estimate)m")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 56)
            .padding(.trailing)
            .padding(.vertical, 4)
            .contextMenu {
                Button("Edit...") {
                    showEditSheet = true
                }
                Menu("Status") {
                    ForEach(ItemStatus.allCases, id: \.self) { status in
                        Button(status.displayName) {
                            if status == .blocked {
                                blockedType = .poorlyDefined
                                blockedReason = ""
                                showBlockedSheet = true
                            } else if status == .waiting {
                                waitingReason = ""
                                waitingCheckBackDate = nil
                                showWaitingSheet = true
                            } else {
                                var updated = task
                                updated.status = status
                                updated.kanbanColumn = status.kanbanColumn
                                if status == .completed { updated.completedAt = Date() }
                                updated.blockedType = nil
                                updated.blockedReason = nil
                                updated.waitingReason = nil
                                updated.waitingCheckBackDate = nil
                                Task { await viewModel.updateTask(updated) }
                            }
                        }
                    }
                }
                Divider()
                Button("Delete Task", role: .destructive) {
                    Task { await viewModel.deleteTask(task) }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                TaskEditSheet(task: task, viewModel: viewModel)
            }
            .sheet(isPresented: $showBlockedSheet) {
                TaskBlockedSheet(task: task, viewModel: viewModel,
                                 blockedType: $blockedType, reason: $blockedReason)
            }
            .sheet(isPresented: $showWaitingSheet) {
                TaskWaitingSheet(task: task, viewModel: viewModel,
                                 reason: $waitingReason, checkBackDate: $waitingCheckBackDate)
            }

            if isExpanded {
                let subtasks = viewModel.subtasksByTask[task.id] ?? []
                ForEach(subtasks) { subtask in
                    SubtaskRow(subtask: subtask, viewModel: viewModel)
                }

                // Add subtask
                HStack {
                    TextField("New subtask...", text: $newSubtaskName)
                        .textFieldStyle(.plain)
                    Button("Add") {
                        let name = newSubtaskName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        Task {
                            await viewModel.createSubtask(in: task.id, name: name)
                            newSubtaskName = ""
                        }
                    }
                    .disabled(newSubtaskName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.leading, 88)
                .padding(.trailing)
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Subtask Row

struct SubtaskRow: View {
    let subtask: Subtask
    let viewModel: ProjectDetailViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                Task { await viewModel.toggleSubtask(subtask) }
            } label: {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(subtask.isCompleted ? .green : .secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Text(subtask.name)
                .font(.caption)
                .strikethrough(subtask.isCompleted)
                .foregroundStyle(subtask.isCompleted ? .secondary : .primary)

            Spacer()
        }
        .padding(.leading, 80)
        .padding(.trailing)
        .padding(.vertical, 2)
        .contextMenu {
            Button("Delete Subtask", role: .destructive) {
                Task { await viewModel.deleteSubtask(subtask) }
            }
        }
    }
}

// MARK: - Task Blocked Sheet

struct TaskBlockedSheet: View {
    let task: PMTask
    let viewModel: ProjectDetailViewModel
    @Binding var blockedType: BlockedType
    @Binding var reason: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("What's blocking this task?") {
                    Picker("Type", selection: $blockedType) {
                        ForEach(BlockedType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
                Section("Details (optional)") {
                    TextField("Reason", text: $reason)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Block Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Block") {
                        Task {
                            await viewModel.blockTask(task, type: blockedType, reason: reason)
                            dismiss()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 350, minHeight: 200)
    }
}

// MARK: - Task Waiting Sheet

struct TaskWaitingSheet: View {
    let task: PMTask
    let viewModel: ProjectDetailViewModel
    @Binding var reason: String
    @Binding var checkBackDate: Date?
    @Environment(\.dismiss) private var dismiss
    @State private var hasCheckBack = false

    var body: some View {
        NavigationStack {
            Form {
                Section("What are you waiting for?") {
                    TextField("Reason", text: $reason)
                }
                Section("Check back date") {
                    Toggle("Set check-back date", isOn: $hasCheckBack)
                    if hasCheckBack {
                        DatePicker("Check back", selection: Binding(
                            get: { checkBackDate ?? Date().addingTimeInterval(86400) },
                            set: { checkBackDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Set Waiting")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set Waiting") {
                        Task {
                            await viewModel.waitTask(task, reason: reason,
                                                      checkBackDate: hasCheckBack ? checkBackDate : nil)
                            dismiss()
                        }
                    }
                    .disabled(reason.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 350, minHeight: 250)
    }
}

// MARK: - Task Edit Sheet

struct TaskEditSheet: View {
    let viewModel: ProjectDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var status: ItemStatus
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

    init(task: PMTask, viewModel: ProjectDetailViewModel) {
        self.viewModel = viewModel
        self.taskId = task.id
        self.milestoneId = task.milestoneId
        self.sortOrder = task.sortOrder
        _name = State(initialValue: task.name)
        _status = State(initialValue: task.status)
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
                        var task = PMTask(
                            id: taskId,
                            milestoneId: milestoneId,
                            name: name.trimmingCharacters(in: .whitespaces),
                            sortOrder: sortOrder,
                            status: status,
                            isTimeboxed: isTimeboxed,
                            timeEstimateMinutes: Int(timeEstimate),
                            timeboxMinutes: isTimeboxed ? Int(timeboxMinutes) : nil,
                            deadline: hasDeadline ? deadline : nil,
                            priority: priority,
                            effortType: effortType,
                            kanbanColumn: status.kanbanColumn
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

// MARK: - Milestone Edit Sheet

struct MilestoneEditSheet: View {
    let viewModel: ProjectDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var priority: Priority
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var definitionOfDone: String

    private let milestoneId: UUID
    private let phaseId: UUID
    private let sortOrder: Int
    private let status: ItemStatus

    init(milestone: Milestone, viewModel: ProjectDetailViewModel) {
        self.viewModel = viewModel
        self.milestoneId = milestone.id
        self.phaseId = milestone.phaseId
        self.sortOrder = milestone.sortOrder
        self.status = milestone.status
        _name = State(initialValue: milestone.name)
        _priority = State(initialValue: milestone.priority)
        _hasDeadline = State(initialValue: milestone.deadline != nil)
        _deadline = State(initialValue: milestone.deadline ?? Date().addingTimeInterval(86400 * 14))
        _definitionOfDone = State(initialValue: milestone.definitionOfDone ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Milestone") {
                    TextField("Name", text: $name)
                }
                Section("Properties") {
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Text(p.rawValue.capitalized).tag(p)
                        }
                    }
                }
                Section("Deadline") {
                    Toggle("Set deadline", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                    }
                }
                Section("Definition of Done") {
                    TextEditor(text: $definitionOfDone)
                        .frame(minHeight: 60)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Milestone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let milestone = Milestone(
                            id: milestoneId,
                            phaseId: phaseId,
                            name: name.trimmingCharacters(in: .whitespaces),
                            sortOrder: sortOrder,
                            status: status,
                            definitionOfDone: definitionOfDone,
                            deadline: hasDeadline ? deadline : nil,
                            priority: priority
                        )
                        Task {
                            await viewModel.updateMilestone(milestone)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 350)
        #endif
    }
}
