import Foundation
import PMDomain
import PMData

/// Fetches focused project data from repositories for Life Planner export.
public final class RepositoryExportDataProvider: LifePlannerDataProvider, @unchecked Sendable {
    private let projectRepo: ProjectRepositoryProtocol
    private let categoryRepo: CategoryRepositoryProtocol
    private let phaseRepo: PhaseRepositoryProtocol
    private let milestoneRepo: MilestoneRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let dependencyRepo: DependencyRepositoryProtocol

    public init(
        projectRepo: ProjectRepositoryProtocol,
        categoryRepo: CategoryRepositoryProtocol,
        phaseRepo: PhaseRepositoryProtocol,
        milestoneRepo: MilestoneRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        dependencyRepo: DependencyRepositoryProtocol
    ) {
        self.projectRepo = projectRepo
        self.categoryRepo = categoryRepo
        self.phaseRepo = phaseRepo
        self.milestoneRepo = milestoneRepo
        self.taskRepo = taskRepo
        self.dependencyRepo = dependencyRepo
    }

    public func fetchExportData() async throws -> LifePlannerExportData {
        let projects = try await projectRepo.fetchFocused()
        let categories = try await categoryRepo.fetchAll()

        var allPhases: [Phase] = []
        var allMilestones: [Milestone] = []
        var allTasks: [PMTask] = []
        var dependencyNames: [UUID: [String]] = [:]

        for project in projects {
            let phases = try await phaseRepo.fetchAll(forProject: project.id)
            allPhases.append(contentsOf: phases)

            for phase in phases {
                let milestones = try await milestoneRepo.fetchAll(forPhase: phase.id)
                allMilestones.append(contentsOf: milestones)

                for milestone in milestones {
                    let tasks = try await taskRepo.fetchAll(forMilestone: milestone.id)
                    allTasks.append(contentsOf: tasks)
                }
            }
        }

        // Resolve dependency names for each task
        // Dependencies use source/target model: source depends on target
        for task in allTasks {
            let deps = try await dependencyRepo.fetchAll(forSource: task.id, sourceType: .task)
            if !deps.isEmpty {
                let names = deps.compactMap { dep in
                    allTasks.first { $0.id == dep.targetId }?.name
                }
                if !names.isEmpty {
                    dependencyNames[task.id] = names
                }
            }
        }

        return LifePlannerExportData(
            projects: projects,
            categories: categories,
            phases: allPhases,
            milestones: allMilestones,
            tasks: allTasks,
            dependencyNames: dependencyNames
        )
    }
}
