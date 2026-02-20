import SwiftUI

struct FamilySharingSettingsView: View {
    @State private var viewModel = GlobalSharingSettingsViewModel()
    @State private var showInviteSheet = false
    @State private var showEnableConfirmation = false

    var body: some View {
        List {
            statusSection

            if viewModel.isSharingEnabled {
                policySection
                membersSection
                invitesSection
                homesSummarySection
            }
        }
        .navigationTitle("Family Sharing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isSharingEnabled {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Invite", systemImage: "person.badge.plus") {
                        showInviteSheet = true
                    }
                    .accessibilityIdentifier("family-sharing-invite-button")
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteMemberSheet(viewModel: viewModel)
        }
        .alert(
            "Enable Family Sharing?",
            isPresented: $showEnableConfirmation
        ) {
            Button("Enable") {
                Task {
                    await viewModel.setSharingEnabled(true)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can keep specific homes private and exclude them from automatic sharing.")
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
            HStack {
                Label("Family Sharing", systemImage: "person.2.fill")
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Text(viewModel.isSharingEnabled ? "Enabled" : "Disabled")
                        .foregroundStyle(viewModel.isSharingEnabled ? .green : .secondary)
                }
            }

            if viewModel.isSharingEnabled {
                Text(viewModel.shareStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Enable Family Sharing", systemImage: "person.2.badge.gearshape") {
                    showEnableConfirmation = true
                }
                .accessibilityIdentifier("family-sharing-enable-button")
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
    private var invitesSection: some View {
        Section {
            if viewModel.pendingInvites.isEmpty {
                Text("No pending invites.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.pendingInvites) { invite in
                    inviteRow(invite)
                }
            }
        } header: {
            Text("Pending Invites")
        } footer: {
            Text("Invites become members automatically with access to non-private homes.")
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

    private func inviteRow(_ invite: SQLiteHouseholdInvite) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "envelope.badge")
                .foregroundStyle(.orange)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(invite.displayName.isEmpty ? invite.email : invite.displayName)
                Text(invite.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Mark Accepted") {
                Task {
                    await viewModel.acceptInvite(inviteID: invite.id)
                }
            }
            .buttonStyle(.borderless)
        }
        .accessibilityIdentifier("family-sharing-invite-\(invite.id.uuidString)")
    }
}

private struct InviteMemberSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: GlobalSharingSettingsViewModel

    @State private var displayName = ""
    @State private var email = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Invite Details") {
                    TextField("Name", text: $displayName)
                        .textInputAutocapitalization(.words)

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                }
            }
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send Invite") {
                        isSubmitting = true
                        Task {
                            await viewModel.createInvite(displayName: displayName, email: email)
                            isSubmitting = false
                            dismiss()
                        }
                    }
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                    .bold()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FamilySharingSettingsView()
    }
}
