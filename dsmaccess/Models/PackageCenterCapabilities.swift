//
//  PackageCenterCapabilities.swift
//  dsmaccess
//
//  Capacités réellement annoncées par SYNO.API.Info pour le Centre de paquets.
//

import Foundation

struct PackageCenterCapabilities: Equatable, Sendable {
    let canListInstalledPackages: Bool
    let canBrowseCatalog: Bool
    let canInstallCatalogPackages: Bool
    let canInstallManualPackages: Bool
    let canInstallVerifiedUpdates: Bool
    let canRepairPackages: Bool
    let canControlPackages: Bool
    let canUninstallPackages: Bool
    let canManageSettings: Bool
    let canManagePackageSources: Bool
    let maximumVersions: [String: Int]
}

struct PackageOperationProgress: Equatable, Sendable {
    let taskID: String
    let statusChecks: Int
    let isFinished: Bool
}
