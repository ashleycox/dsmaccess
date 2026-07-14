//
//  SurveillanceViewModel.swift
//  dsmaccess
//
//  État, activation et instantanés des caméras.
//

import Foundation
import Observation

@MainActor
@Observable
final class SurveillanceViewModel {
    private(set) var cameras: [SurveillanceCamera] = []
    private(set) var snapshotData: Data?
    private(set) var snapshotCameraID: String?
    private(set) var isLoading = false
    private(set) var isLoadingSnapshot = false
    private(set) var busyIDs: Set<String> = []
    var errorMessage: String?
    var snapshotErrorMessage: String?

    private let session: SessionStore

    init(session: SessionStore) {
        self.session = session
    }

    func load(silently: Bool = false) async {
        guard let client = session.client, let sid = session.sid else {
            session.clear()
            return
        }
        if !silently { isLoading = true }
        errorMessage = nil
        defer { isLoading = false }

        do {
            cameras = try await client.listSurveillanceCameras(sid: sid).sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        } catch {
            guard !DSMError.isCancellation(error) else { return }
            errorMessage = (error as? DSMError)?.errorDescription ?? error.localizedDescription
        }
    }

    func setEnabled(_ enabled: Bool, ids: Set<String>) async -> String {
        guard !ids.isEmpty else { return String(localized: "Aucune caméra sélectionnée") }
        guard let client = session.client, let sid = session.sid else {
            return String(localized: "Session expirée.")
        }
        busyIDs.formUnion(ids)
        defer { busyIDs.subtract(ids) }

        do {
            try await client.setSurveillanceCameras(ids: ids, enabled: enabled, sid: sid)
            await load(silently: true)
            return enabled
                ? String(localized: "\(ids.count) caméras activées")
                : String(localized: "\(ids.count) caméras désactivées")
        } catch {
            let reason = (error as? DSMError)?.errorDescription ?? error.localizedDescription
            return String(localized: "Échec de l’opération : \(reason)")
        }
    }

    func loadSnapshot(for camera: SurveillanceCamera) async {
        guard let client = session.client, let sid = session.sid else { return }
        isLoadingSnapshot = true
        snapshotErrorMessage = nil
        snapshotCameraID = camera.id
        defer { isLoadingSnapshot = false }

        do {
            snapshotData = try await client.surveillanceSnapshot(cameraID: camera.id, sid: sid)
        } catch {
            guard !DSMError.isCancellation(error) else { return }
            snapshotData = nil
            snapshotErrorMessage = (error as? DSMError)?.errorDescription ?? error.localizedDescription
        }
    }

    var summary: String {
        if let errorMessage { return errorMessage }
        let available = cameras.filter(\.isAvailable).count
        return String(localized: "\(cameras.count) caméras, \(available) disponibles")
    }
}
