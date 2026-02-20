import Testing
@testable import PMFeatures

@Suite("PMFeatures")
struct PMFeaturesTests {
    @Test("Module is accessible")
    func moduleAccessible() {
        #expect(PMFeaturesMarker.version == "0.1.0")
    }
}
