import SwiftUI
import PMDomain
import PMDesignSystem

/// The roadmap tab showing the full phase → milestone → task → subtask hierarchy.
struct RoadmapView: View {
    @Bindable var viewModel: ProjectDetailViewModel

    @State private var newPhaseName = ""
    @State private var expandedPhases: Set<UUID> = []
    @State private var expandedMilestones: Set<UUID> = []
    @State private var expandedTasks: Set<UUID> = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.phases) { phase in
                    PhaseRow(phase: phase, viewModel: viewModel,
                             isExpanded: expandedPhases.contains(phase.id),
                             expandedMilestones: $expandedMilestones,
                             expandedTasks: $expandedTasks) {
                        toggleExpansion(phase.id, in: &expandedPhases)
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

                Spacer()

                Text(phase.status.rawValue.capitalized)
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
                Button("Delete Phase", role: .destructive) {
                    Task { await viewModel.deletePhase(phase) }
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
                Button("Delete Milestone", role: .destructive) {
                    Task { await viewModel.deleteMilestone(milestone) }
                }
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

                Text(task.kanbanColumn.rawValue.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(task.kanbanColumn.color.opacity(0.12), in: Capsule())
                    .foregroundStyle(task.kanbanColumn.color)
            }
            .padding(.leading, 56)
            .padding(.trailing)
            .padding(.vertical, 4)
            .contextMenu {
                Menu("Status") {
                    ForEach(ItemStatus.allCases, id: \.self) { status in
                        Button(status.rawValue.capitalized) {
                            var updated = task
                            updated.status = status
                            if status == .completed { updated.completedAt = Date() }
                            Task { await viewModel.updateTask(updated) }
                        }
                    }
                }
                Menu("Kanban") {
                    ForEach(KanbanColumn.allCases, id: \.self) { col in
                        Button(col.rawValue.capitalized) {
                            var updated = task
                            updated.kanbanColumn = col
                            if col == .done {
                                updated.status = .completed
                                updated.completedAt = Date()
                            }
                            Task { await viewModel.updateTask(updated) }
                        }
                    }
                }
                Divider()
                Button("Delete Task", role: .destructive) {
                    Task { await viewModel.deleteTask(task) }
                }
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
