//
//  NASProfile.swift
//  dsmaccess
//
//  Métadonnées non secrètes d'un NAS enregistré.
//

import Foundation

struct NASProfile: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var useHTTPS: Bool
    var account: String
    var remembersPassword: Bool

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int,
        useHTTPS: Bool,
        account: String,
        remembersPassword: Bool
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.useHTTPS = useHTTPS
        self.account = account
        self.remembersPassword = remembersPassword
    }

    var endpoint: DSMEndpoint {
        DSMEndpoint(useHTTPS: useHTTPS, host: host, port: port)
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? host : trimmed
    }
}
