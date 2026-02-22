import SwiftUI
import PMUtilities
import PMFeatures
import PMServices
import PMData
import PMDomain
import UserNotifications

struct iOSContentView: View {
    @State private var dbManager: DatabaseManager?
    @State private var projectBrowserVM: ProjectBrowserViewModel?
    @State private var focusBoardVM: FocusBoardViewModel?
    @State private var chatVM: ChatViewModel?
    @State private var quickCaptureVM: QuickCaptureViewModel?
    @State private var settingsManager = SettingsManager()
    @State private var exportService: ExportService?
    @State private var checkInFlowManager: CheckInFlowManager?
    @State private var onboardingManager: OnboardingFlowManager?
    @State private var retrospectiveManager: RetrospectiveFlowManager?
    @State private var knowledgeBaseManager: KnowledgeBaseManager?
    @State private var syncManager: SyncManager?
    @State private var httpServer: HTTPServer?
    @State private var reviewManager: ProjectReviewManager?
    @State private var notificationManager: NotificationManager?
    @State private var crossProjectRoadmapVM: CrossProjectRoadmapViewModel?
    @State private var initError: String?
    @State private var selectedTab: IOSTab = .focusBoard

    // Cache detail ViewModels by project ID to preserve state across navigation
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
            if let projectBrowserVM, let focusBoardVM, let chatVM, let quickCaptureVM {
                IOSTabNavigationView(selectedTab: $selectedTab) {
                    FocusBoardView(viewModel: focusBoardVM, onSelectProject: { project in
                        // Navigation handled by navigationDestination in IOSTabNavigationView's NavigationStack
                    }, reviewManager: reviewManager)
                    .navigationDestination(for: Project.self) { project in
                        makeProjectDetailView(project: project)
                    }
                } projects: {
                    ProjectBrowserView(viewModel: projectBrowserVM, onSelectProject: { project in
                        // Navigation handled by navigationDestination
                    }, onboardingManager: onboardingManager)
                    .navigationDestination(for: Project.self) { project in
                        makeProjectDetailView(project: project)
                    }
                } aiChat: {
                    ChatView(viewModel: chatVM)
                } quickCapture: {
                    QuickCaptureView(viewModel: quickCaptureVM)
                } more: {
                    List {
                        if let crossProjectRoadmapVM {
                            NavigationLink {
                                CrossProjectRoadmapView(viewModel: crossProjectRoadmapVM)
                            } label: {
                                Label("Cross-Project Roadmap", systemImage: "map")
                            }
                        }
                        NavigationLink {
                            SettingsView(settings: settingsManager, exportService: exportService, syncManager: syncManager)
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                    }
                    .navigationTitle("More")
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
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .task {
            await initialize()
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "projectmanager" else { return }
        switch url.host {
        case "quickcapture":
            selectedTab = .quickCapture
        case "focusboard":
            selectedTab = .focusBoard
        case "projects":
            selectedTab = .projects
        case "chat":
            selectedTab = .aiChat
        default:
            break
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
            let analyticsVM = AnalyticsViewModel(
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo,
                taskRepo: taskRepo
            )
            let adversarialVM: AdversarialReviewManager? = documentRepo.map { docRepo in
                AdversarialReviewManager(documentRepo: docRepo, llmClient: LLMClient())
            }
            ProjectDetailView(viewModel: detailVM, roadmapViewModel: roadmapVM, documentViewModel: docVM, analyticsViewModel: analyticsVM, adversarialReviewManager: adversarialVM)
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

            let reviewMgr = ProjectReviewManager(
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo,
                taskRepo: taskRepo,
                checkInRepo: checkInRepo,
                llmClient: LLMClient(),
                contextAssembler: ContextAssembler(knowledgeBase: kbManager)
            )
            self.reviewManager = reviewMgr

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

            // Initialize export service with backend based on Life Planner settings
            let exportDir = dbDir.appendingPathComponent("exports", isDirectory: true)
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            let defaultExportPath = exportDir.appendingPathComponent("export.json").path

            let exportBackend: ExportBackendProtocol
            let exportConfig: ExportConfig
            switch settingsManager.lifePlannerSyncMethod {
            case "rest":
                exportBackend = APIExportBackend()
                exportConfig = ExportConfig(
                    destination: .api,
                    apiEndpoint: settingsManager.lifePlannerAPIEndpoint.isEmpty ? nil : settingsManager.lifePlannerAPIEndpoint,
                    apiKey: settingsManager.lifePlannerAPIKey.isEmpty ? nil : settingsManager.lifePlannerAPIKey
                )
            default:
                exportBackend = FileExportBackend()
                let filePath = settingsManager.lifePlannerFilePath.isEmpty ? defaultExportPath : settingsManager.lifePlannerFilePath
                exportConfig = ExportConfig(
                    destination: .jsonFile,
                    filePath: filePath
                )
            }

            let expService = ExportService(backend: exportBackend, config: exportConfig)

            let exportDataProvider = RepositoryExportDataProvider(
                projectRepo: projectRepo,
                categoryRepo: categoryRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo,
                taskRepo: taskRepo,
                dependencyRepo: dependencyRepo
            )
            await expService.setDataProvider(exportDataProvider)
            self.exportService = expService

            // Wire debounced export into ActionExecutor
            if settingsManager.lifePlannerSyncEnabled {
                let exportRef = expService
                actionExecutor.onLifePlannerExport = {
                    Task { await exportRef.triggerDebouncedExport() }
                }
            }

            self.crossProjectRoadmapVM = CrossProjectRoadmapViewModel(
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
                milestoneRepo: milestoneRepo
            )

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

            // Trigger Life Planner export on launch if enabled
            if settingsManager.lifePlannerSyncEnabled {
                _ = await expService.triggerLifePlannerExport()
            }

            // Start integration API server if enabled
            if settingsManager.integrationAPIEnabled {
                let apiConfig = APIServerConfig(
                    port: UInt16(settingsManager.integrationAPIPort),
                    apiKey: settingsManager.integrationAPIKey.isEmpty ? nil : settingsManager.integrationAPIKey,
                    enabled: true
                )
                let apiHandler = IntegrationAPIHandler(
                    config: apiConfig,
                    projectRepo: projectRepo,
                    phaseRepo: phaseRepo,
                    milestoneRepo: milestoneRepo,
                    taskRepo: taskRepo,
                    documentRepo: documentRepo
                )
                let server = HTTPServer(handler: apiHandler, config: apiConfig)
                try await server.start()
                self.httpServer = server
            }

            // Update widget shared data
            await updateWidgetData(projectRepo: projectRepo)

            Log.ui.info("iOS database initialized at \(dbPath)")
        } catch {
            initError = error.localizedDescription
            Log.ui.error("Failed to initialize database: \(error)")
        }
    }

    private func updateWidgetData(projectRepo: SQLiteProjectRepository) async {
        do {
            let projects = try await projectRepo.fetchAll()
            let focused = projects.first(where: { $0.lifecycleState == .focused })
            let defaults = UserDefaults(suiteName: "group.com.projectmanager.shared")
            defaults?.set(projects.count, forKey: "widgetProjectCount")
            defaults?.set(focused?.name, forKey: "widgetFocusedProjectName")
        } catch {
            Log.ui.error("Failed to update widget data: \(error)")
        }
    }
}

#Preview {
    iOSContentView()
}
