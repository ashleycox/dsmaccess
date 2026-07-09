//
//  ShareLinkSheet.swift
//  dsmaccess
//
//  Feuille affichée après création d'un lien de partage : montre l'URL (lisible et
//  sélectionnable), la copie automatiquement dans le presse-papier macOS, et permet de la
//  recopier. Accessible : focus sur l'URL + annonce à l'ouverture.
//

import AppKit
import SwiftUI

struct ShareLinkSheet: View {
    let url: String
    @AccessibilityFocusState private var focusURL: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Lien de partage")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text(url)
                .textSelection(.enabled)
                .font(.body.monospaced())
                .lineLimit(3)
                .truncationMode(.middle)
                .accessibilityLabel(url)
                .accessibilityFocused($focusURL)

            HStack {
                Spacer()
                Button("Fermer", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Copier le lien") { copyToClipboard() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            copyToClipboard(announce: false)   // déjà copié : on l'annonce dans le message global
            focusURL = true
            VoiceOver.announce(String(localized: "Lien de partage créé et copié"))
        }
    }

    private func copyToClipboard(announce: Bool = true) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        if announce {
            VoiceOver.announce(String(localized: "Lien copié"))
        }
    }
}
