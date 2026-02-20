import SwiftUI
import PMUtilities
import PMFeatures
import PMData
import PMDomain

struct ContentView: View {
    @State private var dbManager: DatabaseManager?
    @State private var projectBrowserVM: ProjectBrowserViewModel?
    @State private var initError: String?

    var body: some View {
        Group {
            if let projectBrowserVM {
                AppNavigationView {
                    PlaceholderView(
                        title: "Focus Board",
                        iconName: "square.grid.2x2",
                        message: "Coming in Phase 7"
                    )
                } projectBrowser: {
                    ProjectBrowserView(viewModel: projectBrowserVM)
                } aiChat: {
                    PlaceholderView(
                        title: "AI Chat",
                        iconName: "bubble.left.and.bubble.right",
                        message: "Coming in Phase 10"
                    )
                } settings: {
                    PlaceholderView(
                        title: "Settings",
                        iconName: "gear",
                        message: "Coming in Phase 9"
                    )
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
            self.projectBrowserVM = ProjectBrowserViewModel(projectRepo: projectRepo, categoryRepo: categoryRepo)

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
