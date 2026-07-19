//
//  ShareLinksView.swift
//  dsmaccess
//
//  Gestion complète des liens de partage File Station.
//

import AppKit
import SwiftUI

struct ShareLinksView: View {
    @Bindable var vm: FileBrowserViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var selection = Set<String>()
    @State private var sort = FileStationSharingSort.name
    @State private var ascending = true
    @State private var editingLink: SharingLink?
    @State private var detailsLink: SharingLink?
    @State private var pendingDelete = [SharingLink]()
    @State private var confirmsInvalidCleanup = false
    @State private var isMutating = false
    @State private var operationError: String?
    @AccessibilityFocusState private var focusTitle: Bool
    @AccessibilityFocusState private var focusStatus: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controls
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 780, height: 570)
        .task {
            focusTitle = true
            await loadShareLinks(forceRefresh: false)
        }
        .sheet(item: $editingLink) { link in
            ShareLinkEditorSheet(link: link) { changes in
                await vm.editShareLink(link, changes: changes)
            }
        }
        .sheet(item: $detailsLink) { link in
            ShareLinkDetailsSheet(vm: vm, link: link)
        }
        .alert(
            deleteTitle,
            isPresented: Binding(
                get: { !pendingDelete.isEmpty },
                set: { if !$0 { pendingDelete.removeAll() } }
            )
        ) {
            Button("Supprimer", role: .destructive) { Task { await deletePendingLinks() } }
            Button("Annuler", role: .cancel) { pendingDelete.removeAll() }
        } message: {
            Text(deleteMessage)
        }
        .alert("Effacer les liens invalides ?", isPresented: $confirmsInvalidCleanup) {
            Button("Effacer", role: .destructive) { Task { await clearInvalidLinks() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tous les liens que File Station considère comme invalides seront supprimés. Cette action est irréversible.")
        }
    }

    private var header: some View {
        HStack {
            Text("Liens de partage")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusTitle)
            Spacer()
            if vm.isLoadingShareLinks || isMutating {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Opération sur les liens en cours…")
            }
            Button("Fermer", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
                .help("Fermer les liens de partage")
        }
        .padding()
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Picker("Trier par", selection: $sort) {
                ForEach(FileStationSharingSort.allCases, id: \.self) { value in
                    Text(value.localizedTitle).tag(value)
                }
            }
            .frame(maxWidth: 230)
            Toggle("Ordre croissant", isOn: $ascending)
            Button("Appliquer") { Task { await loadShareLinks(forceRefresh: false) } }
                .disabled(vm.isLoadingShareLinks || isMutating)
            Spacer()
            Button("Actualiser", systemImage: "arrow.clockwise") {
                Task { await loadShareLinks(forceRefresh: true) }
            }
            .disabled(vm.isLoadingShareLinks || isMutating)
            .help("Actualiser les liens depuis File Station")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if let operationError {
            VStack(spacing: 12) {
                Text(operationError)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityFocused($focusStatus)
                Button("Fermer l’erreur") { self.operationError = nil }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.isLoadingShareLinks && vm.shareLinks.isEmpty {
            ModuleLoadingView("Chargement des liens de partage…")
                .accessibilityFocused($focusStatus)
        } else if let error = vm.shareLinksError {
            VStack(spacing: 12) {
                Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
                Button("Réessayer") { Task { await loadShareLinks(forceRefresh: true) } }
                    .help("Réessayer de charger les liens de partage")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityFocused($focusStatus)
        } else if vm.shareLinks.isEmpty {
            ContentUnavailableView(
                "Aucun lien de partage",
                systemImage: "link",
                description: Text("Créez un lien depuis un fichier ou un dossier pour le retrouver ici.")
            )
            .accessibilityFocused($focusStatus)
        } else {
            List(vm.shareLinks, selection: $selection) { link in
                row(for: link)
                    .tag(link.id)
            }
            .accessibilityLabel("Liens de partage File Station")
        }
    }

    private var footer: some View {
        HStack {
            Button("Effacer les liens invalides…", role: .destructive) {
                confirmsInvalidCleanup = true
            }
            .disabled(isMutating || vm.isLoadingShareLinks)
            .help("Supprimer les liens signalés comme invalides par File Station")
            Spacer()
            Button("Supprimer la sélection…", role: .destructive) {
                pendingDelete = selectedLinks
            }
            .disabled(selection.isEmpty || isMutating)
            Button("Fermer", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    private func row(for link: SharingLink) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(link.name ?? link.path ?? link.url)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(link.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(linkSummary(link))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Détails", systemImage: "info.circle") { detailsLink = link }
                .labelStyle(.iconOnly)
                .help("Afficher les détails du lien")
            Button("Modifier", systemImage: "pencil") { editingLink = link }
                .labelStyle(.iconOnly)
                .help("Modifier ce lien de partage")
            Button("Copier", systemImage: "doc.on.clipboard") { copyToClipboard(link.url) }
                .labelStyle(.iconOnly)
                .help("Copier ce lien de partage")
            Button("Supprimer", systemImage: "trash", role: .destructive) {
                pendingDelete = [link]
            }
            .labelStyle(.iconOnly)
            .help("Supprimer ce lien de partage")
        }
        .accessibilityElement(children: .contain)
    }

    private var selectedLinks: [SharingLink] {
        vm.shareLinks.filter { selection.contains($0.id) }
    }

    private var deleteTitle: String {
        pendingDelete.count == 1
            ? String(localized: "Supprimer ce lien de partage ?")
            : String(localized: "Supprimer \(pendingDelete.count) liens de partage ?")
    }

    private var deleteMessage: String {
        if pendingDelete.count == 1, let link = pendingDelete.first {
            return String(
                localized: "Le lien vers « \(link.name ?? link.path ?? link.url) » cessera de fonctionner immédiatement."
            )
        }
        return String(
            localized: "Les liens sélectionnés cesseront de fonctionner immédiatement. Cette action est irréversible."
        )
    }

    private func linkSummary(_ link: SharingLink) -> String {
        var parts = [String]()
        if let status = link.status { parts.append(status) }
        if link.hasPassword == true { parts.append(String(localized: "Protégé par mot de passe")) }
        if let available = link.availableDate {
            parts.append(String(localized: "Disponible le \(available)"))
        }
        if let expiration = link.expirationDate {
            parts.append(String(localized: "Expire le \(expiration)"))
        }
        return parts.isEmpty ? String(localized: "Aucune restriction") : parts.formatted(.list(type: .and))
    }

    private func loadShareLinks(forceRefresh: Bool) async {
        operationError = nil
        await vm.loadShareLinks(
            options: FileStationSharingListOptions(
                sortBy: sort,
                sortDirection: ascending ? .ascending : .descending,
                forceRefresh: forceRefresh
            )
        )
        guard !Task.isCancelled else { return }
        selection.formIntersection(vm.shareLinks.map(\.id))
        if vm.shareLinksError == nil {
            focusTitle = true
        } else {
            focusStatus = true
        }
        VoiceOver.announce(
            shareLinksAnnouncement,
            category: vm.shareLinksError == nil ? .result : .error
        )
    }

    private var shareLinksAnnouncement: String {
        if let error = vm.shareLinksError { return error }
        return String(localized: "Liens de partage : \(vm.shareLinks.count)")
    }

    private func deletePendingLinks() async {
        let links = pendingDelete
        pendingDelete.removeAll()
        isMutating = true
        defer { isMutating = false }
        let outcome = await vm.deleteShareLinks(links)
        selection.subtract(links.map(\.id))
        handle(outcome)
    }

    private func clearInvalidLinks() async {
        isMutating = true
        defer { isMutating = false }
        handle(await vm.clearInvalidShareLinks())
    }

    private func handle(_ outcome: DSMOperationOutcome) {
        if case .failure(let message) = outcome {
            operationError = message
            focusStatus = true
        }
        VoiceOver.announce(outcome, priority: .high)
    }

    private func copyToClipboard(_ url: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        VoiceOver.announce(String(localized: "Lien copié"))
    }
}

private extension FileStationSharingSort {
    var localizedTitle: String {
        switch self {
        case .id: String(localized: "Identifiant")
        case .name: String(localized: "Nom")
        case .isFolder: String(localized: "Type")
        case .path: String(localized: "Chemin")
        case .expirationDate: String(localized: "Date d’expiration")
        case .availableDate: String(localized: "Date de disponibilité")
        case .status: String(localized: "Statut")
        case .hasPassword: String(localized: "Protection par mot de passe")
        case .url: "URL"
        case .owner: String(localized: "Propriétaire")
        }
    }
}
