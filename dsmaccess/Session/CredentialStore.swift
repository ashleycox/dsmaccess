//
//  CredentialStore.swift
//  dsmaccess
//
//  Mémorisation du mot de passe pour la reconnexion automatique (« Rester connecté »).
//  Le mot de passe dort dans le Trousseau (chiffré) ; un indicateur non secret
//  (`Preferences.rememberPassword`) dit si l'option est active. Les mots de passe et
//  jetons d'appareil sont séparés par compte, schéma, hôte et port.
//

import Foundation

enum CredentialStore {
    private static func legacyKey(account: String, endpoint: DSMEndpoint) -> String {
        "\(account)@\(endpoint.host):\(endpoint.port)"
    }

    /// Mémorise le mot de passe et active la reconnexion automatique.
    @discardableResult
    static func remember(password: String, account: String, endpoint: DSMEndpoint) -> Bool {
        let saved = save(password, service: KeychainStore.passwordService,
                         account: account, endpoint: endpoint)
        Preferences.rememberPassword = saved
        return saved
    }

    /// Lit le mot de passe mémorisé pour ce NAS (nil si aucun).
    static func password(account: String, endpoint: DSMEndpoint) -> String? {
        load(service: KeychainStore.passwordService, account: account, endpoint: endpoint)
    }

    /// Oublie le mot de passe et désactive la reconnexion automatique.
    static func forget(account: String, endpoint: DSMEndpoint) {
        delete(service: KeychainStore.passwordService, account: account, endpoint: endpoint)
        Preferences.rememberPassword = false
    }

    static func deviceID(account: String, endpoint: DSMEndpoint) -> String? {
        load(service: KeychainStore.deviceTokenService, account: account, endpoint: endpoint)
    }

    @discardableResult
    static func remember(deviceID: String, account: String, endpoint: DSMEndpoint) -> Bool {
        save(deviceID, service: KeychainStore.deviceTokenService,
             account: account, endpoint: endpoint)
    }

    private static func save(
        _ value: String,
        service: String,
        account: String,
        endpoint: DSMEndpoint
    ) -> Bool {
        let saved = KeychainStore.save(
            value,
            service: service,
            account: endpoint.credentialStoreKey(account: account)
        )
        if saved, endpoint.useHTTPS {
            KeychainStore.delete(
                service: service,
                account: legacyKey(account: account, endpoint: endpoint)
            )
        }
        return saved
    }

    private static func load(
        service: String,
        account: String,
        endpoint: DSMEndpoint
    ) -> String? {
        let key = endpoint.credentialStoreKey(account: account)
        if let value = KeychainStore.load(service: service, account: key) {
            return value
        }

        // Les anciennes clés n'indiquaient pas le schéma. Elles ne sont migrées que
        // vers HTTPS afin qu'un secret existant ne puisse pas être repris en HTTP.
        guard endpoint.useHTTPS,
              let value = KeychainStore.load(
                  service: service,
                  account: legacyKey(account: account, endpoint: endpoint)
              ) else { return nil }
        if KeychainStore.save(value, service: service, account: key) {
            KeychainStore.delete(
                service: service,
                account: legacyKey(account: account, endpoint: endpoint)
            )
        }
        return value
    }

    private static func delete(
        service: String,
        account: String,
        endpoint: DSMEndpoint
    ) {
        KeychainStore.delete(
            service: service,
            account: endpoint.credentialStoreKey(account: account)
        )
        if endpoint.useHTTPS {
            KeychainStore.delete(
                service: service,
                account: legacyKey(account: account, endpoint: endpoint)
            )
        }
    }
}
