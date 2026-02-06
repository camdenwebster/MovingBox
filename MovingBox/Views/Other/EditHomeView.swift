//
//  EditHomeView.swift
//  MovingBox
//
//  Created by Camden Webster on 3/20/25.
//

import PhotosUI
import SwiftData
import SwiftUI

@MainActor
struct EditHomeView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: Router
    @Query(sort: [SortDescriptor(\Home.purchaseDate)]) private var homes: [Home]

    var home: Home?
    var presentedInSheet: Bool
    var onDismiss: (() -> Void)?

    @State private var isEditing = false
    @State private var loadedImage: UIImage?
    @State private var loadingError: Error?
    @State private var isLoading = false
    @State private var cachedImageURL: URL?

    @State private var tempHome = {
        var home = Home()
        home.country = Locale.current.region?.identifier ?? "US"
        return home
    }()

    init(
        home: Home? = nil,
        presentedInSheet: Bool = false,
        onDismiss: (() -> Void)? = nil
    ) {
        self.home = home
        self.presentedInSheet = presentedInSheet
        self.onDismiss = onDismiss
    }

    private var isNewHome: Bool {
        if presentedInSheet {
            return home == nil
        }
        return homes.isEmpty
    }

    private var isEditingEnabled: Bool {
        isNewHome || isEditing
    }

    private var activeHome: Home? {
        if presentedInSheet {
            return home
        }
        return home ?? homes.last
    }

    private func countryName(for code: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forRegionCode: code) ?? code
    }

    var body: some View {
        Form {
            if isEditingEnabled || loadedImage != nil {
                Section {
                    if let uiImage = loadedImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: UIScreen.main.bounds.width - 32)
                            .frame(height: UIScreen.main.bounds.height / 3)
                            .clipped()
                            .listRowInsets(EdgeInsets())
                            .overlay(alignment: .bottomTrailing) {
                                if isEditingEnabled {
                                    PhotoPickerView(
                                        model: Binding(
                                            get: { activeHome ?? tempHome },
                                            set: { newValue in
                                                if let existingHome = activeHome {
                                                    existingHome.imageURL = newValue.imageURL
                                                    try? modelContext.save()
                                                } else {
                                                    tempHome = newValue
                                                }
                                            }
                                        ),
                                        loadedImage: $loadedImage,
                                        isLoading: $isLoading
                                    )
                                }
                            }
                    } else if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height / 3)
                    } else if isEditingEnabled {
                        PhotoPickerView(
                            model: Binding(
                                get: { activeHome ?? tempHome },
                                set: { newValue in
                                    if let existingHome = activeHome {
                                        existingHome.imageURL = newValue.imageURL
                                        try? modelContext.save()
                                    } else {
                                        tempHome = newValue
                                    }
                                }
                            ),
                            loadedImage: $loadedImage,
                            isLoading: $isLoading
                        ) { isPresented in
                            AddPhotoButton {
                                isPresented.wrappedValue = true
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: UIScreen.main.bounds.height / 3)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if isEditingEnabled || !tempHome.name.isEmpty {
                Section("Home Nickname") {
                    TextField("Enter a nickname", text: $tempHome.name)
                        .disabled(!isEditingEnabled)
                        .foregroundColor(isEditingEnabled ? .primary : .secondary)
                }
            }

            Section("Home Address") {
                TextField("Street Address", text: $tempHome.address1)
                    .textContentType(.streetAddressLine1)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)

                TextField("Apt, Suite, Unit", text: $tempHome.address2)
                    .textContentType(.streetAddressLine2)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)

                TextField("City", text: $tempHome.city)
                    .textContentType(.addressCity)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)

                TextField("State/Province", text: $tempHome.state)
                    .textContentType(.addressState)
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)

                TextField("ZIP/Postal Code", text: $tempHome.zip)
                    .textContentType(.postalCode)
                    .movingBoxNumberPadKeyboardType()
                    .disabled(!isEditingEnabled)
                    .foregroundColor(isEditingEnabled ? .primary : .secondary)

                if isEditingEnabled {
                    Picker("Country", selection: $tempHome.country) {
                        // Current user's country at the top
                        if let userCountry = Locale.current.region?.identifier {
                            Text(countryName(for: userCountry))
                                .tag(userCountry)

                            Divider()
                        }

                        // All other countries, sorted alphabetically
                        ForEach(
                            Locale.Region.isoRegions.filter { $0.identifier != Locale.current.region?.identifier }
                                .sorted(by: { countryName(for: $0.identifier) < countryName(for: $1.identifier) }),
                            id: \.identifier
                        ) { region in
                            Text(countryName(for: region.identifier))
                                .tag(region.identifier)
                        }
                    }
                } else {
                    HStack {
                        Text("Country")
                        Spacer()
                        Text(countryName(for: tempHome.country))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(isNewHome ? "New Home" : (activeHome?.displayName ?? "Home"))
        .movingBoxNavigationTitleDisplayModeInline()
        .task(id: activeHome?.imageURL) {
            guard let home = activeHome,
                let imageURL = home.imageURL,
                !isLoading
            else { return }

            // If the imageURL changed, clear the cached image
            if cachedImageURL != imageURL {
                await MainActor.run {
                    loadedImage = nil
                    cachedImageURL = imageURL
                }
            }

            // Only load if we don't have a cached image for this URL
            guard loadedImage == nil else { return }

            await MainActor.run {
                isLoading = true
            }

            defer {
                Task { @MainActor in
                    isLoading = false
                }
            }

            do {
                let photo = try await home.photo
                await MainActor.run {
                    loadedImage = photo
                }
            } catch {
                await MainActor.run {
                    loadingError = error
                    print("Failed to load image: \(error)")
                }
            }
        }
        .onAppear {
            if let existingHome = activeHome {
                tempHome = existingHome
            } else {
                // Set default country for new homes
                tempHome.country = Locale.current.region?.identifier ?? "US"
            }
            // When presented in a sheet, start in editing mode
            if presentedInSheet {
                isEditing = true
            }
        }
        .toolbar {
            if presentedInSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismissView()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if !isNewHome {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            if let existingHome = activeHome {
                                existingHome.name = tempHome.name
                                existingHome.address1 = tempHome.address1
                                existingHome.address2 = tempHome.address2
                                existingHome.city = tempHome.city
                                existingHome.state = tempHome.state
                                existingHome.zip = tempHome.zip
                                existingHome.country = tempHome.country
                            }
                            isEditing = false
                            if presentedInSheet {
                                dismissView()
                            }
                        } else {
                            isEditing = true
                        }
                    }
                    .font(isEditing ? .body.bold() : .body)
                } else {
                    Button("Save") {
                        Task {
                            do {
                                let newHome = try await DefaultDataManager.getOrCreateHome(modelContext: modelContext)

                                newHome.name = tempHome.name
                                newHome.address1 = tempHome.address1
                                newHome.address2 = tempHome.address2
                                newHome.city = tempHome.city
                                newHome.state = tempHome.state
                                newHome.zip = tempHome.zip
                                newHome.country = tempHome.country
                                newHome.purchaseDate = Date()
                                newHome.imageURL = tempHome.imageURL

                                TelemetryManager.shared.trackLocationCreated(name: newHome.address1)
                                print("EditHomeView: Created home - \(newHome.name)")

                                try modelContext.save()
                                dismissView()
                            } catch {
                                print("❌ Error saving home: \(error)")
                            }
                        }
                    }
                    .disabled(tempHome.address1.isEmpty)
                    .bold()
                }
            }
        }
    }

    private func dismissView() {
        if presentedInSheet {
            onDismiss?()
            dismiss()
        } else {
            router.navigateBack()
        }
    }
}

//#Preview {
//    do {
//        let previewer = try Previewer()
//
//        return EditHomeView()
//            .modelContainer(previewer.container)
//    } catch {
//        return Text("Failed to create preview: \(error.localizedDescription)")
//    }
//}
