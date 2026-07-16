import Foundation
import Testing
@testable import dsmaccess

@MainActor
struct DSMTransportRetryTests {
    @Test func retriesAnIdempotentReadAfterOneTimeout() async throws {
        let stub = DSMRequestStub(results: [
            .timeout,
            .response(Data(#"{"success":true,"data":{}}"#.utf8)),
        ])
        let transport = makeTransport(stub: stub)
        transport.establishSession(LoginResult(sid: "session-id", did: nil, synotoken: nil))

        let _: EmptyData = try await transport.read(
            api: DSMAPI("SYNO.Example"),
            method: "get",
            as: EmptyData.self
        )

        #expect(await stub.requestCount == 2)
    }

    @Test func doesNotRetryAMutationAfterTimeout() async throws {
        let stub = DSMRequestStub(results: [.timeout])
        let transport = makeTransport(stub: stub)
        transport.establishSession(LoginResult(sid: "session-id", did: nil, synotoken: nil))

        do {
            try await transport.perform(api: DSMAPI("SYNO.Example"), method: "set")
            Issue.record("La mutation aurait dû échouer après le timeout.")
        } catch {
            let dsmError = try #require(error as? DSMError)
            guard case .network = dsmError else {
                Issue.record("Erreur inattendue : \(dsmError)")
                return
            }
        }

        #expect(await stub.requestCount == 1)
    }

    private func makeTransport(stub: DSMRequestStub) -> DSMTransport {
        var capabilities = DSMCapabilities()
        capabilities.merge([
            "SYNO.Example": APIInfoEntry(
                path: "entry.cgi",
                minVersion: 1,
                maxVersion: 1
            ),
        ])
        return DSMTransport(
            endpoint: DSMEndpoint(useHTTPS: true, host: "nas.local", port: 5001),
            session: .shared,
            capabilities: capabilities,
            requestData: { try await stub.data(for: $0) }
        )
    }
}
