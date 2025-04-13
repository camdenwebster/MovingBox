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
    @State private var showPhotoSourceAlert = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showingImageAnalysis = false
    @State private var analyzingImage: UIImage?

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
                        .scaledToFill()
                        .frame(maxWidth: UIScreen.main.bounds.width - 32)
                        .frame(height: UIScreen.main.bounds.height / 3)
                        .clipped()
                        .listRowInsets(EdgeInsets())
                        .overlay(alignment: .bottomTrailing) {
                            if isEditingEnabled {
                                Button {
                                    showPhotoSourceAlert = true
                                } label: {
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Circle().fill(.black.opacity(0.6)))
                                        .padding(8)
                                }
                                .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
                                    Button("Take Photo") {
                                        showCamera = true
                                    }
                                    Button("Choose from Library") {
                                        showPhotoPicker = true
                                    }
                                    if tempUIImage != nil || location?.photo != nil {
                                        Button("Remove Photo", role: .destructive) {
                                            if let location = location {
                                                location.data = nil
                                            } else {
                                                tempUIImage = nil
                                            }
                                        }
                                    }
                                }
                            }
                        }
                } else {
                    if isEditingEnabled {
                        AddPhotoButton(action: {
                            showPhotoSourceAlert = true
                        })
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height / 3)
                            .foregroundStyle(.secondary)
                            .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
                                Button("Take Photo") {
                                    showCamera = true
                                }
                                Button("Choose from Library") {
                                    showPhotoPicker = true
                                }
                                if tempUIImage != nil || location?.photo != nil {
                                    Button("Remove Photo", role: .destructive) {
                                        if let location = location {
                                            location.data = nil
                                        } else {
                                            tempUIImage = nil
                                        }
                                    }
                                }
                            }
                    }
                }
            }
            FormTextFieldRow(label: "Name", text: $locationName, isEditing: $isEditing, placeholder: "Kitchen")
                .disabled(!isEditingEnabled)
                .foregroundColor(isEditingEnabled ? .primary : .secondary)
            if isEditingEnabled || !locationDesc.isEmpty {
                Section("Description") {
                    TextEditor(text: $locationDesc)
                        .disabled(!isEditingEnabled)
                        .foregroundColor(isEditingEnabled ? .primary : .secondary)
                        .frame(height: 100)
                }
            }
        }
        .navigationTitle(isNewLocation ? "New Location" : "\(location?.name ?? "") Details")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto, loadPhoto)
        .sheet(isPresented: $showCamera) {
            CameraView(
                showingImageAnalysis: .constant(false),
                analyzingImage: .constant(nil)
            ) { image, _, completion in
                if let location = location {
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        location.data = imageData
                    }
                } else {
                    tempUIImage = image
                }
                completion()
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
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
                .font(isEditing ? .body.bold() : .body)
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
                    router.navigateBack()
                }
                .disabled(locationName.isEmpty)
                .bold()
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
