//
//  NetworkSettingsView.swift
//  dsmaccess
//
//  Affiche l'identité et la configuration réseau du NAS.
//

import SwiftUI

struct NetworkSettingsView: View {
    @State private var vm: NetworkSettingsViewModel
    @AccessibilityFocusState private var focusContent: Bool

    init(session: SessionStore) {
        _vm = State(initialValue: NetworkSettingsViewModel(session: session))
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.info == nil {
                ModuleLoadingView("Chargement de la configuration réseau…")
                    .accessibilityFocused($focusContent)
            } else if let error = vm.errorMessage {
                ModuleErrorView(message: error) {
                    Task { await load() }
                }
                .accessibilityFocused($focusContent)
            } else if let info = vm.info {
                List {
                    identitySection(info)
                    networkSection(info)
                }
                .accessibilityFocused($focusContent)
            } else {
                EmptyModuleView(
                    title: "Configuration réseau indisponible",
                    systemImage: "network.slash",
                    description: "Le NAS n’a renvoyé aucune information réseau."
                )
                .accessibilityFocused($focusContent)
            }
        }
        .navigationTitle("Réseau et identité")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await load() }
                } label: {
                    Label("Actualiser", systemImage: "arrow.clockwise")
                }
                .help("Actualiser la configuration réseau")
            }
        }
        .task { await load(restoresInitialFocus: true) }
    }

    private func identitySection(_ info: NetworkInfo) -> some View {
        Section("Identité") {
            if let name = info.serverName, !name.isEmpty {
                LabeledContent("Nom du serveur", value: name)
            }
            if info.enableWinDomain == true {
                LabeledContent("Domaine Windows", value: String(localized: "Activé"))
            }
        }
    }

    private func networkSection(_ info: NetworkInfo) -> some View {
        Section("Réseau") {
            if let ip = info.gatewayInfo?.ip, !ip.isEmpty {
                LabeledContent("Adresse IP", value: ip)
            }
            if let mask = info.gatewayInfo?.mask, !mask.isEmpty {
                LabeledContent("Masque de sous-réseau", value: mask)
            }
            if let gateway = info.gateway, !gateway.isEmpty {
                LabeledContent("Passerelle par défaut", value: gateway)
            }
            if let dns = dnsText(info) {
                LabeledContent("Serveur DNS", value: dns)
            }
            if let mode = dnsModeText(info) {
                LabeledContent("Configuration DNS", value: mode)
            }
            if let v6 = info.v6gateway, !v6.isEmpty {
                LabeledContent("Passerelle IPv6", value: v6)
            }
            if let interface = interfaceText(info) {
                LabeledContent("Interface", value: interface)
            }
        }
    }

    private func dnsText(_ info: NetworkInfo) -> String? {
        let servers = [info.dnsPrimary, info.dnsSecondary]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return servers.isEmpty ? nil : servers.joined(separator: ", ")
    }

    private func dnsModeText(_ info: NetworkInfo) -> String? {
        guard let manual = info.dnsManual else { return nil }
        return manual ? String(localized: "Manuelle") : String(localized: "Automatique (DHCP)")
    }

    private func interfaceText(_ info: NetworkInfo) -> String? {
        guard let name = info.gatewayInfo?.ifname, !name.isEmpty else { return nil }
        if info.gatewayInfo?.useDhcp == true {
            return String(localized: "\(name) (DHCP)")
        }
        return name
    }

    private func load(restoresInitialFocus: Bool = false) async {
        VoiceOver.announce(
            String(localized: "Chargement de la configuration réseau…"),
            category: .progress,
            priority: .low
        )
        await vm.load()
        guard !Task.isCancelled else { return }
        if restoresInitialFocus {
            await VoiceOver.restoreFocusIfCapturedByToolbar { focusContent = true }
        }
        VoiceOver.announce(
            vm.summary,
            category: vm.errorMessage == nil ? .result : .error
        )
    }
}
