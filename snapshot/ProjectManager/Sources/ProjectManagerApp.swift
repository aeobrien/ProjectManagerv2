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
        .commands {
            CommandGroup(after: .newItem) {
                Button("Quick Capture") {
                    NotificationCenter.default.post(name: .quickCaptureShortcut, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }
}

extension Notification.Name {
    static let quickCaptureShortcut = Notification.Name("quickCaptureShortcut")
}
