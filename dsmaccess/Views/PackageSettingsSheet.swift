//
//  PackageSettingsSheet.swift
//  dsmaccess
//
//  Feuille des réglages globaux du Centre de paquets (SYNO.Core.Package.Setting) : mise à jour
//  automatique, paquets bêta, notifications. Chaque contrôle enregistre immédiatement (comme
//  les bascules de FileServicesView) et annonce le résultat à VoiceOver.
//

import SwiftUI

struct PackageSettingsSheet: View {
    @State private var vm: PackageSettingsViewModel
    @AccessibilityFocusState private var focusTitle: Bool
    @AccessibilityFocusState private var focusStatus: Bool
    @Environment(\.dismiss) private var dismiss

    init(session: SessionStore) {
        _vm = State(initialValue: PackageSettingsViewModel(session: session))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Réglages du Centre de paquets")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusTitle)

            content

            HStack {
                Spacer()
                Button("Terminé") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
        .task {
            focusTitle = true
            await load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.settings == nil {
            HStack(spacing: 12) {
                ProgressView().controlSize(.small)
                Text("Chargement…").foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityFocused($focusStatus)
        } else if let error = vm.errorMessage, vm.settings == nil {
            VStack(alignment: .leading, spacing: 12) {
                Text(error).foregroundStyle(.red)
                Button("Réessayer") { Task { await load() } }
            }
            .accessibilityFocused($focusStatus)
        } else if vm.settings != nil {
            controls
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Mise à jour automatique.
            VStack(alignment: .leading, spacing: 4) {
                Picker("Mise à jour automatique", selection: autoUpdateBinding) {
                    Text("Désactivée").tag(AutoUpdateMode.off)
                    Text("Versions importantes").tag(AutoUpdateMode.important)
                    Text("Dernières versions").tag(AutoUpdateMode.latest)
                }
                Text("Certains paquets ne prennent pas en charge la mise à jour automatique.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Paquets bêta.
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Afficher les versions bêta", isOn: boolBinding(
                    get: { $0.updateChannelBeta },
                    set: { await vm.setBeta($0) }
                ))
                Text("Les versions bêta permettent d'essayer les nouvelles fonctionnalités avant leur publication officielle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Notifications.
            VStack(alignment: .leading, spacing: 8) {
                Text("Notifications de mise à jour")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Toggle("Activer les notifications sur le bureau", isOn: boolBinding(
                    get: { $0.enableDsm },
                    set: { await vm.setDsmNotify($0) }
                ))
                Toggle("Activer la notification par courriel", isOn: boolBinding(
                    get: { $0.enableEmail },
                    set: { await vm.setEmailNotify($0) }
                ))
            }
        }
        .disabled(vm.isSaving)
    }

    // MARK: - Bindings

    private var autoUpdateBinding: Binding<AutoUpdateMode> {
        Binding(
            get: { vm.settings?.autoUpdateMode ?? .off },
            set: { mode in
                Task {
                    let msg = await vm.setAutoUpdateMode(mode)
                    VoiceOver.announce(msg, priority: .high)
                }
            }
        )
    }

    /// Fabrique un Binding<Bool> qui lit un champ des réglages et enregistre via `set`.
    private func boolBinding(get: @escaping (PackageSettings) -> Bool,
                             set: @escaping (Bool) async -> String) -> Binding<Bool> {
        Binding(
            get: { vm.settings.map(get) ?? false },
            set: { newValue in
                Task {
                    let msg = await set(newValue)
                    VoiceOver.announce(msg, priority: .high)
                }
            }
        )
    }

    private var loadAnnouncement: String {
        if let error = vm.errorMessage { return error }
        return String(localized: "Réglages du Centre de paquets chargés")
    }

    private func load() async {
        await vm.load()
        guard !Task.isCancelled else { return }
        if vm.errorMessage != nil { focusStatus = true }
        VoiceOver.announce(
            loadAnnouncement,
            category: vm.errorMessage == nil ? .result : .error
        )
    }
}
