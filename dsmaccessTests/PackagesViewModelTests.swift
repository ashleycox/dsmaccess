import Testing
@testable import dsmaccess

@MainActor
struct PackagesViewModelTests {
    @Test func comparesSynologyVersionsWithoutOfferingDowngrades() {
        #expect(PackagesViewModel.isVersion("1.4.5-1", newerThan: "1.4.4-2221"))
        #expect(!PackagesViewModel.isVersion("1.4.4-2221", newerThan: "1.4.4-2221"))
        #expect(!PackagesViewModel.isVersion("1.4.3-9999", newerThan: "1.4.4-1"))
    }
}
