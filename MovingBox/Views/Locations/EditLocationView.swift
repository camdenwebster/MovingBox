//
//  EditLocationView.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import Dependencies
import PhotosUI
import SQLiteData
import SwiftUI

@MainActor
struct EditLocationView: View {
    @Dependency(\.defaultDatabase) var database
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: Router
    @EnvironmentObject var settingsManager: SettingsManager

    let locationID: UUID?
    var presentedInSheet: Bool
    var onDismiss: (() -> Void)?
    var homeID: UUID?

    @FetchAll(SQLiteHome.order(by: \.purchaseDate), animation: .default)
    private var homes: [SQLiteHome]

    // Form state
    @State private var locationName: String
    @State private var locationDesc: String
    @State private var selectedSFSymbol: String?
    @State private var imageURL: URL?
    @State private var isEditing = false
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var loadingError: Error?
    @State private var selectedPhoto: PhotosPickerItem?

    private var activeHome: SQLiteHome? {
        if let homeID = homeID {
            return homes.first { $0.id == homeID }
        }
        guard let activeIdString = settingsManager.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    init(
        locationID: UUID? = nil,
        isEditing: Bool = false,
        presentedInSheet: Bool = false,
        homeID: UUID? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.locationID = locationID
        self.presentedInSheet = presentedInSheet
        self.homeID = homeID
        self.onDismiss = onDismiss
        // State will be loaded in .task from the database if locationID is provided
        _locationName = State(initialValue: "")
        _locationDesc = State(initialValue: "")
        _selectedSFSymbol = State(initialValue: nil)
        _isEditing = State(initialValue: isEditing)
    }

    // Computed properties
    private var isNewLocation: Bool {
        locationID == nil
    }

    private var isEditingEnabled: Bool {
        isNewLocation || isEditing
    }

    var body: some View {
        Form {
            FormTextFieldRow(
                label: "Name",
                text: $locationName,
                isEditing: .constant(isEditingEnabled),
                placeholder: "Kitchen"
            )
            .disabled(!isEditingEnabled)
            .accessibilityIdentifier("location-name-field")

            if isEditingEnabled || selectedSFSymbol != nil {
                Section {
                    Button {
                        if isEditingEnabled {
                            showSymbolPicker = true
                        }
                    } label: {
                        HStack {
                            Text("Icon")
                                .foregroundStyle(.primary)
                            Spacer()
                            if let symbolName = selectedSFSymbol {
                                Image(systemName: symbolName)
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                            } else {
                                Text("None")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(!isEditingEnabled)
                    .accessibilityIdentifier("location-icon-row")
                }
            }

            if isEditingEnabled || !locationDesc.isEmpty {
                Section(header: Text("Description")) {
                    TextEditor(text: $locationDesc)
                        .disabled(!isEditingEnabled)
                        .foregroundStyle(isEditingEnabled ? .primary : .secondary)
                        .frame(height: 100)
                }
            }
            
            // Photo section
            if isEditingEnabled || loadedImage != nil {
                Section(header: EmptyView()) {
                    if let uiImage = loadedImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: UIScreen.main.bounds.width - 32)
                            .frame(height: UIScreen.main.bounds.height / 3)
                            .clipped()
                            .listRowInsets(EdgeInsets())
                            .overlay(alignment: .bottomTrailing) {
                                if isEditingEnabled {
                                    photoPickerButton
                                }
                            }
                    } else if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height / 3)
                    } else if isEditingEnabled {
                        photoPickerButton
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height / 3)
                    }
                }
            }
        }
        .navigationTitle(isNewLocation ? "New Location" : locationName.isEmpty ? "Location" : locationName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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

            ToolbarItem(placement: .confirmationAction) {
                if !isNewLocation {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveExistingLocation()
                            isEditing = false
                            if presentedInSheet {
                                dismissView()
                            }
                        } else {
                            isEditing = true
                        }
                    }
                    .font(isEditing ? .body.bold() : .body)
                } else {
                    Button("Save") {
                        Task {
                            await saveNewLocation()
                            dismissView()
                        }
                    }
                    .disabled(locationName.isEmpty)
                    .bold()
                    .accessibilityIdentifier("location-save-button")
                }
            }
        }
        .sheet(isPresented: $showSymbolPicker) {
            SFSymbolPickerView(selectedSymbol: $selectedSFSymbol)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task(id: locationID) {
            await loadLocationData()
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                    let image = UIImage(data: data)
                {
                    loadedImage = image
                }
            }
        }
    }

    @State private var showSymbolPicker = false

    @ViewBuilder
    private var photoPickerButton: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            if loadedImage != nil {
                Image(systemName: "photo.badge.arrow.down")
                    .font(.title2)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title)
                    Text("Add Photo")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private func loadLocationData() async {
        guard let locationID = locationID else { return }
        do {
            guard
                let location = try await database.read({ db in
                    try SQLiteInventoryLocation.find(locationID).fetchOne(db)
                })
            else { return }

            locationName = location.name
            locationDesc = location.desc
            selectedSFSymbol = location.sfSymbolName
            imageURL = location.imageURL

            // Load photo
            if let url = location.imageURL {
                isLoading = true
                do {
                    let photo = try await OptimizedImageManager.shared.loadImage(url: url)
                    loadedImage = photo
                } catch {
                    loadingError = error
                    print("Failed to load image: \(error)")
                }
                isLoading = false
            }
        } catch {
            print("Failed to load location: \(error)")
        }
    }

    private func saveExistingLocation() {
        guard let locationID = locationID else { return }
        // Capture state values for the closure
        let name = locationName
        let desc = locationDesc
        let symbol = selectedSFSymbol
        let url = imageURL
        do {
            try database.write { db in
                try SQLiteInventoryLocation.find(locationID)
                    .update {
                        $0.name = name
                        $0.desc = desc
                        $0.sfSymbolName = symbol
                        $0.imageURL = url
                    }
                    .execute(db)
            }
        } catch {
            print("Failed to save location: \(error)")
        }
    }

    private func saveNewLocation() async {
        let newID = UUID()

        // Save photo if one was selected
        var savedImageURL: URL?
        if let image = loadedImage {
            let id = UUID().uuidString
            savedImageURL = try? await OptimizedImageManager.shared.saveImage(image, id: id)
        }

        // Capture state values for the closure
        let name = locationName
        let desc = locationDesc
        let symbol = selectedSFSymbol
        let homeId = activeHome?.id

        do {
            try await database.write { db in
                try SQLiteInventoryLocation.insert {
                    SQLiteInventoryLocation(
                        id: newID,
                        name: name,
                        desc: desc,
                        sfSymbolName: symbol,
                        imageURL: savedImageURL,
                        homeID: homeId
                    )
                }.execute(db)
            }
            TelemetryManager.shared.trackLocationCreated(name: name)
            print("EditLocationView: Created new location - \(name)")
        } catch {
            print("Failed to create location: \(error)")
        }
    }

    private func dismissView() {
        if presentedInSheet {
            onDismiss?()
            dismiss()
        } else {
            router.navigateBack()
        }
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    EditLocationView(isEditing: true, presentedInSheet: true)
        .environmentObject(Router())
        .environmentObject(SettingsManager())
}
