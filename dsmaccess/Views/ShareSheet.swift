//
//  ShareSheet.swift
//  dsmaccess
//
//  Création accessible d’un lien File Station avec disponibilité et expiration exactes.
//

import AppKit
import SwiftUI

struct ShareSheet: View {
    let item: FileStationItem
    let create: (
        _ password: String?,
        _ expirationDate: String?,
        _ availableDate: String?
    ) async -> FileBrowserViewModel.ShareOutcome

    @Environment(\.dismiss) private var dismiss
    @State private var phase = Phase.options
    @State private var password = ""
    @State private var hasAvailableDate = false
    @State private var availableDate = Date.now
    @State private var hasExpirationDate = false
    @State private var expirationDate = Date.now.addingTimeInterval(604_800)
    @State private var isCreating = false
    @State private var errorMessage: String?
    @FocusState private var passwordFocused: Bool
    @AccessibilityFocusState private var focusHeading: Bool
    @AccessibilityFocusState private var focusURL: Bool
    @AccessibilityFocusState private var focusError: Bool

    private enum Phase: Equatable {
        case options
        case created(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch phase {
            case .options:
                optionsView
            case .created(let url):
                resultView(url: url)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    @ViewBuilder
    private var optionsView: some View {
        Text("Créer un lien de partage")
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($focusHeading)

        Text(item.name)
            .foregroundStyle(.secondary)

        LabeledField(label: "Mot de passe (facultatif)") {
            SecureField("Mot de passe (facultatif)", text: $password)
                .focused($passwordFocused)
                .help("Protéger le lien de partage par un mot de passe")
        }

        GroupBox("Période de disponibilité") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Disponible à partir d’une date", isOn: $hasAvailableDate)
                if hasAvailableDate {
                    DatePicker("Date de disponibilité", selection: $availableDate)
                }
                Toggle("Définir une date d’expiration", isOn: $hasExpirationDate)
                if hasExpirationDate {
                    DatePicker("Date d’expiration", selection: $expirationDate)
                }
            }
            .padding(.top, 4)
        }

        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityFocused($focusError)
        }

        if isCreating {
            ProgressView("Création du lien en cours…")
        }

        HStack {
            Spacer()
            Button("Annuler", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
                .disabled(isCreating)
                .help("Annuler la création du lien")
            Button("Créer le lien") { Task { await createLink() } }
                .keyboardShortcut(.defaultAction)
                .disabled(isCreating)
                .help("Créer le lien de partage")
        }
        .onAppear {
            focusHeading = true
            passwordFocused = true
            VoiceOver.announce("Créer un lien de partage", category: .navigation)
        }
    }

    @ViewBuilder
    private func resultView(url: String) -> some View {
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
                .help("Fermer le lien de partage")
            Button("Copier le lien") { copyToClipboard(url) }
                .keyboardShortcut(.defaultAction)
                .help("Copier le lien de partage")
        }
        .onAppear {
            copyToClipboard(url, announce: false)
            focusURL = true
            VoiceOver.announce(
                String(localized: "Lien de partage créé et copié"),
                category: .result
            )
        }
    }

    private func createLink() async {
        guard !isCreating else { return }
        if hasAvailableDate, hasExpirationDate, availableDate > expirationDate {
            let message = String(
                localized: "La date de disponibilité doit précéder la date d’expiration."
            )
            errorMessage = message
            focusError = true
            VoiceOver.announce(message, category: .error, priority: .high)
            return
        }

        isCreating = true
        defer { isCreating = false }
        errorMessage = nil
        VoiceOver.announce(
            String(localized: "Création du lien en cours…"),
            category: .progress,
            priority: .low
        )
        switch await create(
            password.isEmpty ? nil : password,
            hasExpirationDate ? sharingDateString(expirationDate) : nil,
            hasAvailableDate ? sharingDateString(availableDate) : nil
        ) {
        case .link(let url):
            phase = .created(url)
        case .failure(let message):
            errorMessage = message
            focusError = true
            VoiceOver.announce(message, category: .error, priority: .high)
        case .cancelled:
            break
        }
    }

    private func copyToClipboard(_ url: String, announce: Bool = true) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        if announce { VoiceOver.announce(String(localized: "Lien copié")) }
    }
}

func sharingDateString(_ date: Date) -> String {
    date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
}

func sharingDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    let style = Date.ISO8601FormatStyle().year().month().day().dateSeparator(.dash)
    return try? Date(value, strategy: style.parseStrategy)
}
