//
//  FileBrowserViewModel.swift
//  dsmaccess
//
//  Navigation, recherche et opérations File Station.
//

import Foundation
import Observation

@MainActor
@Observable
final class FileBrowserViewModel {
    struct Level: Equatable {
        let name: String
        let path: String?
    }

    struct Clipboard {
        let items: [FileStationItem]
        let movesItems: Bool
    }

    enum SortMode: String, CaseIterable, Identifiable {
        case name
        case modificationDate
        case size
        case kind

        var id: Self { self }

        var title: String {
            switch self {
            case .name: String(localized: "Nom")
            case .modificationDate: String(localized: "Date de modification")
            case .size: String(localized: "Taille")
            case .kind: String(localized: "Type")
            }
        }
    }

    private(set) var stack: [Level]
    private(set) var items: [FileStationItem] = []
    private(set) var favorites: [FileStationFavorite] = []
    private(set) var isLoading = false
    private(set) var isSearching = false
    private(set) var isWorking = false
    private(set) var isDownloading = false
    private(set) var isShowingSearchResults = false
    private(set) var searchQuery = ""
    private(set) var clipboard: Clipboard?
    private(set) var shareLinks: [SharingLink] = []
    private(set) var isLoadingShareLinks = false

    var errorMessage: String?
    var shareLinksError: String?
    var sortMode = SortMode.name
    var sortAscending = true

    private var directoryItems: [FileStationItem] = []
    private let session: SessionStore

    init(session: SessionStore) {
        self.session = session
        stack = [Level(name: String(localized: "Fichiers"), path: nil)]
    }

    var currentLevel: Level {
        stack.last ?? Level(name: String(localized: "Fichiers"), path: nil)
    }

    var title: String { currentLevel.name }
    var canGoUp: Bool { stack.count > 1 }
    var canWrite: Bool { currentLevel.path != nil }
    var canPaste: Bool { clipboard != nil && canWrite }
    var breadcrumb: String { stack.map(\.name).joined(separator: " ▸ ") }

