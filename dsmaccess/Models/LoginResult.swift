//
//  LoginResult.swift
//  dsmaccess
//
//  Charge utile renvoyée par SYNO.API.Auth (method=login) en cas de succès.
//

import Foundation

/// Résultat d'un login réussi.
struct LoginResult: Decodable {
    /// Identifiant de session à joindre (`_sid=`) à toutes les requêtes suivantes.
    let sid: String
    /// Jeton d'appareil (device token) renvoyé quand on demande à « se souvenir de l'appareil ».
    /// Secret durable : à stocker au Trousseau, jamais en clair.
    let did: String?
    /// Jeton anti-CSRF optionnel.
    let synotoken: String?
}
