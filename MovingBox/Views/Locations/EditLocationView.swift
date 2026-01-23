//
//  EditLocationView.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import PhotosUI
import SwiftData
import SwiftUI

@MainActor
struct EditLocationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: Router
    @EnvironmentObject var settingsManager: SettingsManager
    var location: InventoryLocation?
    var presentedInSheet: Bool
    var onDismiss: (() -> Void)?
    var home: Home?
    @State private var locationInstance = InventoryLocation()
    @State private var locationName: String
    @State private var locationDesc: String
    @State private var isEditing = false
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) private var locations: [InventoryLocation]
    @Query(sort: \Home.purchaseDate) private var homes: [Home]
    @State private var tempUIImage: UIImage?
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var loadingError: Error?
    @State private var cachedImageURL: URL?
    @State private var showPhotoSourceAlert = false

    private var activeHome: Home? {
        // Use explicitly provided home if available
        if let home = home {
            return home
        }
        guard let activeIdString = settingsManager.activeHomeId,
            let activeId = UUID(uuidString: activeIdString)
        else {
            return homes.first { $0.isPrimary }
        }
        return homes.first { $0.id == activeId } ?? homes.first { $0.isPrimary }
    }

    init(
        location: InventoryLocation? = nil,
        isEditing: Bool = false,
        presentedInSheet: Bool = false,
        home: Home? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.location = location
        self.presentedInSheet = presentedInSheet
        self.home = home
        self.onDismiss = onDismiss
        if let location = location {
            self._locationInstance = State(initialValue: location)
        }
        _locationName = State(initialValue: location?.name ?? "")
        _locationDesc = State(initialValue: location?.desc ?? "")
    }

    // Computed properties
    private var isNewLocation: Bool {
        location == nil
    }

    private var isEditingEnabled: Bool {
        isNewLocation || isEditing
    }

    var body: some View {
        Form {
            if isEditingEnabled || loadedImage != nil {
                Section(header: EmptyView()) {
                    if let uiImage = tempUIImage ?? loadedImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: UIScreen.main.bounds.width - 32)
                            .frame(height: UIScreen.main.bounds.height / 3)
                            .clipped()
                            .listRowInsets(EdgeInsets())
                            .overlay(alignment: .bottomTrailing) {
                                if isEditingEnabled {
                                    PhotoPickerView(
                                        model: $locationInstance,
                                        loadedImage: isNewLocation ? $tempUIImage : $loadedImage,
                                        isLoading: $isLoading
                                    )
                                }
                            }
                    } else if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height / 3)
                    } else if isEditingEnabled {
                        PhotoPickerView(
                            model: $locationInstance,
                            loadedImage: isNewLocation ? $tempUIImage : $loadedImage,
                            isLoading: $isLoading
                        ) { showPhotoSourceAlert in
                            AddPhotoButton {
                                showPhotoSourceAlert.wrappedValue = true
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height / 3)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            FormTextFieldRow(
                label: "Name",
                text: $locationName,
                isEditing: .constant(isEditingEnabled),
                placeholder: "Kitchen"
            )
            .disabled(!isEditingEnabled)
            .onChange(of: locationName) { _, newValue in
                locationInstance.name = newValue
            }

            if isEditingEnabled || !locationDesc.isEmpty {
                Section(header: Text("Description")) {
                    TextEditor(text: $locationDesc)
                        .disabled(!isEditingEnabled)
                        .foregroundColor(isEditingEnabled ? .primary : .secondary)
                        .frame(height: 100)
                        .onChange(of: locationDesc) { _, newValue in
                            locationInstance.desc = newValue
                        }
                }
            }
        }
        .navigationTitle(isNewLocation ? "New Location" : "Edit \(location?.name ?? "Location")")
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
                            if let existingLocation = location {
                                existingLocation.name = locationInstance.name
                                existingLocation.desc = locationInstance.desc
                                existingLocation.imageURL = locationInstance.imageURL
                                try? modelContext.save()
                            }
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
                            if let uiImage = tempUIImage {
                                let id = UUID().uuidString
                                if let imageURL = try? await OptimizedImageManager.shared.saveImage(uiImage, id: id) {
                                    locationInstance.imageURL = imageURL
                                }
                            }

                            // Assign active home to new location
                            locationInstance.home = activeHome

                            modelContext.insert(locationInstance)
                            TelemetryManager.shared.trackLocationCreated(name: locationInstance.name)
                            print("EditLocationView: Created new location - \(locationInstance.name)")
                            print("EditLocationView: Assigned to home - \(activeHome?.name ?? "nil")")
                            print("EditLocationView: Total number of locations after save: \(locations.count)")
                            dismissView()
                        }
                    }
                    .disabled(locationName.isEmpty)
                    .bold()
                }
            }
        }
        .task(id: location?.imageURL) {
            guard let location = location,
                let imageURL = location.imageURL,
                !isLoading
            else { return }

            // If the imageURL changed, clear the cached image
            if cachedImageURL != imageURL {
                await MainActor.run {
                    loadedImage = nil
                    cachedImageURL = imageURL
                }
            }

            // Only load if we don't have a cached image for this URL
            guard loadedImage == nil else { return }

            await MainActor.run {
                isLoading = true
            }

            defer {
                Task { @MainActor in
                    isLoading = false
                }
            }

            do {
                let photo = try await location.photo
                await MainActor.run {
                    loadedImage = photo
                }
            } catch {
                await MainActor.run {
                    loadingError = error
                    print("Failed to load image: \(error)")
                }
            }
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
    do {
        let previewer = try Previewer()

        return EditLocationView(location: previewer.location)
            .modelContainer(previewer.container)
            .environmentObject(Router())
            .environmentObject(SettingsManager())
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
