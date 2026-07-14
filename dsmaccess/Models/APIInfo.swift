//
//  APIInfo.swift
//  dsmaccess
//
//  Réponse de SYNO.API.Info : pour chaque API demandée, le chemin CGI réel et la
//  fourchette de versions supportées. On ne code JAMAIS les chemins en dur car ils
//  varient selon la version de DSM.
//

import Foundation

/// Détail d'une API renvoyé par SYNO.API.Info (chemin CGI relatif à /webapi/).
struct APIInfoEntry: Decodable, Equatable, Sendable {
    let path: String
    let minVersion: Int
    let maxVersion: Int
    let requestFormat: String?

    init(path: String, minVersion: Int, maxVersion: Int, requestFormat: String? = nil) {
        self.path = path
        self.minVersion = minVersion
        self.maxVersion = maxVersion
        self.requestFormat = requestFormat
    }
}
