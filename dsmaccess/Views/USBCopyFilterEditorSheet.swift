//
//  USBCopyFilterEditorSheet.swift
//  dsmaccess
//

import SwiftUI

struct USBCopyFilterEditorSheet: View {
    let task: USBCopyTask
    let onSave: (USBCopyFilter) async -> DSMOperationOutcome

    @State private var selection: USBCopyFilterSelection
    @State private var isSaving = false
    @State private var errorMessage: String?
    @AccessibilityFocusState private var headingFocused: Bool
    @AccessibilityFocusState private var errorFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(
        task: USBCopyTask,
        filter: USBCopyFilter,
        onSave: @escaping (USBCopyFilter) async -> DSMOperationOutcome
    ) {
        self.task = task
        self.onSave = onSave
        _selection = State(initialValue: USBCopyFilterSelection(filter: filter))
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Filtre de fichiers de \(task.name)")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($headingFocused)
                .padding()
            Form {
                Section("Types de fichiers à copier") {
                    USBCopyFilterFields(selection: $selection)
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
                if isSaving { ProgressView("Enregistrement…").controlSize(.small) }
                Spacer()
                Button("Annuler", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isSaving)
                Button("Enregistrer") { Task { await save() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSaving)
            }
            .padding()
        }
        .frame(minWidth: 620, minHeight: 680)
        .onAppear {
            headingFocused = true
            VoiceOver.announce(
                String(localized: "Modifier le filtre de fichiers de \(task.name)"),
                category: .navigation
            )
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        VoiceOver.announce(String(localized: "Enregistrement…"), category: .progress)
        let outcome = await onSave(selection.filter)
        isSaving = false
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
