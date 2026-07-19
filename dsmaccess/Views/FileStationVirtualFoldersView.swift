//
//  FileStationVirtualFoldersView.swift
//  dsmaccess
//
//  Navigation dans les montages NFS, CIFS et ISO annoncés par File Station.
//

import SwiftUI

struct FileStationVirtualFoldersView: View {
    @Bindable var vm: FileBrowserViewModel
    let open: (FileStationItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType = FileStationVirtualFolderType.cifs
    @State private var sort = FileStationListSort.name
    @State private var ascending = true
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
            HStack {
                Spacer()
                Button("Fermer", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 720, height: 520)
        .task {
            if !vm.availableVirtualFolderTypes.contains(selectedType),
               let first = vm.availableVirtualFolderTypes.first {
                selectedType = first
            } else {
                await load()
            }
        }
        .onChange(of: selectedType) { _, _ in Task { await load() } }
    }

    private var header: some View {
        HStack {
            Text("Dossiers virtuels")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusHeading)
            Spacer()
            if vm.isLoadingVirtualFolders {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Chargement des dossiers virtuels…")
            }
            Button("Fermer", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Picker("Protocole", selection: $selectedType) {
                ForEach(vm.availableVirtualFolderTypes) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .frame(maxWidth: 180)
            Picker("Trier par", selection: $sort) {
                ForEach(FileStationListSort.allCases, id: \.self) { value in
                    Text(value.localizedTitle).tag(value)
                }
            }
            .frame(maxWidth: 230)
            Toggle("Ordre croissant", isOn: $ascending)
            Button("Appliquer") { Task { await load() } }
                .disabled(vm.isLoadingVirtualFolders)
            Spacer()
            Button("Actualiser", systemImage: "arrow.clockwise") { Task { await load() } }
                .disabled(vm.isLoadingVirtualFolders)
                .help("Actualiser les dossiers virtuels depuis File Station")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if vm.availableVirtualFolderTypes.isEmpty {
            ContentUnavailableView(
                "Aucun protocole de dossier virtuel",
                systemImage: "externaldrive.badge.questionmark",
                description: Text("Ce NAS n’annonce aucun montage NFS, CIFS ou ISO pris en charge.")
            )
            .accessibilityFocused($focusStatus)
        } else if vm.isLoadingVirtualFolders && vm.virtualFolders.isEmpty {
            ModuleLoadingView("Chargement des dossiers virtuels…")
                .accessibilityFocused($focusStatus)
        } else if let error = vm.virtualFoldersError {
            VStack(spacing: 12) {
                Text(error)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                Button("Réessayer") { Task { await load() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityFocused($focusStatus)
        } else if vm.virtualFolders.isEmpty {
            ContentUnavailableView(
                "Aucun dossier \(selectedType.displayName)",
                systemImage: "externaldrive",
                description: Text("File Station n’a renvoyé aucun montage pour ce protocole.")
            )
            .accessibilityFocused($focusStatus)
        } else {
            List(vm.virtualFolders) { folder in
                virtualFolderRow(folder)
            }
            .accessibilityLabel("Dossiers virtuels File Station")
        }
    }

    private func virtualFolderRow(_ folder: FileStationItem) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name)
                Text(folder.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let summary = volumeSummary(folder.additional?.volumeStatus) {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Ouvrir", systemImage: "arrow.forward") {
                open(folder)
                dismiss()
            }
            .help("Ouvrir ce dossier virtuel")
        }
        .accessibilityElement(children: .contain)
    }

    private func load() async {
        guard vm.availableVirtualFolderTypes.contains(selectedType) else {
            focusStatus = true
            return
        }
        await vm.loadVirtualFolders(
            type: selectedType,
            options: FileStationListOptions(
                sortBy: sort,
                sortDirection: ascending ? .ascending : .descending
            )
        )
        guard !Task.isCancelled else { return }
        if let error = vm.virtualFoldersError {
            focusStatus = true
            VoiceOver.announce(error, category: .error, priority: .high)
        } else {
            focusHeading = true
            VoiceOver.announce(
                String(localized: "Dossiers virtuels : \(vm.virtualFolders.count)"),
                category: .result
            )
        }
    }

    private func volumeSummary(_ volume: FileStationItem.VolumeStatus?) -> String? {
        guard let volume else { return nil }
        var parts = [String]()
        if let freeSpace = volume.freeSpace {
            parts.append(
                String(localized: "Libre : \(freeSpace.formatted(.byteCount(style: .file)))")
            )
        }
        if volume.isReadOnly == true {
            parts.append(String(localized: "Lecture seule"))
        }
        return parts.isEmpty ? nil : parts.formatted(.list(type: .and))
    }
}

private extension FileStationVirtualFolderType {
    var displayName: String { rawValue.uppercased() }
}

private extension FileStationListSort {
    var localizedTitle: String {
        switch self {
        case .name: String(localized: "Nom")
        case .size: String(localized: "Taille")
        case .user: String(localized: "Propriétaire")
        case .group: String(localized: "Groupe")
        case .modifiedTime: String(localized: "Date de modification")
        case .accessedTime: String(localized: "Date d’accès")
        case .changedTime: String(localized: "Date de changement")
        case .createdTime: String(localized: "Date de création")
        case .posix: "POSIX"
        case .type: String(localized: "Type")
        }
    }
}
