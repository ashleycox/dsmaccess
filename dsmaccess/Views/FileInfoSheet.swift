//
//  FileInfoSheet.swift
//  dsmaccess
//
//  Inspecteur File Station alimenté par des métadonnées DSM actualisées.
//

import AppKit
import SwiftUI

struct FileInfoSheet: View {
    @Bindable var vm: FileBrowserViewModel
    let selectedItem: FileStationItem

    @Environment(\.dismiss) private var dismiss
    @State private var calculationTask: Task<Void, Never>?
    @AccessibilityFocusState private var focusTitle: Bool
    @AccessibilityFocusState private var focusError: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            HStack {
                Spacer()
                Button("Fermer", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .help("Fermer les informations")
            }
            .padding()
        }
        .frame(width: 600, height: 650)
        .task { await load() }
        .onDisappear {
            calculationTask?.cancel()
            vm.clearInspector()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isdir ? "folder" : "doc")
                .foregroundStyle(item.isdir ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)
            Text(item.name)
                .font(.headline)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusTitle)
            Spacer()
            if vm.isLoadingInspectorDetails {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Chargement des détails du fichier…")
            }
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoadingInspector && vm.inspectorItem == nil {
            ModuleLoadingView("Chargement des informations…")
        } else if let error = vm.inspectorError {
            VStack(spacing: 12) {
                Text(error)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityFocused($focusError)
                Button("Réessayer") { Task { await load() } }
                    .help("Recharger les informations depuis le NAS")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Form {
                if let thumbnailImage {
                    Section("Aperçu") {
                        Image(nsImage: thumbnailImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 420, maxHeight: 220)
                            .accessibilityLabel(String(localized: "Aperçu de \(item.name)"))
                    }
                }

                Section("Informations générales") {
                    LabeledContent("Nom", value: item.name)
                    LabeledContent("Type", value: kind)
                    if let size = item.additional?.size, !item.isdir {
                        LabeledContent("Taille") {
                            Text(size, format: .byteCount(style: .file, includesActualByteCount: true))
                        }
                    }
                    LabeledContent("Emplacement", value: item.path)
                    if let realPath = item.additional?.realPath, realPath != item.path {
                        LabeledContent("Chemin réel", value: realPath)
                    }
                    if let mountPointType = item.additional?.mountPointType {
                        LabeledContent("Type de montage", value: mountPointType)
                    }
                }

                if item.isdir, vm.supports(.directorySize) {
                    Section("Contenu du dossier") {
                        if let directorySize = vm.inspectorDirectorySize {
                            LabeledContent("Taille totale") {
                                Text(
                                    directorySize.totalSize,
                                    format: .byteCount(style: .file, includesActualByteCount: true)
                                )
                            }
                            LabeledContent("Fichiers") {
                                Text(directorySize.fileCount, format: .number)
                            }
                            LabeledContent("Sous-dossiers") {
                                Text(directorySize.directoryCount, format: .number)
                            }
                        } else {
                            Button("Calculer la taille du dossier") {
                                calculationTask = Task {
                                    await vm.calculateInspectorDirectorySize()
                                    announceDirectorySizeResult()
                                    calculationTask = nil
                                }
                            }
                            .disabled(vm.isCalculatingInspectorSize)
                            .help("Calculer le nombre d’éléments et leur taille totale")
                        }
                        if vm.isCalculatingInspectorSize {
                            ProgressView("Calcul de la taille du dossier…")
                        }
                    }
                }

                if !item.isdir, vm.supports(.checksum) {
                    Section("Intégrité") {
                        if let checksum = vm.inspectorChecksum {
                            LabeledContent("Somme MD5") {
                                HStack {
                                    Text(checksum)
                                        .font(.body.monospaced())
                                        .textSelection(.enabled)
                                    Button("Copier") { copyToClipboard(checksum) }
                                        .help("Copier la somme MD5")
                                }
                            }
                        } else {
                            Button("Calculer la somme MD5") {
                                calculationTask = Task {
                                    await vm.calculateInspectorChecksum()
                                    announceChecksumResult()
                                    calculationTask = nil
                                }
                            }
                            .disabled(vm.isCalculatingInspectorChecksum)
                            .help("Calculer l’empreinte MD5 du fichier")
                        }
                        if vm.isCalculatingInspectorChecksum {
                            ProgressView("Calcul de la somme MD5…")
                        }
                    }
                }

                if let time = item.additional?.time {
                    Section("Dates") {
                        dateRow("Modification", timestamp: time.mtime)
                        dateRow("Création", timestamp: time.crtime ?? time.ctime)
                        dateRow("Dernier accès", timestamp: time.atime)
                        dateRow("Changement des métadonnées", timestamp: time.ctime)
                    }
                }

                if let owner = item.additional?.owner,
                   owner.user != nil || owner.group != nil || owner.uid != nil || owner.gid != nil {
                    Section("Propriétaire") {
                        if let user = owner.user { LabeledContent("Utilisateur", value: user) }
                        if let uid = owner.uid {
                            LabeledContent("UID") { Text(uid, format: .number.grouping(.never)) }
                        }
                        if let group = owner.group { LabeledContent("Groupe", value: group) }
                        if let gid = owner.gid {
                            LabeledContent("GID") { Text(gid, format: .number.grouping(.never)) }
                        }
                    }
                }

                if let permission = item.additional?.permission {
                    Section("Autorisations") {
                        if let posix = permission.posix {
                            LabeledContent("Mode POSIX") {
                                Text(posix, format: .number.grouping(.never))
                            }
                        }
                        if let shareRight = permission.shareRight {
                            LabeledContent("Droit du dossier partagé", value: shareRight)
                        }
                        if let accessList = accessList(for: permission.acl) {
                            LabeledContent("Accès", value: accessList)
                        }
                        if let restrictions = restrictions(for: permission.advancedRight) {
                            LabeledContent("Restrictions", value: restrictions)
                        }
                        if let aclEnabled = permission.aclEnabled ?? permission.isACLMode {
                            LabeledContent("Liste de contrôle d’accès") {
                                Text(aclEnabled ? "Activée" : "Désactivée")
                            }
                        }
                    }
                }

                if let volume = item.additional?.volumeStatus {
                    Section("Volume") {
                        if let freeSpace = volume.freeSpace {
                            LabeledContent("Espace disponible") {
                                Text(freeSpace, format: .byteCount(style: .file))
                            }
                        }
                        if let totalSpace = volume.totalSpace {
                            LabeledContent("Capacité") {
                                Text(totalSpace, format: .byteCount(style: .file))
                            }
                        }
                        if let isReadOnly = volume.isReadOnly {
                            LabeledContent("Accès au volume") {
                                Text(isReadOnly ? "Lecture seule" : "Lecture et écriture")
                            }
                        }
                    }
                }

                if !vm.inspectorDetailErrors.isEmpty {
                    Section("Détails indisponibles") {
                        ForEach(vm.inspectorDetailErrors, id: \.self) { error in
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .accessibilityLabel(String(localized: "Informations sur \(item.name)"))
        }
    }

    private var item: FileStationItem { vm.inspectorItem ?? selectedItem }

    private var thumbnailImage: NSImage? {
        vm.inspectorThumbnail.flatMap(NSImage.init(data:))
    }

    @ViewBuilder
    private func dateRow(_ label: LocalizedStringKey, timestamp: Int?) -> some View {
        if let timestamp {
            LabeledContent(label) {
                Text(
                    Date(timeIntervalSince1970: TimeInterval(timestamp)),
                    format: Date.FormatStyle(date: .long, time: .standard)
                )
            }
        }
    }

    private var kind: String {
        if item.isdir { return String(localized: "Dossier") }
        if let type = item.additional?.type, !type.isEmpty { return type }
        let pathExtension = (item.name as NSString).pathExtension
        return pathExtension.isEmpty
            ? String(localized: "Fichier")
            : pathExtension.uppercased()
    }

    private func accessList(for acl: FileStationItem.ACLInfo?) -> String? {
        guard let acl else { return nil }
        var access = [String]()
        if acl.read == true { access.append(String(localized: "Lecture")) }
        if acl.write == true { access.append(String(localized: "Écriture")) }
        if acl.append == true { access.append(String(localized: "Ajout")) }
        if acl.execute == true { access.append(String(localized: "Exécution")) }
        if acl.delete == true { access.append(String(localized: "Suppression")) }
        return access.isEmpty ? String(localized: "Aucun") : access.formatted(.list(type: .and))
    }

    private func restrictions(for rights: FileStationItem.AdvancedRight?) -> String? {
        guard let rights else { return nil }
        var restrictions = [String]()
        if rights.disablesDownload == true {
            restrictions.append(String(localized: "Téléchargement interdit"))
        }
        if rights.disablesList == true {
            restrictions.append(String(localized: "Liste interdite"))
        }
        if rights.disablesModify == true {
            restrictions.append(String(localized: "Modification interdite"))
        }
        return restrictions.isEmpty ? nil : restrictions.formatted(.list(type: .and))
    }

    private func load() async {
        focusTitle = true
        VoiceOver.announce(
            String(localized: "Chargement des informations sur \(selectedItem.name)…"),
            category: .progress,
            priority: .low
        )
        await vm.loadInspector(for: selectedItem)
        guard !Task.isCancelled else { return }
        if let error = vm.inspectorError {
            focusError = true
            VoiceOver.announce(error, category: .error, priority: .high)
        } else {
            focusTitle = true
            VoiceOver.announce(
                String(localized: "Informations actualisées sur \(selectedItem.name)"),
                category: .result
            )
            if !vm.inspectorDetailErrors.isEmpty {
                VoiceOver.announce(
                    String(localized: "Certains détails ne sont pas disponibles."),
                    category: .error
                )
            }
        }
    }

    private func copyToClipboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        VoiceOver.announce(String(localized: "Somme MD5 copiée"), category: .result)
    }

    private func announceDirectorySizeResult() {
        if let size = vm.inspectorDirectorySize {
            VoiceOver.announce(
                String(
                    localized: "Taille du dossier calculée : \(size.totalSize.formatted(.byteCount(style: .file)))"
                ),
                category: .result
            )
        } else if let error = vm.inspectorDetailErrors.last {
            VoiceOver.announce(error, category: .error, priority: .high)
        }
    }

    private func announceChecksumResult() {
        if vm.inspectorChecksum != nil {
            VoiceOver.announce(String(localized: "Somme MD5 calculée"), category: .result)
        } else if let error = vm.inspectorDetailErrors.last {
            VoiceOver.announce(error, category: .error, priority: .high)
        }
    }
}
