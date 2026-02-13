//
//  HomeDetailSettingsView.swift
//  MovingBox
//
//  Created by Claude on 12/20/25.
//

import CloudKit
import Dependencies
import SQLiteData
import SwiftUI

struct HomeDetailSettingsView: View {
    @Dependency(\.defaultDatabase) var database
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager

    @FetchAll(SQLiteHome.order(by: \.name), animation: .default)
    private var allHomes: [SQLiteHome]

    private let homeID: UUID?
    let presentedInSheet: Bool

    @State private var viewModel: HomeDetailSettingsViewModel?

    @State private var tempUIImage: UIImage?
    @State private var loadedImage: UIImage?
    @State private var photoIsLoading = false
    @State private var sharingViewModel: FamilySharingViewModel?
    @State private var showSharingSheet = false
    @State private var showStopSharingConfirmation = false
    @State private var showLeaveSharingConfirmation = false

    private let availableColors: [(name: String, color: Color)] = [
        ("green", .green),
        ("blue", .blue),
        ("purple", .purple),
        ("pink", .pink),
        ("red", .red),
        ("orange", .orange),
        ("yellow", .yellow),
        ("teal", .teal),
        ("cyan", .cyan),
        ("indigo", .indigo),
        ("mint", .mint),
        ("brown", .brown),
    ]

    init(homeID: UUID?, presentedInSheet: Bool = false) {
        self.homeID = homeID
        self.presentedInSheet = presentedInSheet
    }

