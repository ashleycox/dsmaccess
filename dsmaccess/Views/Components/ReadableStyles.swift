//
//  ReadableColors.swift
//  dsmaccess
//
//  Couleurs de texte à contraste garanti. Les gris et couleurs d'état du
//  système échouent au seuil AA (4,5:1) sur les petits corps de texte que
//  l'app utilise pour les statuts et sous-titres ; ces variantes gardent la
//  hiérarchie visuelle et la sémantique tout en restant lisibles pour les
//  utilisateurs malvoyants, dans les deux apparences.
//

import AppKit
import SwiftUI

extension ShapeStyle where Self == Color {
    /// Remplace `.secondary` pour un texte porteur d'information.
    static var readableSecondary: Color { Color.primary.opacity(0.8) }

    static var readableGreen: Color { .readable(.systemGreen) }
    static var readableOrange: Color { .readable(.systemOrange) }
    static var readableRed: Color { .readable(.systemRed) }
}

/// Reproduit la disposition étiquette/valeur des listes en garantissant le
/// contraste des deux côtés, le style système rendant l'étiquette trop claire.
struct ReadableLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline) {
            configuration.label
            Spacer()
            configuration.content
                .foregroundStyle(.readableSecondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

extension LabeledContentStyle where Self == ReadableLabeledContentStyle {
    static var readable: ReadableLabeledContentStyle { ReadableLabeledContentStyle() }
}

private extension Color {
    static func readable(_ base: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let blend: NSColor? =
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? base.blended(withFraction: 0.25, of: .white)
                    : base.blended(withFraction: 0.35, of: .black)
            return blend ?? base
        })
    }
}
