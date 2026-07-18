//
//  DSMContainerService.swift
//  dsmaccess
//
//  Inventaire, cycle de vie et journaux de Container Manager.
//

import Foundation

@MainActor
final class DSMContainerService {
    private static let containerAPI = DSMAPI("SYNO.Docker.Container", preferredVersion: 1)
    private static let resourceAPI = DSMAPI("SYNO.Docker.Container.Resource", preferredVersion: 1)
    private static let logAPI = DSMAPI("SYNO.Docker.Container.Log", preferredVersion: 1)

    private let transport: DSMTransport

    init(transport: DSMTransport) {
        self.transport = transport
    }

    func containers() async throws -> [ContainerItem] {
        let result = try await transport.read(
            api: Self.containerAPI,
            method: "list",
            parameters: [
                "offset": .integer(0),
                "limit": .integer(-1),
                "type": .string("all"),
            ],
            as: ContainerList.self
        )
        guard transport.capabilities.supports(Self.resourceAPI.name) else {
            return result.containers
        }

        let resourceResult = try await transport.read(
            api: Self.resourceAPI,
            method: "get",
            as: ContainerResourceList.self
        )
        var resourcesByName = [String: ContainerResource]()
        for resource in resourceResult.resources {
            resourcesByName[resource.name] = resource
        }
        return result.containers.map { container in
            guard let resource = resourcesByName[container.name] else { return container }
            return container.applying(resource)
        }
    }

    func perform(_ action: ContainerAction, name: String) async throws {
        try await transport.perform(
            api: Self.containerAPI,
            method: action.rawValue,
            parameters: ["name": .string(name)]
        )
    }

    func logs(name: String, limit: Int = 300) async throws -> [ContainerLogEntry] {
        guard transport.capabilities.supports(Self.logAPI.name) else { return [] }
        let result = try await transport.read(
            api: Self.logAPI,
            method: "get",
            parameters: [
                "name": .string(name),
                "from": .string(""),
                "to": .string(""),
                "level": .string(""),
                "keyword": .string(""),
                "sort_by": .string("time"),
                "sort_dir": .string("DESC"),
                "offset": .integer(0),
                "limit": .integer(limit),
            ],
            as: ContainerLogList.self
        )
        return result.logs
    }
}