    var sortedItems: [FileStationItem] {
        items.sorted { left, right in
            if left.isdir != right.isdir {
                return left.isdir && !right.isdir
            }
            let result: ComparisonResult
            switch sortMode {
            case .name:
                result = left.name.localizedStandardCompare(right.name)
            case .modificationDate:
                result = compare(left.additional?.time?.mtime, right.additional?.time?.mtime)
            case .size:
                result = compare(left.additional?.size, right.additional?.size)
            case .kind:
                let leftKind = left.additional?.type ?? left.name.pathExtension
                let rightKind = right.additional?.type ?? right.name.pathExtension
                result = leftKind.localizedStandardCompare(rightKind)
            }
            return sortAscending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    func loadCurrent() async {
        guard let client = session.client, let sid = session.sid else {
            session.clear()
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let result: [FileStationItem]
            if let path = currentLevel.path {
                result = try await client.list(folderPath: path, sid: sid)
            } else {
                result = try await client.listShares(sid: sid)
            }
            try Task.checkCancellation()
            directoryItems = result
            items = result
            isShowingSearchResults = false
        } catch is CancellationError {
            // Une nouvelle navigation ou recherche a remplacé ce chargement.
        } catch {
            errorMessage = errorMessage(for: error)
        }
        isLoading = false
    }

    func loadFavorites() async {
        guard let client = session.client, let sid = session.sid else { return }
        do {
            favorites = try await client.fileStationFavorites(sid: sid)
        } catch {
            // Les favoris sont un complément : leur absence ne masque jamais les fichiers.
            favorites = []
        }
    }

    func search(_ query: String) async {
        let pattern = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchQuery = pattern
        guard !pattern.isEmpty else {
            isSearching = false
            isShowingSearchResults = false
            errorMessage = nil
            items = directoryItems
            return
        }

        if currentLevel.path == nil {
            items = directoryItems.filter {
                $0.name.localizedCaseInsensitiveContains(pattern)
            }
            isShowingSearchResults = true
            return
        }

        guard let client = session.client, let sid = session.sid, let path = currentLevel.path else {
            return
        }
        isSearching = true
        defer { isSearching = false }
        errorMessage = nil
        do {
            let result = try await client.searchFiles(in: path, matching: pattern, sid: sid)
            try Task.checkCancellation()
            items = result
            isShowingSearchResults = true
        } catch is CancellationError {
            return
        } catch {
            errorMessage = errorMessage(for: error)
        }
    }

    func open(_ item: FileStationItem) async {
        guard item.isdir else { return }
        searchQuery = ""
        stack.append(Level(name: item.name, path: item.path))
        directoryItems = []
        items = []
        await loadCurrent()
    }

    func openFavorite(_ favorite: FileStationFavorite) async {
        guard favorite.isAvailable else { return }
        searchQuery = ""
        stack = [
            Level(name: String(localized: "Fichiers"), path: nil),
            Level(name: favorite.name, path: favorite.path),
        ]
        directoryItems = []
        items = []
        await loadCurrent()
    }

    func goUp() async {
        guard canGoUp else { return }
        searchQuery = ""
        stack.removeLast()
        directoryItems = []
        items = []
        await loadCurrent()
    }

    func suggestedFilename(for item: FileStationItem) -> String {
        item.isdir ? "\(item.name).zip" : item.name
    }

    func download(_ item: FileStationItem, to destination: URL) async -> String {
        guard let client = session.client, let sid = session.sid else {
            session.clear()
            return String(localized: "Session expirée.")
        }
        isDownloading = true
        defer { isDownloading = false }
        do {
            try await client.downloadFile(path: item.path, sid: sid, to: destination)
            return String(localized: "Téléchargement terminé : \(item.name)")
        } catch {
            return String(localized: "Échec du téléchargement : \(errorMessage(for: error))")
        }
    }

    func download(_ selectedItems: [FileStationItem], to directory: URL) async -> String {
        guard let client = session.client, let sid = session.sid else {
            session.clear()
            return String(localized: "Session expirée.")
        }
        isDownloading = true
        defer { isDownloading = false }
        var completed = 0
        var firstError: String?
        for item in selectedItems {
            let destination = directory.appendingPathComponent(suggestedFilename(for: item))
            do {
                try Task.checkCancellation()
                try await client.downloadFile(path: item.path, sid: sid, to: destination)
                completed += 1
            } catch is CancellationError {
                break
            } catch {
                if firstError == nil { firstError = errorMessage(for: error) }
            }
        }
        if completed == selectedItems.count {
            return String(localized: "\(completed) éléments téléchargés")
        }
        return String(localized: "\(completed) téléchargés, \(selectedItems.count - completed) en échec. \(firstError ?? "")")
    }

    func createFolder(named name: String) async -> String {
        guard let client = session.client, let sid = session.sid, let parent = currentLevel.path else {
            return String(localized: "Impossible de créer le dossier ici.")
        }
        return await performAndReload {
            try await client.createFolder(in: parent, name: name, sid: sid)
            return String(localized: "Dossier créé : \(name)")
        }
    }

    func rename(_ item: FileStationItem, to name: String) async -> String {
        guard let client = session.client, let sid = session.sid else {
            return String(localized: "Session expirée.")
        }
        return await performAndReload {
            try await client.rename(path: item.path, to: name, sid: sid)
            return String(localized: "Renommé en : \(name)")
        }
    }

    func delete(_ selectedItems: [FileStationItem]) async -> String {
        guard let client = session.client, let sid = session.sid else {
            return String(localized: "Session expirée.")
        }
        return await performAndReload {
            try await client.delete(paths: selectedItems.map(\.path), sid: sid)
            return selectedItems.count == 1
                ? String(localized: "Supprimé : \(selectedItems[0].name)")
                : String(localized: "\(selectedItems.count) éléments supprimés")
        }
    }

    func upload(fileURLs: [URL]) async -> String {
        guard let client = session.client, let sid = session.sid, let parent = currentLevel.path else {
            return String(localized: "Impossible d’envoyer ici.")
        }
        isWorking = true
        defer { isWorking = false }
        var sent = 0
        var firstFailure: String?
        let query = searchQuery
        for url in fileURLs {
            do {
                try Task.checkCancellation()
                try await client.upload(fileURL: url, to: parent, sid: sid)
                sent += 1
            } catch {
                if firstFailure == nil { firstFailure = errorMessage(for: error) }
            }
        }
        await loadCurrent()
        if !query.isEmpty {
            await search(query)
        }
        let failed = fileURLs.count - sent
        if failed > 0 {
            return String(localized: "\(sent) envoyés, \(failed) en échec : \(firstFailure ?? "")")
        }
        return sent == 1
            ? String(localized: "Fichier envoyé : \(fileURLs[0].lastPathComponent)")
            : String(localized: "\(sent) fichiers envoyés")
    }

    func copy(_ selectedItems: [FileStationItem]) -> String {
        clipboard = Clipboard(items: selectedItems, movesItems: false)
        return selectedItems.count == 1
            ? String(localized: "Copié : \(selectedItems[0].name)")
            : String(localized: "\(selectedItems.count) éléments copiés")
    }

    func cut(_ selectedItems: [FileStationItem]) -> String {
        clipboard = Clipboard(items: selectedItems, movesItems: true)
        return selectedItems.count == 1
            ? String(localized: "Coupé : \(selectedItems[0].name). Ouvrez la destination puis Coller pour déplacer.")
            : String(localized: "\(selectedItems.count) éléments coupés. Ouvrez la destination puis Coller pour déplacer.")
    }

    func paste() async -> String {
        guard let clipboard else { return String(localized: "Rien à coller.") }
        guard let client = session.client, let sid = session.sid, let destination = currentLevel.path else {
            return String(localized: "Impossible de coller ici.")
        }
        return await performAndReload {
            try await client.copyMove(
                paths: clipboard.items.map(\.path),
                to: destination,
                remove: clipboard.movesItems,
                sid: sid
            )
            if clipboard.movesItems { self.clipboard = nil }
            return clipboard.movesItems
                ? String(localized: "\(clipboard.items.count) éléments déplacés ici")
                : String(localized: "\(clipboard.items.count) éléments copiés ici")
        }
    }

    func compress(_ selectedItems: [FileStationItem], archiveName: String) async -> String {
        guard let client = session.client, let sid = session.sid, let folder = currentLevel.path else {
            return String(localized: "Impossible de créer une archive ici.")
        }
        let trimmed = archiveName.trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = trimmed.lowercased().hasSuffix(".zip") ? trimmed : "\(trimmed).zip"
        let destination = folder.appendingNASPathComponent(filename)
        return await performAndReload {
            try await client.compress(paths: selectedItems.map(\.path), to: destination, sid: sid)
            return String(localized: "Archive créée : \(filename)")
        }
    }

    func extract(_ item: FileStationItem) async -> String {
        guard let client = session.client, let sid = session.sid, let folder = currentLevel.path else {
            return String(localized: "Impossible d’extraire l’archive ici.")
        }
        return await performAndReload {
            try await client.extract(archivePath: item.path, to: folder, sid: sid)
            return String(localized: "Archive extraite : \(item.name)")
        }
    }

    func canExtract(_ item: FileStationItem) -> Bool {
        guard !item.isdir else { return false }
        let extensions = ["zip", "gz", "tar", "tgz", "tbz", "bz2", "rar", "7z", "iso"]
        return extensions.contains(item.name.pathExtension.lowercased())
    }

    func isFavorite(path: String) -> Bool {
        favorites.contains { $0.path == path }
    }

    func toggleCurrentFavorite() async -> String {
        guard let client = session.client, let sid = session.sid, let path = currentLevel.path else {
            return String(localized: "Impossible d’ajouter ce dossier aux favoris.")
        }
        do {
            if isFavorite(path: path) {
                try await client.removeFileStationFavorite(path: path, sid: sid)
                await loadFavorites()
                return String(localized: "Favori supprimé : \(currentLevel.name)")
            }
            try await client.addFileStationFavorite(path: path, name: currentLevel.name, sid: sid)
            await loadFavorites()
            return String(localized: "Favori ajouté : \(currentLevel.name)")
        } catch {
            return String(localized: "Échec de la modification du favori : \(errorMessage(for: error))")
        }
    }

    enum ShareOutcome {
        case link(String)
        case failure(String)
    }

    func createShareLink(for item: FileStationItem, password: String?, dateExpired: String?) async -> ShareOutcome {
        guard let client = session.client, let sid = session.sid else {
            return .failure(String(localized: "Session expirée."))
        }
        do {
            let url = try await client.createShareLink(
                path: item.path,
                password: password,
                dateExpired: dateExpired,
                sid: sid
            )
            return .link(url)
        } catch {
            return .failure(String(localized: "Échec de la création du lien : \(errorMessage(for: error))"))
        }
    }

    func loadShareLinks() async {
        guard let client = session.client, let sid = session.sid else {
            session.clear()
            return
        }
        isLoadingShareLinks = true
        shareLinksError = nil
        do {
            shareLinks = try await client.listShareLinks(sid: sid)
        } catch {
            shareLinksError = errorMessage(for: error)
        }
        isLoadingShareLinks = false
    }

    func deleteShareLink(_ link: SharingLink) async -> String {
        guard let client = session.client, let sid = session.sid else {
            return String(localized: "Session expirée.")
        }
        do {
            try await client.deleteShareLink(id: link.id, sid: sid)
            await loadShareLinks()
            return String(localized: "Lien supprimé")
        } catch {
            return String(localized: "Échec de la suppression du lien : \(errorMessage(for: error))")
        }
    }

    var summary: String {
        if let errorMessage { return errorMessage }
        let count: String
        switch sortedItems.count {
        case 0: count = isShowingSearchResults ? String(localized: "Aucun résultat") : String(localized: "Dossier vide")
        case 1: count = String(localized: "1 élément")
        default: count = String(localized: "\(sortedItems.count) éléments")
        }
        return "\(title), \(count)"
    }

    private func performAndReload(_ operation: () async throws -> String) async -> String {
        isWorking = true
        defer { isWorking = false }
        do {
            let message = try await operation()
            let query = searchQuery
            await loadCurrent()
            if !query.isEmpty {
                await search(query)
            }
            return message
        } catch {
            return String(localized: "Échec de l’opération : \(errorMessage(for: error))")
        }
    }

    private func errorMessage(for error: Error) -> String {
        (error as? DSMError)?.errorDescription ?? error.localizedDescription
    }

    private func compare<Value: Comparable>(_ left: Value?, _ right: Value?) -> ComparisonResult {
        switch (left, right) {
        case let (left?, right?) where left < right: .orderedAscending
        case let (left?, right?) where left > right: .orderedDescending
        case (nil, .some): .orderedAscending
        case (.some, nil): .orderedDescending
        default: .orderedSame
        }
    }
}

private extension String {
    var pathExtension: String {
        (self as NSString).pathExtension
    }

    func appendingNASPathComponent(_ component: String) -> String {
        hasSuffix("/") ? self + component : self + "/" + component
    }
}
