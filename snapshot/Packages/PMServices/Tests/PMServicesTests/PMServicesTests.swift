import Testing
@testable import PMServices

@Suite("PMServices")
struct PMServicesTests {
    @Test("Module is accessible")
    func moduleAccessible() {
        #expect(PMServicesMarker.version == "0.1.0")
    }
}
