import Foundation
import Testing
@testable import dsmaccess

@MainActor
struct DSMAccountServiceTests {
    @Test func fetchesGroupMembersThroughTheDedicatedAPI() async throws {
        let stub = DSMRequestStub(results: [
            .response(Data(
                #"{"success":true,"data":{"groups":[{"name":"administrators"},{"name":"users"}],"offset":0,"total":2}}"#.utf8
            )),
            .response(Data(
                #"{"success":true,"data":{"offset":0,"total":2,"users":[{"name":"admin","uid":1024},{"name":"math65","uid":1026}]}}"#.utf8
            )),
            .response(Data(
                #"{"success":true,"data":{"offset":0,"total":1,"users":[{"name":"math65","uid":1026}]}}"#.utf8
            )),
        ])
        let service = makeService(stub: stub)

        let groups = try await service.groups()

        #expect(groups.map(\.name) == ["administrators", "users"])
        #expect(groups.first?.members == ["admin", "math65"])
        #expect(groups.last?.members == ["math65"])

        let requests = await stub.requests
        #expect(requests.count == 3)
        let listParameters = try query(from: requests[0])
        // DSM ignore « members » dans l'additional : ne demander que ce qui est honoré.
        #expect(listParameters["additional"] == #"["description"]"#)
        let firstMembers = try query(from: requests[1])
        #expect(firstMembers["api"] == "SYNO.Core.Group.Member")
        #expect(firstMembers["method"] == "list")
        #expect(firstMembers["group"] == #""administrators""#)
        let secondMembers = try query(from: requests[2])
        #expect(secondMembers["group"] == #""users""#)
    }

    @Test func groupLoadingFailsWhenMembersCannotBeRead() async throws {
        let stub = DSMRequestStub(results: [
            .response(Data(
                #"{"success":true,"data":{"groups":[{"name":"administrators"}],"offset":0,"total":1}}"#.utf8
            )),
            .response(Data(#"{"success":false,"error":{"code":105}}"#.utf8)),
        ])
        let service = makeService(stub: stub)

        await #expect(throws: DSMError.permissionDenied) {
            _ = try await service.groups()
        }
    }

    @Test func sendsTheVerifiedUserCreationContract() async throws {
        let stub = DSMRequestStub(results: [
            .response(Data(#"{"success":true,"data":{"name":"martine","uid":1031}}"#.utf8)),
        ])
        let service = makeService(stub: stub)

        try await service.createUser(
            DSMUserDraft(
                name: "martine",
                password: "secret",
                description: "Compte invité",
                email: "",
                groups: ["users"]
            )
        )

        let request = try #require(await stub.requests.first)
        let parameters = try query(from: request)
        #expect(parameters["api"] == "SYNO.Core.User")
        #expect(parameters["method"] == "create")
        #expect(parameters["name"] == #""martine""#)
        #expect(parameters["password"] == #""secret""#)
        #expect(parameters["group"] == #"["users"]"#)
        #expect(parameters["_sid"] == "session-id")
    }

    private func makeService(stub: DSMRequestStub) -> DSMAccountService {
        var capabilities = DSMCapabilities()
        capabilities.merge([
            "SYNO.Core.User": APIInfoEntry(
                path: "entry.cgi",
                minVersion: 1,
                maxVersion: 1,
                requestFormat: "JSON"
            ),
            "SYNO.Core.Group": APIInfoEntry(
                path: "entry.cgi",
                minVersion: 1,
                maxVersion: 1,
                requestFormat: "JSON"
            ),
            "SYNO.Core.Group.Member": APIInfoEntry(
                path: "entry.cgi",
                minVersion: 1,
                maxVersion: 1,
                requestFormat: "JSON"
            ),
        ])
        let transport = DSMTransport(
            endpoint: DSMEndpoint(useHTTPS: true, host: "nas.local", port: 5001),
            session: .shared,
            capabilities: capabilities,
            requestData: { try await stub.data(for: $0) }
        )
        transport.establishSession(LoginResult(sid: "session-id", did: nil, synotoken: nil))
        return DSMAccountService(transport: transport)
    }

    private func query(from request: URLRequest) throws -> [String: String] {
        let url = try #require(request.url)
        let items = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        )
        return Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }
}
