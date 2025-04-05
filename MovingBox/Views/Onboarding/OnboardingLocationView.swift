import SwiftUI
import PhotosUI
import SwiftData

struct OnboardingLocationView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var manager: OnboardingManager
    
    @State private var locationName = ""
    @State private var locationDesc = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var tempUIImage: UIImage?
    @State private var showPhotoSourceAlert = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showValidationAlert = false
    
    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        OnboardingHeaderText(text: "Add Your First Location")
                        
                        OnboardingDescriptionText(text: "A Location is a room in your home. If you're at home, start with the room you're currently in. Otherwise, start with any room that has valuable possessions.")
                        
                        // Photo Section
                        Group {
                            if let uiImage = tempUIImage {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: UIScreen.main.bounds.width - 32)
                                    .frame(height: UIScreen.main.bounds.height / 3)
                                    .clipped()
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
                                    }
                            } else {
                                Button {
                                    showPhotoSourceAlert = true
                                } label: {
                                    AddPhotoButton()
                                }
                                .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                }
                            }
                        }
                        
                        // Name Field
                        TextField("Location Name (e.g. Kitchen, Living Room)", text: $locationName)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                        
                        // Optional Description
                        TextField("Description (optional)", text: $locationDesc, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...)
                            .padding(.horizontal)
                        
                        // Add some bottom padding to ensure content doesn't get hidden behind the button
                        Spacer()
                            .frame(height: 100)
                    }
                }
                
                // Continue button in its own VStack outside of ScrollView
                VStack {
                    OnboardingContinueButton {
                        if locationName.isEmpty {
                            showValidationAlert = true
                        } else {
                            saveLocationAndContinue()
                        }
                    }
                }
            }
        }
        .onboardingBackground()
        .onChange(of: selectedPhoto, loadPhoto)
        .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
            Button("Take Photo") {
                showCamera = true
            }
            Button("Choose from Library") {
                showPhotoPicker = true
            }
            if tempUIImage != nil {
                Button("Remove Photo", role: .destructive) {
                    tempUIImage = nil
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image, needsAIAnalysis, completion in
                tempUIImage = image
                completion()
            }
            .onboardingCamera()
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
        let location = InventoryLocation(name: locationName, desc: locationDesc)
        if let imageData = tempUIImage?.jpegData(compressionQuality: 0.8) {
            location.data = imageData
        }
        modelContext.insert(location)
        TelemetryManager.shared.trackLocationCreated(name: location.name)
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
