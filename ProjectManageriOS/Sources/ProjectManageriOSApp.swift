import SwiftUI
import PMUtilities

@main
struct ProjectManageriOSApp: App {
    init() {
        Log.ui.info("Project Manager iOS launching")
    }

    var body: some Scene {
        WindowGroup {
            iOSContentView()
        }
    }
}
