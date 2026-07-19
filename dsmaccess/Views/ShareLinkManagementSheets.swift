//
//  ShareLinkManagementSheets.swift
//  dsmaccess
//
//  Détails et modification d’un lien de partage File Station.
//

import AppKit
import SwiftUI

struct ShareLinkEditorSheet: View {
    let link: SharingLink
    let save: (FileStationShareLinkChanges) async -> DSMOperationOutcome

    @Environment(\.dismiss) private var dismiss
    @State private var editsPassword = false
    @State private var password = ""
    @State private var editsAvailableDate = false
    @State private var hasAvailableDate: Bool
    @State private var availableDate: Date
    @State private var editsExpirationDate = false
    @State private var hasExpirationDate: Bool
    @State private var expirationDate: Date
    @State private var isSaving = false
    @State private var errorMessage: String?
    @AccessibilityFocusState private var focusHeading: Bool
    @AccessibilityFocusState private var focusError: Bool

    init(
        link: SharingLink,
        save: @escaping (FileStationShareLinkChanges) async -> DSMOperationOutcome
    ) {
        self.link = link
        self.save = save
        let available = sharingDate(link.availableDate)
        let expiration = sharingDate(link.expirationDate)
        _hasAvailableDate = State(initialValue: available != nil)
        _availableDate = State(initialValue: available ?? .now)
        _hasExpirationDate = State(initialValue: expiration != nil)
        _expirationDate = State(
            initialValue: expiration ?? Date.now.addingTimeInterval(604_800)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Modifier le lien de partage")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusHeading)

            Divider()

            Form {
                Section("Lien") {
                    LabeledContent("Élément", value: link.name ?? link.path ?? link.url)
                }

                Section("Mot de passe") {
                    Toggle("Modifier le mot de passe", isOn: $editsPassword)
                    if editsPassword {
                        SecureField("Nouveau mot de passe", text: $password)
                        Text("Laissez le champ vide pour supprimer le mot de passe.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Disponibilité") {
                    Toggle("Modifier la date de disponibilité", isOn: $editsAvailableDate)
                    if editsAvailableDate {
                        Toggle("Disponible à partir d’une date", isOn: $hasAvailableDate)
                        if hasAvailableDate {
                            DatePicker("Date de disponibilité", selection: $availableDate)
                        }
                    }
                }

                Section("Expiration") {
                    Toggle("Modifier la date d’expiration", isOn: $editsExpirationDate)
                    if editsExpirationDate {
                        Toggle("Le lien expire à une date", isOn: $hasExpirationDate)
                        if hasExpirationDate {
                            DatePicker("Date d’expiration", selection: $expirationDate)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .accessibilityFocused($focusError)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Annuler", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isSaving)
                Spacer()
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Modification du lien en cours…")
                }
                Button("Enregistrer") { Task { await submit() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSaving || !hasChanges)
            }
            .padding()
        }
        .frame(width: 560, height: 600)
        .onAppear {
            focusHeading = true
            VoiceOver.announce("Modifier le lien de partage", category: .navigation)
        }
    }

    private var hasChanges: Bool {
        editsPassword || editsAvailableDate || editsExpirationDate
    }

    private func submit() async {
        let resultingAvailableDate = editsAvailableDate
            ? (hasAvailableDate ? availableDate : nil)
            : sharingDate(link.availableDate)
        let resultingExpirationDate = editsExpirationDate
            ? (hasExpirationDate ? expirationDate : nil)
            : sharingDate(link.expirationDate)
        if let resultingAvailableDate, let resultingExpirationDate,
           resultingAvailableDate > resultingExpirationDate {
            showError(
                String(localized: "La date de disponibilité doit précéder la date d’expiration.")
            )
            return
        }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        let changes = FileStationShareLinkChanges(
            password: editsPassword ? password : nil,
            expirationDate: editsExpirationDate
                ? (hasExpirationDate ? sharingDateString(expirationDate) : "0")
                : nil,
            availableDate: editsAvailableDate
                ? (hasAvailableDate ? sharingDateString(availableDate) : "0")
                : nil
        )
        let outcome = await save(changes)
        switch outcome {
        case .success:
            VoiceOver.announce(outcome, priority: .high)
            dismiss()
        case .failure(let message):
            showError(message)
        case .cancelled:
            break
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        focusError = true
        VoiceOver.announce(message, category: .error, priority: .high)
    }
}

struct ShareLinkDetailsSheet: View {
    @Bindable var vm: FileBrowserViewModel
    let link: SharingLink

    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var focusHeading: Bool
    @AccessibilityFocusState private var focusError: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text("Détails du lien de partage")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusHeading)

            Divider()

            content

            Divider()

            HStack {
                Button("Copier le lien") { copy(details.url) }
                Spacer()
                Button("Fermer", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 580, height: 590)
        .task { await load() }
        .onDisappear { vm.clearShareLinkDetails() }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoadingShareLinkDetails && vm.shareLinkDetails == nil {
            ModuleLoadingView("Chargement des détails du lien…")
        } else if let error = vm.shareLinkDetailsError {
            VStack(spacing: 12) {
                Text(error)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityFocused($focusError)
                Button("Réessayer") { Task { await load() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Form {
                Section("Lien") {
                    LabeledContent("URL") {
                        Text(details.url)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    }
                    if let name = details.name { LabeledContent("Nom", value: name) }
                    if let path = details.path { LabeledContent("Chemin", value: path) }
                    if let owner = details.owner { LabeledContent("Propriétaire", value: owner) }
                }

                Section("État") {
                    if let status = details.status { LabeledContent("Statut", value: status) }
                    if let hasPassword = details.hasPassword {
                        LabeledContent("Protection par mot de passe") {
                            Text(
                                hasPassword
                                    ? String(localized: "Activée")
                                    : String(localized: "Désactivée")
                            )
                        }
                    }
                    if let isFolder = details.isFolder {
                        LabeledContent("Type") {
                            Text(
                                isFolder
                                    ? String(localized: "Dossier")
                                    : String(localized: "Fichier")
                            )
                        }
                    }
                    if let availableDate = details.availableDate {
                        LabeledContent("Disponible à partir du", value: availableDate)
                    }
                    if let expirationDate = details.expirationDate {
                        LabeledContent("Expire le", value: expirationDate)
                    }
                    if let creationError = details.creationError, creationError != 0 {
                        LabeledContent("Code d’erreur") {
                            Text(creationError, format: .number.grouping(.never))
                        }
                    }
                }

                if let qrImage {
                    Section("Code QR") {
                        Image(nsImage: qrImage)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .accessibilityLabel("Code QR du lien de partage")
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private var details: SharingLink { vm.shareLinkDetails ?? link }

    private var qrImage: NSImage? {
        guard let qrCode = details.qrCode else { return nil }
        let encoded = qrCode.split(separator: ",", maxSplits: 1).last.map(String.init) ?? qrCode
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return NSImage(data: data)
    }

    private func load() async {
        focusHeading = true
        VoiceOver.announce(
            String(localized: "Chargement des détails du lien…"),
            category: .progress,
            priority: .low
        )
        await vm.loadShareLinkDetails(link)
        guard !Task.isCancelled else { return }
        if let error = vm.shareLinkDetailsError {
            focusError = true
            VoiceOver.announce(error, category: .error, priority: .high)
        } else {
            focusHeading = true
            VoiceOver.announce("Détails du lien chargés", category: .result)
        }
    }

    private func copy(_ url: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        VoiceOver.announce(String(localized: "Lien copié"))
    }
}
