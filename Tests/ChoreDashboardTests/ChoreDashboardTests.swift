import Testing
@testable import ChoreDashboard

@Suite("ChoreDashboard Package Sanity")
struct ChoreDashboardPackageSanityTests {
    @Test("Package builds and registers test target")
    func testSanity() {
        #expect(true)
    }
}