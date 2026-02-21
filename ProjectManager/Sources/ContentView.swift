import SwiftUI
import PMUtilities
import PMFeatures
import PMServices
import PMData
import PMDomain

struct ContentView: View {
    @State private var dbManager: DatabaseManager?
    @State private var projectBrowserVM: ProjectBrowserViewModel?
    @State private var focusBoardVM: FocusBoardViewModel?
    @State private var chatVM: ChatViewModel?
    @State private var settingsManager = SettingsManager()
    @State private var initError: String?

    var body: some View {
        Group {
            if let projectBrowserVM, let focusBoardVM, let chatVM {
                AppNavigationView {
                    FocusBoardView(viewModel: focusBoardVM)
                } projectBrowser: {
                    ProjectBrowserView(viewModel: projectBrowserVM)
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
        .task {
            await initialize()
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

            let documentRepo = SQLiteDocumentRepository(db: db.dbQueue)

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
