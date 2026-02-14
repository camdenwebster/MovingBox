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

    @State private var locationName = ""
    @State private var locationDesc = ""
    @State private var tempUIImage: UIImage?
    @State private var isLoading = false

    private func loadExistingData() async {
        if let existingLocation = locations.first {
            locationName = existingLocation.name
            locationDesc = existingLocation.desc

            // Load photo from BLOB
            if let photo = try? await database.read({ db in
                try SQLiteInventoryLocationPhoto.primaryPhoto(for: existingLocation.id, in: db)
            }) {
                tempUIImage = UIImage(data: photo.data)
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
        let image = tempUIImage

        // Process photo before DB write
        var photoData: Data?
        if let image {
            photoData = await OptimizedImageManager.shared.processImage(image)
        }

        if let existingLocation = locations.first {
            try await database.write { db in
                try SQLiteInventoryLocation.find(existingLocation.id).update {
                    $0.name = saveName
                    $0.desc = saveDesc
                }.execute(db)

                // Replace photo
                try SQLiteInventoryLocationPhoto
                    .where { $0.inventoryLocationID == existingLocation.id }
                    .delete()
                    .execute(db)

                if let photoData {
                    try SQLiteInventoryLocationPhoto.insert {
                        SQLiteInventoryLocationPhoto(
                            id: UUID(),
                            inventoryLocationID: existingLocation.id,
                            data: photoData,
                            sortOrder: 0
                        )
                    }.execute(db)
                }
            }
        } else {
            let homeID: UUID? = settings.activeHomeId.flatMap { UUID(uuidString: $0) }
            let newLocationID = UUID()

            try await database.write { db in
                try SQLiteInventoryLocation.insert {
                    SQLiteInventoryLocation(
                        id: newLocationID,
                        name: saveName,
                        desc: saveDesc,
                        homeID: homeID
                    )
                }.execute(db)

                if let photoData {
                    try SQLiteInventoryLocationPhoto.insert {
                        SQLiteInventoryLocationPhoto(
                            id: UUID(),
                            inventoryLocationID: newLocationID,
                            data: photoData,
                            sortOrder: 0
                        )
                    }.execute(db)
                }
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
