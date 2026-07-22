//
//  USBCopyTaskEditorSheet.swift
//  dsmaccess
//

import SwiftUI

struct USBCopyTaskEditorSheet: View {
    private let task: USBCopyTask?
    private let localShares: [SharedFolder]
    private let externalShares: [SharedFolder]
    private let onCreate: ((USBCopyTaskCreation) async -> DSMOperationOutcome)?
    private let onSave: ((USBCopyTaskSettings) async -> DSMOperationOutcome)?

    @State private var type: USBCopyTaskType
    @State private var name: String
    @State private var sourcePath: String
    @State private var destinationPath: String
    @State private var strategy: USBCopyStrategy
    @State private var enableRotation: Bool
    @State private var rotationPolicy: USBCopyRotationPolicy
    @State private var maxVersionCount: Int
    @State private var removeSourceFile: Bool
    @State private var notKeepDirectoryStructure: Bool
    @State private var smartCreateDateDirectory: Bool
    @State private var renamePhotoVideo: Bool
    @State private var conflictPolicy: USBCopyConflictPolicy
    @State private var trigger: USBCopyTrigger
    @State private var filterSelection: USBCopyFilterSelection
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showMirrorConfirmation = false
    @FocusState private var nameFocused: Bool
    @AccessibilityFocusState private var contentFocused: Bool
    @AccessibilityFocusState private var errorFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(
        localShares: [SharedFolder],
        externalShares: [SharedFolder],
        onCreate: @escaping (USBCopyTaskCreation) async -> DSMOperationOutcome
    ) {
        task = nil
        self.localShares = localShares
        self.externalShares = externalShares
        self.onCreate = onCreate
        onSave = nil
        let initialType = USBCopyTaskType.exportGeneral
        let filter = USBCopyFilter.defaultValue(for: initialType)
        _type = State(initialValue: initialType)
        _name = State(initialValue: "")
        _sourcePath = State(initialValue: localShares.first.map { "/\($0.name)" } ?? "")
        _destinationPath = State(initialValue: externalShares.first.map { "/\($0.name)" } ?? "")
        _strategy = State(initialValue: .versioning)
        _enableRotation = State(initialValue: false)
        _rotationPolicy = State(initialValue: .oldestVersion)
        _maxVersionCount = State(initialValue: 256)
        _removeSourceFile = State(initialValue: false)
        _notKeepDirectoryStructure = State(initialValue: false)
        _smartCreateDateDirectory = State(initialValue: false)
        _renamePhotoVideo = State(initialValue: false)
        _conflictPolicy = State(initialValue: .rename)
        _trigger = State(initialValue: USBCopyTrigger(
            runWhenPlugIn: false,
            ejectWhenTaskDone: true,
            scheduleEnabled: false,
            scheduleContent: .defaultValue
        ))
        _filterSelection = State(initialValue: USBCopyFilterSelection(filter: filter))
    }

