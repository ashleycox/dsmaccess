//
//  FileStationFavoritesView.swift
//  dsmaccess
//
//  Gestion accessible de l’ensemble des favoris File Station.
//

import SwiftUI

struct FileStationFavoritesView: View {
    @Bindable var vm: FileBrowserViewModel
    let open: (FileStationFavorite) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var status = FileStationFavoriteStatus.all
    @State private var editingFavorite: FileStationFavorite?
    @State private var pendingRemoval: FileStationFavorite?
    @State private var confirmsBrokenCleanup = false
    @State private var isMutating = false
    @State private var operationError: String?
    @AccessibilityFocusState private var focusHeading: Bool
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
        .frame(width: 720, height: 540)
        .task(id: status) { await load() }
        .sheet(item: $editingFavorite) { favorite in
            NameEntrySheet(
                title: "Renommer le favori",
                fieldLabel: "Nom du favori",
                confirmLabel: "Renommer",
                announcement: String(localized: "Renommer le favori « \(favorite.name) »"),
                initialName: favorite.name
            ) { name in
                Task { await rename(favorite, to: name) }
            }
        }
        .alert(
            "Retirer ce favori ?",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            )
        ) {
            Button("Retirer", role: .destructive) {
                if let favorite = pendingRemoval {
                    pendingRemoval = nil
                    Task { await remove(favorite) }
                }
            }
            Button("Annuler", role: .cancel) { pendingRemoval = nil }
        } message: {
            if let favorite = pendingRemoval {
                Text(
                    "« \(favorite.name) » sera retiré des favoris. Le dossier et son contenu ne seront pas supprimés."
                )
            }
        }
        .alert("Effacer les favoris indisponibles ?", isPresented: $confirmsBrokenCleanup) {
            Button("Effacer", role: .destructive) { Task { await clearBrokenFavorites() } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tous les favoris qui ne correspondent plus à un dossier seront retirés. Aucun fichier ne sera supprimé.")
        }
    }

    private var header: some View {
        HStack {
            Text("Gérer les favoris")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusHeading)
            Spacer()
            if vm.isLoadingManagedFavorites || isMutating {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Opération sur les favoris en cours…")
            }
            Button("Fermer", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
                .disabled(isMutating)
        }
        .padding()
    }

    private var controls: some View {
        HStack {
            Picker("Afficher", selection: $status) {
                ForEach(FileStationFavoriteStatus.allCases, id: \.self) { value in
                    Text(value.localizedTitle).tag(value)
                }
            }
            .frame(maxWidth: 280)
            Spacer()
            Button("Actualiser", systemImage: "arrow.clockwise") { Task { await load() } }
                .disabled(vm.isLoadingManagedFavorites || isMutating)
                .help("Actualiser les favoris depuis File Station")
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
        } else if vm.isLoadingManagedFavorites && vm.managedFavorites.isEmpty {
            ModuleLoadingView("Chargement des favoris…")
                .accessibilityFocused($focusStatus)
        } else if let error = vm.managedFavoritesError {
            VStack(spacing: 12) {
                Text(error)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                Button("Réessayer") { Task { await load() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityFocused($focusStatus)
        } else if vm.managedFavorites.isEmpty {
            ContentUnavailableView(
                emptyTitle,
                systemImage: "star",
                description: Text("Ajoutez un dossier aux favoris pour le retrouver rapidement.")
            )
            .accessibilityFocused($focusStatus)
        } else {
            List(vm.managedFavorites) { favorite in
                favoriteRow(favorite)
            }
            .accessibilityLabel("Favoris File Station")
        }
    }

    private var footer: some View {
        HStack {
            Button("Effacer les favoris indisponibles…", role: .destructive) {
                confirmsBrokenCleanup = true
            }
            .disabled(isMutating || vm.isLoadingManagedFavorites)
            .help("Retirer tous les favoris dont le dossier n’existe plus")
            Spacer()
            Button("Fermer", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
                .disabled(isMutating)
        }
        .padding()
    }

    private func favoriteRow(_ favorite: FileStationFavorite) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(favorite.name)
                Text(favorite.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(
                    favorite.isAvailable
                        ? String(localized: "Disponible")
                        : String(localized: "Indisponible")
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Ouvrir", systemImage: "arrow.forward") {
                open(favorite)
                dismiss()
            }
            .labelStyle(.iconOnly)
            .disabled(!favorite.isAvailable || isMutating)
            .help("Ouvrir ce favori")
            Button("Renommer", systemImage: "pencil") { editingFavorite = favorite }
                .labelStyle(.iconOnly)
                .disabled(isMutating)
                .help("Renommer ce favori")
            Button("Monter", systemImage: "arrow.up") {
                Task { await move(favorite, by: -1) }
            }
            .labelStyle(.iconOnly)
            .disabled(!canMove(favorite, by: -1) || isMutating)
            .help("Monter ce favori")
            Button("Descendre", systemImage: "arrow.down") {
                Task { await move(favorite, by: 1) }
            }
            .labelStyle(.iconOnly)
            .disabled(!canMove(favorite, by: 1) || isMutating)
            .help("Descendre ce favori")
            Button("Retirer", systemImage: "trash", role: .destructive) {
                pendingRemoval = favorite
            }
            .labelStyle(.iconOnly)
            .disabled(isMutating)
            .help("Retirer ce favori")
        }
        .accessibilityElement(children: .contain)
    }

    private var emptyTitle: LocalizedStringKey {
        switch status {
        case .all: "Aucun favori"
        case .valid: "Aucun favori disponible"
        case .broken: "Aucun favori indisponible"
        }
    }

    private func canMove(_ favorite: FileStationFavorite, by offset: Int) -> Bool {
        guard status == .all,
              let index = vm.managedFavorites.firstIndex(where: { $0.id == favorite.id }) else {
            return false
        }
        return vm.managedFavorites.indices.contains(index + offset)
    }

    private func load() async {
        operationError = nil
        await vm.loadManagedFavorites(status: status)
        guard !Task.isCancelled else { return }
        if let error = vm.managedFavoritesError {
            focusStatus = true
            VoiceOver.announce(error, category: .error, priority: .high)
        } else {
            focusHeading = true
            VoiceOver.announce(
                String(localized: "Favoris : \(vm.managedFavorites.count)"),
                category: .result
            )
        }
    }

    private func rename(_ favorite: FileStationFavorite, to name: String) async {
        await mutate { await vm.renameFavorite(favorite, to: name) }
    }

    private func remove(_ favorite: FileStationFavorite) async {
        await mutate { await vm.removeFavorite(favorite) }
    }

    private func clearBrokenFavorites() async {
        await mutate { await vm.clearBrokenFavorites() }
    }

    private func move(_ favorite: FileStationFavorite, by offset: Int) async {
        await mutate { await vm.moveFavorite(favorite, by: offset) }
    }

    private func mutate(
        _ operation: @escaping @MainActor () async -> DSMOperationOutcome
    ) async {
        isMutating = true
        operationError = nil
        defer { isMutating = false }
        let outcome = await operation()
        if case .failure(let message) = outcome {
            operationError = message
            focusStatus = true
        }
        VoiceOver.announce(outcome, priority: .high)
    }
}

private extension FileStationFavoriteStatus {
    var localizedTitle: String {
        switch self {
        case .all: String(localized: "Tous les favoris")
        case .valid: String(localized: "Favoris disponibles")
        case .broken: String(localized: "Favoris indisponibles")
        }
    }
}
