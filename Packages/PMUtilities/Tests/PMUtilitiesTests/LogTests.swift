import Testing
@testable import PMUtilities

@Suite("Log")
struct LogTests {
    @Test("All logger categories are accessible")
    func allCategoriesExist() {
        // Verify all loggers can be accessed without crashing.
        // os.Logger doesn't expose its configuration, so the test
        // confirms they are initialised correctly.
        _ = Log.data
        _ = Log.focus
        _ = Log.ai
        _ = Log.voice
        _ = Log.sync
        _ = Log.ui
        _ = Log.api
        _ = Log.export
    }
}
