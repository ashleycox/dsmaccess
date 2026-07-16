//
//  PackageInstallStatus.swift
//  dsmaccess
//
//  État d'une installation suivie par le Centre de paquets.
//

import Foundation

struct PackageInstallStatus: nonisolated Decodable, Sendable {
    let isFinished: Bool

    private enum CodingKeys: String, CodingKey {
        case finished
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isFinished = container.flexBool(.finished) ?? false
    }
}
