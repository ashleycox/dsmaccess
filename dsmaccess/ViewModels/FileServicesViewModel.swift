//
//  FileServicesViewModel.swift
//  dsmaccess
//
//  Charge l'état des services de fichiers (SMB, NFS, FTP) et pilote leur
//  activation/désactivation. Chaque service est interrogé indépendamment : si l'un
//  échoue, les autres restent utilisables. Les actions renvoient un message déjà
//  localisé à annoncer à VoiceOver.
//

import Foundation
import Observation

/// État affiché d'un service de fichiers.
enum FileServiceState: Equatable {
    case on
    case off
    case unknown          // drapeau absent de la réponse (nom d'API/champ à confirmer)
    case failed(String)   // erreur réseau ou API
}

@MainActor
@Observable
final class FileServicesViewModel {
    /// Services affichés, dans l'ordre.
    let services = FileService.allCases
    private(set) var states: [FileService: FileServiceState] = [:]
    private(set) var isLoading = false
    /// Services dont une bascule est en cours (bouton désactivé le temps de l'appel).
    private(set) var busy: Set<FileService> = []

    private let session: SessionStore

    init(session: SessionStore) {
        self.session = session
    }

    func load() async {
        guard let client = session.client, let sid = session.sid else {
            session.clear()
            return
        }
        isLoading = true
        for service in services {
            states[service] = await fetch(service, client: client, sid: sid)
        }
        isLoading = false
    }

    /// Bascule un service. Renvoie le message à annoncer à VoiceOver.
    func setEnabled(_ service: FileService, _ enabled: Bool) async -> String {
        guard let client = session.client, let sid = session.sid else {
            return String(localized: "Session expirée.")
        }
        busy.insert(service)
        defer { busy.remove(service) }
        do {
            try await client.setFileService(service, enabled: enabled, sid: sid)
            states[service] = await fetch(service, client: client, sid: sid)
            return enabled
                ? String(localized: "\(service.displayName) activé")
                : String(localized: "\(service.displayName) désactivé")
        } catch {
            let reason = (error as? DSMError)?.errorDescription ?? error.localizedDescription
            states[service] = await fetch(service, client: client, sid: sid)
            return String(localized: "Échec pour \(service.displayName) : \(reason)")
        }
    }

    /// Résumé annoncé une fois le chargement terminé.
    var summary: String {
        let on = states.values.filter { $0 == .on }.count
        return String(localized: "Services de fichiers : \(on) activés sur \(services.count)")
    }

    private func fetch(_ service: FileService, client: DSMClientProtocol, sid: String) async -> FileServiceState {
        do {
            switch try await client.fileServiceEnabled(service, sid: sid) {
            case true?: return .on
            case false?: return .off
            case nil: return .unknown
            }
        } catch {
            return .failed((error as? DSMError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
