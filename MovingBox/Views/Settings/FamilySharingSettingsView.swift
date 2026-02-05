//
//  FamilySharingSettingsView.swift
//  MovingBox
//
//  Created by Camden Webster on 2/4/26.
//

import CloudKit
import SwiftUI

struct FamilySharingSettingsView: View {
    @State private var viewModel = FamilySharingViewModel()
    @State private var showSharingSheet = false
    @State private var showStopSharingConfirmation = false

    var body: some View {
        List {
            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if let error = viewModel.error {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Error", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                sharingStatusSection
                participantsSection
                actionsSection
            }

            infoSection
        }
        .navigationTitle("Family Sharing")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchSharingState()
        }
        .sheet(isPresented: $showSharingSheet) {
            CloudSharingPrepareView(
                viewModel: viewModel,
                isPresented: $showSharingSheet
            )
        }
        .confirmationDialog(
            "Stop Sharing",
            isPresented: $showStopSharingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop Sharing", role: .destructive) {
                Task {
                    await viewModel.stopSharing()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Other people will no longer have access to your MovingBox data. This cannot be undone."
            )
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var sharingStatusSection: some View {
        Section {
            HStack {
                Label {
                    Text("Status")
                } icon: {
                    Image(systemName: viewModel.isSharing ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(viewModel.isSharing ? .green : .secondary)
                }

                Spacer()

                Text(viewModel.isSharing ? "Sharing Active" : "Not Sharing")
                    .foregroundStyle(.secondary)
            }

            if viewModel.isSharing {
                HStack {
                    Label("Owner", systemImage: "person.fill")
                    Spacer()
                    Text(viewModel.ownerName)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Sharing Status")
        }
    }

    @ViewBuilder
    private var participantsSection: some View {
        if viewModel.isSharing && !viewModel.participants.isEmpty {
            Section {
                ForEach(viewModel.participants, id: \.userIdentity) { participant in
                    ParticipantRow(participant: participant)
                }
            } header: {
                Text("Participants")
            } footer: {
                Text("People with access to your MovingBox data.")
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            Button {
                showSharingSheet = true
            } label: {
                Label(
                    viewModel.isSharing ? "Manage Sharing" : "Start Sharing",
                    systemImage: viewModel.isSharing ? "person.2.badge.gearshape" : "person.badge.plus"
                )
            }

            if viewModel.isSharing && viewModel.isOwner {
                Button(role: .destructive) {
                    showStopSharingConfirmation = true
                } label: {
                    Label("Stop Sharing", systemImage: "xmark.circle")
                }
            }
        }
    }

    @ViewBuilder
    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    icon: "house.2",
                    title: "Share Everything",
                    description: "All your homes, rooms, items, labels, and policies are shared."
                )

                InfoRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Real-time Sync",
                    description: "Changes sync automatically between all participants."
                )

                InfoRow(
                    icon: "lock.shield",
                    title: "Secure",
                    description: "Data is encrypted and only shared with people you invite."
                )
            }
            .padding(.vertical, 8)
        } header: {
            Text("About Family Sharing")
        }
    }
}

// MARK: - Supporting Views

private struct ParticipantRow: View {
    let participant: CKShare.Participant

    var body: some View {
        HStack {
            Image(systemName: participantIcon)
                .foregroundStyle(participantColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(participantName)
                    .font(.body)

                HStack(spacing: 4) {
                    Text(roleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if participant.acceptanceStatus == .pending {
                        Text("(Pending)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            Text(permissionText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var participantName: String {
        participant.userIdentity.nameComponents?.formatted() ?? "Unknown"
    }

    private var participantIcon: String {
        switch participant.role {
        case .owner:
            return "crown.fill"
        case .privateUser:
            return "person.fill"
        case .publicUser:
            return "person"
        @unknown default:
            return "person"
        }
    }

    private var participantColor: Color {
        switch participant.role {
        case .owner:
            return .yellow
        case .privateUser:
            return .blue
        case .publicUser:
            return .secondary
        @unknown default:
            return .secondary
        }
    }

    private var roleText: String {
        switch participant.role {
        case .owner:
            return "Owner"
        case .privateUser:
            return "Member"
        case .publicUser:
            return "Public"
        @unknown default:
            return "Unknown"
        }
    }

    private var permissionText: String {
        switch participant.permission {
        case .readOnly:
            return "View Only"
        case .readWrite:
            return "Can Edit"
        case .none:
            return "No Access"
        case .unknown:
            return ""
        @unknown default:
            return ""
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        FamilySharingSettingsView()
    }
}
