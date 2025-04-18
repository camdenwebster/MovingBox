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
    @State private var loadedImage: UIImage?
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
                loadedImage = try await existingHome.photo
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
                                if let uiImage = loadedImage {
                                    Image(uiImage: uiImage)
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
                                        model: Binding(
                                            get: { activeHome ?? tempHome },
                                            set: { newValue in
                                                tempHome = newValue
                                            }
                                        ),
                                        loadedImage: $loadedImage,
                                        isLoading: $isLoading
                                    ) { isPresented in
                                        AddPhotoButton {
                                            isPresented.wrappedValue = true
                                        }
                                        .accessibilityIdentifier("onboarding-home-add-photo-button")
                                        .padding()
                                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                                        .background {
                                            RoundedRectangle(cornerRadius: 12)
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
        .task {
            await loadExistingData()
        }
    }
    
    @MainActor
    private func handleContinueButton() async {
        if homeName.isEmpty {
            manager.showError(message: "Please enter a name for your home")
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
            } else {
                let home = Home()
                home.name = homeName
                modelContext.insert(home)
            }
        } catch {
            loadingError = error
            print("Failed to save home: \(error)")
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
