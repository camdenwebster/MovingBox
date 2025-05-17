//
//  EditLocationView.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import SwiftData
import SwiftUI
import PhotosUI

@MainActor
struct EditLocationView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var router: Router
    var location: InventoryLocation?
    @State private var locationInstance = InventoryLocation()
    @State private var locationName: String
    @State private var locationDesc: String
    @State private var isEditing = false
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) private var locations: [InventoryLocation]
    @State private var tempUIImage: UIImage?
    @State private var loadedImage: UIImage?
    @State private var loadedImages: [UIImage] = []
    @State private var isLoading = false
    @State private var loadingError: Error?
    @State private var showPhotoSourceAlert = false

    init(location: InventoryLocation? = nil,
         isEditing: Bool = false) {
        self.location = location
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
                                        loadedImages: $loadedImages,
                                        isLoading: $isLoading
                                    ) { showSourceAlert in
                                        AddPhotoButton {
                                            showSourceAlert.wrappedValue = true
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: UIScreen.main.bounds.height / 3)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                            }
                    } else if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height / 3)
                    } else if isEditingEnabled {
                        PhotoPickerView(
                            model: $locationInstance,
                            loadedImages: $loadedImages,
                            isLoading: $isLoading
                        ) { showSourceAlert in
                            AddPhotoButton {
                                showSourceAlert.wrappedValue = true
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height / 3)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            FormTextFieldRow(label: "Name",
                           text: $locationName,
                           isEditing: .constant(isEditingEnabled),
                           placeholder: "Kitchen")
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
        .navigationTitle(isNewLocation ? "New Location" : "\(location?.name ?? "") Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
                        modelContext.insert(locationInstance)
                        TelemetryManager.shared.trackLocationCreated(name: locationInstance.name)
                        print("EditLocationView: Created new location - \(locationInstance.name)")
                        print("EditLocationView: Total number of locations after save: \(locations.count)")
                        router.navigateBack()
                    }
                }
                .disabled(locationName.isEmpty)
                .bold()
            }
        }
        .task(id: location?.imageURL) {
            guard let location = location else { return }
            isLoading = true
            defer { isLoading = false }
            
            do {
                loadedImage = try await location.photo
            } catch {
                loadingError = error
                print("Failed to load image: \(error)")
            }
        }
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        
        return EditLocationView(location: previewer.location)
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
