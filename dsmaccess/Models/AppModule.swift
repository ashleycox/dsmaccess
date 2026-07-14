//
//  AppModule.swift
//  dsmaccess
//
//  Navigation principale de l'application.
//

import SwiftUI

enum AppModuleSection: String, CaseIterable, Identifiable {
    case overview
    case files
    case administration
    case applications

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .overview: "Vue d’ensemble"
        case .files: "Fichiers et partage"
        case .administration: "Administration"
        case .applications: "Applications"
        }
    }
}

struct AppModuleShortcut {
    let key: KeyEquivalent
    let modifiers: EventModifiers
}

enum AppModule: String, CaseIterable, Identifiable {
    case systemInfo
    case storage
    case logsSecurity
    case files
    case shares
    case downloads
    case usersGroups
    case fileServices
    case packages
    case containers
    case virtualMachines
    case surveillance

    var id: Self { self }

    var section: AppModuleSection {
        switch self {
        case .systemInfo, .storage, .logsSecurity: .overview
        case .files, .shares, .downloads: .files
        case .usersGroups, .fileServices, .packages: .administration
        case .containers, .virtualMachines, .surveillance: .applications
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .systemInfo: "Votre NAS"
        case .storage: "Stockage"
        case .logsSecurity: "Journaux et sécurité"
        case .files: "Fichiers"
        case .shares: "Dossiers partagés"
        case .downloads: "Download Station"
        case .usersGroups: "Utilisateurs et groupes"
        case .fileServices: "Services de fichiers"
        case .packages: "Centre de paquets"
        case .containers: "Conteneurs"
        case .virtualMachines: "Machines virtuelles"
        case .surveillance: "Surveillance Station"
        }
    }

    var systemImage: String {
        switch self {
        case .systemInfo: "server.rack"
        case .storage: "internaldrive"
        case .logsSecurity: "lock.shield"
        case .files: "folder"
        case .shares: "externaldrive.badge.person.crop"
        case .downloads: "arrow.down.circle"
        case .usersGroups: "person.2"
        case .fileServices: "network"
        case .packages: "shippingbox"
        case .containers: "shippingbox.fill"
        case .virtualMachines: "desktopcomputer"
        case .surveillance: "video"
        }
    }

    var keyboardShortcut: AppModuleShortcut {
        switch self {
        case .systemInfo: AppModuleShortcut(key: "1", modifiers: .command)
        case .storage: AppModuleShortcut(key: "2", modifiers: .command)
        case .logsSecurity: AppModuleShortcut(key: "3", modifiers: .command)
        case .files: AppModuleShortcut(key: "4", modifiers: .command)
        case .shares: AppModuleShortcut(key: "5", modifiers: .command)
        case .downloads: AppModuleShortcut(key: "6", modifiers: .command)
        case .usersGroups: AppModuleShortcut(key: "7", modifiers: .command)
        case .fileServices: AppModuleShortcut(key: "8", modifiers: .command)
        case .packages: AppModuleShortcut(key: "9", modifiers: .command)
        case .containers: AppModuleShortcut(key: "0", modifiers: .command)
        case .virtualMachines: AppModuleShortcut(key: "1", modifiers: [.command, .shift])
        case .surveillance: AppModuleShortcut(key: "2", modifiers: [.command, .shift])
        }
    }

    func isAvailable(in capabilities: DSMCapabilities) -> Bool {
        switch self {
        case .systemInfo, .storage, .files, .shares, .fileServices, .packages:
            true
        case .logsSecurity:
            capabilities.supports("SYNO.Core.SyslogClient.Log")
                || capabilities.supports(prefix: "SYNO.Core.Security")
                || capabilities.supports(prefix: "SYNO.Core.SmartBlock")
        case .downloads:
            capabilities.supports("SYNO.DownloadStation.Task")
        case .usersGroups:
            capabilities.supports("SYNO.Core.User") && capabilities.supports("SYNO.Core.Group")
        case .containers:
            capabilities.supports("SYNO.Docker.Container")
        case .virtualMachines:
            capabilities.supports("SYNO.Virtualization.API.Guest")
                && capabilities.supports("SYNO.Virtualization.API.Guest.Action")
        case .surveillance:
            capabilities.supports("SYNO.SurveillanceStation.Camera")
        }
    }

    var unavailableHelp: LocalizedStringKey {
        switch self {
        case .downloads: "Download Station n’est pas installé ou son API n’est pas disponible."
        case .containers: "Container Manager n’est pas installé ou son API n’est pas disponible."
        case .virtualMachines: "Virtual Machine Manager n’est pas installé ou son API n’est pas disponible."
        case .surveillance: "Surveillance Station n’est pas installé ou son API n’est pas disponible."
        case .usersGroups: "L’administration des utilisateurs et groupes n’est pas exposée par ce NAS."
        case .logsSecurity: "Les interfaces de journalisation et de sécurité ne sont pas exposées par ce NAS."
        default: "Ce module n’est pas disponible sur ce NAS."
        }
    }
}

extension AppModuleSection {
    var modules: [AppModule] {
        AppModule.allCases.filter { $0.section == self }
    }
}
