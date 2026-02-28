//
//  JoiningShareView.swift
//  MovingBox
//
//  Created by Camden Webster on 2/6/26.
//

import CloudKit
import Dependencies
import GRDB
import SQLiteData
import SwiftUI

struct JoiningShareView: View {
    let shareMetadata: CKShare.Metadata
    let onComplete: () -> Void

    @Dependency(\.defaultSyncEngine) private var syncEngine
    @State private var phase: Phase = .accepting
    @State private var errorMessage: String?

    private enum Phase {
        case accepting
        case success
        case error
    }

    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        switch phase {
                        case .accepting:
                            acceptingContent
                        case .success:
                            successContent
                        case .error:
                            errorContent
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }

                if phase == .success {
                    OnboardingContinueButton(action: finishJoining, title: "Get Started")
                        .accessibilityIdentifier("joining-share-continue-button")
                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                }
            }
        }
        .onboardingBackground()
        .task {
            guard phase == .accepting else { return }
            await acceptShare()
        }
    }

    // MARK: - Phase Content

    private var acceptingContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .padding(.bottom, 8)

            OnboardingHeaderText(text: "Joining Shared Inventory")

            OnboardingDescriptionText(
                text: "Setting up your access to the shared inventory..."
            )

            ProgressView()
                .controlSize(.large)
                .padding(.top, 8)
        }
    }

    private var successContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .padding(.bottom, 8)

            OnboardingHeaderText(text: "You're All Set!")

            OnboardingDescriptionText(
                text: "You now have access to the shared inventory."
            )

            VStack(alignment: .leading, spacing: 12) {
                OnboardingFeatureRow(
                    icon: "eye.fill",
                    title: "View shared items",
                    description: "Browse everything in the shared inventory"
                )

                OnboardingFeatureRow(
                    icon: "plus.circle.fill",
                    title: "Add new items",
                    description: "Contribute items to the shared collection"
                )

                OnboardingFeatureRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Stay in sync",
                    description: "Changes sync automatically across devices"
                )
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
                    .fill(.ultraThinMaterial)
            }
            .padding(.horizontal)
        }
    }

    private var errorContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
                .padding(.bottom, 8)

            OnboardingHeaderText(text: "Something Went Wrong")

            if let errorMessage {
                OnboardingDescriptionText(text: errorMessage)
            }

            VStack(spacing: 12) {
                OnboardingContinueButton(
                    action: {
                        phase = .accepting
                        Task { await acceptShare() }
                    }, title: "Try Again"
                )
                .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))

                Button("Skip and Start Fresh") {
                    finishJoining()
                }
                .foregroundStyle(.secondary)
                .padding(.bottom, 30)
            }
        }
    }

    // MARK: - Actions

    private func acceptShare() async {
        do {
            try await syncEngine.acceptShare(metadata: shareMetadata)
            withAnimation {
                phase = .success
            }
        } catch {
            errorMessage = "Could not join the shared inventory. Check your network connection and try again."
            withAnimation {
                phase = .error
            }
        }
    }

    private func finishJoining() {
        OnboardingManager.markOnboardingCompleteStatic()
        onComplete()
    }
}

