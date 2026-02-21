import SwiftUI
import PMUtilities
import PMFeatures
import PMServices
import PMData
import PMDomain
import UserNotifications

struct ContentView: View {
    @State private var dbManager: DatabaseManager?
    @State private var projectBrowserVM: ProjectBrowserViewModel?
    @State private var focusBoardVM: FocusBoardViewModel?
    @State private var chatVM: ChatViewModel?
    @State private var quickCaptureVM: QuickCaptureViewModel?
    @State private var crossProjectRoadmapVM: CrossProjectRoadmapViewModel?
    @State private var settingsManager = SettingsManager()
    @State private var notificationManager: NotificationManager?
    @State private var initError: String?
    @State private var focusBoardNavPath = NavigationPath()
    @State private var browserNavPath = NavigationPath()
    @State private var showQuickCaptureSheet = false

    // Repositories stored for creating detail VMs on demand
    @State private var projectRepo: SQLiteProjectRepository?
    @State private var categoryRepo: SQLiteCategoryRepository?
    @State private var phaseRepo: SQLitePhaseRepository?
    @State private var milestoneRepo: SQLiteMilestoneRepository?
    @State private var taskRepo: SQLiteTaskRepository?
    @State private var subtaskRepo: SQLiteSubtaskRepository?
    @State private var dependencyRepo: SQLiteDependencyRepository?
    @State private var documentRepo: SQLiteDocumentRepository?
    @State private var checkInRepo: SQLiteCheckInRepository?
    @State private var conversationRepo: SQLiteConversationRepository?

    var body: some View {
        Group {
            if let projectBrowserVM, let focusBoardVM, let chatVM, let quickCaptureVM, let crossProjectRoadmapVM {
                AppNavigationView {
                    NavigationStack(path: $focusBoardNavPath) {
                        FocusBoardView(viewModel: focusBoardVM) { project in
                            focusBoardNavPath.append(project)
                        }
                        .navigationDestination(for: Project.self) { project in
                            makeProjectDetailView(project: project)
                        }
                    }
                } projectBrowser: {
                    NavigationStack(path: $browserNavPath) {
                        ProjectBrowserView(viewModel: projectBrowserVM) { project in
                            browserNavPath.append(project)
                        }
                        .navigationDestination(for: Project.self) { project in
                            makeProjectDetailView(project: project)
                        }
                    }
                } quickCapture: {
                    QuickCaptureView(viewModel: quickCaptureVM)
                } crossProjectRoadmap: {
                    CrossProjectRoadmapView(viewModel: crossProjectRoadmapVM)
                } aiChat: {
                    ChatView(viewModel: chatVM)
                } settings: {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showQuickCaptureSheet) {
            if let quickCaptureVM {
                QuickCaptureView(viewModel: quickCaptureVM)
                    .frame(minWidth: 400, minHeight: 300)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickCaptureShortcut)) { _ in
            showQuickCaptureSheet = true
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
            let conversationRepo = SQLiteConversationRepository(db: db.dbQueue)

            self.projectRepo = projectRepo
            self.categoryRepo = categoryRepo
            self.phaseRepo = phaseRepo
            self.milestoneRepo = milestoneRepo
            self.taskRepo = taskRepo
            self.subtaskRepo = subtaskRepo
            self.checkInRepo = checkInRepo
            self.dependencyRepo = dependencyRepo
            self.documentRepo = documentRepo
            self.conversationRepo = conversationRepo

            self.projectBrowserVM = ProjectBrowserViewModel(
                projectRepo: projectRepo,
                categoryRepo: categoryRepo,
                documentRepo: documentRepo
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
                checkInRepo: checkInRepo,
                conversationRepo: conversationRepo
            )

            self.quickCaptureVM = QuickCaptureViewModel(
                projectRepo: projectRepo,
                categoryRepo: categoryRepo
            )

            self.crossProjectRoadmapVM = CrossProjectRoadmapViewModel(
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo
            )

            // Initialize notification manager
            let delivery = UNNotificationDelivery()
            let maxDaily = settingsManager.maxDailyNotifications
            let quietStart = settingsManager.quietHoursStart
            let quietEnd = settingsManager.quietHoursEnd
            let notifManager = NotificationManager(
                delivery: delivery,
                preferences: {
                    NotificationPreferences(
                        maxDailyCount: maxDaily,
                        quietHoursStart: quietStart,
                        quietHoursEnd: quietEnd
                    )
                }
            )
            self.notificationManager = notifManager

            // Request notification authorization
            _ = try? await notifManager.requestAuthorization()

            Log.ui.info("Database initialized at \(dbPath)")
        } catch {
            initError = error.localizedDescription
            Log.ui.error("Failed to initialize database: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
