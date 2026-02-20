import Testing
@testable import PMData

@Suite("PMData")
struct PMDataTests {
    @Test("Module is accessible")
    func moduleAccessible() {
        #expect(PMDataMarker.version == "0.1.0")
    }
}