    init(
        details: USBCopyTaskDetails,
        localShares: [SharedFolder],
        externalShares: [SharedFolder],
        onSave: @escaping (USBCopyTaskSettings) async -> DSMOperationOutcome
    ) {
        let task = details.task
        self.task = task
        self.localShares = localShares
        self.externalShares = externalShares
        onCreate = nil
        self.onSave = onSave
        _type = State(initialValue: task.knownType ?? .exportGeneral)
        _name = State(initialValue: task.name)
        _sourcePath = State(initialValue: task.sourcePath)
        _destinationPath = State(initialValue: task.destinationPath)
        _strategy = State(initialValue: task.knownStrategy ?? .versioning)
        _enableRotation = State(initialValue: task.enableRotation ?? false)
        _rotationPolicy = State(initialValue: task.rotationPolicy.flatMap(USBCopyRotationPolicy.init) ?? .oldestVersion)
        _maxVersionCount = State(initialValue: task.maxVersionCount ?? 256)
        _removeSourceFile = State(initialValue: task.removeSourceFile ?? false)
        _notKeepDirectoryStructure = State(initialValue: task.notKeepDirectoryStructure ?? false)
        _smartCreateDateDirectory = State(initialValue: task.smartCreateDateDirectory ?? false)
        _renamePhotoVideo = State(initialValue: task.renamePhotoVideo ?? false)
        _conflictPolicy = State(initialValue: task.conflictPolicy.flatMap(USBCopyConflictPolicy.init) ?? .rename)
        _trigger = State(initialValue: details.trigger)
        _filterSelection = State(initialValue: USBCopyFilterSelection(filter: details.filter))
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(task == nil ? "Créer une tâche USB Copy" : "Modifier la tâche USB Copy")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($contentFocused)
                .padding()

            Form {
                Section("Tâche") {
                    Picker("Direction", selection: $type) {
                        ForEach(USBCopyTaskType.allCases) { taskType in
                            Text(taskType.localizedName).tag(taskType)
                        }
                    }
                    .disabled(task != nil)
                    .help("Choisir le sens de la copie")

                    TextField("Nom de la tâche", text: $name)
                        .focused($nameFocused)
                        .help("Nom de la tâche USB Copy, jusqu’à 64 caractères")

                    USBCopyPathField(
                        label: "Dossier source",
                        path: $sourcePath,
                        shares: sourceShares,
                        isDisabled: task != nil
                    )
                    USBCopyPathField(
                        label: "Dossier de destination",
                        path: $destinationPath,
                        shares: destinationShares,
                        isDisabled: false
                    )

                    if externalShares.isEmpty {
                        Label(
                            task == nil
                                ? "Aucun dossier USB ou carte SD n’est actuellement monté. La création d’une tâche exige normalement un périphérique connecté."
                                : "Aucun dossier USB ou carte SD n’est actuellement monté. Connectez le périphérique pour choisir une autre destination.",
                            systemImage: "externaldrive.badge.questionmark"
                        )
                        .foregroundStyle(.secondary)
                    }

                    Picker("Mode de copie", selection: $strategy) {
                        ForEach(USBCopyStrategy.allCases) { copyStrategy in
                            Text(copyStrategy.localizedName).tag(copyStrategy)
                        }
                    }
                    .disabled(task != nil || type == .importPhoto)
                    .help("Choisir comment USB Copy met à jour la destination")
                }

                if strategy == .versioning {
                    Section("Rotation des versions") {
                        Toggle("Activer la rotation des versions", isOn: $enableRotation)
                        Picker("Règle de rotation", selection: $rotationPolicy) {
                            ForEach(USBCopyRotationPolicy.allCases) { policy in
                                Text(policy.localizedName).tag(policy)
                            }
                        }
                        .disabled(!enableRotation)
                        Stepper(value: $maxVersionCount, in: 1...65_535) {
                            Text("Nombre maximal de versions : \(maxVersionCount)")
                        }
                        .disabled(!enableRotation)
                    }
                }

                if strategy == .incremental {
                    Section("Copie incrémentielle") {
                        Toggle("Supprimer les fichiers source après la copie", isOn: $removeSourceFile)
                            .help("Déplacer les fichiers au lieu de les conserver à la source")
                        Toggle("Ne pas conserver la structure des dossiers", isOn: $notKeepDirectoryStructure)
                        if notKeepDirectoryStructure {
                            Toggle("Créer des dossiers selon la date", isOn: $smartCreateDateDirectory)
                            Toggle("Renommer les photos et vidéos selon la date", isOn: $renamePhotoVideo)
                        }
                        Picker("En cas de conflit", selection: $conflictPolicy) {
                            ForEach(USBCopyConflictPolicy.allCases) { policy in
                                Text(policy.localizedName).tag(policy)
                            }
                        }
                    }
                }

                if task == nil {
                    Section("Déclenchement") {
                        USBCopyScheduleFields(trigger: $trigger)
                    }
                    Section("Filtre de fichiers") {
                        USBCopyFilterFields(selection: $filterSelection)
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .accessibilityFocused($errorFocused)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                if isSaving {
                    ProgressView("Enregistrement…")
                        .controlSize(.small)
                }
                Spacer()
                Button("Annuler", role: .cancel, action: dismiss.callAsFunction)
                    .keyboardShortcut(.cancelAction)
                    .disabled(isSaving)
                Button(task == nil ? "Créer" : "Enregistrer", action: requestSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSaving)
                    .confirmationDialog(
                        "Créer une copie miroir ?",
                        isPresented: $showMirrorConfirmation
                    ) {
                        Button("Créer la tâche miroir", role: .destructive) {
                            Task { await save() }
                        }
                        Button("Annuler", role: .cancel) { }
                    } message: {
                        Text("USB Copy supprimera de la destination les fichiers qui ne sont plus présents à la source. Vérifiez soigneusement le dossier de destination.")
                    }
            }
            .padding()
        }
        .frame(minWidth: 680, minHeight: 680)
        .onAppear {
            if task == nil { nameFocused = true }
            contentFocused = true
            VoiceOver.announce(
                task == nil
                    ? String(localized: "Créer une tâche USB Copy")
                    : String(localized: "Modifier la tâche USB Copy"),
                category: .navigation
            )
        }
        .onChange(of: type) { oldValue, newValue in
            guard task == nil, oldValue != newValue else { return }
            strategy = newValue == .importPhoto ? .incremental : .versioning
            let defaultFilter = USBCopyFilter.defaultValue(for: newValue)
            filterSelection = USBCopyFilterSelection(filter: defaultFilter)
            notKeepDirectoryStructure = newValue == .importPhoto
            smartCreateDateDirectory = newValue == .importPhoto
            renamePhotoVideo = newValue == .importPhoto
            sourcePath = sourceShares.first.map { "/\($0.name)" } ?? ""
            destinationPath = destinationShares.first.map { "/\($0.name)" } ?? ""
        }
    }

    private var sourceShares: [SharedFolder] { type.isImport ? externalShares : localShares }
    private var destinationShares: [SharedFolder] { type.isImport ? localShares : externalShares }

    private func requestSave() {
        guard validate() else { return }
        if task == nil && strategy == .mirror {
            showMirrorConfirmation = true
        } else {
            Task { await save() }
        }
    }

    private func validate() -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = sourcePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDestination = destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || trimmedName.count > 64 {
            return failValidation(String(localized: "Saisissez un nom de tâche de 1 à 64 caractères."))
        }
        if trimmedSource.isEmpty || trimmedDestination.isEmpty {
            return failValidation(String(localized: "Choisissez un dossier source et un dossier de destination."))
        }
        if trigger.scheduleEnabled && !trigger.scheduleContent.hasSelectedWeekday {
            return failValidation(String(localized: "Choisissez au moins un jour d’exécution."))
        }
        if trigger.scheduleEnabled && !trigger.scheduleContent.hasValidReferenceDate {
            return failValidation(String(localized: "Saisissez une date de référence valide au format AAAA/MM/JJ."))
        }
        if strategy == .versioning && !(1...65_535).contains(maxVersionCount) {
            return failValidation(String(localized: "Le nombre maximal de versions doit être compris entre 1 et 65 535."))
        }
        return true
    }

