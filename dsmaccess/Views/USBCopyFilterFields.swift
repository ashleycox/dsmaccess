//
//  USBCopyFilterFields.swift
//  dsmaccess
//

import SwiftUI

struct USBCopyFilterFields: View {
    @Binding var selection: USBCopyFilterSelection
    @State private var newRule = ""
    @State private var validationMessage: String?
    @AccessibilityFocusState private var validationFocused: Bool

    var body: some View {
        Toggle("Inclure les autres types de fichiers", isOn: $selection.includesOtherFiles)
            .help("Inclure tous les types qui ne figurent pas dans les catégories ci-dessous")

        ForEach(USBCopyFileCategory.allCases) { category in
            DisclosureGroup(category.localizedName) {
                VStack(alignment: .leading) {
                    Toggle("Tout inclure dans \(category.localizedName)", isOn: categoryBinding(category))
                    Divider()
                    ForEach(category.extensions.sorted(), id: \.self) { fileExtension in
                        Toggle("*.\(fileExtension)", isOn: extensionBinding(fileExtension))
                    }
                }
                .padding(.leading)
            }
        }

        GroupBox("Règles personnalisées") {
            VStack(alignment: .leading) {
                Text("Saisissez *.extension pour une extension, ou un nom de fichier exact.")
                    .foregroundStyle(.readableSecondary)
                HStack {
                    TextField("*.extension ou nom de fichier", text: $newRule)
                        .onSubmit(addRule)
                        .help("Nouvelle extension ou nouveau nom de fichier à inclure")
                    Button("Ajouter", action: addRule)
                        .disabled(trimmedRule.isEmpty)
                        .help("Ajouter cette règle personnalisée")
                }

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.readableRed)
                        .accessibilityFocused($validationFocused)
                }

                ForEach(selection.customExtensions, id: \.self) { fileExtension in
                    customRuleRow("*.\(fileExtension)") {
                        selection.customExtensions.removeAll { $0 == fileExtension }
                    }
                }
                ForEach(selection.customNames, id: \.self) { name in
                    customRuleRow(name) {
                        selection.customNames.removeAll { $0 == name }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func customRuleRow(_ rule: String, remove: @escaping () -> Void) -> some View {
        HStack {
            Text(rule)
            Spacer()
            Button("Retirer \(rule)", systemImage: "minus.circle", action: remove)
                .labelStyle(.iconOnly)
                .help(String(localized: "Retirer la règle \(rule)"))
        }
    }

    private func categoryBinding(_ category: USBCopyFileCategory) -> Binding<Bool> {
        Binding(
            get: { category.extensions.isSubset(of: selection.selectedExtensions) },
            set: { isSelected in
                if isSelected {
                    selection.selectedExtensions.formUnion(category.extensions)
                } else {
                    selection.selectedExtensions.subtract(category.extensions)
                }
            }
        )
    }

    private func extensionBinding(_ fileExtension: String) -> Binding<Bool> {
        Binding(
            get: { selection.selectedExtensions.contains(fileExtension) },
            set: { isSelected in
                if isSelected {
                    selection.selectedExtensions.insert(fileExtension)
                } else {
                    selection.selectedExtensions.remove(fileExtension)
                }
            }
        )
    }

    private var trimmedRule: String {
        newRule.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addRule() {
        let value = trimmedRule
        guard !value.isEmpty else { return }
        let forbidden = CharacterSet(charactersIn: ":?\"<>|\\/")
        guard value.rangeOfCharacter(from: forbidden) == nil else {
            showValidation(String(localized: "Cette règle contient un caractère non autorisé."))
            return
        }

        if value.hasPrefix("*.") {
            let fileExtension = String(value.dropFirst(2)).lowercased()
            guard !fileExtension.isEmpty, !fileExtension.contains("*") else {
                showValidation(String(localized: "Saisissez une extension après *."))
                return
            }
            if !selection.customExtensions.contains(fileExtension) {
                selection.customExtensions.append(fileExtension)
                selection.customExtensions.sort()
            }
        } else {
            guard !value.contains("*") else {
                showValidation(String(localized: "Utilisez *.extension pour filtrer une extension."))
                return
            }
            if !selection.customNames.contains(value) {
                selection.customNames.append(value)
                selection.customNames.sort()
            }
        }
        newRule = ""
        validationMessage = nil
    }

    private func showValidation(_ message: String) {
        validationMessage = message
        validationFocused = true
        VoiceOver.announce(message, category: .error, priority: .high)
    }
}
