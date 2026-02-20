import Testing
@testable import PMDomain

@Suite("PMDomain")
struct PMDomainTests {
    @Test("Module is accessible")
    func moduleAccessible() {
        #expect(PMDomainMarker.version == "0.1.0")
    }
}
