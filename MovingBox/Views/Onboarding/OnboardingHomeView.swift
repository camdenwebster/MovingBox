import SwiftUI
import PhotosUI
import SwiftData

@MainActor
struct OnboardingHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var manager: OnboardingManager
    @EnvironmentObject private var settings: SettingsManager
    @Query(sort: [SortDescriptor(\Home.purchaseDate)]) private var homes: [Home]
    @State private var homeName = ""
    @State private var loadedImages: [UIImage] = []
    @State private var loadingError: Error?
    @State private var isLoading = false
    @State private var tempHome = Home()
    
    private var activeHome: Home? {
        homes.last
    }
    
    @MainActor
    private func loadExistingData() async {
        if let existingHome = activeHome {
            homeName = existingHome.name
            do {
                // Removed loadedImage
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
                                if !loadedImages.isEmpty {
                                    Image(uiImage: loadedImages.first ?? UIImage())
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                                        .frame(height: UIScreen.main.bounds.height / 3)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(alignment: .bottomTrailing) {
                                            PhotoPickerView(
                                                model: Binding(
                                                    get: { activeHome ?? tempHome },
                                                    set: { newValue in
                                                        tempHome = newValue
                                                    }
                                                ),
                                                loadedImages: $loadedImages,
                                                isLoading: $isLoading
                                            ) { showSourceAlert in
                                                AddPhotoButton {
                                                    showSourceAlert.wrappedValue = true
                                                }
                                                .frame(maxWidth: .infinity)
                                                .frame(height: UIScreen.main.bounds.height / 3)
                                                .foregroundStyle(.secondary)
                                            }
                                        }
                                } else if isLoading {
                                    ProgressView()
                                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                                        .frame(height: UIScreen.main.bounds.height / 3)
                                } else {
                                    PhotoPickerView(
                                        model: Binding(
                                            get: { activeHome ?? tempHome },
                                            set: { newValue in
                                                tempHome = newValue
                                            }
                                        ),
                                        loadedImages: $loadedImages,
                                        isLoading: $isLoading
                                    ) { showSourceAlert in
                                        AddPhotoButton {
                                            showSourceAlert.wrappedValue = true
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: UIScreen.main.bounds.height / 3)
                                        .foregroundStyle(.secondary)
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
                                    loadingError = error
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
        if let existingHome = activeHome {
            existingHome.name = homeName
            try modelContext.save()
        } else {
            let home = Home()
            home.name = homeName
            modelContext.insert(home)
            try modelContext.save()
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
