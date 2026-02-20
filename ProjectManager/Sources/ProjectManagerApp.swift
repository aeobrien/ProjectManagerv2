import SwiftUI
import PMUtilities

@main
struct ProjectManagerApp: App {
    init() {
        Log.ui.info("Project Manager launching")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
