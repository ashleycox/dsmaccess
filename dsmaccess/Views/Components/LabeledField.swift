//
//  LabeledField.swift
//  dsmaccess
//
//  Champ de saisie avec libellé visible au-dessus. Le libellé décoratif est masqué
//  à VoiceOver (le champ porte lui-même le libellé d'accessibilité), pour éviter une
//  double lecture.
//

import SwiftUI

struct LabeledField<Content: View>: View {
    // LocalizedStringKey pour que le libellé (affiché ET utilisé comme label
    // d'accessibilité) soit traduit automatiquement via le String Catalog.
    let label: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            content
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(label)
        }
    }
}
