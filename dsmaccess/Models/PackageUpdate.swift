//
//  PackageUpdate.swift
//  dsmaccess
//
//  Métadonnées nécessaires à la mise à jour d'un paquet officiel.
//

import Foundation

struct PackageUpdate: Equatable, Sendable {
    let packageID: String
    let version: String
    let downloadURL: URL
    let checksum: String
    let fileSize: Int
    let isBeta: Bool
    let packageType: Int
}
