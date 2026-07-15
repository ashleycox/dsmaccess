//
//  PackageSettings.swift
//  dsmaccess
//
//  Réponse de SYNO.Core.Package.Setting (method=get) : préférences globales du Centre de
//  paquets. API NON documentée. Particularité confirmée : `update_channel` est un booléen en
//  lecture mais s'écrit en chaîne ("stable"/"beta"). On garde tous les champs (même ceux non
//  exposés dans l'UI, comme default_vol/trust_level) pour les *préserver* à l'écriture : le
//  `set` de l'API attend l'objet complet.
//

import Foundation

struct PackageSettings: nonisolated Decodable, Equatable, Sendable {
    var enableAutoupdate: Bool
    var autoupdateAll: Bool
    var autoupdateImportant: Bool
    var enableDsm: Bool
    var enableEmail: Bool
    var defaultVol: String
    var trustLevel: Int
    /// Canal beta : true = versions beta affichées. Envoyé en "beta"/"stable" à l'écriture.
    var updateChannelBeta: Bool

    enum CodingKeys: String, CodingKey {
        case enableAutoupdate = "enable_autoupdate"
        case autoupdateAll = "autoupdateall"
        case autoupdateImportant = "autoupdateimportant"
        case enableDsm = "enable_dsm"
        case enableEmail = "enable_email"
        case defaultVol = "default_vol"
        case trustLevel = "trust_level"
        case updateChannelBeta = "update_channel"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enableAutoupdate = try c.requiredFlexBool(.enableAutoupdate)
        autoupdateAll = try c.requiredFlexBool(.autoupdateAll)
        autoupdateImportant = try c.requiredFlexBool(.autoupdateImportant)
        enableDsm = try c.requiredFlexBool(.enableDsm)
        enableEmail = try c.requiredFlexBool(.enableEmail)
        defaultVol = try c.requiredFlexString(.defaultVol)
        trustLevel = try c.requiredFlexInt(.trustLevel)
        // update_channel : booléen en lecture, mais on tolère une chaîne ("beta"/"stable").
        if let b = try? c.decode(Bool.self, forKey: .updateChannelBeta) {
            updateChannelBeta = b
        } else if let s = try? c.decode(String.self, forKey: .updateChannelBeta) {
            updateChannelBeta = s.lowercased() == "beta"
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .updateChannelBeta,
                in: c,
                debugDescription: "Required package update channel is missing or malformed."
            )
        }
    }
}

/// Stratégie de mise à jour automatique, dérivée des trois champs bruts de l'API.
enum AutoUpdateMode: CaseIterable, Identifiable, Sendable {
    case off        // désactivée
    case important  // versions importantes (sécurité)
    case latest     // dernières versions
    var id: Self { self }
}

extension PackageSettings {
    /// Mode courant, calculé depuis enable_autoupdate + autoupdateall.
    var autoUpdateMode: AutoUpdateMode {
        guard enableAutoupdate else { return .off }
        return autoupdateAll ? .latest : .important
    }

    /// Applique un mode aux trois champs bruts.
    mutating func setAutoUpdateMode(_ mode: AutoUpdateMode) {
        switch mode {
        case .off:
            enableAutoupdate = false
        case .important:
            enableAutoupdate = true
            autoupdateAll = false
            autoupdateImportant = true
        case .latest:
            enableAutoupdate = true
            autoupdateAll = true
            autoupdateImportant = true
        }
    }
}
