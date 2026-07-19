//
//  PackageSource.swift
//  dsmaccess
//
//  Source de paquets tierce configurée dans le Centre de paquets DSM.
//

import Foundation

struct PackageSourceList: nonisolated Decodable, Sendable {
    let items: [PackageSource]
}

struct PackageSource: nonisolated Codable, Equatable, Identifiable, Sendable {
    var name: String
    var feed: String

    var id: String { feed }
}
