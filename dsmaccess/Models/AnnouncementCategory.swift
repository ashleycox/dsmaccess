//
//  AnnouncementCategory.swift
//  dsmaccess
//
//  Catégories d'annonces configurables dans les réglages d'accessibilité.
//

import Foundation

enum AnnouncementCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case navigation
    case progress
    case result
    case error
    case automaticRefresh

    var id: Self { self }

    var title: String {
        switch self {
        case .navigation: String(localized: "Navigation et changements d’écran")
        case .progress: String(localized: "Chargements et opérations en cours")
        case .result: String(localized: "Résultats et opérations terminées")
        case .error: String(localized: "Erreurs")
        case .automaticRefresh: String(localized: "Actualisation automatique")
        }
    }

    var detail: String {
        switch self {
        case .navigation: String(localized: "Annonce la connexion, le module sélectionné et les changements de dossier.")
        case .progress: String(localized: "Annonce le début des chargements, recherches et opérations longues.")
        case .result: String(localized: "Annonce les résumés de contenu et le résultat des actions.")
        case .error: String(localized: "Annonce les erreurs de connexion, de chargement et d’opération.")
        case .automaticRefresh: String(localized: "Annonce l’activation ou la désactivation des actualisations automatiques.")
        }
    }
}
