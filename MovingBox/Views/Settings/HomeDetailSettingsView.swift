//
//  HomeDetailSettingsView.swift
//  MovingBox
//
//  Created by Claude on 12/20/25.
//

import SwiftData
import SwiftUI

struct HomeDetailSettingsView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @Query private var allHomes: [Home]

    private let home: Home?
    let presentedInSheet: Bool

    @State private var viewModel: HomeDetailSettingsViewModel?

    // Photo state
    @State private var tempUIImage: UIImage?
    @State private var loadedImage: UIImage?
    @State private var photoIsLoading = false
    @State private var cachedImageURL: URL?

    private let availableColors: [(name: String, color: Color)] = [
        ("green", .green),
        ("blue", .blue),
        ("purple", .purple),
        ("pink", .pink),
        ("red", .red),
        ("orange", .orange),
        ("yellow", .yellow),
        ("teal", .teal),
        ("cyan", .cyan),
        ("indigo", .indigo),
        ("mint", .mint),
        ("brown", .brown),
    ]

    init(home: Home?, presentedInSheet: Bool = false) {
        self.home = home
        self.presentedInSheet = presentedInSheet
    }

    var body: some View {
        Group {
            if let viewModel = viewModel {
                formContent(viewModel: viewModel)
                    .navigationTitle(viewModel.isNewHome ? "Add Home" : viewModel.displayHome.displayName)
                    .movingBoxNavigationTitleDisplayModeInline()
                    .toolbar { toolbarContent(viewModel: viewModel) }
                    .disabled(viewModel.isCreating)
                    .overlay { loadingOverlay(viewModel: viewModel) }
                    .alert("Delete Home", isPresented: deleteConfirmationBinding(viewModel: viewModel)) {
                        deleteConfirmationButtons(viewModel: viewModel)
                    } message: {
                        Text(
                            "Are you sure you want to delete \(viewModel.displayHome.displayName)? This will also delete all locations associated with this home. Items will remain but will be unassigned."
                        )
                    }
                    .alert("Cannot Delete", isPresented: deleteErrorBinding(viewModel: viewModel)) {
                        Button("OK") { viewModel.clearDeleteError() }
                    } message: {
                        if let error = viewModel.deleteError {
                            Text(error)
                        }
                    }
                    .alert("Error", isPresented: saveErrorBinding(viewModel: viewModel)) {
                        Button("OK") { viewModel.clearSaveError() }
                    } message: {
                        if let error = viewModel.saveError {
                            Text(error)
                        }
                    }
            } else {
                ProgressView()
                    .navigationTitle(home?.displayName ?? "Add Home")
                    .movingBoxNavigationTitleDisplayModeInline()
            }
        }
        .task(id: home?.imageURL) {
            guard let home = home,
                let imageURL = home.imageURL,
                !photoIsLoading
            else { return }

            if cachedImageURL != imageURL {
                loadedImage = nil
                cachedImageURL = imageURL
            }

            guard loadedImage == nil else { return }

            photoIsLoading = true
            defer { photoIsLoading = false }

            do {
                // Load thumbnail instead of full-size image to reduce memory usage
                let thumbnail = try await OptimizedImageManager.shared.loadThumbnail(for: imageURL)
                loadedImage = thumbnail
            } catch {
                // Fall back to full-size image if thumbnail isn't available
                do {
                    let photo = try await home.photo
                    loadedImage = photo
                } catch {
                    print("Failed to load home image: \(error)")
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = HomeDetailSettingsViewModel(
                    home: home,
                    modelContext: modelContext,
                    settings: settings,
                    allHomesProvider: { self.allHomes }
                )
            }
        }
        .onDisappear {
            // Release full-size images from memory when leaving the view
            tempUIImage = nil
            loadedImage = nil
        }
    }

    // MARK: - Bindings

    private func deleteConfirmationBinding(viewModel: HomeDetailSettingsViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.showingDeleteConfirmation },
            set: { viewModel.showingDeleteConfirmation = $0 }
        )
    }

    private func deleteErrorBinding(viewModel: HomeDetailSettingsViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.deleteError != nil },
            set: { if !$0 { viewModel.clearDeleteError() } }
        )
    }

    private func saveErrorBinding(viewModel: HomeDetailSettingsViewModel) -> Binding<Bool> {
        Binding(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.clearSaveError() } }
        )
    }

    // MARK: - Form Content

    @ViewBuilder
    private func formContent(viewModel: HomeDetailSettingsViewModel) -> some View {
        Form {
            photoSection(viewModel: viewModel)
            homeDetailsSection(viewModel: viewModel)
            addressSection(viewModel: viewModel)
            organizationSection(viewModel: viewModel)
            deleteSection(viewModel: viewModel)
        }
    }

    // MARK: - Photo Section

    @ViewBuilder
    private func photoSection(viewModel: HomeDetailSettingsViewModel) -> some View {
        if viewModel.isEditing || loadedImage != nil {
            Section(header: EmptyView()) {
                if let uiImage = tempUIImage ?? loadedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                        .listRowInsets(EdgeInsets())
                        .overlay(alignment: .bottomTrailing) {
                            if viewModel.isEditing {
                                PhotoPickerView(
                                    model: tempHomeBinding(viewModel: viewModel),
                                    loadedImage: viewModel.isNewHome ? $tempUIImage : $loadedImage,
                                    isLoading: $photoIsLoading
                                )
                            }
                        }
                } else if photoIsLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                } else if viewModel.isEditing {
                    PhotoPickerView(
                        model: tempHomeBinding(viewModel: viewModel),
                        loadedImage: viewModel.isNewHome ? $tempUIImage : $loadedImage,
                        isLoading: $photoIsLoading
                    ) { showPhotoSourceAlert in
                        AddPhotoButton {
                            showPhotoSourceAlert.wrappedValue = true
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func tempHomeBinding(viewModel: HomeDetailSettingsViewModel) -> Binding<Home> {
        Binding(
            get: { viewModel.tempHome },
            set: { _ in }
        )
    }

    // MARK: - Home Details Section

    @ViewBuilder
    private func homeDetailsSection(viewModel: HomeDetailSettingsViewModel) -> some View {
        Section {
            nameField(viewModel: viewModel)
            primaryToggle(viewModel: viewModel)
            colorPicker(viewModel: viewModel)
        } header: {
            Text("Home Details")
        } footer: {
            if viewModel.isEditing && viewModel.tempHome.name.isEmpty {
                Text("If no name is provided, the street address will be used.")
            }
        }
    }

    @ViewBuilder
    private func nameField(viewModel: HomeDetailSettingsViewModel) -> some View {
        if viewModel.isEditing {
            TextField(
                "Home Name (Optional)",
                text: Binding(
                    get: { viewModel.tempHome.name },
                    set: { viewModel.tempHome.name = $0 }
                )
            )
        } else {
            HStack {
                Text("Name")
                Spacer()
                Text(viewModel.displayHome.displayName)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func primaryToggle(viewModel: HomeDetailSettingsViewModel) -> some View {
        if viewModel.isEditing && !viewModel.isNewHome {
            Toggle(
                "Set as Primary",
                isOn: Binding(
                    get: { viewModel.tempHome.isPrimary },
                    set: { viewModel.togglePrimary($0) }
                )
            )
        } else if !viewModel.isEditing {
            HStack {
                Text("Primary Home")
                Spacer()
                if viewModel.displayHome.isPrimary {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    @ViewBuilder
    private func colorPicker(viewModel: HomeDetailSettingsViewModel) -> some View {
        if viewModel.isEditing {
            HStack {
                Text("Color")
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(availableColors, id: \.name) { colorOption in
                            colorCircle(for: colorOption, viewModel: viewModel)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } else {
            HStack {
                Text("Color")
                Spacer()
                Circle()
                    .fill(viewModel.displayHome.color)
                    .frame(width: 24, height: 24)
            }
        }
    }

    private func colorCircle(for colorOption: (name: String, color: Color), viewModel: HomeDetailSettingsViewModel)
        -> some View
    {
        Circle()
            .fill(colorOption.color)
            .frame(width: 32, height: 32)
            .overlay(
                Circle()
                    .strokeBorder(
                        viewModel.tempHome.colorName == colorOption.name
                            ? Color.primary : Color.clear,
                        lineWidth: 2
                    )
            )
            .onTapGesture {
                viewModel.tempHome.colorName = colorOption.name
            }
    }

    // MARK: - Address Section

    @ViewBuilder
    private func addressSection(viewModel: HomeDetailSettingsViewModel) -> some View {
        Section("Address") {
            if viewModel.isEditing {
                addressEditingFields(viewModel: viewModel)
            } else {
                addressDisplayFields(viewModel: viewModel)
            }
        }
    }

    // MARK: - Organization Section

    @ViewBuilder
    private func organizationSection(viewModel: HomeDetailSettingsViewModel) -> some View {
        if !viewModel.isNewHome {
            Section("Organization") {
                NavigationLink {
                    LocationSettingsView(home: viewModel.displayHome)
                } label: {
                    Label("Locations", systemImage: "map")
                }
            }
        }
    }

    // MARK: - Delete Section

    @ViewBuilder
    private func deleteSection(viewModel: HomeDetailSettingsViewModel) -> some View {
        if !viewModel.isNewHome && viewModel.canDelete {
            Section {
                Button(action: {
                    viewModel.confirmDelete()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Home")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(Color.red)
                    .clipShape(.rect(cornerRadius: UIConstants.cornerRadius))
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text(
                    "Deleting this home will also delete all associated locations. Items will remain but will be unassigned."
                )
            }
        }
    }

    // MARK: - Toolbar Content

    @ToolbarContentBuilder
    private func toolbarContent(viewModel: HomeDetailSettingsViewModel) -> some ToolbarContent {
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

        ToolbarItem(placement: viewModel.isEditing ? .confirmationAction : .movingBoxTrailing) {
            if viewModel.isEditing {
                Button("Save") {
                    Task {
                        // Save photo if one was selected
                        if let uiImage = tempUIImage {
                            let id = UUID().uuidString
                            if let imageURL = try? await OptimizedImageManager.shared.saveImage(uiImage, id: id) {
                                viewModel.tempHome.imageURL = imageURL
                            }
                            // Release the full-size UIImage from memory now that it's saved to disk
                            tempUIImage = nil
                        }

                        if viewModel.isNewHome {
                            if await viewModel.createHome() {
                                dismissView()
                            }
                        } else {
                            await viewModel.saveChanges()
                            viewModel.isEditing = false
                        }
                    }
                }
                .bold()
                .disabled(viewModel.isNewHome && !viewModel.canSave)
            } else {
                Button("Edit") {
                    viewModel.isEditing = true
                }
            }
        }
    }

    // MARK: - Loading Overlay

    @ViewBuilder
    private func loadingOverlay(viewModel: HomeDetailSettingsViewModel) -> some View {
        if viewModel.isCreating {
            ProgressView()
                .scaleEffect(1.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.2))
        }
    }

    // MARK: - Delete Confirmation Buttons

    @ViewBuilder
    private func deleteConfirmationButtons(viewModel: HomeDetailSettingsViewModel) -> some View {
        Button("Cancel", role: .cancel) {}
        Button("Delete", role: .destructive) {
            if viewModel.deleteHome() {
                dismissView()
            }
        }
    }

    private func dismissView() {
        if presentedInSheet {
            dismiss()
        } else {
            router.navigateBack()
        }
    }

    // MARK: - Address Editing Fields

    @ViewBuilder
    private func addressEditingFields(viewModel: HomeDetailSettingsViewModel) -> some View {
        TextField(
            "Address",
            text: Binding(
                get: { viewModel.addressInput },
                set: { viewModel.addressInput = $0 }
            ),
            axis: .vertical
        )
        .textContentType(.fullStreetAddress)
        .lineLimit(2...5)
    }

    // MARK: - Address Display Fields

    @ViewBuilder
    private func addressDisplayFields(viewModel: HomeDetailSettingsViewModel) -> some View {
        let address = formatDisplayAddress(viewModel.displayHome)
        if !address.isEmpty {
            Text(address)
                .foregroundStyle(.secondary)
        }
    }

    private func formatDisplayAddress(_ home: Home) -> String {
        var lines: [String] = []
        if !home.address1.isEmpty { lines.append(home.address1) }
        if !home.address2.isEmpty { lines.append(home.address2) }
        var cityStateParts: [String] = []
        if !home.city.isEmpty { cityStateParts.append(home.city) }
        if !home.state.isEmpty { cityStateParts.append(home.state) }
        if !home.zip.isEmpty { cityStateParts.append(home.zip) }
        if !cityStateParts.isEmpty {
            lines.append(cityStateParts.joined(separator: ", "))
        }
        return lines.joined(separator: "\n")
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Home.self, InventoryLocation.self, InventoryLabel.self, configurations: config)

        let home1 = Home(name: "Main House", address1: "123 Main St", city: "San Francisco", state: "CA", zip: "94102")
        home1.isPrimary = true

        let home2 = Home(
            name: "Beach House", address1: "456 Ocean Ave", city: "Santa Monica", state: "CA", zip: "90401")

        container.mainContext.insert(home1)
        container.mainContext.insert(home2)

        return NavigationStack {
            HomeDetailSettingsView(home: home1)
                .modelContainer(container)
                .environmentObject(Router())
                .environmentObject(SettingsManager())
        }
    } catch {
        return Text("Failed to set up preview: \(error.localizedDescription)")
            .foregroundStyle(.red)
    }
}
