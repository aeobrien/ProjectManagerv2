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
    @State private var httpServer: HTTPServer?
    @State private var reviewManager: ProjectReviewManager?
    @State private var initError: String?
    @State private var selectedBrowserProject: Project?
    @State private var selectedFocusBoardProject: Project?
    @State private var showQuickCaptureSheet = false
    @State private var voiceManager = VoiceInputManager()

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
    @State private var sessionRepo: SQLiteSessionRepository?
    @State private var processProfileRepo: SQLiteProcessProfileRepository?
    @State private var deliverableRepo: SQLiteDeliverableRepository?
    @State private var loadedCategories: [PMDomain.Category] = []

    var body: some View {
        Group {
            if let projectBrowserVM, let focusBoardVM, let chatVM, let quickCaptureVM, let crossProjectRoadmapVM {
                AppNavigationView {
                    if let project = selectedFocusBoardProject {
                        projectDetailWithBack(project: project) {
                            selectedFocusBoardProject = nil
                        }
                    } else {
                        FocusBoardView(viewModel: focusBoardVM, onSelectProject: { project in
                            selectedFocusBoardProject = project
                        }, reviewManager: reviewManager)
                    }
                } projectBrowser: {
                    if let project = selectedBrowserProject {
                        projectDetailWithBack(project: project) {
                            selectedBrowserProject = nil
                        }
                    } else {
                        ProjectBrowserView(viewModel: projectBrowserVM, onSelectProject: { project in
                            selectedBrowserProject = project
                        }, onboardingManager: onboardingManager)
                    }
                } quickCapture: {
                    QuickCaptureView(viewModel: quickCaptureVM, voiceManager: voiceManager)
                } crossProjectRoadmap: {
                    CrossProjectRoadmapView(viewModel: crossProjectRoadmapVM)
                } aiChat: {
                    ChatView(viewModel: chatVM)
                } settings: {
                    makeSettingsView()
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
                QuickCaptureView(viewModel: quickCaptureVM, voiceManager: voiceManager)
                    .frame(minWidth: 400, minHeight: 300)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickCaptureShortcut)) { _ in
            showQuickCaptureSheet = true
        }
        .onChange(of: showQuickCaptureSheet) { _, isShowing in
            if isShowing {
                quickCaptureVM?.reset()
            }
        }
        .task {
            await initialize()
            await voiceManager.preloadModel()
        }
    }

    private func projectDetailWithBack(project: Project, onBack: @escaping () -> Void) -> some View {
        makeProjectDetailView(project: project)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
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
            ProjectDetailView(viewModel: detailVM, roadmapViewModel: roadmapVM, documentViewModel: docVM, analyticsViewModel: analyticsVM, adversarialReviewManager: adversarialVM, sessionRepo: sessionRepo)
        } else {
            EmptyView()
        }
    }

    private func makeMigrationViewModel() -> MigrationViewModel {
        return MigrationViewModel(importer: MarkdownImporter())
    }

    private func makeAIDevScreenViewModel() -> AIDevScreenViewModel {
        guard let sessionRepo, let projectRepo, let phaseRepo, let milestoneRepo,
              let taskRepo, let subtaskRepo, let checkInRepo, let processProfileRepo,
              let deliverableRepo else {
            fatalError("AIDevScreen requires all repos to be initialized")
        }

        let llmClient = LLMClient()
        let lifecycleManager = SessionLifecycleManager(repo: sessionRepo)
        let summaryService = SummaryGenerationService(llmClient: llmClient, repo: sessionRepo)
        let promptComposer = PromptComposer()
        let contextAssembler = V2ContextAssembler()

        let conversationManager = ConversationManager(
            llmClient: llmClient,
            sessionRepo: sessionRepo,
            lifecycleManager: lifecycleManager,
            summaryService: summaryService,
            promptComposer: promptComposer,
            contextAssembler: contextAssembler
        )

        return AIDevScreenViewModel(
            projectRepo: projectRepo,
            phaseRepo: phaseRepo,
            milestoneRepo: milestoneRepo,
            taskRepo: taskRepo,
            subtaskRepo: subtaskRepo,
            checkInRepo: checkInRepo,
            sessionRepo: sessionRepo,
            processProfileRepo: processProfileRepo,
            deliverableRepo: deliverableRepo,
            conversationManager: conversationManager
        )
    }

    @ViewBuilder
    private func makeSettingsView() -> some View {
        #if DEBUG
        SettingsView(
            settings: settingsManager,
            exportService: exportService,
            syncManager: syncManager,
            migrationViewModelFactory: makeMigrationViewModel,
            onboardingManager: onboardingManager,
            categories: loadedCategories,
            aiDevScreenViewModelFactory: makeAIDevScreenViewModel
        )
        #else
        SettingsView(
            settings: settingsManager,
            exportService: exportService,
            syncManager: syncManager,
            migrationViewModelFactory: makeMigrationViewModel,
            onboardingManager: onboardingManager,
            categories: loadedCategories
        )
        #endif
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
            let sessionRepo = SQLiteSessionRepository(db: db.dbQueue)
            let processProfileRepo = SQLiteProcessProfileRepository(db: db.dbQueue)
            let deliverableRepo = SQLiteDeliverableRepository(db: db.dbQueue)

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
            self.sessionRepo = sessionRepo
            self.processProfileRepo = processProfileRepo
            self.deliverableRepo = deliverableRepo
            self.loadedCategories = (try? await categoryRepo.fetchAll()) ?? []

            var actionExecutor = ActionExecutor(
                taskRepo: taskRepo,
                milestoneRepo: milestoneRepo,
                subtaskRepo: subtaskRepo,
                projectRepo: projectRepo,
                phaseRepo: phaseRepo,
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
                subtaskRepo: subtaskRepo,
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
                subtaskRepo: subtaskRepo,
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
                milestoneRepo: milestoneRepo,
                taskRepo: taskRepo
            )

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
            default: // "file" or "mysql" (mysql falls back to file for now)
                exportBackend = FileExportBackend()
                let filePath = settingsManager.lifePlannerFilePath.isEmpty ? defaultExportPath : settingsManager.lifePlannerFilePath
                exportConfig = ExportConfig(
                    destination: .jsonFile,
                    filePath: filePath
                )
            }

            let expService = ExportService(backend: exportBackend, config: exportConfig)

            // Wire data provider so export can fetch live data
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

            // Initialize notification manager
            // Read live from UserDefaults so mid-session settings changes take effect.
            // UserDefaults is Sendable/thread-safe, unlike @MainActor SettingsManager.
            let delivery = UNNotificationDelivery()
            let notifManager = NotificationManager(
                delivery: delivery,
                preferences: {
                    let defaults = UserDefaults.standard
                    var types = Set<NotificationType>()
                    if defaults.bool(forKey: "settings.notificationsEnabled") {
                        if defaults.bool(forKey: "settings.notifyWaitingCheckBack") { types.insert(.waitingCheckBack) }
                        if defaults.bool(forKey: "settings.notifyDeadlineApproaching") { types.insert(.deadlineApproaching) }
                        if defaults.bool(forKey: "settings.notifyCheckInReminder") { types.insert(.checkInReminder) }
                        if defaults.bool(forKey: "settings.notifyPhaseCompletion") { types.insert(.phaseCompletion) }
                    }
                    return NotificationPreferences(
                        enabledTypes: types,
                        maxDailyCount: max(1, defaults.integer(forKey: "settings.maxDailyNotifications")),
                        quietHoursStart: defaults.integer(forKey: "settings.quietHoursStart"),
                        quietHoursEnd: defaults.integer(forKey: "settings.quietHoursEnd")
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
