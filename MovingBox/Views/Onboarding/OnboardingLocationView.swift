import SwiftUI
import PhotosUI
import SwiftData

@MainActor
struct OnboardingLocationView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var manager: OnboardingManager
    @EnvironmentObject private var settings: SettingsManager
    
    @Query private var locations: [InventoryLocation]
    
    @State private var locationInstance = InventoryLocation()
    @State private var locationName = ""
    @State private var locationDesc = ""
    @State private var tempUIImage: UIImage?
    @State private var isLoading = false
    
    private func loadExistingData() async {
        if let existingLocation = locations.first {
            locationName = existingLocation.name
            locationDesc = existingLocation.desc
            locationInstance = existingLocation
            do {
                if let photo = try await existingLocation.photo {
                    tempUIImage = photo
                }
            } catch {
                print("Failed to load location photo: \(error)")
            }
        }
    }
    
    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
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
                                            PhotoPickerView(
                                                model: $locationInstance,
                                                loadedImage: $tempUIImage,
                                                isLoading: $isLoading
                                            )
                                        }
                                } else if isLoading {
                                    ProgressView()
                                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                                        .frame(height: UIScreen.main.bounds.height / 3)
                                } else {
                                    PhotoPickerView(
                                        model: $locationInstance,
                                        loadedImage: $tempUIImage,
                                        isLoading: $isLoading
                                    ) { showPhotoSourceAlert in
                                        AddPhotoButton {
                                            showPhotoSourceAlert.wrappedValue = true
                                        }
                                        .accessibilityIdentifier("onboarding-location-add-photo-button")
                                        .padding()
                                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                                        .background {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(.ultraThinMaterial)
                                        }
                                    }
                                }
                            }
                            
                            // Text Fields
                            VStack(spacing: 16) {
                                TextField("Location Name", text: $locationName)
                                    .accessibilityIdentifier("onboarding-location-name-field")
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: locationName) { _, newValue in
                                        locationInstance.name = newValue
                                    }
                                
                                TextField("Description", text: $locationDesc, axis: .vertical)
                                    .accessibilityIdentifier("onboarding-location-description-field")
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...)
                                    .onChange(of: locationDesc) { _, newValue in
                                        locationInstance.desc = newValue
                                    }
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
                            manager.showError(message: "Please enter a name for your location")
                        } else {
                            Task {
                                do {
                                    try await saveLocationAndContinue()
                                    manager.moveToNext()
                                } catch {
                                    manager.showError(message: "Failed to save location: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier("onboarding-location-continue-button")
                    .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onboardingBackground()
        .task {
            await loadExistingData()
        }
    }
    
    private func saveLocationAndContinue() async throws {
        if let existingLocation = locations.first {
            existingLocation.name = locationInstance.name
            existingLocation.desc = locationInstance.desc
            existingLocation.imageURL = locationInstance.imageURL
            try modelContext.save()
        } else {
            modelContext.insert(locationInstance)
            try modelContext.save()
            TelemetryManager.shared.trackLocationCreated(name: locationInstance.name)
        }
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
