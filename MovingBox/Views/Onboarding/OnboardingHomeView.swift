import SwiftUI
import PhotosUI
import SwiftData

struct OnboardingHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var manager: OnboardingManager
    @EnvironmentObject private var settings: SettingsManager
    
    @Query(sort: [SortDescriptor(\Home.purchaseDate)]) private var homes: [Home]
    
    @State private var homeName = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var tempUIImage: UIImage?
    @State private var showPhotoSourceAlert = false
    @State private var showingCamera = false
    @State private var showPhotoPicker = false
    @State private var showValidationAlert = false
    @State private var loadingError: Error?
    
    private var activeHome: Home? {
        homes.first
    }
    
    @MainActor
    private func loadExistingData() async {
        if let existingHome = activeHome {
            homeName = existingHome.name
            do {
                if let photo = try await existingHome.photo {
                    tempUIImage = photo
                }
            } catch {
                loadingError = error
                print("Failed to load home photo: \(error)")
            }
        }
    }
    
    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 20) {

                            OnboardingHeaderText(text: "Add Home Details")
                            
                            OnboardingDescriptionText(text: "Add some details about your home to customize your experience")
                            
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
                                } else {
                                    AddPhotoButton(action: {
                                        showPhotoSourceAlert = true
                                    })
                                    .accessibilityIdentifier("onboarding-home-add-photo-button")
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
                            
                            TextField("Home Name", text: $homeName)
                                .accessibilityIdentifier("onboarding-home-name-field")
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                        }
                        .frame(maxWidth: .infinity)
                        
                        Spacer()
                            .frame(height: 100)
                    }
                }
                
                VStack {
                    OnboardingContinueButton {
                        Task {
                            await handleContinueButton()
                        }
                    }
                    .accessibilityIdentifier("onboarding-home-continue-button")
                    .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onboardingBackground()
        .onChange(of: selectedPhoto, loadPhoto)
        .task {
            await loadExistingData()
        }
        .sheet(isPresented: $showingCamera, onDismiss: nil) {
            CameraView(
                showingImageAnalysis: .constant(false),
                analyzingImage: .constant(nil)
            ) { image, _, completion async -> Void in
                tempUIImage = image
                await completion()
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .alert("Missing Details", isPresented: $showValidationAlert) {
            Button("Go Back") { }
            Button("Continue Anyway") {
                Task {
                    await saveHomeAndContinue()
                    manager.moveToNext()
                }
            }
        } message: {
            Text("Some details haven't been filled out. Would you like to go back and complete them or continue anyway?")
        }
    }
    
    @MainActor
    private func loadPhoto() {
        Task {
            do {
                if let data = try await selectedPhoto?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    tempUIImage = uiImage
                }
            } catch {
                loadingError = error
                print("Failed to load photo: \(error)")
            }
        }
    }
    
    @MainActor
    private func handleContinueButton() async {
        if homeName.isEmpty {
            showValidationAlert = true
        } else {
            do {
                await saveHomeAndContinue()
                manager.moveToNext()
            } catch {
                loadingError = error
                print("Failed to save home: \(error)")
            }
        }
    }
    
    @MainActor
    private func saveHomeAndContinue() async {
        do {
            if let existingHome = activeHome {
                existingHome.name = homeName
                if let uiImage = tempUIImage {
                    let id = UUID().uuidString
                    let imageURL = try await OptimizedImageManager.shared.saveImage(uiImage, id: id)
                    existingHome.imageURL = imageURL
                }
            } else {
                let home = Home()
                home.name = homeName
                if let uiImage = tempUIImage {
                    let id = UUID().uuidString
                    let imageURL = try await OptimizedImageManager.shared.saveImage(uiImage, id: id)
                    home.imageURL = imageURL
                }
                modelContext.insert(home)
            }
        } catch {
            loadingError = error
            print("Failed to save home photo: \(error)")
        }
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
