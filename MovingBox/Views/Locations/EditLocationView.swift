//
//  EditLocationView.swift
//  MovingBox
//
//  Created by Camden Webster on 5/18/24.
//

import SwiftData
import SwiftUI
import PhotosUI

struct EditLocationView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    var location: InventoryLocation?
    @State private var locationName = ""
    @State private var locationDesc = ""
    @State private var isEditing = false
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) var locations: [InventoryLocation]
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var tempUIImage: UIImage?
    
    // Computed properties
    private var isNewLocation: Bool {
        location == nil
    }
    
    private var isEditingEnabled: Bool {
        isNewLocation || isEditing
    }
    
    var body: some View {
        Form {
            Section {
                if let uiImage = tempUIImage ?? location?.photo {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                }
                if isEditingEnabled {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Select Image", systemImage: "photo")
                    }
                }
            }
            Section("Location Name") {
                TextField("Attic, Basement, Kitchen, Office, etc.", text: $locationName)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)
            }
            if isEditingEnabled || !locationDesc.isEmpty {
                Section("Location Description") {
                    TextField("Enter a Description", text: $locationDesc)
                        .disabled(!isEditingEnabled)
                        .foregroundColor(isEditingEnabled ? .primary : .secondary)
                }
            }
        }
        .navigationTitle(isNewLocation ? "New Location" : "\(location?.name ?? "") Details")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto, loadPhoto)
        .toolbar {
            if !isNewLocation {
                // Edit/Save button for existing locations
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        // Save changes
                        location?.name = locationName
                        location?.desc = locationDesc
                        isEditing = false
                    } else {
                        isEditing = true
                    }
                }
            } else {
                // Save button for new locations
                Button("Save") {
                    let newLocation = InventoryLocation(name: locationName, desc: locationDesc)
                    if let imageData = tempUIImage?.jpegData(compressionQuality: 0.8) {
                        newLocation.data = imageData
                    }
                    modelContext.insert(newLocation)
                    TelemetryManager.shared.trackLocationCreated(name: newLocation.name)
                    print("EditLocationView: Created new location - \(newLocation.name)")
                    print("EditLocationView: Total number of locations after save: \(locations.count)")
                    router.path.removeLast()
                }
                .disabled(locationName.isEmpty)
            }
        }
        .onAppear {
            if let existingLocation = location {
                // Initialize editing fields with existing values
                locationName = existingLocation.name
                locationDesc = existingLocation.desc
            }
        }
    }
    
    private func loadPhoto() {
        Task {
            if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        if let location = location {
                            // Existing location
                            location.data = data
                        } else {
                            // New location
                            tempUIImage = uiImage
                        }
                    }
                }
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
