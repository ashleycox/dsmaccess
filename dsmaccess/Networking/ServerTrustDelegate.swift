//
//  ServerTrustDelegate.swift
//  dsmaccess
//
//  Accepte le certificat TLS auto-signé d'un NAS local, mais UNIQUEMENT pour l'hôte
//  que l'utilisateur a explicitement configuré (pas de contournement global).
//

import Foundation

/// Delegate d'URLSession qui autorise le certificat auto-signé de l'hôte de confiance.
final class ServerTrustDelegate: NSObject, URLSessionDelegate {
    private let trustedHost: String

    init(trustedHost: String) {
        self.trustedHost = trustedHost
    }

    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // On ne prend en charge que la validation du certificat serveur, et seulement
        // pour l'hôte configuré. Tout le reste suit la validation par défaut du système.
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == trustedHost,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
