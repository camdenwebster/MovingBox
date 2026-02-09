import Dependencies
import PhotosUI
import SQLiteData
import SwiftUI

@MainActor
struct OnboardingHomeView: View {
    @Dependency(\.defaultDatabase) var database
    @EnvironmentObject private var manager: OnboardingManager
    @EnvironmentObject private var settings: SettingsManager

    @FetchAll(SQLiteHome.order(by: \.purchaseDate), animation: .default)
    private var homes: [SQLiteHome]

    @State private var homeName = ""
    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    private var activeHome: SQLiteHome? {
        homes.last
    }

    @MainActor
    private func loadExistingData() async {
        if let existingHome = activeHome {
            homeName = existingHome.name

            // Load photo from BLOB
            if let photo = try? await database.read({ db in
                try SQLiteHomePhoto.primaryPhoto(for: existingHome.id, in: db)
            }) {
                loadedImage = UIImage(data: photo.data)
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

                            OnboardingDescriptionText(
                                text: "Add some details about your home to customize your experience")

                            Group {
                                if let uiImage = loadedImage {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                                        .frame(height: UIScreen.main.bounds.height / 3)
                                        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cornerRadius))
                                        .overlay(alignment: .bottomTrailing) {
                                            PhotoPickerView(
                                                loadedImage: $loadedImage,
                                                isLoading: $isLoading
                                            )
                                        }
                                } else if isLoading {
                                    ProgressView()
                                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                                        .frame(height: UIScreen.main.bounds.height / 3)
                                } else {
                                    PhotoPickerView(
                                        loadedImage: $loadedImage,
                                        isLoading: $isLoading
                                    ) { isPresented in
                                        AddPhotoButton {
                                            isPresented.wrappedValue = true
                                        }
                                        .foregroundStyle(.green)
                                        .accessibilityIdentifier("onboarding-home-add-photo-button")
                                        .padding()
                                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                                        .background {
                                            RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
                                                .fill(.ultraThinMaterial)
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
                        if homeName.isEmpty {
                            manager.showError(message: "Please enter a name for your home")
                        } else {
                            Task {
                                do {
                                    try await handleContinueButton()
                                } catch {
                                    manager.showError(message: "Failed to save home: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier("onboarding-home-continue-button")
                    .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .task {
            await loadExistingData()
        }
    }

    @MainActor
    private func handleContinueButton() async throws {
        try await saveHomeAndContinue()
        manager.moveToNext()
    }

    @MainActor
    private func saveHomeAndContinue() async throws {
        let saveName = homeName
        let image = loadedImage

        // Process photo before DB write
        var photoData: Data?
        if let image {
            photoData = await OptimizedImageManager.shared.processImage(image)
        }

        if let existingHome = activeHome {
            try await database.write { db in
                try SQLiteHome.find(existingHome.id).update {
                    $0.name = saveName
                }.execute(db)

                // Replace photo
                try SQLiteHomePhoto
                    .where { $0.homeID == existingHome.id }
                    .delete()
                    .execute(db)

                if let photoData {
                    try SQLiteHomePhoto.insert {
                        SQLiteHomePhoto(
                            id: UUID(),
                            homeID: existingHome.id,
                            data: photoData,
                            sortOrder: 0
                        )
                    }.execute(db)
                }
            }
        } else {
            let newHomeID = DefaultSeedID.home
            try await database.write { db in
                try SQLiteHome.insert {
                    SQLiteHome(
                        id: newHomeID,
                        name: saveName,
                        isPrimary: true,
                        colorName: "green"
                    )
                }.execute(db)

                if let photoData {
                    try SQLiteHomePhoto.insert {
                        SQLiteHomePhoto(
                            id: UUID(),
                            homeID: newHomeID,
                            data: photoData,
                            sortOrder: 0
                        )
                    }.execute(db)
                }

                for (index, roomData) in TestData.defaultRooms.enumerated() {
                    try SQLiteInventoryLocation.insert {
                        SQLiteInventoryLocation(
                            id: DefaultSeedID.roomIDs[index],
                            name: roomData.name,
                            desc: roomData.desc,
                            sfSymbolName: roomData.sfSymbol,
                            homeID: newHomeID
                        )
                    }.execute(db)
                }
            }
            settings.activeHomeId = newHomeID.uuidString
        }
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    OnboardingHomeView()
        .environmentObject(OnboardingManager())
        .environmentObject(SettingsManager())
}
