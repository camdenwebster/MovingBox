import SQLiteData
import SwiftUI

struct FamilySharingSettingsView: View {
    @Environment(\.featureFlags) private var featureFlags
    @State private var viewModel = GlobalSharingSettingsViewModel()
    @State private var shareRecord: SharedRecord?

    var body: some View {
        List {
            statusSection

            if viewModel.isSharingEnabled {
                if featureFlags.familySharingScopingEnabled {
                    policySection
                }
                membersSection
                if featureFlags.familySharingScopingEnabled {
                    homesSummarySection
                }
            }
        }
        .navigationTitle("Family Sharing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isSharingEnabled {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Invite", systemImage: "person.badge.plus") {
                        Task {
                            do {
                                shareRecord = try await viewModel.prepareShareRecord()
                            } catch {
                                viewModel.errorMessage =
                                    "Failed to prepare sharing sheet: \(error.localizedDescription)"
                            }
                        }
                    }
                    .accessibilityIdentifier("family-sharing-invite-button")
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .sheet(item: $shareRecord) { sharedRecord in
            SQLiteData.CloudSharingView(
                sharedRecord: sharedRecord,
                availablePermissions: [.allowReadWrite, .allowPrivate],
                didFinish: { _ in
                    Task {
                        await viewModel.load()
                    }
                },
                didStopSharing: {
                    Task {
                        await viewModel.handleCloudShareStopped()
                    }
                }
            )
        }
        .alert(
            "Sharing Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        viewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        Section("Status") {
            Toggle(
                isOn: Binding(
                    get: { viewModel.isSharingEnabled },
                    set: { newValue in
                        Task {
                            await viewModel.setSharingEnabled(newValue)
                        }
                    }
                )
            ) {
                Label("Family Sharing", systemImage: "person.2.fill")
            }
            .disabled(viewModel.isLoading)
            .accessibilityIdentifier("family-sharing-toggle")

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            if viewModel.isSharingEnabled {
                Text(viewModel.shareStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Use the invite button to share your household with iCloud participants.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var policySection: some View {
        Section {
            Picker(
                "Access Policy",
                selection: Binding(
                    get: { viewModel.defaultAccessPolicy },
                    set: { viewModel.defaultAccessPolicy = $0 }
                )
            ) {
                Text("All Homes").tag(HouseholdDefaultAccessPolicy.allHomesShared)
                Text("Owner Scoped").tag(HouseholdDefaultAccessPolicy.ownerScopesHomes)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("family-sharing-policy-picker")
        } header: {
            Text("Default Home Access")
        } footer: {
            Text("Home-specific overrides can still grant or deny access per member.")
        }
    }

    @ViewBuilder
    private var membersSection: some View {
        Section {
            if viewModel.nonOwnerMembers.isEmpty {
                Text("No members yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.nonOwnerMembers) { member in
                    memberRow(member)
                }
            }
        } header: {
            Text("Members")
        }
    }

    @ViewBuilder
    private var homesSummarySection: some View {
        Section {
            HStack {
                Label("Homes marked private", systemImage: "house.and.flag.fill")
                Spacer()
                Text("\(viewModel.privateHomeCount)")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Private Homes")
        } footer: {
            Text("Manage private-home and per-member overrides from each home's settings.")
        }
    }

    private func memberRow(_ member: SQLiteHouseholdMember) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.fill")
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName.isEmpty ? member.contactEmail : member.displayName)
                if !member.contactEmail.isEmpty {
                    Text(member.contactEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Remove", role: .destructive) {
                Task {
                    await viewModel.revokeMember(memberID: member.id)
                }
            }
            .buttonStyle(.borderless)
        }
        .accessibilityIdentifier("family-sharing-member-\(member.id.uuidString)")
    }
}

#Preview {
    NavigationStack {
        FamilySharingSettingsView()
    }
}