    private func failValidation(_ message: String) -> Bool {
        errorMessage = message
        errorFocused = true
        VoiceOver.announce(message, category: .error, priority: .high)
        return false
    }

    private func save() async {
        guard validate() else { return }
        isSaving = true
        errorMessage = nil
        VoiceOver.announce(String(localized: "Enregistrement de la tâche USB Copy…"), category: .progress)
        let outcome: DSMOperationOutcome
        if let task, let onSave {
            outcome = await onSave(USBCopyTaskSettings(
                id: task.id,
                type: type,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                sourcePath: sourcePath.trimmingCharacters(in: .whitespacesAndNewlines),
                destinationPath: destinationPath.trimmingCharacters(in: .whitespacesAndNewlines),
                copyStrategy: strategy,
                enableRotation: strategy == .versioning && enableRotation,
                rotationPolicy: rotationPolicy,
                maxVersionCount: maxVersionCount,
                removeSourceFile: strategy == .incremental && removeSourceFile,
                notKeepDirectoryStructure: strategy == .incremental && notKeepDirectoryStructure,
                smartCreateDateDirectory: strategy == .incremental && smartCreateDateDirectory,
                renamePhotoVideo: strategy == .incremental && renamePhotoVideo,
                conflictPolicy: conflictPolicy
            ))
        } else if let onCreate {
            outcome = await onCreate(creation)
        } else {
            outcome = .failure(String(localized: "Impossible d’enregistrer cette tâche."))
        }
        isSaving = false
        handle(outcome)
    }

    private var creation: USBCopyTaskCreation {
        USBCopyTaskCreation(
            type: type,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            sourcePath: sourcePath.trimmingCharacters(in: .whitespacesAndNewlines),
            destinationPath: destinationPath.trimmingCharacters(in: .whitespacesAndNewlines),
            copyStrategy: strategy,
            enableRotation: strategy == .versioning ? enableRotation : nil,
            rotationPolicy: strategy == .versioning ? rotationPolicy : nil,
            maxVersionCount: strategy == .versioning ? maxVersionCount : nil,
            removeSourceFile: strategy == .incremental ? removeSourceFile : false,
            notKeepDirectoryStructure: strategy == .incremental ? notKeepDirectoryStructure : nil,
            smartCreateDateDirectory: strategy == .incremental ? smartCreateDateDirectory : nil,
            renamePhotoVideo: strategy == .incremental ? renamePhotoVideo : nil,
            conflictPolicy: strategy == .incremental ? conflictPolicy : nil,
            runWhenPlugIn: trigger.runWhenPlugIn,
            ejectWhenTaskDone: trigger.ejectWhenTaskDone,
            scheduleEnabled: trigger.scheduleEnabled,
            scheduleContent: trigger.scheduleContent,
            filter: filterSelection.filter
        )
    }

    private func handle(_ outcome: DSMOperationOutcome) {
        VoiceOver.announce(outcome, priority: .high)
        switch outcome {
        case .success:
            dismiss()
        case .failure(let message):
            errorMessage = message
            errorFocused = true
        case .cancelled:
            break
        }
    }
}

private struct USBCopyPathField: View {
    let label: LocalizedStringKey
    @Binding var path: String
    let shares: [SharedFolder]
    let isDisabled: Bool

    var body: some View {
        LabeledContent(label) {
            HStack {
                TextField("Chemin", text: $path)
                    .disabled(isDisabled)
                    .accessibilityLabel(label)
                Menu("Choisir un dossier partagé", systemImage: "folder") {
                    ForEach(shares) { share in
                        Button(share.name) { path = "/\(share.name)" }
                    }
                }
                .disabled(isDisabled || shares.isEmpty)
                .help("Choisir un dossier partagé dans la liste")
            }
        }
    }
}
