//
//  DSMStorageService.swift
//  dsmaccess
//
//  Accès aux volumes, groupes de stockage et disques du NAS.
//

import Foundation

@MainActor
final class DSMStorageService {
    private static let storageAPI = DSMAPI("SYNO.Storage.CGI.Storage")

    private let transport: DSMTransport

    init(transport: DSMTransport) {
        self.transport = transport
    }

    func information() async throws -> StorageInfo {
        try await transport.value(
            api: Self.storageAPI,
            method: "load_info",
            as: StorageInfo.self
        )
    }
}
