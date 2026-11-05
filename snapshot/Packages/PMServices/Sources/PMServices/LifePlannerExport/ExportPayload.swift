import Foundation
import PMDomain

/// A task exported for the Life Planner.
public struct ExportedTask: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let definitionOfDone: String
    public let adjustedEstimateMinutes: Int?
    public let deadline: Date?
    public let milestoneName: String
    public let projectName: String
    public let categoryName: String
    public let status: String
    public let priority: String
    public let effortType: String?
    public let dependencyNames: [String]
    public let kanbanColumn: String

    public init(
        id: UUID,
        name: String,
        definitionOfDone: String,
        adjustedEstimateMinutes: Int?,
        deadline: Date?,
        milestoneName: String,
        projectName: String,
        categoryName: String,
        status: String,
        priority: String,
        effortType: String?,
        dependencyNames: [String],
        kanbanColumn: String
    ) {
        self.id = id
        self.name = name
        self.definitionOfDone = definitionOfDone
        self.adjustedEstimateMinutes = adjustedEstimateMinutes
        self.deadline = deadline
        self.milestoneName = milestoneName
        self.projectName = projectName
        self.categoryName = categoryName
        self.status = status
        self.priority = priority
        self.effortType = effortType
        self.dependencyNames = dependencyNames
        self.kanbanColumn = kanbanColumn
    }
}

/// Summary of a project included in the export.
public struct ExportedProjectSummary: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let categoryName: String
    public let lifecycleState: String
    public let focusSlotIndex: Int?
    public let taskCount: Int
    public let completedTaskCount: Int

    public init(
        id: UUID,
        name: String,
        categoryName: String,
        lifecycleState: String,
        focusSlotIndex: Int?,
        taskCount: Int,
        completedTaskCount: Int
    ) {
        self.id = id
        self.name = name
        self.categoryName = categoryName
        self.lifecycleState = lifecycleState
        self.focusSlotIndex = focusSlotIndex
        self.taskCount = taskCount
        self.completedTaskCount = completedTaskCount
    }
}

/// The full export payload for the Life Planner.
public struct ExportPayload: Codable, Sendable, Equatable {
    public let exportedAt: Date
    public let projects: [ExportedProjectSummary]
    public let tasks: [ExportedTask]

    public init(exportedAt: Date = Date(), projects: [ExportedProjectSummary], tasks: [ExportedTask]) {
        self.exportedAt = exportedAt
        self.projects = projects
        self.tasks = tasks
    }
}

/// Builds export payloads from domain data.
public struct ExportPayloadBuilder: Sendable {
    public init() {}

    /// Build an export payload from focused projects and their tasks.
    ///
    /// The mapping chain is: task → milestone (via milestoneId) → phase (via phaseId) → project (via projectId).
    public func build(
        projects: [Project],
        categories: [PMDomain.Category],
        phases: [Phase],
        milestones: [Milestone],
        tasks: [PMTask],
        dependencyNames: [UUID: [String]]
    ) -> ExportPayload {
        let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let projectMap = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        let phaseMap = Dictionary(uniqueKeysWithValues: phases.map { ($0.id, $0) })
        let milestoneMap = Dictionary(uniqueKeysWithValues: milestones.map { ($0.id, $0) })

        // Build milestone → project lookup: milestone.phaseId → phase.projectId
        var milestoneToProject: [UUID: Project] = [:]
        for ms in milestones {
            if let phase = phaseMap[ms.phaseId], let project = projectMap[phase.projectId] {
                milestoneToProject[ms.id] = project
            }
        }

        let projectSummaries = projects.map { project in
            let projectTasks = tasks.filter { task in
                milestoneToProject[task.milestoneId]?.id == project.id
            }

            return ExportedProjectSummary(
                id: project.id,
                name: project.name,
                categoryName: categoryMap[project.categoryId] ?? "Unknown",
                lifecycleState: project.lifecycleState.rawValue,
                focusSlotIndex: project.focusSlotIndex,
                taskCount: projectTasks.count,
                completedTaskCount: projectTasks.filter { $0.status == .completed }.count
            )
        }

        let exportedTasks = tasks.map { task in
            let milestone = milestoneMap[task.milestoneId]
            let project = milestoneToProject[task.milestoneId]

            return ExportedTask(
                id: task.id,
                name: task.name,
                definitionOfDone: task.definitionOfDone,
                adjustedEstimateMinutes: task.adjustedEstimateMinutes,
                deadline: task.deadline,
                milestoneName: milestone?.name ?? "Unknown",
                projectName: project?.name ?? "Unknown",
                categoryName: project.flatMap { categoryMap[$0.categoryId] } ?? "Unknown",
                status: task.status.rawValue,
                priority: task.priority.rawValue,
                effortType: task.effortType?.rawValue,
                dependencyNames: dependencyNames[task.id] ?? [],
                kanbanColumn: task.kanbanColumn.rawValue
            )
        }

        return ExportPayload(projects: projectSummaries, tasks: exportedTasks)
    }
}
