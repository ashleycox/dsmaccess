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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
        // Fenêtre unique et lisible ; pas de sidebar automatique pour le MVP.
        .windowResizability(.contentSize)
    }
}
