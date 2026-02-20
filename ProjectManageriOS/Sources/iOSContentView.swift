import SwiftUI
import PMUtilities
import PMFeatures
import PMData
import PMDomain

struct iOSContentView: View {
    @State private var dbManager: DatabaseManager?
    @State private var projectBrowserVM: ProjectBrowserViewModel?
    @State private var settingsManager = SettingsManager()
    @State private var initError: String?

    var body: some View {
        Group {
            if let projectBrowserVM {
                IOSTabNavigationView {
                    PlaceholderView(
                        title: "Focus Board",
                        iconName: "square.grid.2x2",
                        message: "Your focused tasks will appear here."
                    )
                } projects: {
                    ProjectBrowserView(viewModel: projectBrowserVM)
                } aiChat: {
                    PlaceholderView(
                        title: "AI Chat",
                        iconName: "bubble.left.and.bubble.right",
                        message: "Chat with your AI project assistant."
                    )
                } quickCapture: {
                    PlaceholderView(
                        title: "Quick Capture",
                        iconName: "plus.circle",
                        message: "Capture project ideas quickly."
                    )
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
            self.projectBrowserVM = ProjectBrowserViewModel(projectRepo: projectRepo, categoryRepo: categoryRepo)

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
