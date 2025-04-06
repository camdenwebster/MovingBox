import SwiftUI
import PhotosUI
import SwiftData

struct OnboardingHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var manager: OnboardingManager
    @EnvironmentObject private var settings: SettingsManager
    
    @Query private var homes: [Home]
    
    @State private var homeName = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var tempUIImage: UIImage?
    @State private var showPhotoSourceAlert = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showValidationAlert = false
    
    private func loadExistingData() {
        if let existingHome = homes.first {
            homeName = existingHome.name
            if let imageData = existingHome.data {
                tempUIImage = UIImage(data: imageData)
            }
        }
    }
    
    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        OnboardingHeaderText(text: "Add Home Details")
                        
                        OnboardingDescriptionText(text: "Add some details about your home to customize your experience")
                        
                        // Photo Section
                        Group {
                            if let uiImage = tempUIImage {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: UIScreen.main.bounds.width - 32)
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
                                    }
                            } else {
                                AddPhotoButton(action: {
                                    showPhotoSourceAlert = true
                                })
                                .accessibilityIdentifier("onboarding-home-add-photo-button")
                                .padding()
                                .background {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                }
                            }
                        }
                        
                        // Name Field
                        TextField("Home Name", text: $homeName)
                            .accessibilityIdentifier("onboarding-home-name-field")
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                        
                        // Add some bottom padding to ensure content doesn't get hidden behind the button
                        Spacer()
                            .frame(height: 100)
                    }
                }
                
                // Continue button in its own VStack outside of ScrollView
                VStack {
                    OnboardingContinueButton {
                        if homeName.isEmpty {
                            showValidationAlert = true
                        } else {
                            saveHomeAndContinue()
                        }
                    }
                    .accessibilityIdentifier("onboarding-home-continue-button")
                }
            }
        }
        .onboardingBackground()
        .onChange(of: selectedPhoto, loadPhoto)
        .onAppear(perform: loadExistingData)
        .confirmationDialog("Choose Photo Source", isPresented: $showPhotoSourceAlert) {
            Button("Take Photo") {
                showCamera = true
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
        .fullScreenCover(isPresented: $showCamera) {
            NavigationStack {
                PhotoCaptureFlow { image in
                    tempUIImage = image
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .alert("Missing Details", isPresented: $showValidationAlert) {
            Button("Go Back") { }
            Button("Continue Anyway") {
                saveHomeAndContinue()
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
    
    private func saveHomeAndContinue() {
        if let existingHome = homes.first {
            existingHome.name = homeName
            if let imageData = tempUIImage?.jpegData(compressionQuality: 0.8) {
                existingHome.data = imageData
            }
        } else {
            let home = Home()
            home.name = homeName
            if let imageData = tempUIImage?.jpegData(compressionQuality: 0.8) {
                home.data = imageData
            }
            modelContext.insert(home)
        }
        manager.moveToNext()
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        
        return OnboardingHomeView()
            .environmentObject(OnboardingManager())
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
