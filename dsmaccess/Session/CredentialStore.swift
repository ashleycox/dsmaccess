//
//  CredentialStore.swift
//  dsmaccess
//
//  Mémorisation du mot de passe pour la reconnexion automatique (« Rester connecté »).
//  Le mot de passe dort dans le Trousseau (chiffré) ; un indicateur non secret
//  (`Preferences.rememberPassword`) dit si l'option est active. Une seule clé par NAS
//  (compte@hôte:port), même convention que le jeton d'appareil. Partagé par le formulaire
//  de connexion (mémoriser) et la déconnexion (oublier).
//

import Foundation

enum CredentialStore {
    /// Clé de trousseau propre à un couple compte + NAS.
    private static func key(account: String, endpoint: DSMEndpoint) -> String {
        "\(account)@\(endpoint.host):\(endpoint.port)"
    }

    /// Mémorise le mot de passe et active la reconnexion automatique.
    static func remember(password: String, account: String, endpoint: DSMEndpoint) {
        KeychainStore.save(password,
                           service: KeychainStore.passwordService,
                           account: key(account: account, endpoint: endpoint))
        Preferences.rememberPassword = true
    }

    /// Lit le mot de passe mémorisé pour ce NAS (nil si aucun).
    static func password(account: String, endpoint: DSMEndpoint) -> String? {
        KeychainStore.load(service: KeychainStore.passwordService,
                           account: key(account: account, endpoint: endpoint))
    }

    /// Oublie le mot de passe et désactive la reconnexion automatique.
    static func forget(account: String, endpoint: DSMEndpoint) {
        KeychainStore.delete(service: KeychainStore.passwordService,
                             account: key(account: account, endpoint: endpoint))
        Preferences.rememberPassword = false
    }
}
