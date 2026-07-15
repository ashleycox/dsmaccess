//
//  ContainerItem.swift
//  dsmaccess
//
//  Conteneurs et journaux exposés par Container Manager.
//

import Foundation

struct ContainerItem: nonisolated Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let image: String?
    let status: String
    let createdAt: Int64?
    let startedAt: Int64?
    let autoRestart: Bool
    let cpuPercent: Double?
    let memoryBytes: Int64?

    var isRunning: Bool {
        let value = status.lowercased()
        return value == "running" || value.hasPrefix("up")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case image
        case status
        case state
        case createdAt = "created"
        case startedAt = "started"
        case autoRestart = "enable_auto_restart"
        case cpuPercent = "cpu_percent"
        case memoryBytes = "memory_usage"
    }

    nonisolated init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.requiredFlexString(.name)
        id = values.flexString(.id) ?? name
        image = values.flexString(.image)
        status = values.flexString(.status) ?? values.flexString(.state) ?? "unknown"
        createdAt = values.flexInt64(.createdAt)
        startedAt = values.flexInt64(.startedAt)
        autoRestart = values.flexBool(.autoRestart) ?? false
        if let number = try? values.decode(Double.self, forKey: .cpuPercent) {
            cpuPercent = number
        } else if let string = values.flexString(.cpuPercent) {
            cpuPercent = Double(string.replacingOccurrences(of: "%", with: ""))
        } else {
            cpuPercent = nil
        }
        memoryBytes = values.flexInt64(.memoryBytes)
    }
}

struct ContainerList: nonisolated Decodable, Sendable {
    let containers: [ContainerItem]

    enum CodingKeys: String, CodingKey { case containers }

    nonisolated init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        containers = try values.decodeIfPresent([ContainerItem].self, forKey: .containers) ?? []
    }
}

struct ContainerLogEntry: nonisolated Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let timestamp: Int64?
    let stream: String?
    let message: String

    enum CodingKeys: String, CodingKey {
        case timestamp = "time"
        case alternateTimestamp = "timestamp"
        case stream
        case message = "log"
        case alternateMessage = "message"
    }

    nonisolated init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            let position = decoder.codingPath.last?.intValue ?? 0
            id = "fallback:\(position):\(value.hashValue)"
            timestamp = nil
            stream = nil
            message = value
            return
        }

        let values = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = values.flexInt64(.timestamp) ?? values.flexInt64(.alternateTimestamp)
        stream = values.flexString(.stream)
        message = values.flexString(.message) ?? values.flexString(.alternateMessage) ?? ""
        let position = decoder.codingPath.last?.intValue ?? 0
        id = "fallback:\(position):\(timestamp ?? 0):\(message.hashValue)"
    }
}

struct ContainerLogList: nonisolated Decodable, Sendable {
    let logs: [ContainerLogEntry]

    enum CodingKeys: String, CodingKey { case logs }

    nonisolated init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        logs = try values.decodeIfPresent([ContainerLogEntry].self, forKey: .logs) ?? []
    }
}

enum ContainerAction: String, Sendable {
    case start
    case stop
    case restart
}
