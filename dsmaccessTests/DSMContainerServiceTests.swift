import Foundation
import Testing
@testable import dsmaccess

@MainActor
struct DSMContainerServiceTests {
    @Test func loadsDSM74ResourcesFromTheResourceAPI() async throws {
        let stub = DSMRequestStub(results: [
            .response(Data(
                #"{"success":true,"data":{"containers":[{"id":"container-id","name":"web","image":"nginx:latest","status":"running","up_time":90061}]}}"#.utf8
            )),
            .response(Data(
                #"{"success":true,"data":{"resources":[{"name":"web","cpu":2.5,"memory":67108864}]}}"#.utf8
            )),
        ])
        let service = makeService(stub: stub)

        let containers = try await service.containers()

        let container = try #require(containers.first)
        #expect(container.cpuPercent == 2.5)
        #expect(container.memoryBytes == 67_108_864)
        #expect(container.uptimeSeconds == 90_061)

        let requests = await stub.requests
        #expect(requests.count == 2)
        #expect(try query(from: requests[0])["type"] == "all")
        #expect(try query(from: requests[1])["api"] == "SYNO.Docker.Container.Resource")
        #expect(try query(from: requests[1])["method"] == "get")
    }

    @Test func postsCompleteContainerLogRequestAndDecodesDSM74Rows() async throws {
        let response = Data(
            #"{"success":true,"data":{"logs":[{"created":"2025-06-15T10:38:55.869358659Z","docid":"42","stream":"stderr","text":"Starting server"}]}}"#.utf8
        )
        let stub = DSMRequestStub(results: [.response(response)])
        let service = makeService(stub: stub)

        let logs = try await service.logs(name: "web", limit: 300)

        let entry = try #require(logs.first)
        #expect(entry.id == "42")
        #expect(entry.timestamp == "2025-06-15T10:38:55.869358659Z")
        #expect(entry.stream == "stderr")
        #expect(entry.message == "Starting server")

        let requests = await stub.requests
        let request = try #require(requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.query == nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded; charset=utf-8")
        let parameters = try formParameters(from: request)
        #expect(parameters["api"] == "SYNO.Docker.Container.Log")
        #expect(parameters["method"] == "get")
        #expect(parameters["name"] == #""web""#)
        #expect(parameters["from"] == #""""#)
        #expect(parameters["to"] == #""""#)
        #expect(parameters["level"] == #""""#)
        #expect(parameters["keyword"] == #""""#)
        #expect(parameters["sort_by"] == #""time""#)
        #expect(parameters["sort_dir"] == #""DESC""#)
        #expect(parameters["offset"] == "0")
        #expect(parameters["limit"] == "300")
    }

    private func makeService(stub: DSMRequestStub) -> DSMContainerService {
        var capabilities = DSMCapabilities()
        capabilities.merge([
            "SYNO.Docker.Container": APIInfoEntry(
                path: "entry.cgi",
                minVersion: 1,
                maxVersion: 1
            ),
            "SYNO.Docker.Container.Resource": APIInfoEntry(
                path: "entry.cgi",
                minVersion: 1,
                maxVersion: 1
            ),
            "SYNO.Docker.Container.Log": APIInfoEntry(
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
        return DSMContainerService(transport: transport)
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

    private func formParameters(from request: URLRequest) throws -> [String: String] {
        let body = try #require(request.httpBody)
        let encoded = try #require(String(data: body, encoding: .utf8))
        let items = try #require(URLComponents(string: "?\(encoded)")?.queryItems)
        return Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }
}
