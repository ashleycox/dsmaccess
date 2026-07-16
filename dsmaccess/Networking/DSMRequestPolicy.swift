//
//  DSMRequestPolicy.swift
//  dsmaccess
//
//  Politique de nouvelle tentative des requêtes DSM.
//

enum DSMRequestPolicy: Equatable, Sendable {
    case singleAttempt
    case idempotent
}
