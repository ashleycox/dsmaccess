//
//  DSMOperationOutcome.swift
//  dsmaccess
//
//  Résultat d'une action utilisateur envoyée au NAS.
//

import Foundation

enum DSMOperationOutcome: Equatable, Sendable {
    case success(String)
    case failure(String)
    case cancelled
}
