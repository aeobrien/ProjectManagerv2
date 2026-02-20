import Testing
@testable import PMDesignSystem

@Suite("PMDesignSystem")
struct PMDesignSystemTests {
    @Test("Module is accessible")
    func moduleAccessible() {
        #expect(PMDesignSystemMarker.version == "0.1.0")
    }
}
