import Foundation
import Testing

/// Le repli de langue de l'app repose sur deux invariants faciles à casser en silence :
/// la langue de développement doit rester l'anglais (un système ni français ni anglais
/// reçoit l'anglais), et chaque clé du catalogue doit porter une entrée française
/// explicite, sinon la chaîne fuit en anglais pour les utilisateurs francophones
/// (le français n'est plus servi par retour de clé depuis qu'un fr.lproj existe).
struct LocalizationCatalogTests {
    private static func loadCatalog() throws -> [String: [String: Any]] {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dsmaccess/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        return try #require(root["strings"] as? [String: [String: Any]])
    }

    private static func stringUnit(
        _ entry: [String: Any], language: String
    ) -> [String: Any]? {
        let localizations = entry["localizations"] as? [String: Any]
        let localization = localizations?[language] as? [String: Any]
        return localization?["stringUnit"] as? [String: Any]
    }

    @Test("Chaque clé traduisible a des entrées française et anglaise complètes")
    func catalogCoversFrenchAndEnglish() throws {
        let strings = try Self.loadCatalog()
        var missing: [String] = []
        for (key, entry) in strings {
            if entry["shouldTranslate"] as? Bool == false { continue }
            for language in ["fr", "en"] {
                guard let unit = Self.stringUnit(entry, language: language),
                      unit["state"] as? String == "translated",
                      let value = unit["value"] as? String,
                      !value.isEmpty
                else {
                    missing.append("\(language) : \(key)")
                    continue
                }
            }
        }
        #expect(
            missing.isEmpty,
            "Entrées absentes ou non traduites : \(missing.sorted().joined(separator: " | "))"
        )
    }

    @Test("L'app se replie sur l'anglais et déclare le français")
    func bundleFallsBackToEnglish() {
        let bundle = Bundle.main
        #expect(bundle.developmentLocalization == "en")
        #expect(bundle.localizations.contains("fr"))
        #expect(bundle.localizations.contains("en"))
    }
}
