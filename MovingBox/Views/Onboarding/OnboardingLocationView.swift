import SwiftUI
import PhotosUI
import SwiftData

struct OnboardingLocationView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var manager: OnboardingManager
    @EnvironmentObject private var settings: SettingsManager
    
    @Query private var locations: [InventoryLocation]
    
    @State private var locationName = ""
    @State private var locationDesc = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var tempUIImage: UIImage?
    @State private var showPhotoSourceAlert = false
    @State private var showingCamera = false
    @State private var showPhotoPicker = false
    @State private var showValidationAlert = false
    
    private func loadExistingData() {
        if let existingLocation = locations.first {
            locationName = existingLocation.name
            locationDesc = existingLocation.desc
            if let imageData = existingLocation.data {
                tempUIImage = UIImage(data: imageData)
            }
        }
    }
    
    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 20) {
                            OnboardingHeaderText(text: "Add Your First Location")
                            
                            OnboardingDescriptionText(text: "A Location is a room in your home. If you're at home, start with the room you're currently in. Otherwise, start with any room that has valuable possessions.")
                                .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                            
                            // Photo Section
                            Group {
                                if let uiImage = tempUIImage {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                                        .frame(height: UIScreen.main.bounds.height / 3)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(alignment: .bottomTrailing) {
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
                                            .accessibilityIdentifier("onboarding-location-change-photo-button")
                                        }
                                } else {
                                    AddPhotoButton(action: {
                                        showPhotoSourceAlert = true
                                    })
                                    .accessibilityIdentifier("onboarding-location-add-photo-button")
                                    .padding()
                                    .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                                    .background {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.ultraThinMaterial)
                                    }
                                    .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
                                        Button("Take Photo") {
                                            showingCamera = true
                                        }
                                        .accessibilityIdentifier("takePhoto")
                                        Button("Choose from Library") {
                                            showPhotoPicker = true
                                        }
                                        .accessibilityIdentifier("chooseFromLibrary")
                                        if tempUIImage != nil {
                                            Button("Remove Photo", role: .destructive) {
                                                tempUIImage = nil
                                            }
                                            .accessibilityIdentifier("removePhoto")
                                        }
                                    }
                                }
                            }
                            
                            // Text Fields
                            VStack(spacing: 16) {
                                TextField("Location Name", text: $locationName)
                                    .accessibilityIdentifier("onboarding-location-name-field")
                                    .textFieldStyle(.roundedBorder)
                                
                                TextField("Description", text: $locationDesc, axis: .vertical)
                                    .accessibilityIdentifier("onboarding-location-description-field")
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...)
                            }
                            .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                        }
                        .frame(maxWidth: .infinity)
                        
                        Spacer()
                            .frame(height: 100)
                    }
                }
                
                VStack {
                    OnboardingContinueButton {
                        if locationName.isEmpty {
                            showValidationAlert = true
                        } else {
                            saveLocationAndContinue()
                        }
                    }
                    .accessibilityIdentifier("onboarding-location-continue-button")
                    .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onboardingBackground()
        .onChange(of: selectedPhoto, loadPhoto)
        .onAppear(perform: loadExistingData)
        .sheet(isPresented: $showingCamera, onDismiss: nil) {
            CameraView(
                showingImageAnalysis: .constant(false),
                analyzingImage: .constant(nil)
            ) { image, _, completion in
                tempUIImage = image
                completion()
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .alert("Missing Details", isPresented: $showValidationAlert) {
            Button("Go Back") { }
            Button("Continue Anyway") {
                saveLocationAndContinue()
            }
        } message: {
            Text("Some details haven't been filled out. Would you like to go back and complete them or continue anyway?")
        }
    }
    
    private func loadPhoto() {
        Task {
            if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        tempUIImage = uiImage
                    }
                }
            }
        }
    }
    
    private func saveLocationAndContinue() {
        if let existingLocation = locations.first {
            existingLocation.name = locationName
            existingLocation.desc = locationDesc
            if let imageData = tempUIImage?.jpegData(compressionQuality: 0.8) {
                existingLocation.data = imageData
            }
        } else {
            let location = InventoryLocation(name: locationName, desc: locationDesc)
            if let imageData = tempUIImage?.jpegData(compressionQuality: 0.8) {
                location.data = imageData
            }
            modelContext.insert(location)
            TelemetryManager.shared.trackLocationCreated(name: location.name)
        }
        manager.moveToNext()
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        
        return OnboardingLocationView()
            .environmentObject(OnboardingManager())
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
