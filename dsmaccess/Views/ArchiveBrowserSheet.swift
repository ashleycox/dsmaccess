//
//  ArchiveBrowserSheet.swift
//  dsmaccess
//
//  Navigation et extraction sélective du contenu d’une archive File Station.
//

import SwiftUI

struct ArchiveBrowserSheet: View {
    private struct Level: Equatable {
        let name: String
        let itemID: Int?
    }

    @Bindable var vm: FileBrowserViewModel
    let archive: FileStationItem
    let onExtract: (FileStationExtractionOptions) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var levels = [Level(name: String(localized: "Racine"), itemID: nil)]
    @State private var selection = Set<Int>()
    @State private var sort = FileStationArchiveSort.name
    @State private var ascending = true
    @State private var usesCodepage = false
    @State private var codepage = FileStationArchiveCodepage.french
    @State private var password = ""
    @State private var showingExtractionOptions = false
    @AccessibilityFocusState private var focusHeading: Bool
    @AccessibilityFocusState private var focusStatus: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            optionsBar
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 760, height: 650)
        .task {
            focusHeading = true
            await load()
        }
        .onDisappear { vm.clearArchive() }
        .sheet(isPresented: $showingExtractionOptions) {
            FileExtractionOptionsSheet(
                archiveName: archive.name,
                itemIDs: Array(selection).sorted(),
                initialCodepage: usesCodepage ? codepage : nil,
                initialPassword: password
            ) { options in
                onExtract(options)
                dismiss()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button("Dossier parent", systemImage: "chevron.up", action: goUp)
                .disabled(levels.count == 1 || vm.isLoadingArchive)
                .help("Afficher le dossier parent dans l’archive")
            VStack(alignment: .leading, spacing: 2) {
                Text("Contenu de \(archive.name)")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($focusHeading)
                Text(levels.map(\.name).joined(separator: " ▸ "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Actualiser", systemImage: "arrow.clockwise") {
                Task { await load() }
            }
            .disabled(vm.isLoadingArchive)
            .help("Relire le contenu de l’archive")
        }
        .padding()
    }

    private var optionsBar: some View {
        Form {
            HStack(alignment: .top, spacing: 16) {
                SecureField("Mot de passe facultatif", text: $password)
                    .frame(maxWidth: 240)
                Toggle("Choisir l’encodage", isOn: $usesCodepage)
                if usesCodepage {
                    Picker("Encodage", selection: $codepage) {
                        ForEach(FileStationArchiveCodepage.allCases) { value in
                            Text(value.localizedTitle).tag(value)
                        }
                    }
                    .frame(maxWidth: 190)
                }
            }
            HStack(spacing: 16) {
                Picker("Trier par", selection: $sort) {
                    ForEach(FileStationArchiveSort.allCases, id: \.self) { value in
                        Text(value.localizedTitle).tag(value)
                    }
                }
                .frame(maxWidth: 220)
                Toggle("Ordre croissant", isOn: $ascending)
                Button("Appliquer") { Task { await load() } }
                    .disabled(vm.isLoadingArchive)
            }
        }
        .formStyle(.grouped)
        .frame(height: 155)
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoadingArchive && vm.archiveItems.isEmpty {
            ModuleLoadingView("Lecture de l’archive…")
                .accessibilityFocused($focusStatus)
        } else if let error = vm.archiveError {
            VStack(spacing: 12) {
                Text(error)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                Text("Vérifiez le mot de passe ou l’encodage, puis réessayez.")
                    .foregroundStyle(.secondary)
                Button("Réessayer") { Task { await load() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityFocused($focusStatus)
        } else if vm.archiveItems.isEmpty {
            ContentUnavailableView(
                "Dossier vide dans l’archive",
                systemImage: "archivebox",
                description: Text("Ce niveau ne contient aucun élément.")
            )
            .accessibilityFocused($focusStatus)
        } else {
            List(vm.archiveItems, selection: $selection) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.isDirectory ? "folder" : "doc")
                        .foregroundStyle(item.isDirectory ? Color.accentColor : Color.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                        HStack(spacing: 8) {
                            Text(item.size, format: .byteCount(style: .file))
                            Text(String(localized: "Compressé : \(item.packedSize.formatted(.byteCount(style: .file)))"))
                            Text(item.modificationTime)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if item.isDirectory {
                        Button("Ouvrir") { open(item) }
                            .help(String(localized: "Ouvrir \(item.name) dans l’archive"))
                    }
                }
                .tag(item.itemID)
                .accessibilityElement(children: .contain)
            }
            .accessibilityLabel("Contenu de l’archive")
        }
    }

    private var footer: some View {
        HStack {
            Button("Tout sélectionner") {
                selection.formUnion(vm.archiveItems.map(\.itemID))
            }
            .disabled(vm.archiveItems.isEmpty)
            Button("Effacer la sélection") { selection.removeAll() }
                .disabled(selection.isEmpty)
            Spacer()
            Button("Annuler", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button {
                showingExtractionOptions = true
            } label: {
                Text(
                    selection.isEmpty
                        ? String(localized: "Extraire tout")
                        : String(localized: "Extraire la sélection")
                )
            }
            .disabled(vm.isLoadingArchive || vm.archiveError != nil)
            .keyboardShortcut(.defaultAction)
            .help(selection.isEmpty
                  ? String(localized: "Extraire tout le contenu de l’archive")
                  : String(localized: "Extraire uniquement les éléments sélectionnés"))
        }
        .padding()
    }

    private func load() async {
        VoiceOver.announce(
            String(localized: "Lecture de l’archive en cours…"),
            category: .progress,
            priority: .low
        )
        await vm.loadArchive(
            archive,
            options: FileStationArchiveListOptions(
                sortBy: sort,
                sortDirection: ascending ? .ascending : .descending,
                codepage: usesCodepage ? codepage : nil,
                password: password.isEmpty ? nil : password,
                parentItemID: levels.last?.itemID
            )
        )
        guard !Task.isCancelled else { return }
        if let error = vm.archiveError {
            focusStatus = true
            VoiceOver.announce(error, category: .error, priority: .high)
        } else {
            focusHeading = true
            VoiceOver.announce(
                String(localized: "Éléments dans ce dossier : \(vm.archiveItems.count)"),
                category: .result
            )
        }
    }

    private func open(_ item: FileStationArchiveItem) {
        guard item.isDirectory else { return }
        levels.append(Level(name: item.name, itemID: item.itemID))
        Task { await load() }
    }

    private func goUp() {
        guard levels.count > 1 else { return }
        levels.removeLast()
        Task { await load() }
    }
}

private extension FileStationArchiveSort {
    var localizedTitle: String {
        switch self {
        case .name: String(localized: "Nom")
        case .size: String(localized: "Taille d’origine")
        case .packedSize: String(localized: "Taille compressée")
        case .modifiedTime: String(localized: "Date de modification")
        }
    }
}
