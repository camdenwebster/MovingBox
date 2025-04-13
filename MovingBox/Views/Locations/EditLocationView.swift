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
    @State private var locationName = ""
    @State private var locationDesc = ""
    @State private var isEditing = false
    @Query(sort: [
        SortDescriptor(\InventoryLocation.name)
    ]) private var locations: [InventoryLocation]
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var tempUIImage: UIImage?
    @State private var loadedImage: UIImage?
    @State private var loadingError: Error?
    @State private var isLoading = false
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
                                photoButton
                            }
                        }
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: UIScreen.main.bounds.height / 3)
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
                                if tempUIImage != nil || loadedImage != nil {
                                    Button("Remove Photo", role: .destructive) {
                                        if let location = location {
                                            location.imageURL = nil
                                            loadedImage = nil
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
        .onChange(of: selectedPhoto) { item in
            Task {
                await loadPhoto(from: item)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(
                showingImageAnalysis: .constant(false),
                analyzingImage: .constant(nil)
            ) { image, _, completion async -> Void in
                if let location = location {
                    let id = UUID().uuidString
                    if let imageURL = try? await OptimizedImageManager.shared.saveImage(image, id: id) {
                        location.imageURL = imageURL
                    }
                } else {
                    tempUIImage = image
                }
                await completion()
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .toolbar {
            if !isNewLocation {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        location?.name = locationName
                        location?.desc = locationDesc
                        isEditing = false
                    } else {
                        isEditing = true
                    }
                }
                .font(isEditing ? .body.bold() : .body)
            } else {
                Button("Save") {
                    Task {
                        let newLocation = InventoryLocation(name: locationName, desc: locationDesc)
                        if let uiImage = tempUIImage {
                            let id = UUID().uuidString
                            if let imageURL = try? await OptimizedImageManager.shared.saveImage(uiImage, id: id) {
                                newLocation.imageURL = imageURL
                            }
                        }
                        modelContext.insert(newLocation)
                        TelemetryManager.shared.trackLocationCreated(name: newLocation.name)
                        print("EditLocationView: Created new location - \(newLocation.name)")
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
    
    private var photoButton: some View {
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
            if tempUIImage != nil || loadedImage != nil {
                Button("Remove Photo", role: .destructive) {
                    if let location = location {
                        location.imageURL = nil
                        loadedImage = nil
                    } else {
                        tempUIImage = nil
                    }
                }
            }
        }
    }
    
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                let id = UUID().uuidString
                do {
                    let imageURL = try await OptimizedImageManager.shared.saveImage(uiImage, id: id)
                    if let location = location {
                        location.imageURL = imageURL
                        loadedImage = uiImage
                    } else {
                        tempUIImage = uiImage
                    }
                    try? modelContext.save()
                }
            }
        } catch {
            loadingError = error
            print("Failed to load photo: \(error.localizedDescription)")
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