/// Existing-user invite acceptance shell flow.
/// `i9i.4` expands this into full join/merge/start-fresh choices.
struct ExistingUserShareAcceptanceView: View {
    let shareMetadata: CKShare.Metadata
    let onComplete: () -> Void

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.defaultSyncEngine) private var syncEngine
    @EnvironmentObject private var settings: SettingsManager

    @State private var phase: Phase = .choosingOption
    @State private var errorState: ErrorState?
    @State private var showStartFreshConfirmation = false
    @State private var sharedHomeName: String?
    @State private var mergeCandidates: [MergeCandidate] = []
    @State private var selectedMergeCandidateID: UUID?
    @State private var isLoadingMergeCandidates = false
    @State private var didDeleteDataForStartFresh = false
    @State private var hasAcceptedShareForMerge = false
    @State private var mergePreAcceptanceSnapshot: MergePreAcceptanceSnapshot?
    @State private var completionState: CompletionState?
    @State private var lastAttemptedAction: FlowAction?

    private enum FlowAction: Equatable {
        case joinAlongside
        case startFresh
        case merge(sourceHomeID: UUID, deduplication: MergeDeduplicationPreference)
    }

    private enum MergeDeduplicationPreference: Equatable {
        case mergeMatchingNames
        case keepAllSeparate
    }

    private enum Phase: Equatable {
        case choosingOption
        case mergeHomePicker
        case mergeDedupChoice
        case working(FlowAction)
        case success
        case error
    }

    private struct MergeCandidate: Identifiable {
        let id: UUID
        let name: String
        let itemCount: Int
        let locationCount: Int
    }

    private struct SharedHomeInfo {
        let id: UUID
        let name: String
    }

    private struct MergePreAcceptanceSnapshot {
        let homeIDs: Set<UUID>
        let locationIDs: Set<UUID>
        let itemIDs: Set<UUID>
        let labelIDs: Set<UUID>
        let insurancePolicyIDs: Set<UUID>
    }

    private struct MergeSummary: Equatable {
        let movedItems: Int
        let mergedLocations: Int
        let mergedLabels: Int
        let mergedPolicies: Int
    }

    private enum CompletionState: Equatable {
        case joinAlongside
        case merge(summary: MergeSummary)
        case startFresh
    }

    private enum ErrorRecovery {
        case retryWithCancel
        case retryOnly
    }

    private struct ErrorState {
        let message: String
        let recovery: ErrorRecovery
    }

    private enum MergeFlowError: LocalizedError {
        case selectedHomeNotFound
        case sharedHomeNotFound
        case cannotMergeIntoSharedHome
        case missingPreAcceptanceSnapshot
    }

    private var ownerDisplayName: String {
        shareMetadata.share.owner.userIdentity.nameComponents?.formatted() ?? "another user"
    }

    private var metadataHomeName: String? {
        if let title = shareMetadata.share[CKShare.SystemFieldKey.title] as? String,
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return title
        }

        if let rootRecordName = shareMetadata.rootRecord?["name"] as? String,
            !rootRecordName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return rootRecordName
        }

        return nil
    }

    private var homeDisplayName: String {
        sharedHomeName ?? metadataHomeName ?? "shared home"
    }

    private var phaseTitle: String {
        switch phase {
        case .choosingOption:
            return "You're joining \(ownerDisplayName)'s \(homeDisplayName)"
        case .mergeHomePicker:
            return "Select a Home to Merge"
        case .mergeDedupChoice:
            return "Choose Merge Preference"
        case .working(.joinAlongside):
            return "Joining Shared Home"
        case .working(.startFresh):
            return "Starting Fresh"
        case .working(.merge(_, _)):
            return "Merging Into Shared Home"
        case .success:
            return "You're All Set!"
        case .error:
            return "Could Not Complete Invite"
        }
    }

    private var successMessage: String {
        switch completionState {
        case .joinAlongside:
            return "You now have access to \(homeDisplayName)."
        case .merge:
            return "Your items have been moved to \(homeDisplayName)."
        case .startFresh:
            return "You're all set with \(homeDisplayName)."
        case .none:
            return "You now have access to \(homeDisplayName)."
        }
    }

    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        switch phase {
                        case .choosingOption:
                            choosingOptionContent
                        case .mergeHomePicker:
                            mergeHomePickerContent
                        case .mergeDedupChoice:
                            mergeDedupChoiceContent
                        case .working(let action):
                            workingContent(for: action)
                        case .success:
                            successContent
                        case .error:
                            errorContent
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }

            if phase == .success {
                OnboardingContinueButton(
                    action: { onComplete() },
                    title: "Get Started"
                )
                .accessibilityIdentifier("existing-share-get-started-button")
                .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
            }
        }
        .onboardingBackground()
        .task {
            if sharedHomeName == nil {
                sharedHomeName = metadataHomeName
            }
        }
        .confirmationDialog(
            "Start Fresh?",
            isPresented: $showStartFreshConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete My Data and Join", role: .destructive) {
                Task { await performStartFresh() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes your current local inventory data before joining the shared home.")
        }
        .task(id: phase) {
            guard phase == .mergeHomePicker else { return }
            await loadMergeCandidates()
        }
    }

    private var choosingOptionContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .padding(.bottom, 8)

            OnboardingHeaderText(text: phaseTitle)

            OnboardingDescriptionText(
                text:
                    "Choose how you'd like to join. You can keep your current homes, prepare to merge one home, or start fresh."
            )

            VStack(spacing: 12) {
                actionCardButton(
                    icon: "person.2.fill",
                    iconColor: .green,
                    title: "Join Alongside",
                    description:
                        "Keep your existing homes and add \(homeDisplayName) to your inventory.",
                    isRecommended: true,
                    role: nil
                ) {
                    Task { await performJoinAlongside() }
                }

                actionCardButton(
                    icon: "arrow.triangle.merge",
                    iconColor: .blue,
                    title: "Merge Into Shared Home",
                    description:
                        "Move items from one of your existing homes into \(homeDisplayName).",
                    isRecommended: false,
                    role: nil
                ) {
                    withAnimation {
                        selectedMergeCandidateID = nil
                        phase = .mergeHomePicker
                    }
                }

                actionCardButton(
                    icon: "trash.fill",
                    iconColor: .red,
                    title: "Start Fresh",
                    description:
                        "Remove your existing local data and use only \(homeDisplayName).",
                    isRecommended: false,
                    role: .destructive
                ) {
                    showStartFreshConfirmation = true
                }
            }
            .padding(.horizontal)
        }
    }

    private var mergeHomePickerContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 70))
                .foregroundStyle(.blue)
                .padding(.bottom, 8)

            OnboardingHeaderText(text: phaseTitle)

            OnboardingDescriptionText(
                text: "Choose which home you'd like to merge into \(homeDisplayName)."
            )

            if isLoadingMergeCandidates {
                ProgressView()
                    .controlSize(.large)
                    .padding(.top, 8)
            } else if mergeCandidates.isEmpty {
                Text("No homes available to merge.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(mergeCandidates) { candidate in
                        Button {
                            selectedMergeCandidateID = candidate.id
                            withAnimation {
                                phase = .mergeDedupChoice
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "house")
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.name)
                                        .font(.headline)
                                    Text("\(candidate.itemCount) items • \(candidate.locationCount) locations")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(
                                .ultraThinMaterial, in: .rect(cornerRadius: UIConstants.cornerRadius))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            Button("Back") {
                withAnimation {
                    phase = .choosingOption
                }
            }
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
    }

    private var mergeDedupChoiceContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 70))
                .foregroundStyle(.blue)
                .padding(.bottom, 8)

            OnboardingHeaderText(text: phaseTitle)

            if let selectedMergeCandidate {
                OnboardingDescriptionText(
                    text:
                        "Merge \"\(selectedMergeCandidate.name)\" into \(homeDisplayName). Choose how to handle matching names."
                )

                VStack(spacing: 8) {
                    Text(
                        "\(selectedMergeCandidate.itemCount) items • \(selectedMergeCandidate.locationCount) locations"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            } else {
                Text("Select a home first to continue.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                actionCardButton(
                    icon: "arrow.triangle.merge",
                    iconColor: .blue,
                    title: "Merge matching names",
                    description:
                        "Locations and labels with the same name will be combined. The owner's versions take priority.",
                    isRecommended: true,
                    role: nil
                ) {
                    Task { await performMergeSelection(deduplication: .mergeMatchingNames) }
                }

                actionCardButton(
                    icon: "square.stack.3d.up.fill",
                    iconColor: .blue,
                    title: "Keep all separate",
                    description:
                        "Everything will be kept as-is. You may see duplicate names.",
                    isRecommended: false,
                    role: nil
                ) {
                    Task { await performMergeSelection(deduplication: .keepAllSeparate) }
                }
            }
            .padding(.horizontal)

            Button("Back") {
                withAnimation {
                    phase = .mergeHomePicker
                }
            }
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
    }

    private func workingContent(for action: FlowAction) -> some View {
        let description: String
        switch action {
        case .joinAlongside:
            description = "Setting up your access to \(homeDisplayName)..."
        case .startFresh:
            description = "Deleting your current data and setting up access to \(homeDisplayName)..."
        case .merge(let sourceHomeID, let deduplication):
            let selectedHomeName =
                mergeCandidates.first(where: { $0.id == sourceHomeID })?.name ?? "your selected home"
            let dedupText: String
            if deduplication == .mergeMatchingNames {
                dedupText = "matching names will be combined"
            } else {
                dedupText = "all names will remain separate"
            }
            description =
                "Preparing merge from \(selectedHomeName) into \(homeDisplayName); \(dedupText)."
        }

        return VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .padding(.bottom, 8)

            OnboardingHeaderText(text: phaseTitle)

            OnboardingDescriptionText(
                text: description
            )

            ProgressView()
                .controlSize(.large)
                .padding(.top, 8)
        }
    }

    private var successContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .padding(.bottom, 8)

            OnboardingHeaderText(text: "You're All Set!")

            OnboardingDescriptionText(
                text: successMessage
            )

            if case .merge(let summary) = completionState {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Moved \(summary.movedItems) items")
                        .font(.subheadline)
                    if summary.mergedLocations > 0 {
                        Text("Combined \(summary.mergedLocations) locations")
                            .font(.subheadline)
                    }
                    if summary.mergedLabels > 0 {
                        Text("Combined \(summary.mergedLabels) labels")
                            .font(.subheadline)
                    }
                    if summary.mergedPolicies > 0 {
                        Text("Combined \(summary.mergedPolicies) insurance policies")
                            .font(.subheadline)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(16)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: UIConstants.cornerRadius))
                .padding(.horizontal)
            }
        }
    }

    private var errorContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
                .padding(.bottom, 8)

            OnboardingHeaderText(text: "Could Not Join")

            if let errorState {
                OnboardingDescriptionText(text: errorState.message)
            }

            VStack(spacing: 12) {
                OnboardingContinueButton(
                    action: {
                        Task { await retryLastAction() }
                    },
                    title: "Try Again"
                )
                .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))

                if errorState?.recovery == .retryWithCancel {
                    Button("Cancel") {
                        onComplete()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 30)
        }
    }

    private func performJoinAlongside() async {
        lastAttemptedAction = .joinAlongside
        errorState = nil
        completionState = nil
        phase = .working(.joinAlongside)

        do {
            try await syncEngine.acceptShare(metadata: shareMetadata)
            await waitForShareFetchCompletion()
            await refreshSharedHomeName()
            completionState = .joinAlongside
            withAnimation {
                phase = .success
            }
        } catch {
            presentError(
                "Could not join \(homeDisplayName). Check your network connection and try again.",
                recovery: .retryWithCancel
            )
        }
    }

    private func performStartFresh() async {
        lastAttemptedAction = .startFresh
        errorState = nil
        completionState = nil
        phase = .working(.startFresh)

        do {
            if !didDeleteDataForStartFresh {
                try await deleteAllLocalData()
                didDeleteDataForStartFresh = true
            }
        } catch {
            presentError(
                "Could not delete your local data before joining \(homeDisplayName). No data was changed.",
                recovery: .retryWithCancel
            )
            return
        }

        do {
            try await syncEngine.acceptShare(metadata: shareMetadata)
            await waitForShareFetchCompletion()
            await refreshSharedHomeName()
            completionState = .startFresh

            withAnimation {
                phase = .success
            }
        } catch {
            presentError(
                "Your local data was deleted, but we couldn't accept \(homeDisplayName). Try Again will retry share acceptance only.",
                recovery: .retryOnly
            )
        }
    }

    private func retryLastAction() async {
        switch lastAttemptedAction {
        case .joinAlongside:
            await performJoinAlongside()
        case .startFresh:
            await performStartFresh()
        case .merge(let sourceHomeID, let deduplication):
            await performMergeSelection(
                sourceHomeID: sourceHomeID,
                deduplication: deduplication
            )
        case .none:
            withAnimation {
                phase = .choosingOption
            }
        }
    }

    private func refreshSharedHomeName() async {
        guard let sharedHome = try? await resolveSharedHome() else { return }
        sharedHomeName = sharedHome.name
        settings.activeHomeId = sharedHome.id.uuidString
    }

    private var selectedMergeCandidate: MergeCandidate? {
        guard let selectedMergeCandidateID else { return nil }
        return mergeCandidates.first(where: { $0.id == selectedMergeCandidateID })
    }

    private func performMergeSelection(deduplication: MergeDeduplicationPreference) async {
        guard let selectedMergeCandidateID else {
            withAnimation {
                phase = .mergeHomePicker
            }
            return
        }

        await performMergeSelection(
            sourceHomeID: selectedMergeCandidateID,
            deduplication: deduplication
        )
    }

    private func performMergeSelection(
        sourceHomeID: UUID,
        deduplication: MergeDeduplicationPreference
    ) async {
        selectedMergeCandidateID = sourceHomeID
        lastAttemptedAction = .merge(sourceHomeID: sourceHomeID, deduplication: deduplication)
        errorState = nil
        completionState = nil
        phase = .working(.merge(sourceHomeID: sourceHomeID, deduplication: deduplication))
        await routeToMergeExecution(sourceHomeID: sourceHomeID, deduplication: deduplication)
    }

    private func routeToMergeExecution(
        sourceHomeID: UUID,
        deduplication: MergeDeduplicationPreference
    ) async {
        enum MergeStage {
            case snapshot
            case acceptShare
            case waitForSync
            case resolveSharedHome
            case mergeTransaction
        }

        var stage: MergeStage = .snapshot

        do {
            if mergePreAcceptanceSnapshot == nil {
                mergePreAcceptanceSnapshot = try await snapshotJoinerRecords()
            }

            guard let mergePreAcceptanceSnapshot else {
                throw MergeFlowError.missingPreAcceptanceSnapshot
            }

            if !hasAcceptedShareForMerge {
                stage = .acceptShare
                try await syncEngine.acceptShare(metadata: shareMetadata)
                hasAcceptedShareForMerge = true
            }

            stage = .waitForSync
            await waitForShareFetchCompletion()

            stage = .resolveSharedHome
            guard let sharedHome = try await resolveSharedHome() else {
                throw MergeFlowError.sharedHomeNotFound
            }
            sharedHomeName = sharedHome.name
            settings.activeHomeId = sharedHome.id.uuidString

            stage = .mergeTransaction
            let summary = try await executeMergeTransaction(
                sourceHomeID: sourceHomeID,
                sharedHomeID: sharedHome.id,
                deduplication: deduplication,
                preAcceptanceSnapshot: mergePreAcceptanceSnapshot
            )

            completionState = .merge(summary: summary)
            withAnimation {
                phase = .success
            }
        } catch {
            switch stage {
            case .acceptShare, .waitForSync:
                presentError(
                    "Could not accept \(homeDisplayName). Check your network connection and try again.",
                    recovery: .retryWithCancel
                )
            case .mergeTransaction:
                presentError(
                    "Merge failed and was rolled back completely. No partial changes were saved.",
                    recovery: .retryWithCancel
                )
            case .snapshot, .resolveSharedHome:
                presentError(
                    "Could not prepare merge into \(homeDisplayName). Try again.",
                    recovery: .retryWithCancel
                )
            }
        }
    }

    private func resolveSharedHome() async throws -> SharedHomeInfo? {
        guard let rootRecordID = shareMetadata.hierarchicalRootRecordID else { return nil }

        return try await database.read { db in
            let homes = try SQLiteHome.fetchAll(db)
            guard
                let matchedHome = try homes.first(where: { home in
                    let metadata: SyncMetadata?
                    do {
                        metadata = try SyncMetadata.find(home.syncMetadataID).fetchOne(db)
                    } catch {
                        if isMissingSyncMetadataTableError(error) {
                            return false
                        }
                        throw error
                    }
                    guard let metadata else {
                        return false
                    }
                    return metadata.recordName == rootRecordID.recordName
                        && metadata.zoneName == rootRecordID.zoneID.zoneName
                        && metadata.ownerName == rootRecordID.zoneID.ownerName
                })
            else { return nil }

            let displayName: String
            if !matchedHome.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                displayName = matchedHome.name
            } else if !matchedHome.address1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                displayName = matchedHome.address1
            } else {
                displayName = "shared home"
            }

            return SharedHomeInfo(id: matchedHome.id, name: displayName)
        }
    }

    private func waitForShareFetchCompletion() async {
        let timeoutNanos = UInt64(20 * 1_000_000_000)
        let start = DispatchTime.now().uptimeNanoseconds

        while syncEngine.isFetchingChanges {
            if DispatchTime.now().uptimeNanoseconds - start > timeoutNanos {
                return
            }
            try? await Task.sleep(for: .milliseconds(150))
        }
    }

    private func snapshotJoinerRecords() async throws -> MergePreAcceptanceSnapshot {
        try await database.read { db in
            MergePreAcceptanceSnapshot(
                homeIDs: Set(try SQLiteHome.select(\.id).fetchAll(db)),
                locationIDs: Set(try SQLiteInventoryLocation.select(\.id).fetchAll(db)),
                itemIDs: Set(try SQLiteInventoryItem.select(\.id).fetchAll(db)),
                labelIDs: Set(try SQLiteInventoryLabel.select(\.id).fetchAll(db)),
                insurancePolicyIDs: Set(try SQLiteInsurancePolicy.select(\.id).fetchAll(db))
            )
        }
    }

    private func executeMergeTransaction(
        sourceHomeID: UUID,
        sharedHomeID: UUID,
        deduplication: MergeDeduplicationPreference,
        preAcceptanceSnapshot: MergePreAcceptanceSnapshot
    ) async throws -> MergeSummary {
        try await database.write { db in
            guard preAcceptanceSnapshot.homeIDs.contains(sourceHomeID) else {
                throw MergeFlowError.selectedHomeNotFound
            }

            guard sourceHomeID != sharedHomeID else {
                throw MergeFlowError.cannotMergeIntoSharedHome
            }

            guard try SQLiteHome.find(sourceHomeID).fetchOne(db) != nil else {
                throw MergeFlowError.selectedHomeNotFound
            }
            guard try SQLiteHome.find(sharedHomeID).fetchOne(db) != nil else {
                throw MergeFlowError.sharedHomeNotFound
            }

            var movedItemCount = 0
            var mergedLocationCount = 0

            let sharedHomeLocations =
                try SQLiteInventoryLocation
                .where { $0.homeID == sharedHomeID }
                .fetchAll(db)
            var sharedLocationByName: [String: SQLiteInventoryLocation.ID] = [:]
            for location in sharedHomeLocations {
                let key = Self.normalizedName(location.name)
                if !key.isEmpty && sharedLocationByName[key] == nil {
                    sharedLocationByName[key] = location.id
                }
            }

            let sourceHomeLocations =
                try SQLiteInventoryLocation
                .where { $0.homeID == sourceHomeID }
                .fetchAll(db)

            for sourceLocation in sourceHomeLocations {
                let normalizedLocationName = Self.normalizedName(sourceLocation.name)
                let shouldDeduplicateLocation =
                    deduplication == .mergeMatchingNames
                    && !normalizedLocationName.isEmpty
                    && sharedLocationByName[normalizedLocationName] != nil

                if shouldDeduplicateLocation, let sharedLocationID = sharedLocationByName[normalizedLocationName] {
                    let itemIDs =
                        try SQLiteInventoryItem
                        .where { $0.locationID == sourceLocation.id }
                        .select(\.id)
                        .fetchAll(db)

                    movedItemCount += itemIDs.count
                    for itemID in itemIDs {
                        try SQLiteInventoryItem.find(itemID).update {
                            $0.locationID = sharedLocationID
                            $0.homeID = sharedHomeID
                        }.execute(db)
                    }

                    try SQLiteInventoryLocation.find(sourceLocation.id).delete().execute(db)
                    mergedLocationCount += 1
                } else {
                    try SQLiteInventoryLocation.find(sourceLocation.id).update {
                        $0.homeID = sharedHomeID
                    }.execute(db)
                }
            }

            let remainingSourceHomeItemIDs =
                try SQLiteInventoryItem
                .where { $0.homeID == sourceHomeID }
                .select(\.id)
                .fetchAll(db)

            movedItemCount += remainingSourceHomeItemIDs.count
            for itemID in remainingSourceHomeItemIDs {
                try SQLiteInventoryItem.find(itemID).update {
                    $0.homeID = sharedHomeID
                }.execute(db)
            }

            let mergedLabelCount: Int
            let mergedPolicyCount: Int

            if deduplication == .mergeMatchingNames {
                mergedLabelCount = try Self.deduplicateLabels(
                    db: db,
                    preAcceptanceSnapshot: preAcceptanceSnapshot
                )
                mergedPolicyCount = try Self.migratePoliciesToSharedHome(
                    db: db,
                    sourceHomeID: sourceHomeID,
                    sharedHomeID: sharedHomeID,
                    deduplicateMatchingNames: true
                )
            } else {
                mergedLabelCount = 0
                mergedPolicyCount = try Self.migratePoliciesToSharedHome(
                    db: db,
                    sourceHomeID: sourceHomeID,
                    sharedHomeID: sharedHomeID,
                    deduplicateMatchingNames: false
                )
            }

            try SQLiteHome.find(sourceHomeID).delete().execute(db)

            return MergeSummary(
                movedItems: movedItemCount,
                mergedLocations: mergedLocationCount,
                mergedLabels: mergedLabelCount,
                mergedPolicies: mergedPolicyCount
            )
        }
    }

    private nonisolated static func deduplicateLabels(
        db: Database,
        preAcceptanceSnapshot: MergePreAcceptanceSnapshot
    ) throws -> Int {
        let allLabels = try SQLiteInventoryLabel.fetchAll(db)
        let joinerLabels = allLabels.filter { preAcceptanceSnapshot.labelIDs.contains($0.id) }
        let ownerLabels = allLabels.filter { !preAcceptanceSnapshot.labelIDs.contains($0.id) }

        var ownerLabelByName: [String: SQLiteInventoryLabel] = [:]
        for ownerLabel in ownerLabels {
            let key = normalizedName(ownerLabel.name)
            if !key.isEmpty && ownerLabelByName[key] == nil {
                ownerLabelByName[key] = ownerLabel
            }
        }

        var mergedLabelCount = 0

        for joinerLabel in joinerLabels {
            let key = normalizedName(joinerLabel.name)
            guard let ownerLabel = ownerLabelByName[key], ownerLabel.id != joinerLabel.id else { continue }
            var affectedItemIDs: Set<UUID> = []

            let associations =
                try SQLiteInventoryItemLabel
                .where { $0.inventoryLabelID == joinerLabel.id }
                .fetchAll(db)

            for association in associations {
                affectedItemIDs.insert(association.inventoryItemID)
                let duplicateExists =
                    try SQLiteInventoryItemLabel
                    .where {
                        $0.inventoryItemID == association.inventoryItemID
                            && $0.inventoryLabelID == ownerLabel.id
                    }
                    .fetchOne(db) != nil

                if duplicateExists {
                    try SQLiteInventoryItemLabel.find(association.id).delete().execute(db)
                } else {
                    try SQLiteInventoryItemLabel.find(association.id).update {
                        $0.inventoryLabelID = ownerLabel.id
                    }.execute(db)
                }
            }

            for itemID in affectedItemIDs {
                let labelIDs =
                    try SQLiteInventoryItemLabel
                    .where { $0.inventoryItemID == itemID }
                    .fetchAll(db)
                    .map(\.inventoryLabelID)
                try SQLiteInventoryItem.find(itemID).update {
                    $0.labelIDs = labelIDs
                }.execute(db)
            }

            try SQLiteInventoryLabel.find(joinerLabel.id).delete().execute(db)
            mergedLabelCount += 1
        }

        return mergedLabelCount
    }

    private nonisolated static func migratePoliciesToSharedHome(
        db: Database,
        sourceHomeID: UUID,
        sharedHomeID: UUID,
        deduplicateMatchingNames: Bool
    ) throws -> Int {
        let sourceHomePolicyJoins =
            try SQLiteHomeInsurancePolicy
            .where { $0.homeID == sourceHomeID }
            .fetchAll(db)

        guard !sourceHomePolicyJoins.isEmpty else { return 0 }

        guard deduplicateMatchingNames else {
            for join in sourceHomePolicyJoins {
                try movePolicyJoin(join, to: sharedHomeID, db: db)
            }
            return 0
        }

        let sharedHomePolicyJoins =
            try SQLiteHomeInsurancePolicy
            .where { $0.homeID == sharedHomeID }
            .fetchAll(db)

        let policies = try SQLiteInsurancePolicy.fetchAll(db)
        let policyByID = Dictionary(uniqueKeysWithValues: policies.map { ($0.id, $0) })

        var sharedPolicyByName: [String: SQLiteInsurancePolicy] = [:]
        for sharedJoin in sharedHomePolicyJoins {
            guard let policy = policyByID[sharedJoin.insurancePolicyID] else { continue }
            let key = normalizedName(policy.providerName)
            if !key.isEmpty && sharedPolicyByName[key] == nil {
                sharedPolicyByName[key] = policy
            }
        }

        var mergedPolicyCount = 0

        for sourceJoin in sourceHomePolicyJoins {
            guard let sourcePolicy = policyByID[sourceJoin.insurancePolicyID] else {
                try movePolicyJoin(sourceJoin, to: sharedHomeID, db: db)
                continue
            }

            let key = normalizedName(sourcePolicy.providerName)
            if let sharedPolicy = sharedPolicyByName[key], sharedPolicy.id != sourcePolicy.id {
                try SQLiteHomeInsurancePolicy.find(sourceJoin.id).delete().execute(db)

                let sharedPolicyJoinExists =
                    try SQLiteHomeInsurancePolicy
                    .where {
                        $0.homeID == sharedHomeID
                            && $0.insurancePolicyID == sharedPolicy.id
                    }
                    .fetchOne(db) != nil
                if !sharedPolicyJoinExists {
                    try SQLiteHomeInsurancePolicy.insert {
                        SQLiteHomeInsurancePolicy(
                            id: UUID(),
                            homeID: sharedHomeID,
                            insurancePolicyID: sharedPolicy.id
                        )
                    }.execute(db)
                }

                let sourcePolicyStillUsed =
                    try SQLiteHomeInsurancePolicy
                    .where { $0.insurancePolicyID == sourcePolicy.id }
                    .fetchOne(db) != nil
                if !sourcePolicyStillUsed {
                    try SQLiteInsurancePolicy.find(sourcePolicy.id).delete().execute(db)
                }

                mergedPolicyCount += 1
            } else {
                try movePolicyJoin(sourceJoin, to: sharedHomeID, db: db)
            }
        }

        return mergedPolicyCount
    }

    private nonisolated static func movePolicyJoin(
        _ join: SQLiteHomeInsurancePolicy,
        to homeID: UUID,
        db: Database
    ) throws {
        let duplicateExists =
            try SQLiteHomeInsurancePolicy
            .where {
                $0.homeID == homeID
                    && $0.insurancePolicyID == join.insurancePolicyID
            }
            .fetchOne(db) != nil

        if duplicateExists {
            try SQLiteHomeInsurancePolicy.find(join.id).delete().execute(db)
        } else {
            try SQLiteHomeInsurancePolicy.find(join.id).update {
                $0.homeID = homeID
            }.execute(db)
        }
    }

    private nonisolated static func normalizedName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func presentError(_ message: String, recovery: ErrorRecovery) {
        errorState = ErrorState(message: message, recovery: recovery)
        withAnimation {
            phase = .error
        }
    }

    private func loadMergeCandidates() async {
        isLoadingMergeCandidates = true
        defer { isLoadingMergeCandidates = false }

        do {
            mergeCandidates = try await database.read { db in
                let homes = try SQLiteHome.order(by: \.name).fetchAll(db)
                return try homes.map { home in
                    let itemCount =
                        try SQLiteInventoryItem
                        .where { $0.homeID == home.id }
                        .count()
                        .fetchOne(db) ?? 0
                    let locationCount =
                        try SQLiteInventoryLocation
                        .where { $0.homeID == home.id }
                        .count()
                        .fetchOne(db) ?? 0

                    let displayName: String
                    if !home.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        displayName = home.name
                    } else if !home.address1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        displayName = home.address1
                    } else {
                        displayName = "Unnamed Home"
                    }

                    return MergeCandidate(
                        id: home.id,
                        name: displayName,
                        itemCount: itemCount,
                        locationCount: locationCount
                    )
                }
            }
        } catch {
            mergeCandidates = []
        }
    }

    private func deleteAllLocalData() async throws {
        try await database.write { db in
            try SQLiteInventoryItemLabel.delete().execute(db)
            try SQLiteHomeInsurancePolicy.delete().execute(db)

            try SQLiteInventoryItemPhoto.delete().execute(db)
            try SQLiteInventoryLocationPhoto.delete().execute(db)
            try SQLiteHomePhoto.delete().execute(db)

            try SQLiteInventoryItem.delete().execute(db)
            try SQLiteInventoryLocation.delete().execute(db)
            try SQLiteInventoryLabel.delete().execute(db)
            try SQLiteInsurancePolicy.delete().execute(db)
            try SQLiteHome.delete().execute(db)
        }

        settings.activeHomeId = nil
        clearOptimizedImageCache()
    }

    private func clearOptimizedImageCache() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        let imagesDirectory = documentsDirectory.appendingPathComponent("OptimizedImages")
        try? FileManager.default.removeItem(at: imagesDirectory)
    }

    @ViewBuilder
    private func actionCardButton(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        isRecommended: Bool,
        role: ButtonRole?,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if isRecommended {
                            Text("Recommended")
                                .font(.caption2)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.15), in: Capsule())
                        }
                    }

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: UIConstants.cornerRadius))
        }
        .buttonStyle(.plain)
    }
}
