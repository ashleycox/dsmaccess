//
//  ConnectionViewModel.swift
//  dsmaccess
//
//  Machine à états de la connexion : saisie → tentative → (code 2FA si demandé) → connecté.
//  L'écran de code n'apparaît QUE si DSM renvoie « code requis » (erreur 403).
//

import Foundation
import Observation

@MainActor
@Observable
final class ConnectionViewModel {
    enum State: Equatable {
        case editing      // saisie des identifiants
        case connecting   // tentative en cours
        case needsOTP     // DSM réclame un code de vérification
    }

    // Champs du formulaire (pré-remplis depuis les préférences si disponibles).
    var host: String
    var useHTTPS: Bool
    var portText: String
    var account: String
    var password: String = ""
    var otpCode: String = ""
    var rememberDevice: Bool = true

    private(set) var state: State = .editing
    /// Message d'erreur à afficher et à annoncer (nil si aucun).
    var errorMessage: String?

    private let session: SessionStore
    private var client: DSMClient?
    private var pendingEndpoint: DSMEndpoint?

    // Clés de préférences (valeurs non secrètes uniquement).
    private static let hostKey = "lastHost"
    private static let portKey = "lastPort"
    private static let httpsKey = "lastUseHTTPS"
    private static let accountKey = "lastAccount"

    init(session: SessionStore) {
        self.session = session
        let defaults = UserDefaults.standard
        self.host = defaults.string(forKey: Self.hostKey) ?? ""
        self.account = defaults.string(forKey: Self.accountKey) ?? ""
        let https = defaults.object(forKey: Self.httpsKey) as? Bool ?? false
        self.useHTTPS = https
        if let savedPort = defaults.object(forKey: Self.portKey) as? Int {
            self.portText = String(savedPort)
        } else {
            self.portText = String(DSMEndpoint.defaultPort(useHTTPS: https))
        }
    }

    /// Port effectif (repli sur le port par défaut du schéma si la saisie est vide/invalide).
    var port: Int {
        Int(portText) ?? DSMEndpoint.defaultPort(useHTTPS: useHTTPS)
    }

    var canSubmit: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty
            && !account.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && state != .connecting
    }

    /// Ajuste le port par défaut quand on bascule HTTP/HTTPS, si l'utilisateur n'a pas
    /// saisi un port personnalisé.
    func syncDefaultPortIfNeeded() {
        let httpDefault = String(DSMEndpoint.defaultPort(useHTTPS: false))
        let httpsDefault = String(DSMEndpoint.defaultPort(useHTTPS: true))
        if portText == httpDefault || portText == httpsDefault || portText.isEmpty {
            portText = String(DSMEndpoint.defaultPort(useHTTPS: useHTTPS))
        }
    }

    // MARK: - Actions

    /// Première tentative : identifiants seuls (+ jeton d'appareil mémorisé si présent).
    func connect() async {
        let cleanedHost = host.trimmingCharacters(in: .whitespaces)
        let cleanedAccount = account.trimmingCharacters(in: .whitespaces)
        guard !cleanedHost.isEmpty, !cleanedAccount.isEmpty, !password.isEmpty else {
            errorMessage = String(localized: "Veuillez renseigner l'adresse, le nom d'utilisateur et le mot de passe.")
            return
        }

        let endpoint = DSMEndpoint(useHTTPS: useHTTPS, host: cleanedHost, port: port)
        let client = DSMClient(endpoint: endpoint)
        self.client = client
        self.pendingEndpoint = endpoint

        state = .connecting
        errorMessage = nil

        let deviceID = KeychainStore.load(service: KeychainStore.deviceTokenService, account: keychainKey(cleanedAccount, endpoint))

        do {
            let result = try await client.login(
                account: cleanedAccount, password: password,
                otpCode: nil, deviceID: deviceID, rememberDevice: false
            )
            finish(with: result, account: cleanedAccount, endpoint: endpoint)
        } catch DSMError.needsOTP {
            state = .needsOTP
            errorMessage = nil
        } catch {
            state = .editing
            errorMessage = (error as? DSMError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Soumission du code de vérification après un 403.
    func submitOTP() async {
        guard let client, let endpoint = pendingEndpoint else { return }
        let cleanedAccount = account.trimmingCharacters(in: .whitespaces)
        guard !otpCode.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = String(localized: "Saisissez le code de vérification.")
            return
        }

        state = .connecting
        errorMessage = nil

        do {
            let result = try await client.login(
                account: cleanedAccount, password: password,
                otpCode: otpCode.trimmingCharacters(in: .whitespaces),
                deviceID: nil, rememberDevice: rememberDevice
            )
            finish(with: result, account: cleanedAccount, endpoint: endpoint)
        } catch DSMError.badOTP {
            state = .needsOTP
            otpCode = ""
            errorMessage = DSMError.badOTP.errorDescription
        } catch {
            state = .needsOTP
            errorMessage = (error as? DSMError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Annule la saisie du code et revient au formulaire d'identifiants.
    func cancelOTP() {
        state = .editing
        otpCode = ""
        errorMessage = nil
    }

    // MARK: - Interne

    private func finish(with result: LoginResult, account: String, endpoint: DSMEndpoint) {
        guard let client else { return }
        if rememberDevice, let did = result.did, !did.isEmpty {
            KeychainStore.save(did, service: KeychainStore.deviceTokenService, account: keychainKey(account, endpoint))
        }
        persistPreferences(account: account, endpoint: endpoint)
        session.establish(endpoint: endpoint, sid: result.sid, client: client)
        // RootView bascule automatiquement vers l'écran de contenu.
        state = .editing
        errorMessage = nil
        password = ""
        otpCode = ""
    }

    private func keychainKey(_ account: String, _ endpoint: DSMEndpoint) -> String {
        "\(account)@\(endpoint.host):\(endpoint.port)"
    }

    private func persistPreferences(account: String, endpoint: DSMEndpoint) {
        let defaults = UserDefaults.standard
        defaults.set(endpoint.host, forKey: Self.hostKey)
        defaults.set(endpoint.port, forKey: Self.portKey)
        defaults.set(endpoint.useHTTPS, forKey: Self.httpsKey)
        defaults.set(account, forKey: Self.accountKey)
    }
}
