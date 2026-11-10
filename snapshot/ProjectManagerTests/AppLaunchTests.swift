import Testing
@testable import PMUtilities

@Suite("App Smoke Tests")
struct AppLaunchTests {
    @Test("Logging subsystem is initialised")
    func loggingWorks() {
        // Verify that the logging system is accessible from the app target.
        // os.Logger doesn't throw on initialisation, so accessing it confirms
        // the PMUtilities dependency is correctly linked.
        Log.ui.info("Smoke test: logging works")
    }
}
