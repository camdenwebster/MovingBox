import Dependencies
import PhotosUI
import SQLiteData
import SwiftUI

@MainActor
struct OnboardingLocationView: View {
    @Dependency(\.defaultDatabase) var database
    @EnvironmentObject private var manager: OnboardingManager
    @EnvironmentObject private var settings: SettingsManager

    @FetchAll(SQLiteInventoryLocation.all, animation: .default)
    private var locations: [SQLiteInventoryLocation]

    // InventoryLocation() used only as PhotoManageable bridge for PhotoPickerView
    @State private var locationPhotoAdapter = InventoryLocation()
    @State private var locationName = ""
    @State private var locationDesc = ""
    @State private var imageURL: URL?
    @State private var tempUIImage: UIImage?
    @State private var isLoading = false

    private func loadExistingData() async {
        if let existingLocation = locations.first {
            locationName = existingLocation.name
            locationDesc = existingLocation.desc
            imageURL = existingLocation.imageURL

            if let url = existingLocation.imageURL {
                do {
                    let thumbnail = try await OptimizedImageManager.shared.loadThumbnail(for: url)
                    tempUIImage = thumbnail
                } catch {
                    do {
                        let photo = try await OptimizedImageManager.shared.loadImage(url: url)
                        tempUIImage = photo
                    } catch {
                        print("Failed to load location photo: \(error)")
                    }
                }
            }
        }
    }

    private var photoAdapterBinding: Binding<InventoryLocation> {
        Binding(
            get: {
                locationPhotoAdapter.imageURL = imageURL
                return locationPhotoAdapter
            },
            set: { newValue in
                imageURL = newValue.imageURL
            }
        )
    }

    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 20) {
                            OnboardingHeaderText(text: "Add Your First Location")

                            OnboardingDescriptionText(
                                text:
                                    "A Location is a room in your home. If you're at home, start with the room you're currently in. Otherwise, start with any room that has valuable possessions."
                            )
                            .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))

                            // Photo Section
                            Group {
                                if let uiImage = tempUIImage {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                                        .frame(height: UIScreen.main.bounds.height / 3)
                                        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cornerRadius))
                                        .overlay(alignment: .bottomTrailing) {
                                            PhotoPickerView(
                                                model: photoAdapterBinding,
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
                                        model: photoAdapterBinding,
                                        loadedImage: $tempUIImage,
                                        isLoading: $isLoading
                                    ) { showPhotoSourceAlert in
                                        AddPhotoButton {
                                            showPhotoSourceAlert.wrappedValue = true
                                        }
                                        .foregroundStyle(.green)
                                        .accessibilityIdentifier("onboarding-location-add-photo-button")
                                        .padding()
                                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                                        .background {
                                            RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
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
                            manager.showError(message: "Please enter a name for your location")
                        } else {
                            Task {
                                do {
                                    try await saveLocationAndContinue()
                                    manager.moveToNext()
                                } catch {
                                    manager.showError(
                                        message: "Failed to save location: \(error.localizedDescription)")
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
        .task {
            await loadExistingData()
        }
    }

    private func saveLocationAndContinue() async throws {
        let saveName = locationName
        let saveDesc = locationDesc
        let saveImageURL = imageURL

        if let existingLocation = locations.first {
            try await database.write { db in
                try SQLiteInventoryLocation.find(existingLocation.id).update {
                    $0.name = saveName
                    $0.desc = saveDesc
                    $0.imageURL = saveImageURL
                }.execute(db)
            }
        } else {
            // Get the active home ID for the new location
            let homeID: UUID? = settings.activeHomeId.flatMap { UUID(uuidString: $0) }

            try await database.write { db in
                try SQLiteInventoryLocation.insert {
                    SQLiteInventoryLocation(
                        id: UUID(),
                        name: saveName,
                        desc: saveDesc,
                        imageURL: saveImageURL,
                        homeID: homeID
                    )
                }.execute(db)
            }
            TelemetryManager.shared.trackLocationCreated(name: saveName)
        }
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    OnboardingLocationView()
        .environmentObject(OnboardingManager())
        .environmentObject(SettingsManager())
}
