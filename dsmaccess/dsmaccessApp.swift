//
//  dsmaccessApp.swift
//  dsmaccess
//
//  Created by Mathieu Martin on 09/07/2026.
//

import SwiftUI

@main
struct dsmaccessApp: App {
    /// État de session partagé pour toute l'app (SID courant, hôte, connecté ou non).
    @State private var session = SessionStore()
    /// Updater Sparkle, propriété de l'app pour toute sa durée de vie.
    @StateObject private var updater = UpdaterViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                // Taille minimale : en dessous, les lignes des listes se tronquent et
                // VoiceOver n'annonce plus les cellules coupées. Plancher lisible pour tous.
                .frame(minWidth: 800, idealWidth: 960, minHeight: 520, idealHeight: 640)
        }
        // Fenêtre unique et lisible ; pas de sidebar automatique pour le MVP.
        .windowResizability(.contentSize)
        .commands {
            // Placé juste après « À propos de DSM Access » : l'emplacement macOS
            // conventionnel, là où VoiceOver s'attend à trouver la commande.
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updater)
            }
        }
    }
}