    var body: some View {
        Group {
            if let viewModel = viewModel {
                formContent(viewModel: viewModel)
                    .navigationTitle(viewModel.isNewHome ? "Add Home" : viewModel.displayName)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbarContent(viewModel: viewModel) }
                    .disabled(viewModel.isCreating)
                    .overlay { loadingOverlay(viewModel: viewModel) }
                    .alert("Delete Home", isPresented: deleteConfirmationBinding(viewModel: viewModel)) {
                        deleteConfirmationButtons(viewModel: viewModel)
                    } message: {
                        Text(
                            "Are you sure you want to delete \(viewModel.displayName)? This will also delete all locations associated with this home. Items will remain but will be unassigned."
                        )
                    }
                    .alert("Cannot Delete", isPresented: deleteErrorBinding(viewModel: viewModel)) {
                        Button("OK") { viewModel.clearDeleteError() }
                    } message: {
                        if let error = viewModel.deleteError {
                            Text(error)
                        }
                    }
                    .alert("Error", isPresented: saveErrorBinding(viewModel: viewModel)) {
                        Button("OK") { viewModel.clearSaveError() }
                    } message: {
                        if let error = viewModel.saveError {
                            Text(error)
                        }
                    }
            } else {
                ProgressView()
                    .navigationTitle(homeID != nil ? "Home" : "Add Home")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task {
            guard let vm = viewModel, let homeID = vm.originalHomeID else { return }

            photoIsLoading = true
            defer { photoIsLoading = false }

            if let photo = try? await database.read({ db in
                try SQLiteHomePhoto.primaryPhoto(for: homeID, in: db)
            }) {
                loadedImage = UIImage(data: photo.data)
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = HomeDetailSettingsViewModel(
                    homeID: homeID,
                    settings: settings,
                    allHomesProvider: { self.allHomes }
                )
                vm.setDatabase(database)
                viewModel = vm
            }
            if sharingViewModel == nil, let homeID {
                sharingViewModel = FamilySharingViewModel(homeID: homeID)
            }
        }
        .task(id: homeID) {
            if let vm = viewModel {
                await vm.loadHomeData()
            }
            if let sharingViewModel {
                await sharingViewModel.fetchSharingState()
            }
        }
        .onChange(of: allHomes) { _, newHomes in
            viewModel?.updateAllHomesProvider { newHomes }
        }
        .sheet(
            isPresented: $showSharingSheet,
            onDismiss: {
                Task {
                    await sharingViewModel?.fetchSharingState()
                }
            }
        ) {
            if let sharingViewModel {
                CloudSharingPrepareView(
                    viewModel: sharingViewModel,
                    isPresented: $showSharingSheet
                )
            }
        }
        .confirmationDialog(
            "Stop Sharing",
            isPresented: $showStopSharingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop Sharing", role: .destructive) {
                Task {
                    await sharingViewModel?.stopSharing()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All participants will lose access to this home.")
        }
        .confirmationDialog(
            "Leave This Home",
            isPresented: $showLeaveSharingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave Home", role: .destructive) {
                Task {
                    await sharingViewModel?.leaveSharedHome()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will lose access to this shared home.")
        }
        .alert(
            "Sharing Error",
            isPresented: Binding(
                get: { sharingViewModel?.error != nil },
                set: { newValue in
                    if !newValue {
                        sharingViewModel?.error = nil
                    }
                }
            )
        ) {
            Button("OK") {
                sharingViewModel?.error = nil
            }
        } message: {
            Text(sharingViewModel?.error ?? "")
        }
        .onDisappear {
            tempUIImage = nil
            loadedImage = nil
        }
    }

    // MARK: - Bindings

    private func deleteConfirmationBinding(viewModel: HomeDetailSettingsViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.showingDeleteConfirmation },
            set: { viewModel.showingDeleteConfirmation = $0 }
        )
    }

    private func deleteErrorBinding(viewModel: HomeDetailSettingsViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.deleteError != nil },
            set: { if !$0 { viewModel.clearDeleteError() } }
        )
    }

    private func saveErrorBinding(viewModel: HomeDetailSettingsViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.clearSaveError() } }
        )
    }

    // MARK: - Form Content

    @ViewBuilder
    private func formContent(viewModel: HomeDetailSettingsViewModel) -> some View {
        Form {
            photoSection(viewModel: viewModel)
            homeDetailsSection(viewModel: viewModel)
            addressSection(viewModel: viewModel)
            organizationSection(viewModel: viewModel)
            sharingSection(viewModel: viewModel)
            deleteSection(viewModel: viewModel)
        }
    }

    // MARK: - Photo Section

    @ViewBuilder
    private func photoSection(viewModel: HomeDetailSettingsViewModel) -> some View {
        if viewModel.isEditing || loadedImage != nil {
            Section(header: EmptyView()) {
                if let uiImage = tempUIImage ?? loadedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                        .listRowInsets(EdgeInsets())
                        .overlay(alignment: .bottomTrailing) {
                            if viewModel.isEditing {
                                PhotoPickerView(
                                    loadedImage: viewModel.isNewHome ? $tempUIImage : $loadedImage,
                                    isLoading: $photoIsLoading
                                )
                            }
                        }
                } else if photoIsLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                } else if viewModel.isEditing {
                    PhotoPickerView(
                        loadedImage: viewModel.isNewHome ? $tempUIImage : $loadedImage,
                        isLoading: $photoIsLoading
                    ) { showPhotoSourceAlert in
                        AddPhotoButton {
                            showPhotoSourceAlert.wrappedValue = true
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Home Details Section

    @ViewBuilder
    private func homeDetailsSection(viewModel: HomeDetailSettingsViewModel) -> some View {
        Section {
            nameField(viewModel: viewModel)
            primaryToggle(viewModel: viewModel)
            colorPicker(viewModel: viewModel)
        } header: {
            Text("Home Details")
        } footer: {
            if viewModel.isEditing && viewModel.name.isEmpty {
                Text("If no name is provided, the street address will be used.")
            }
        }
    }

    @ViewBuilder
    private func nameField(viewModel: HomeDetailSettingsViewModel) -> some View {
        if viewModel.isEditing {
            TextField(
                "Home Name (Optional)",
                text: Binding(
                    get: { viewModel.name },
                    set: { viewModel.name = $0 }
                )
            )
        } else {
            HStack {
                Text("Name")
                Spacer()
                Text(viewModel.displayName)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func primaryToggle(viewModel: HomeDetailSettingsViewModel) -> some View {
        if viewModel.isEditing && !viewModel.isNewHome {
            Toggle(
                "Set as Primary",
                isOn: Binding(
                    get: { viewModel.isPrimary },
                    set: { viewModel.togglePrimary($0) }
                )
            )
        } else if !viewModel.isEditing {
            HStack {
                Text("Primary Home")
                Spacer()
                if viewModel.isPrimary {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    private func colorPicker(viewModel: HomeDetailSettingsViewModel) -> some View {
        if viewModel.isEditing {
            HStack {
                Text("Color")
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(availableColors, id: \.name) { colorOption in
                            colorCircle(for: colorOption, viewModel: viewModel)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } else {
            HStack {
                Text("Color")
                Spacer()
                Circle()
                    .fill(viewModel.displayColor)
                    .frame(width: 24, height: 24)
            }
        }
    }

    private func colorCircle(for colorOption: (name: String, color: Color), viewModel: HomeDetailSettingsViewModel)
        -> some View
    {
        Circle()
            .fill(colorOption.color)
            .frame(width: 32, height: 32)
            .overlay(
                Circle()
                    .strokeBorder(
                        viewModel.colorName == colorOption.name
                            ? Color.primary : Color.clear,
                        lineWidth: 2
                    )
            )
            .onTapGesture {
                viewModel.colorName = colorOption.name
            }
    }

    // MARK: - Address Section

    @ViewBuilder
    private func addressSection(viewModel: HomeDetailSettingsViewModel) -> some View {
        Section("Address") {
            if viewModel.isEditing {
                addressEditingFields(viewModel: viewModel)
            } else {
                addressDisplayFields(viewModel: viewModel)
            }
        }
    }

    // MARK: - Organization Section

    @ViewBuilder
    private func organizationSection(viewModel: HomeDetailSettingsViewModel) -> some View {
        if !viewModel.isNewHome && !viewModel.isEditing {
            Section("Organization") {
                NavigationLink {
                    LocationSettingsView(homeID: viewModel.originalHomeID)
                } label: {
                    Label("Locations", systemImage: "map")
                }
            }
        }
    }

    // MARK: - Sharing Section

    @ViewBuilder
    private func sharingSection(viewModel: HomeDetailSettingsViewModel) -> some View {
        if !viewModel.isNewHome, !viewModel.isEditing, let sharingViewModel {
            Section {
                HStack {
                    Label {
                        Text("Status")
                    } icon: {
                        Image(systemName: sharingViewModel.isSharing ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(sharingViewModel.isSharing ? .green : .secondary)
                    }
                    Spacer()
                    if sharingViewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if sharingViewModel.isSharing {
                        Text("Shared with \(sharingViewModel.participantCount) people")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not Shared")
                            .foregroundStyle(.secondary)
                    }
                }

                if sharingViewModel.isSharing && !sharingViewModel.isOwner {
                    HStack {
                        Label("Shared by", systemImage: "person.fill")
                        Spacer()
                        Text(sharingViewModel.ownerName)
                            .foregroundStyle(.secondary)
                    }
                }

                if sharingViewModel.isSharing && !sharingViewModel.participants.isEmpty {
                    ForEach(sharingViewModel.participants, id: \.userIdentity) { participant in
                        homeParticipantRow(participant: participant)
                    }
                }

                if sharingViewModel.isSharing {
                    Button("Manage Sharing", systemImage: "person.2.badge.gearshape") {
                        showSharingSheet = true
                    }

                    if sharingViewModel.isOwner {
                        Button("Stop Sharing", systemImage: "xmark.circle", role: .destructive) {
                            showStopSharingConfirmation = true
                        }
                    } else {
                        Button(
                            "Leave This Home",
                            systemImage: "rectangle.portrait.and.arrow.right",
                            role: .destructive
                        ) {
                            showLeaveSharingConfirmation = true
                        }
                    }
                } else if settings.isPro {
                    Button("Share This Home", systemImage: "person.badge.plus") {
                        showSharingSheet = true
                    }
                } else {
                    Button("Share This Home (Pro)", systemImage: "person.badge.plus") {
                        router.navigate(to: .subscriptionSettingsView)
                    }
                }
            } header: {
                Text("Sharing")
            } footer: {
                if !settings.isPro && !sharingViewModel.isSharing {
                    Text("A Pro subscription is required to start sharing.")
                } else {
                    Text("Sharing is managed per home.")
                }
            }
        }
    }

    // MARK: - Delete Section

    @ViewBuilder
    private func deleteSection(viewModel: HomeDetailSettingsViewModel) -> some View {
        if !viewModel.isNewHome && viewModel.canDelete {
            Section {
                Button(action: {
                    viewModel.confirmDelete()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Home")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(Color.red)
                    .clipShape(.rect(cornerRadius: UIConstants.cornerRadius))
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text(
                    "Deleting this home will also delete all associated locations. Items will remain but will be unassigned."
                )
            }
        }
    }

    // MARK: - Toolbar Content

    @ToolbarContentBuilder
    private func toolbarContent(viewModel: HomeDetailSettingsViewModel) -> some ToolbarContent {
        if presentedInSheet {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismissView()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }

        ToolbarItem(placement: viewModel.isEditing ? .confirmationAction : .topBarTrailing) {
            if viewModel.isEditing {
                Button("Save") {
                    Task {
                        if viewModel.isNewHome {
                            if let homeID = await viewModel.createHome() {
                                // Save photo BLOB for the new home
                                if let uiImage = tempUIImage,
                                    let imageData = await OptimizedImageManager.shared.processImage(uiImage)
                                {
                                    try? await database.write { db in
                                        try SQLiteHomePhoto.insert {
                                            SQLiteHomePhoto(
                                                id: UUID(),
                                                homeID: homeID,
                                                data: imageData,
                                                sortOrder: 0
                                            )
                                        }.execute(db)
                                    }
                                }
                                tempUIImage = nil
                                dismissView()
                            }
                        } else {
                            // Save photo BLOB for existing home
                            if let uiImage = tempUIImage ?? loadedImage,
                                let homeID = viewModel.originalHomeID,
                                let imageData = await OptimizedImageManager.shared.processImage(uiImage)
                            {
                                try? await database.write { db in
                                    try SQLiteHomePhoto
                                        .where { $0.homeID == homeID }
                                        .delete()
                                        .execute(db)
                                    try SQLiteHomePhoto.insert {
                                        SQLiteHomePhoto(
                                            id: UUID(),
                                            homeID: homeID,
                                            data: imageData,
                                            sortOrder: 0
                                        )
                                    }.execute(db)
                                }
                            }
                            tempUIImage = nil
                            await viewModel.saveChanges()
                            viewModel.isEditing = false
                        }
                    }
                }
                .bold()
                .disabled(viewModel.isNewHome && !viewModel.canSave)
            } else {
                Button("Edit") {
                    viewModel.isEditing = true
                }
                .accessibilityIdentifier("editButton")
            }
        }
    }

    // MARK: - Loading Overlay

    @ViewBuilder
    private func loadingOverlay(viewModel: HomeDetailSettingsViewModel) -> some View {
        if viewModel.isCreating {
            ProgressView()
                .scaleEffect(1.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.2))
        }
    }

    // MARK: - Delete Confirmation Buttons

    @ViewBuilder
    private func deleteConfirmationButtons(viewModel: HomeDetailSettingsViewModel) -> some View {
        Button("Cancel", role: .cancel) {}
        Button("Delete", role: .destructive) {
            if viewModel.deleteHome() {
                dismissView()
            }
        }
    }

    private func dismissView() {
        if presentedInSheet {
            dismiss()
        } else {
            router.navigateBack()
        }
    }

    // MARK: - Address Editing Fields

    @ViewBuilder
    private func addressEditingFields(viewModel: HomeDetailSettingsViewModel) -> some View {
        TextField(
            "Address",
            text: Binding(
                get: { viewModel.addressInput },
                set: { viewModel.addressInput = $0 }
            ),
            axis: .vertical
        )
        .textContentType(.fullStreetAddress)
        .lineLimit(2...5)
    }

    // MARK: - Address Display Fields

    @ViewBuilder
    private func addressDisplayFields(viewModel: HomeDetailSettingsViewModel) -> some View {
        let address = formatDisplayAddress(viewModel)
        if !address.isEmpty {
            Text(address)
                .foregroundStyle(.secondary)
        }
    }

    private func formatDisplayAddress(_ viewModel: HomeDetailSettingsViewModel) -> String {
        var lines: [String] = []
        if !viewModel.address1.isEmpty { lines.append(viewModel.address1) }
        if !viewModel.address2.isEmpty { lines.append(viewModel.address2) }
        var cityStateParts: [String] = []
        if !viewModel.city.isEmpty { cityStateParts.append(viewModel.city) }
        if !viewModel.state.isEmpty { cityStateParts.append(viewModel.state) }
        if !viewModel.zip.isEmpty { cityStateParts.append(viewModel.zip) }
        if !cityStateParts.isEmpty {
            lines.append(cityStateParts.joined(separator: ", "))
        }
        return lines.joined(separator: "\n")
    }

    @ViewBuilder
    private func homeParticipantRow(participant: CKShare.Participant) -> some View {
        HStack {
            Image(systemName: participant.role == .owner ? "crown.fill" : "person.fill")
                .foregroundStyle(participant.role == .owner ? .yellow : .blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(participant.userIdentity.nameComponents?.formatted() ?? "Unknown")
                    .font(.body)
                Text(participant.role == .owner ? "Owner" : "Member")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    NavigationStack {
        HomeDetailSettingsView(homeID: nil, presentedInSheet: true)
            .environmentObject(Router())
            .environmentObject(SettingsManager())
    }
}
