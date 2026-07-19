//
//  PackageSourcesSheet.swift
//  dsmaccess
//
//  Gestion accessible des sources tierces du Centre de paquets.
//

import SwiftUI

struct PackageSourcesSheet: View {
    @State private var vm: PackageSourcesViewModel
    @State private var editorRequest: PackageSourceEditorRequest?
    @State private var pendingDeletion: PackageSource?
    @State private var operationTask: Task<Void, Never>?
    @AccessibilityFocusState private var focusHeading: Bool
    @AccessibilityFocusState private var focusStatus: Bool
    @Environment(\.dismiss) private var dismiss

    init(session: SessionStore) {
        _vm = State(initialValue: PackageSourcesViewModel(session: session))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 680, height: 480)
        .interactiveDismissDisabled(vm.isSaving || operationTask != nil)
        .task {
            focusHeading = true
            VoiceOver.announce("Sources de paquets", category: .navigation)
            await load()
        }
        .sheet(item: $editorRequest) { request in
            PackageSourceEditorSheet(vm: vm, source: request.source)
        }
        .confirmationDialog(
            "Supprimer cette source ?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { source in
            Button("Supprimer \(source.name)", role: .destructive) {
                delete(source)
            }
            Button("Annuler", role: .cancel) { }
        } message: { source in
            Text(
                "La source « \(source.name) » sera retirée du Centre de paquets. Les paquets déjà installés ne seront ni arrêtés ni désinstallés."
            )
        }
        .onDisappear {
            operationTask?.cancel()
        }
    }

    private var header: some View {
        HStack {
            Text("Sources de paquets")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusHeading)
            Spacer()
            if vm.isLoading || vm.isSaving {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(progressLabel)
            }
        }
        .padding()
    }

    private var progressLabel: String {
        vm.isSaving
            ? String(localized: "Enregistrement de la source…")
            : String(localized: "Chargement des sources…")
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.sources.isEmpty {
            ProgressView("Chargement des sources de paquets…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityFocused($focusStatus)
        } else if let error = vm.errorMessage, vm.sources.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .foregroundStyle(.red)
                Button("Réessayer") { Task { await load() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityFocused($focusStatus)
        } else if vm.sources.isEmpty {
            ContentUnavailableView {
                Label("Aucune source tierce", systemImage: "shippingbox")
            } description: {
                Text("Ajoutez une source HTTPS pour afficher ses paquets dans le Centre de paquets.")
            } actions: {
                Button("Ajouter une source…") {
                    editorRequest = PackageSourceEditorRequest(source: nil)
                }
                .disabled(vm.isSaving)
            }
            .accessibilityFocused($focusStatus)
        } else {
            VStack(spacing: 0) {
                if let error = vm.operationErrorMessage ?? vm.errorMessage {
                    HStack {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .accessibilityFocused($focusStatus)
                        Spacer()
                        Button("Fermer l’erreur") {
                            vm.operationErrorMessage = nil
                            vm.errorMessage = nil
                        }
                    }
                    .padding()
                }
                List(vm.sources) { source in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(source.name)
                                .fontWeight(.medium)
                            Text(source.feed)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Spacer()
                        Button("Modifier", systemImage: "pencil") {
                            editorRequest = PackageSourceEditorRequest(source: source)
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Modifier la source \(source.name)")
                        .disabled(vm.isSaving || operationTask != nil)
                        Button(role: .destructive) {
                            pendingDeletion = source
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Supprimer la source \(source.name)")
                        .disabled(vm.isSaving || operationTask != nil)
                    }
                    .accessibilityElement(children: .contain)
                }
                .accessibilityLabel("Sources de paquets configurées")
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Ajouter une source…", systemImage: "plus") {
                editorRequest = PackageSourceEditorRequest(source: nil)
            }
            .disabled(vm.isSaving || operationTask != nil)
            .help("Ajouter une source HTTPS au Centre de paquets")
            Spacer()
            Button("Fermer", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
                .disabled(vm.isSaving || operationTask != nil)
        }
        .padding()
    }

    private func load() async {
        VoiceOver.announce(
            String(localized: "Chargement des sources de paquets…"),
            category: .progress,
            priority: .low
        )
        await vm.load()
        guard !Task.isCancelled else { return }
        if let error = vm.errorMessage {
            focusStatus = true
            VoiceOver.announce(error, category: .error, priority: .high)
        } else {
            VoiceOver.announce(
                String(localized: "\(vm.sources.count) sources de paquets"),
                category: .result
            )
        }
    }

    private func delete(_ source: PackageSource) {
        guard operationTask == nil else { return }
        VoiceOver.announce(
            String(localized: "Suppression de la source \(source.name)…"),
            category: .progress,
            priority: .high
        )
        operationTask = Task {
            let outcome = await vm.delete(source)
            if case .failure = outcome { focusStatus = true }
            if case .cancelled = outcome {
                operationTask = nil
                return
            }
            VoiceOver.announce(outcome, priority: .high)
            operationTask = nil
        }
    }
}

private struct PackageSourceEditorRequest: Identifiable {
    let id = UUID()
    let source: PackageSource?
}

private struct PackageSourceEditorSheet: View {
    private enum FocusTarget: Hashable {
        case name
        case feed
        case error
    }

    @Bindable var vm: PackageSourcesViewModel
    let source: PackageSource?

    @State private var name: String
    @State private var feed: String
    @State private var validationMessage: String?
    @State private var saveTask: Task<Void, Never>?
    @AccessibilityFocusState private var focus: FocusTarget?
    @Environment(\.dismiss) private var dismiss

    init(vm: PackageSourcesViewModel, source: PackageSource?) {
        self.vm = vm
        self.source = source
        _name = State(initialValue: source?.name ?? "")
        _feed = State(initialValue: source?.feed ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(editorTitle)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Form {
                TextField("Nom", text: $name)
                    .accessibilityFocused($focus, equals: .name)
                TextField("Adresse HTTPS", text: $feed)
                    .accessibilityFocused($focus, equals: .feed)
                Text("L’ajout d’une source rend ses paquets visibles mais n’en installe aucun. N’ajoutez que des sources que vous jugez fiables.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .formStyle(.grouped)

            if let message = validationMessage ?? vm.operationErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityFocused($focus, equals: .error)
            }

            if vm.isSaving {
                ProgressView("Enregistrement de la source…")
            }

            HStack {
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(vm.isSaving)
                Button("Enregistrer") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(vm.isSaving)
            }
        }
        .padding(24)
        .frame(width: 500)
        .interactiveDismissDisabled(vm.isSaving)
        .onAppear {
            vm.operationErrorMessage = nil
            focus = .name
            VoiceOver.announce(
                editorTitle,
                category: .navigation
            )
        }
        .onDisappear {
            saveTask?.cancel()
        }
    }

    private var editorTitle: String {
        source == nil
            ? String(localized: "Ajouter une source")
            : String(localized: "Modifier la source")
    }

    private func save() {
        guard saveTask == nil else { return }
        guard PackageSourcesViewModel.validatedSource(name: name, feed: feed) != nil else {
            validationMessage = String(
                localized: "Saisissez un nom et une adresse HTTPS valides pour la source."
            )
            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            focus = normalizedName.isEmpty ? .name : .feed
            VoiceOver.announce(
                validationMessage ?? "",
                category: .error,
                priority: .high
            )
            return
        }
        validationMessage = nil
        VoiceOver.announce(
            String(localized: "Enregistrement de la source…"),
            category: .progress,
            priority: .high
        )
        saveTask = Task {
            let outcome = await vm.save(
                name: name,
                feed: feed,
                originalFeed: source?.feed
            )
            if case .success = outcome {
                VoiceOver.announce(outcome, priority: .high)
                dismiss()
            } else if case .failure = outcome {
                focus = .error
                VoiceOver.announce(outcome, priority: .high)
            }
            saveTask = nil
        }
    }
}
