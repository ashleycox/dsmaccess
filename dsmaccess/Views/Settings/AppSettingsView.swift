//
//  AppSettingsView.swift
//  dsmaccess
//
//  Fenêtre Réglages macOS native.
//

import SwiftUI

struct AppSettingsView: View {
    let settings: AppSettings
    let session: SessionStore
    @State private var selection = AppSettingsPane.announcements

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(AppSettingsPane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.systemImage)
                    .tag(pane)
                    .help(pane.help)
                    .accessibilityIdentifier("settings.pane.\(pane.rawValue)")
            }
            .listStyle(.sidebar)
            .navigationTitle("Réglages")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .accessibilityLabel("Sections des réglages")
            .accessibilityIdentifier("settings.sidebar")
        } detail: {
            Group {
                switch selection {
                case .announcements:
                    AnnouncementSettingsView(settings: settings)
                        .navigationTitle(AppSettingsPane.announcements.title)
                case .sidebar:
                    SidebarSettingsView(settings: settings)
                        .navigationTitle(AppSettingsPane.sidebar.title)
                case .nas:
                    NASSettingsView(session: session)
                        .navigationTitle(AppSettingsPane.nas.title)
                }
            }
        }
        .toolbar(.hidden, for: .windowToolbar)
        .frame(minWidth: 760, idealWidth: 820, minHeight: 520, idealHeight: 600)
        .task {
            announceSelection(selection)
        }
        .onChange(of: selection) { _, newValue in
            announceSelection(newValue)
        }
    }

    private func announceSelection(_ pane: AppSettingsPane) {
        VoiceOver.announce(
            String(localized: "Réglages, \(pane.localizedTitle)"),
            category: .navigation
        )
    }
}
