//
//  PackagesViewModel.swift
//  dsmaccess
//
//  Charge et administre les paquets installés sur DSM.
//

import Foundation
import Observation

@MainActor
@Observable
final class PackagesViewModel {
    private(set) var packages: [PackageInfo] = []
    private(set) var availableUpdates: [String: PackageUpdate] = [:]
    private(set) var isLoading = false
    var errorMessage: String?
    private(set) var busy: Set<String> = []

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
        defer { if generation == loadGeneration { isLoading = false } }
        do {
            let result = try await session.withClient { client in
                let packages = try await client.listPackages().sorted {
                    $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
                }
                let updates: [String: PackageUpdate]
                do {
                    updates = try await client.availablePackageUpdates()
                } catch DSMError.sessionExpired {
                    throw DSMError.sessionExpired
                } catch {
                    updates = [:]
                }
                return (packages, updates)
            }
            guard generation == loadGeneration else { return }
            packages = result.0
            availableUpdates = result.1
        } catch {
            guard generation == loadGeneration, !DSMError.isCancellation(error) else { return }
            errorMessage = (error as? DSMError)?.errorDescription ?? error.localizedDescription
        }
    }

    func setRunning(_ package: PackageInfo, running: Bool) async -> DSMOperationOutcome {
        let id = package.pkgId
        busy.insert(id)
        defer { busy.remove(id) }
        do {
            try await session.withClient { try await $0.setPackageRunning(id: id, running: running) }
            await load()
            return .success(
                running
                    ? String(localized: "\(package.displayName) démarré")
                    : String(localized: "\(package.displayName) arrêté")
            )
        } catch {
            guard !DSMError.isCancellation(error) else { return .cancelled }
            let reason = (error as? DSMError)?.errorDescription ?? error.localizedDescription
            await load()
            return .failure(String(localized: "Échec pour \(package.displayName) : \(reason)"))
        }
    }

    func uninstall(_ package: PackageInfo) async -> DSMOperationOutcome {
        let id = package.pkgId
        busy.insert(id)
        defer { busy.remove(id) }
        do {
            try await session.withClient { try await $0.uninstallPackage(id: id) }
            await load()
            return .success(String(localized: "\(package.displayName) désinstallé"))
        } catch {
            guard !DSMError.isCancellation(error) else { return .cancelled }
            let reason = (error as? DSMError)?.errorDescription ?? error.localizedDescription
            await load()
            return .failure(
                String(localized: "Échec de la désinstallation de \(package.displayName) : \(reason)")
            )
        }
    }

    func applyUpdate(_ package: PackageInfo) async -> DSMOperationOutcome {
        guard let update = update(for: package) else {
            return .failure(
                String(localized: "Aucune mise à jour disponible pour \(package.displayName).")
            )
        }

        let id = package.pkgId
        busy.insert(id)
        defer { busy.remove(id) }
        do {
            try await session.withClient { try await $0.upgradePackage(update) }
            await load()
            return .success(String(localized: "\(package.displayName) mis à jour"))
        } catch {
            guard !DSMError.isCancellation(error) else { return .cancelled }
            let reason = (error as? DSMError)?.errorDescription ?? error.localizedDescription
            await load()
            return .failure(
                String(localized: "Échec de la mise à jour de \(package.displayName) : \(reason)")
            )
        }
    }

    func updateVersion(for package: PackageInfo) -> String? {
        update(for: package)?.version
    }

    func update(for package: PackageInfo) -> PackageUpdate? {
        let id = package.pkgId.lowercased()
        guard let candidate = availableUpdates[id],
              let installed = package.version,
              Self.isVersion(candidate.version, newerThan: installed) else { return nil }
        return candidate
    }

    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let a = versionComponents(candidate)
        let b = versionComponents(current)
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }

    private static func versionComponents(_ version: String) -> [Int] {
        version.split(whereSeparator: { $0 == "." || $0 == "-" }).map { Int($0) ?? 0 }
    }

    var updateCount: Int {
        packages.filter { updateVersion(for: $0) != nil }.count
    }

    var summary: String {
        if let errorMessage { return errorMessage }
        if !availableUpdates.isEmpty && updateCount > 0 {
            return String(localized: "\(packages.count) paquets, \(updateCount) mises à jour disponibles")
        }
        return String(localized: "\(packages.count) paquets installés")
    }
}
