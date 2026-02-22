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
    @State private var exportService: ExportService?
    @State private var checkInFlowManager: CheckInFlowManager?
    @State private var onboardingManager: OnboardingFlowManager?
    @State private var retrospectiveManager: RetrospectiveFlowManager?
    @State private var knowledgeBaseManager: KnowledgeBaseManager?
    @State private var syncManager: SyncManager?
    @State private var initError: String?
    @State private var selectedBrowserProject: Project?
    @State private var selectedFocusBoardProject: Project?
    @State private var showQuickCaptureSheet = false

    // Cache detail ViewModels by project ID to preserve expansion state across navigation
    @State private var detailVMCache: [UUID: ProjectDetailViewModel] = [:]
    @State private var docVMCache: [UUID: DocumentViewModel] = [:]

    // Repositories stored for creating detail VMs on demand
    @State private var projectRepo: SQLiteProjectRepository?
    @State private var categoryRepo: SQLiteCategoryRepository?
    @State private var phaseRepo: SQLitePhaseRepository?
    @State private var milestoneRepo: SQLiteMilestoneRepository?
    @State private var taskRepo: SQLiteTaskRepository?
    @State private var subtaskRepo: SQLiteSubtaskRepository?
    @State private var dependencyRepo: SQLiteDependencyRepository?
    @State private var documentRepo: SQLiteDocumentRepository?
    @State private var documentVersionRepo: SQLiteDocumentVersionRepository?
    @State private var checkInRepo: SQLiteCheckInRepository?
    @State private var conversationRepo: SQLiteConversationRepository?

    var body: some View {
        Group {
            if let projectBrowserVM, let focusBoardVM, let chatVM, let quickCaptureVM, let crossProjectRoadmapVM {
                AppNavigationView {
                    if let project = selectedFocusBoardProject {
                        makeProjectDetailView(project: project)
                            .toolbar {
                                ToolbarItem(placement: .navigation) {
                                    Button {
                                        selectedFocusBoardProject = nil
                                    } label: {
                                        Label("Back", systemImage: "chevron.left")
                                    }
                                }
                            }
                    } else {
                        FocusBoardView(viewModel: focusBoardVM) { project in
                            selectedFocusBoardProject = project
                        }
                    }
                } projectBrowser: {
                    if let project = selectedBrowserProject {
                        makeProjectDetailView(project: project)
                            .toolbar {
                                ToolbarItem(placement: .navigation) {
                                    Button {
                                        selectedBrowserProject = nil
                                    } label: {
                                        Label("Back", systemImage: "chevron.left")
                                    }
                                }
                            }
                    } else {
                        ProjectBrowserView(viewModel: projectBrowserVM, onSelectProject: { project in
                            selectedBrowserProject = project
                        }, onboardingManager: onboardingManager)
                    }
                } quickCapture: {
                    QuickCaptureView(viewModel: quickCaptureVM)
                } crossProjectRoadmap: {
                    CrossProjectRoadmapView(viewModel: crossProjectRoadmapVM)
                } aiChat: {
                    ChatView(viewModel: chatVM)
                } settings: {
                    SettingsView(settings: settingsManager, exportService: exportService, syncManager: syncManager)
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
            let detailVM = detailVMCache[project.id] ?? {
                let vm = ProjectDetailViewModel(
                    project: project,
                    projectRepo: projectRepo,
                    phaseRepo: phaseRepo,
                    milestoneRepo: milestoneRepo,
                    taskRepo: taskRepo,
                    subtaskRepo: subtaskRepo,
                    dependencyRepo: dependencyRepo
                )
                vm.retrospectiveManager = retrospectiveManager
                vm.knowledgeBaseManager = knowledgeBaseManager
                vm.syncManager = syncManager
                vm.notificationManager = notificationManager
                DispatchQueue.main.async { detailVMCache[project.id] = vm }
                return vm
            }()
            let roadmapVM = ProjectRoadmapViewModel(
                project: project,
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo,
                taskRepo: taskRepo,
                subtaskRepo: subtaskRepo,
                dependencyRepo: dependencyRepo
            )
            let docVM: DocumentViewModel? = docVMCache[project.id] ?? {
                guard let documentRepo else { return nil }
                let vm = DocumentViewModel(projectId: project.id, documentRepo: documentRepo, versionRepo: documentVersionRepo, knowledgeBaseManager: knowledgeBaseManager)
                vm.syncManager = syncManager
                DispatchQueue.main.async { docVMCache[project.id] = vm }
                return vm
            }()
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
            let documentVersionRepo = SQLiteDocumentVersionRepository(db: db.dbQueue)
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
            self.documentVersionRepo = documentVersionRepo
            self.conversationRepo = conversationRepo

            var actionExecutor = ActionExecutor(
                taskRepo: taskRepo,
                milestoneRepo: milestoneRepo,
                subtaskRepo: subtaskRepo,
                projectRepo: projectRepo,
                documentRepo: documentRepo
            )

            let embeddingService = EmbeddingService()
            let kbStore = InMemoryKnowledgeBaseStore()
            let kbManager = KnowledgeBaseManager(store: kbStore, embeddingService: embeddingService)
            self.knowledgeBaseManager = kbManager

            let syncDataProvider = RepositorySyncDataProvider(
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo,
                taskRepo: taskRepo,
                subtaskRepo: subtaskRepo,
                checkInRepo: checkInRepo,
                documentRepo: documentRepo,
                categoryRepo: categoryRepo,
                conversationRepo: conversationRepo,
                dependencyRepo: dependencyRepo
            )
            let syncBackend = CloudKitSyncBackend()
            let syncQueue = InMemorySyncQueue()
            let syncEngine = SyncEngine(
                backend: syncBackend,
                queue: syncQueue,
                dataProvider: syncDataProvider
            )
            let syncMgr = SyncManager(syncEngine: syncEngine)
            syncMgr.syncEnabled = settingsManager.syncEnabled
            self.syncManager = syncMgr

            // Wire sync change tracking into ActionExecutor
            actionExecutor.onChangeTracked = { entityType, entityId, changeType in
                guard let syncType = SyncEntityType(rawValue: entityType),
                      let syncChange = SyncChangeType(rawValue: changeType) else { return }
                Task { @MainActor in
                    syncMgr.trackChange(entityType: syncType, entityId: entityId, changeType: syncChange)
                }
            }

            let checkInManager = CheckInFlowManager(
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo,
                taskRepo: taskRepo,
                checkInRepo: checkInRepo,
                llmClient: LLMClient(),
                actionExecutor: actionExecutor,
                contextAssembler: ContextAssembler(knowledgeBase: kbManager)
            )
            checkInManager.gentleThresholdDays = settingsManager.checkInGentlePromptDays
            checkInManager.moderateThresholdDays = settingsManager.checkInModeratePromptDays
            checkInManager.prominentThresholdDays = settingsManager.checkInProminentPromptDays
            checkInManager.deferredThreshold = settingsManager.deferredThreshold
            checkInManager.knowledgeBaseManager = kbManager
            checkInManager.syncManager = syncMgr
            self.checkInFlowManager = checkInManager

            let onboardingMgr = OnboardingFlowManager(
                llmClient: LLMClient(),
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo,
                taskRepo: taskRepo,
                documentRepo: documentRepo
            )
            onboardingMgr.syncManager = syncMgr
            self.onboardingManager = onboardingMgr

            let retroManager = RetrospectiveFlowManager(
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo,
                taskRepo: taskRepo,
                checkInRepo: checkInRepo,
                llmClient: LLMClient()
            )
            retroManager.syncManager = syncMgr
            self.retrospectiveManager = retroManager

            let browserVM = ProjectBrowserViewModel(
                projectRepo: projectRepo,
                categoryRepo: categoryRepo,
                documentRepo: documentRepo
            )
            browserVM.syncManager = syncMgr
            self.projectBrowserVM = browserVM

            let focusBoardVM = FocusBoardViewModel(
                projectRepo: projectRepo,
                categoryRepo: categoryRepo,
                taskRepo: taskRepo,
                milestoneRepo: milestoneRepo,
                phaseRepo: phaseRepo,
                checkInRepo: checkInRepo,
                checkInFlowManager: checkInManager
            )
            focusBoardVM.syncManager = syncMgr
            self.focusBoardVM = focusBoardVM

            let chatViewModel = ChatViewModel(
                llmClient: LLMClient(),
                actionExecutor: actionExecutor,
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo,
                taskRepo: taskRepo,
                checkInRepo: checkInRepo,
                conversationRepo: conversationRepo,
                contextAssembler: ContextAssembler(knowledgeBase: kbManager)
            )
            chatViewModel.aiTrustLevel = settingsManager.aiTrustLevel
            chatViewModel.returnBriefingThresholdDays = settingsManager.returnBriefingThresholdDays
            self.chatVM = chatViewModel

            let quickCaptureVM = QuickCaptureViewModel(
                projectRepo: projectRepo,
                categoryRepo: categoryRepo
            )
            quickCaptureVM.syncManager = syncMgr
            self.quickCaptureVM = quickCaptureVM

            self.crossProjectRoadmapVM = CrossProjectRoadmapViewModel(
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo
            )

            // Initialize export service
            let exportBackend = FileExportBackend()
            let exportDir = dbDir.appendingPathComponent("exports", isDirectory: true)
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            let exportConfig = ExportConfig(
                destination: .jsonFile,
                filePath: exportDir.appendingPathComponent("export.json").path
            )
            self.exportService = ExportService(backend: exportBackend, config: exportConfig)

            // Initialize notification manager
            // Read live from UserDefaults so mid-session settings changes take effect.
            // UserDefaults is Sendable/thread-safe, unlike @MainActor SettingsManager.
            let delivery = UNNotificationDelivery()
            let notifDefaults = UserDefaults.standard
            let notifManager = NotificationManager(
                delivery: delivery,
                preferences: {
                    var types = Set<NotificationType>()
                    if notifDefaults.bool(forKey: "settings.notificationsEnabled") {
                        if notifDefaults.bool(forKey: "settings.notifyWaitingCheckBack") { types.insert(.waitingCheckBack) }
                        if notifDefaults.bool(forKey: "settings.notifyDeadlineApproaching") { types.insert(.deadlineApproaching) }
                        if notifDefaults.bool(forKey: "settings.notifyCheckInReminder") { types.insert(.checkInReminder) }
                        if notifDefaults.bool(forKey: "settings.notifyPhaseCompletion") { types.insert(.phaseCompletion) }
                    }
                    return NotificationPreferences(
                        enabledTypes: types,
                        maxDailyCount: max(1, notifDefaults.integer(forKey: "settings.maxDailyNotifications")),
                        quietHoursStart: notifDefaults.integer(forKey: "settings.quietHoursStart"),
                        quietHoursEnd: notifDefaults.integer(forKey: "settings.quietHoursEnd")
                    )
                }
            )
            self.notificationManager = notifManager

            // Wire notification manager into managers/VMs
            checkInManager.notificationManager = notifManager
            focusBoardVM.notificationManager = notifManager

            // Request notification authorization
            _ = try? await notifManager.requestAuthorization()

            // Start periodic sync if enabled
            if settingsManager.syncEnabled {
                syncMgr.startPeriodicSync()
            }

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
