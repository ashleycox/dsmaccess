//
//  LogsSecurityViewModel.swift
//  dsmaccess
//
//  État des journaux DSM et de la liste de blocage.
//

import Foundation
import Observation

@MainActor
@Observable
final class LogsSecurityViewModel {
    private(set) var logs: [SystemLogEntry] = []
    private(set) var blockedAddresses: [BlockedAddress] = []
    private(set) var isLoading = false
    private(set) var busyAddresses: Set<String> = []
    var errorMessage: String?
    var blockedAddressesError: String?

    private let session: SessionStore
    private var loadGeneration = 0

    init(session: SessionStore) {
        self.session = session
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        blockedAddressesError = nil
        defer { if generation == loadGeneration { isLoading = false } }
        let supportsLogs = session.capabilities.supports("SYNO.Core.SyslogClient.Log")

        do {
            let result = try await session.withClient { client in
                let logs = supportsLogs ? try await client.listSystemLogs() : []
                let blockedAddresses: [BlockedAddress]
                let blockedAddressesError: String?

                do {
                    blockedAddresses = try await client.listBlockedAddresses().sorted {
                        $0.address.localizedStandardCompare($1.address) == .orderedAscending
                    }
                    blockedAddressesError = nil
                } catch let error as DSMError where isOptionalBlockListError(error) {
                    blockedAddresses = []
                    blockedAddressesError = nil
                } catch DSMError.sessionExpired {
                    throw DSMError.sessionExpired
                } catch {
                    blockedAddresses = []
                    blockedAddressesError = (error as? DSMError)?.errorDescription ?? error.localizedDescription
                }
                return (logs, blockedAddresses, blockedAddressesError)
            }
            guard generation == loadGeneration else { return }
            logs = result.0
            blockedAddresses = result.1
            blockedAddressesError = result.2
        } catch {
            guard generation == loadGeneration, !DSMError.isCancellation(error) else { return }
            errorMessage = (error as? DSMError)?.errorDescription ?? error.localizedDescription
        }
    }

    func unblock(_ blockedAddress: BlockedAddress) async -> DSMOperationOutcome {
        busyAddresses.insert(blockedAddress.address)
        defer { busyAddresses.remove(blockedAddress.address) }

        do {
            try await session.withClient { try await $0.unblockAddress(blockedAddress.address) }
            blockedAddresses.removeAll { $0.id == blockedAddress.id }
            return .success(String(localized: "Adresse débloquée : \(blockedAddress.address)"))
        } catch {
            guard !DSMError.isCancellation(error) else { return .cancelled }
            let reason = (error as? DSMError)?.errorDescription ?? error.localizedDescription
            return .failure(String(localized: "Échec du déblocage : \(reason)"))
        }
    }

    var summary: String {
        if let errorMessage { return errorMessage }
        return String(localized: "\(logs.count) entrées de journal, \(blockedAddresses.count) adresses bloquées")
    }

    private func isOptionalBlockListError(_ error: DSMError) -> Bool {
        switch error {
        case .unsupportedAPI, .unsupportedAPIVersion: true
        default: false
        }
    }
}
