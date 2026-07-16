//
//  DSMSystemService.swift
//  dsmaccess
//
//  Informations générales et utilisation instantanée du NAS.
//

import Foundation

@MainActor
final class DSMSystemService {
    private static let infoAPI = DSMAPI("SYNO.DSM.Info", preferredVersion: 2)
    private static let utilizationAPI = DSMAPI("SYNO.Core.System.Utilization")

    private let transport: DSMTransport

    init(transport: DSMTransport) {
        self.transport = transport
    }

    func information() async throws -> SystemInfo {
        try await transport.read(
            api: Self.infoAPI,
            method: "getinfo",
            as: SystemInfo.self
        )
    }

    func resourceUsage() async throws -> ResourceUsage {
        try await transport.read(
            api: Self.utilizationAPI,
            method: "get",
            as: ResourceUsage.self
        )
    }
}
