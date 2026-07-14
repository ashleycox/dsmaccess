//
//  ControlPanelSection.swift
//  dsmaccess
//
//  Sections disponibles dans le Panneau de configuration.
//

import SwiftUI

enum ControlPanelSection: Hashable, CaseIterable, Identifiable {
    case network

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .network: "Réseau et identité"
        }
    }

    var localizedTitle: String {
        switch self {
        case .network: String(localized: "Réseau et identité")
        }
    }

    var systemImage: String {
        switch self {
        case .network: "network"
        }
    }

    var hint: LocalizedStringKey {
        switch self {
        case .network: "Nom du serveur, adresse IP, passerelle et DNS"
        }
    }
}
