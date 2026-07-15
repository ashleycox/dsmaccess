//
//  SystemLogEntry.swift
//  dsmaccess
//
//  Entrées du journal DSM et adresses bloquées par les protections de connexion.
//

import Foundation

struct SystemLogEntry: nonisolated Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let timestamp: String?
    let level: String
    let category: String?
    let user: String?
    let address: String?
    let message: String

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp = "time"
        case alternateTimestamp = "timestamp"
        case level
        case priority
        case category
        case type
        case user
        case who
        case address = "from"
        case ip
        case message
        case event
    }

    nonisolated init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = values.flexString(.timestamp) ?? values.flexString(.alternateTimestamp)
        level = values.flexString(.level) ?? values.flexString(.priority) ?? "info"
        category = values.flexString(.category) ?? values.flexString(.type)
        user = values.flexString(.user) ?? values.flexString(.who)
        address = values.flexString(.address) ?? values.flexString(.ip)
        message = values.flexString(.message) ?? values.flexString(.event) ?? ""
        let position = decoder.codingPath.last?.intValue ?? 0
        id = values.flexString(.id)
            ?? "fallback:\(position):\(timestamp ?? ""):\(message.hashValue)"
    }
}

struct SystemLogList: nonisolated Decodable, Sendable {
    let logs: [SystemLogEntry]

    enum CodingKeys: String, CodingKey { case logs, items }

    nonisolated init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        logs = try values.decodeArray(SystemLogEntry.self, forFirstPresent: [.logs, .items])
    }
}

struct BlockedAddress: nonisolated Decodable, Identifiable, Hashable, Sendable {
    let address: String
    let createdAt: String?
    let expiresAt: String?
    let reason: String?

    var id: String { address }

    enum CodingKeys: String, CodingKey {
        case address = "ip"
        case alternateAddress = "address"
        case host
        case createdAt = "create_time"
        case alternateCreatedAt = "created_at"
        case expiresAt = "expire_time"
        case alternateExpiresAt = "expires_at"
        case reason
    }

    nonisolated init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard let decodedAddress = values.flexString(.address)
            ?? values.flexString(.alternateAddress)
            ?? values.flexString(.host) else {
            throw DecodingError.dataCorruptedError(
                forKey: .address,
                in: values,
                debugDescription: "Required blocked address is missing or malformed."
            )
        }
        address = decodedAddress
        createdAt = values.flexString(.createdAt) ?? values.flexString(.alternateCreatedAt)
        expiresAt = values.flexString(.expiresAt) ?? values.flexString(.alternateExpiresAt)
        reason = values.flexString(.reason)
    }
}

struct BlockedAddressList: nonisolated Decodable, Sendable {
    let addresses: [BlockedAddress]

    enum CodingKeys: String, CodingKey {
        case addresses = "block_list"
        case items
        case hosts
        case data
    }

    nonisolated init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        addresses = try values.decodeArray(
            BlockedAddress.self,
            forFirstPresent: [.addresses, .items, .hosts, .data]
        )
    }
}
