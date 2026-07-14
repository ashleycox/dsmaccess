//
//  DSMTransport.swift
//  dsmaccess
//
//  Transport HTTP commun : découverte des routes, versionnement, session et décodage.
//

import Foundation

@MainActor
final class DSMTransport {
    private static let infoAPI = DSMAPI("SYNO.API.Info", preferredVersion: 1)
    private static let infoPath = "entry.cgi"

    let endpoint: DSMEndpoint
    private let session: URLSession
    private let trustDelegate: ServerTrustDelegate?

    private(set) var capabilities = DSMCapabilities()
    private var sessionID: String?
    private var synoToken: String?

    init(endpoint: DSMEndpoint) {
        self.endpoint = endpoint
        let delegate = ServerTrustDelegate(trustedHost: endpoint.host)
        trustDelegate = delegate

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    init(endpoint: DSMEndpoint, session: URLSession) {
        self.endpoint = endpoint
        self.session = session
        trustDelegate = nil
    }

    func establishSession(_ result: LoginResult) {
        sessionID = result.sid
        synoToken = result.synotoken
    }

    func clearSession() {
        sessionID = nil
        synoToken = nil
    }

    @discardableResult
    func discover(_ names: [String]) async throws -> [String: APIInfoEntry] {
        let requestedNames = names.isEmpty ? [Self.infoAPI.name] : names
        let parameters = [
            "api": Self.infoAPI.name,
            "version": "1",
            "method": "query",
            "query": requestedNames.joined(separator: ","),
        ]
        let response: DSMResponse<[String: APIInfoEntry]> = try await send(
            path: Self.infoPath,
            parameters: parameters
        )
        guard response.success, let data = response.data else {
            throw error(from: response.error)
        }
        capabilities.merge(data)
        return data
    }

    @discardableResult
    func discoverAll() async throws -> DSMCapabilities {
        let parameters = [
            "api": Self.infoAPI.name,
            "version": "1",
            "method": "query",
            "query": "all",
        ]
        let response: DSMResponse<[String: APIInfoEntry]> = try await send(
            path: Self.infoPath,
            parameters: parameters
        )
        guard response.success, let data = response.data else {
            throw error(from: response.error)
        }
        capabilities.merge(data)
        return capabilities
    }

    func response<Value: Decodable>(
        api: DSMAPI,
        method: String,
        parameters: [String: String] = [:],
        authenticated: Bool = true,
        as type: Value.Type
    ) async throws -> DSMResponse<Value> {
        let resolved = try await resolve(api)
        var query = parameters
        query["api"] = resolved.name
        query["version"] = String(resolved.version)
        query["method"] = method
        if authenticated {
            try appendAuthentication(to: &query)
        }
        return try await send(path: resolved.path, parameters: query)
    }

    func value<Value: Decodable>(
        api: DSMAPI,
        method: String,
        parameters: [String: String] = [:],
        authenticated: Bool = true,
        as type: Value.Type
    ) async throws -> Value {
        let response = try await response(
            api: api,
            method: method,
            parameters: parameters,
            authenticated: authenticated,
            as: type
        )
        guard response.success, let data = response.data else {
            throw error(from: response.error)
        }
        return data
    }

    func perform(
        api: DSMAPI,
        method: String,
        parameters: [String: String] = [:],
        authenticated: Bool = true
    ) async throws {
        let response = try await response(
            api: api,
            method: method,
            parameters: parameters,
            authenticated: authenticated,
            as: EmptyData.self
        )
        guard response.success else {
            throw error(from: response.error)
        }
    }

    func resolvedAPI(_ api: DSMAPI) async throws -> ResolvedDSMAPI {
        try await resolve(api)
    }

    func authenticatedParameters() throws -> [String: String] {
        var parameters: [String: String] = [:]
        try appendAuthentication(to: &parameters)
        return parameters
    }

    func makeURL(path: String, parameters: [String: String]) throws -> URL {
        var components = URLComponents()
        components.scheme = endpoint.scheme
        components.host = endpoint.host
        components.port = endpoint.port
        components.path = "/webapi/\(path)"
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else {
            throw DSMError.invalidEndpoint
        }
        return url
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            throw error.code == .cancelled ? DSMError.cancelled : DSMError.network(error.localizedDescription)
        }
    }

    func download(from url: URL) async throws -> (URL, URLResponse) {
        do {
            return try await session.download(from: url)
        } catch let error as URLError {
            throw error.code == .cancelled ? DSMError.cancelled : DSMError.network(error.localizedDescription)
        }
    }

    func upload(for request: URLRequest, from body: Data) async throws -> (Data, URLResponse) {
        do {
            return try await session.upload(for: request, from: body)
        } catch let error as URLError {
            throw error.code == .cancelled ? DSMError.cancelled : DSMError.network(error.localizedDescription)
        }
    }

    private func resolve(_ api: DSMAPI) async throws -> ResolvedDSMAPI {
        if capabilities.entry(for: api.name) == nil {
            _ = try await discover([api.name])
        }
        return try capabilities.resolve(api)
    }

    private func appendAuthentication(to parameters: inout [String: String]) throws {
        guard let sessionID else {
            throw DSMError.sessionExpired
        }
        parameters["_sid"] = sessionID
        if let synoToken, !synoToken.isEmpty {
            parameters["SynoToken"] = synoToken
        }
    }

    private func send<Value: Decodable>(
        path: String,
        parameters: [String: String]
    ) async throws -> DSMResponse<Value> {
        let url = try makeURL(path: path, parameters: parameters)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError {
            throw error.code == .cancelled ? DSMError.cancelled : DSMError.network(error.localizedDescription)
        }
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw DSMError.invalidResponse
        }
        do {
            return try JSONDecoder().decode(DSMResponse<Value>.self, from: data)
        } catch {
            throw DSMError.decoding
        }
    }

    private func error(from body: DSMErrorBody?) -> DSMError {
        switch body?.code {
        case 105: .permissionDenied
        case 106, 107, 119: .sessionExpired
        case let code?: .apiError(code: code)
        case nil: .invalidResponse
        }
    }
}
