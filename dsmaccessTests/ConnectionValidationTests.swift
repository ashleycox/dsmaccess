import Testing
@testable import dsmaccess

@MainActor
struct ConnectionValidationTests {
    @Test func acceptsOnlyValidTCPPorts() {
        let model = ConnectionViewModel(session: SessionStore())
        model.host = "nas.local"
        model.account = "alex"
        model.password = "secret"

        model.portText = "5001"
        #expect(model.port == 5001)
        #expect(model.canSubmit)

        for invalid in ["", "abc", "0", "65536", "-1"] {
            model.portText = invalid
            #expect(model.port == nil)
            #expect(!model.canSubmit)
        }
    }
}
