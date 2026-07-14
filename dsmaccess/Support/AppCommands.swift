//
//  AppCommands.swift
//  dsmaccess
//
//  Commandes de barre des menus reliées à la fenêtre active.
//

import SwiftUI

struct SessionCommandActions {
    let logout: () -> Void
}

struct FileCommandActions {
    let canGoUp: Bool
    let hasSelection: Bool
    let hasSingleSelection: Bool
    let canWrite: Bool
    let canPaste: Bool
    let canExtract: Bool
    let refresh: () -> Void
    let goUp: () -> Void
    let open: () -> Void
    let createFolder: () -> Void
    let upload: () -> Void
    let download: () -> Void
    let rename: () -> Void
    let copy: () -> Void
    let cut: () -> Void
    let paste: () -> Void
    let compress: () -> Void
    let extract: () -> Void
    let delete: () -> Void
    let showInfo: () -> Void
}

private struct SelectedModuleKey: FocusedValueKey {
    typealias Value = Binding<AppModule>
}

private struct SessionCommandActionsKey: FocusedValueKey {
    typealias Value = SessionCommandActions
}

private struct AvailableModulesKey: FocusedValueKey {
    typealias Value = Set<AppModule>
}

private struct FileCommandActionsKey: FocusedValueKey {
    typealias Value = FileCommandActions
}

extension FocusedValues {
    var selectedModule: Binding<AppModule>? {
        get { self[SelectedModuleKey.self] }
        set { self[SelectedModuleKey.self] = newValue }
    }

    var sessionCommandActions: SessionCommandActions? {
        get { self[SessionCommandActionsKey.self] }
        set { self[SessionCommandActionsKey.self] = newValue }
    }

    var availableModules: Set<AppModule>? {
        get { self[AvailableModulesKey.self] }
        set { self[AvailableModulesKey.self] = newValue }
    }


    var fileCommandActions: FileCommandActions? {
        get { self[FileCommandActionsKey.self] }
        set { self[FileCommandActionsKey.self] = newValue }
    }
}

struct DSMCommands: Commands {
    @FocusedBinding(\.selectedModule) private var selectedModule
    @FocusedValue(\.availableModules) private var availableModules
    @FocusedValue(\.sessionCommandActions) private var sessionActions
    @FocusedValue(\.fileCommandActions) private var fileActions

    var body: some Commands {
        CommandMenu("Navigation") {
            ForEach(AppModuleSection.allCases) { section in
                Section(section.title) {
                    ForEach(section.modules) { module in
                        Button(module.title) {
                            selectedModule = module
                        }
                        .keyboardShortcut(
                            module.keyboardShortcut.key,
                            modifiers: module.keyboardShortcut.modifiers
                        )
                        .disabled(
                            selectedModule == nil || availableModules?.contains(module) != true
                        )
                    }
                }
            }
        }

        CommandGroup(before: .appTermination) {
            Button("Déconnexion") {
                sessionActions?.logout()
            }
            .disabled(sessionActions == nil)
        }

        CommandMenu("Fichiers") {
            Button("Ouvrir") { fileActions?.open() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(fileActions?.hasSingleSelection != true)
            Button("Dossier parent") { fileActions?.goUp() }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(fileActions?.canGoUp != true)
            Button("Actualiser") { fileActions?.refresh() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(fileActions == nil)

            Divider()

            Button("Nouveau dossier") { fileActions?.createFolder() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(fileActions?.canWrite != true)
            Button("Envoyer des fichiers…") { fileActions?.upload() }
                .keyboardShortcut("u", modifiers: .command)
                .disabled(fileActions?.canWrite != true)
            Button("Télécharger…") { fileActions?.download() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(fileActions?.hasSelection != true)

            Divider()

            Button("Copier") { fileActions?.copy() }
                .disabled(fileActions?.hasSelection != true || fileActions?.canWrite != true)
            Button("Déplacer (couper)") { fileActions?.cut() }
                .disabled(fileActions?.hasSelection != true || fileActions?.canWrite != true)
            Button("Coller") { fileActions?.paste() }
                .disabled(fileActions?.canPaste != true)
            Button("Renommer…") { fileActions?.rename() }
                .disabled(fileActions?.hasSingleSelection != true || fileActions?.canWrite != true)

            Divider()

            Button("Compresser…") { fileActions?.compress() }
                .disabled(fileActions?.hasSelection != true || fileActions?.canWrite != true)
            Button("Extraire") { fileActions?.extract() }
                .disabled(fileActions?.canExtract != true || fileActions?.canWrite != true)
            Button("Supprimer…", role: .destructive) { fileActions?.delete() }
                .disabled(fileActions?.hasSelection != true || fileActions?.canWrite != true)

            Divider()

            Button("Lire les informations") { fileActions?.showInfo() }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(fileActions?.hasSingleSelection != true)
        }
    }
}
