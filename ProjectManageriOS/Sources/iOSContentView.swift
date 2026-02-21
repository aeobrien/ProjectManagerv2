import SwiftUI
import PMUtilities
import PMFeatures
import PMServices
import PMData
import PMDomain

struct iOSContentView: View {
    @State private var dbManager: DatabaseManager?
    @State private var projectBrowserVM: ProjectBrowserViewModel?
    @State private var focusBoardVM: FocusBoardViewModel?
    @State private var chatVM: ChatViewModel?
    @State private var quickCaptureVM: QuickCaptureViewModel?
    @State private var settingsManager = SettingsManager()
    @State private var initError: String?

    // Repositories stored for creating detail VMs on demand
    @State private var projectRepo: SQLiteProjectRepository?
    @State private var phaseRepo: SQLitePhaseRepository?
    @State private var milestoneRepo: SQLiteMilestoneRepository?
    @State private var taskRepo: SQLiteTaskRepository?
    @State private var subtaskRepo: SQLiteSubtaskRepository?
    @State private var dependencyRepo: SQLiteDependencyRepository?
    @State private var documentRepo: SQLiteDocumentRepository?

    var body: some View {
        Group {
            if let projectBrowserVM, let focusBoardVM, let chatVM, let quickCaptureVM {
                IOSTabNavigationView {
                    FocusBoardView(viewModel: focusBoardVM) { project in
                        // Navigation handled by navigationDestination in IOSTabNavigationView's NavigationStack
                    }
                    .navigationDestination(for: Project.self) { project in
                        makeProjectDetailView(project: project)
                    }
                } projects: {
                    ProjectBrowserView(viewModel: projectBrowserVM) { project in
                        // Navigation handled by navigationDestination
                    }
                    .navigationDestination(for: Project.self) { project in
                        makeProjectDetailView(project: project)
                    }
                } aiChat: {
                    ChatView(viewModel: chatVM)
                } quickCapture: {
                    QuickCaptureView(viewModel: quickCaptureVM)
                } more: {
                    SettingsView(settings: settingsManager)
                }
            } else if let initError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("Failed to Initialize")
                        .font(.title2)
                    Text(initError)
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            await initialize()
        }
    }

    @ViewBuilder
    private func makeProjectDetailView(project: Project) -> some View {
        if let projectRepo, let phaseRepo, let milestoneRepo, let taskRepo, let subtaskRepo, let dependencyRepo {
            let detailVM = ProjectDetailViewModel(
                project: project,
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo,
                taskRepo: taskRepo,
                subtaskRepo: subtaskRepo,
                dependencyRepo: dependencyRepo
            )
            let roadmapVM = ProjectRoadmapViewModel(
                project: project,
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo,
                taskRepo: taskRepo,
                dependencyRepo: dependencyRepo
            )
            let docVM: DocumentViewModel? = documentRepo.map {
                DocumentViewModel(projectId: project.id, documentRepo: $0)
            }
            ProjectDetailView(viewModel: detailVM, roadmapViewModel: roadmapVM, documentViewModel: docVM)
        }
    }

    private func initialize() async {
        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dbDir = appSupport.appendingPathComponent("ProjectManager", isDirectory: true)
            try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
            let dbPath = dbDir.appendingPathComponent("projects.sqlite").path

            let db = try DatabaseManager(path: dbPath)
            try db.seedCategoriesIfNeeded()
            self.dbManager = db

            let projectRepo = SQLiteProjectRepository(db: db.dbQueue)
            let categoryRepo = SQLiteCategoryRepository(db: db.dbQueue)
            let phaseRepo = SQLitePhaseRepository(db: db.dbQueue)
            let milestoneRepo = SQLiteMilestoneRepository(db: db.dbQueue)
            let taskRepo = SQLiteTaskRepository(db: db.dbQueue)
            let subtaskRepo = SQLiteSubtaskRepository(db: db.dbQueue)
            let checkInRepo = SQLiteCheckInRepository(db: db.dbQueue)
            let dependencyRepo = SQLiteDependencyRepository(db: db.dbQueue)
            let documentRepo = SQLiteDocumentRepository(db: db.dbQueue)

            self.projectRepo = projectRepo
            self.phaseRepo = phaseRepo
            self.milestoneRepo = milestoneRepo
            self.taskRepo = taskRepo
            self.subtaskRepo = subtaskRepo
            self.dependencyRepo = dependencyRepo
            self.documentRepo = documentRepo

            self.projectBrowserVM = ProjectBrowserViewModel(
                projectRepo: projectRepo,
                categoryRepo: categoryRepo
            )

            self.focusBoardVM = FocusBoardViewModel(
                projectRepo: projectRepo,
                categoryRepo: categoryRepo,
                taskRepo: taskRepo,
                milestoneRepo: milestoneRepo,
                phaseRepo: phaseRepo,
                checkInRepo: checkInRepo
            )

            let actionExecutor = ActionExecutor(
                taskRepo: taskRepo,
                milestoneRepo: milestoneRepo,
                subtaskRepo: subtaskRepo,
                projectRepo: projectRepo,
                documentRepo: documentRepo
            )

            self.chatVM = ChatViewModel(
                llmClient: LLMClient(),
                actionExecutor: actionExecutor,
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo,
                taskRepo: taskRepo,
                checkInRepo: checkInRepo
            )

            self.quickCaptureVM = QuickCaptureViewModel(
                projectRepo: projectRepo,
                categoryRepo: categoryRepo
            )

            Log.ui.info("iOS database initialized at \(dbPath)")
        } catch {
            initError = error.localizedDescription
            Log.ui.error("Failed to initialize database: \(error)")
        }
    }
}

#Preview {
    iOSContentView()
}
