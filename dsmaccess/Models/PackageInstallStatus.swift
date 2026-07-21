//
//  PackageInstallStatus.swift
//  dsmaccess
//
//  État d'une installation suivie par le Centre de paquets.
//

import Foundation

struct PackageInstallStatus: nonisolated Decodable, Sendable {
    let isFinished: Bool
    let wasSuccessful: Bool?
    let status: String?

    private enum CodingKeys: String, CodingKey {
        case finished, success, status
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isFinished = container.flexBool(.finished) ?? false
        wasSuccessful = container.flexBool(.success)
        status = container.flexString(.status)
    }
}
