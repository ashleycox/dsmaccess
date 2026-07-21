//
//  FileTransfersView.swift
//  dsmaccess
//
//  File d'attente accessible des transferts File Station.
//

import SwiftUI

struct FileTransfersView: View {
    @Bindable var vm: FileBrowserViewModel
    let cancelActiveTransfers: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var focusHeading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transferts")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusHeading)

            if vm.transfers.isEmpty {
                ContentUnavailableView(
                    "Aucun transfert",
                    systemImage: "arrow.up.arrow.down",
                    description: Text("Les téléchargements et les envois apparaîtront ici.")
                )
            } else {
                List(vm.transfers) { transfer in
                    TransferRow(transfer: transfer)
                }
                .accessibilityLabel("Historique des transferts")
            }

            HStack {
                Button("Effacer les transferts terminés") {
                    vm.clearFinishedTransfers()
                    VoiceOver.announce(
                        String(localized: "Transferts terminés effacés"),
                        category: .result
                    )
                }
                .disabled(!vm.transfers.contains(where: { !$0.state.isActive }))
                .help("Conserver uniquement les transferts en attente ou en cours")

                Spacer()

                Button("Annuler les transferts en cours", role: .destructive) {
                    cancelActiveTransfers()
                    VoiceOver.announce(
                        String(localized: "Annulation des transferts demandée"),
                        category: .progress
                    )
                }
                .disabled(!vm.hasActiveTransfers)
                .help("Annuler le transfert actif et ceux qui restent en attente")

                Button("Fermer", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 580, minHeight: 360)
        .task { focusHeading = true }
    }
}

private struct TransferRow: View {
    let transfer: FileTransferRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(transfer.name, systemImage: transfer.direction.systemImage)
                Spacer()
                Text(transfer.state.label)
                    .foregroundStyle(transfer.state.isFailure ? .red : .secondary)
            }

            if let fraction = transfer.progress?.fractionCompleted {
                ProgressView(value: fraction)
                    .accessibilityLabel(progressAccessibilityLabel)
                    .accessibilityValue(fraction.formatted(.percent.precision(.fractionLength(0))))
            } else if transfer.state == .running {
                ProgressView()
                    .accessibilityLabel(progressAccessibilityLabel)
            }

            if let progress = transfer.progress {
                Text(progressLabel(progress))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if case .failed(let message) = transfer.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel(String(localized: "Erreur : \(message)"))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private var progressAccessibilityLabel: String {
        switch transfer.direction {
        case .upload:
            String(localized: "Progression de l’envoi de \(transfer.name)")
        case .download:
            String(localized: "Progression du téléchargement de \(transfer.name)")
        }
    }

    private func progressLabel(_ progress: DSMTransferProgress) -> String {
        let completed = progress.completedBytes.formatted(.byteCount(style: .file))
        guard let total = progress.totalBytes else { return completed }
        return String(localized: "\(completed) sur \(total.formatted(.byteCount(style: .file)))")
    }
}

private extension FileTransferDirection {
    var systemImage: String {
        switch self {
        case .upload: "arrow.up.circle"
        case .download: "arrow.down.circle"
        }
    }
}

private extension FileTransferState {
    var isActive: Bool {
        self == .queued || self == .running
    }

    var isFailure: Bool {
        if case .failed = self { true } else { false }
    }

    var label: String {
        switch self {
        case .queued: String(localized: "En attente")
        case .running: String(localized: "En cours")
        case .completed: String(localized: "Terminé")
        case .cancelled: String(localized: "Annulé")
        case .failed: String(localized: "Échec")
        }
    }
}
