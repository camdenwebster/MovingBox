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
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @Query private var allHomes: [Home]

    let home: Home?
    @State private var tempHome: Home
    @State private var isEditing = false
    @State private var isCreating = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteError: String?
    @State private var saveError: String?
    @FocusState private var focusedField: AddressField?

    enum AddressField: Hashable {
        case street
        case unit
        case city
        case state
        case zip
    }

    private var isNewHome: Bool {
        home == nil
    }

    private var displayHome: Home {
        home ?? tempHome
    }

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

    init(home: Home?) {
        self.home = home
        // Initialize tempHome with either the existing home or a new one
        if let home = home {
            _tempHome = State(initialValue: home)
        } else {
            var newHome = Home()
            newHome.country = Locale.current.region?.identifier ?? "US"
            _tempHome = State(initialValue: newHome)
            _isEditing = State(initialValue: true)
        }
    }

    private func countryName(for code: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forRegionCode: code) ?? code
    }

    var body: some View {
        Form {
            Section {
                if isEditing {
                    TextField(
                        "Home Name (Optional)",
                        text: Binding(
                            get: { tempHome.name },
                            set: { tempHome.name = $0 }
                        ))
                } else {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(displayHome.displayName)
                            .foregroundColor(.secondary)
                    }
                }

                if isEditing && !isNewHome {
                    Toggle(
                        "Set as Primary",
                        isOn: Binding(
                            get: { tempHome.isPrimary },
                            set: { newValue in
                                if newValue {
                                    // Make this home primary and unmark all others
                                    for otherHome in allHomes {
                                        otherHome.isPrimary = (otherHome.id == tempHome.id)
                                    }
                                    tempHome.isPrimary = true
                                    // Update active home ID
                                    settings.activeHomeId = tempHome.id.uuidString
                                } else {
                                    // Can't unset if it's the only home or currently primary
                                    // Find another home to make primary
                                    if let firstOtherHome = allHomes.first(where: { $0.id != tempHome.id }) {
                                        firstOtherHome.isPrimary = true
                                        tempHome.isPrimary = false
                                        settings.activeHomeId = firstOtherHome.id.uuidString
                                    }
                                }
                            }
                        ))
                } else if !isEditing {
                    HStack {
                        Text("Primary Home")
                        Spacer()
                        if displayHome.isPrimary {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                if isEditing {
                    HStack {
                        Text("Color")
                        Spacer()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableColors, id: \.name) { colorOption in
                                    Circle()
                                        .fill(colorOption.color)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    tempHome.colorName == colorOption.name
                                                        ? Color.primary : Color.clear, lineWidth: 2)
                                        )
                                        .onTapGesture {
                                            tempHome.colorName = colorOption.name
                                        }
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
                            .fill(displayHome.color)
                            .frame(width: 24, height: 24)
                    }
                }
            } header: {
                Text("Home Details")
            } footer: {
                if isEditing && tempHome.name.isEmpty {
                    Text("If no name is provided, the street address will be used.")
                }
            }

            Section("Address") {
                if isEditing {
                    TextField(
                        "Street Address",
                        text: Binding(
                            get: { tempHome.address1 },
                            set: { tempHome.address1 = $0 }
                        )
                    )
                    .textContentType(.streetAddressLine1)
                    .focused($focusedField, equals: .street)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .unit
                    }
                    .onChange(of: tempHome.address1) { oldValue, newValue in
                        // If field was populated (likely via autofill) and we're focused here, advance
                        if focusedField == .street && !newValue.isEmpty && oldValue.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                focusedField = .unit
                            }
                        }
                    }

                    TextField(
                        "Apt, Suite, Unit",
                        text: Binding(
                            get: { tempHome.address2 },
                            set: { tempHome.address2 = $0 }
                        )
                    )
                    .textContentType(.streetAddressLine2)
                    .focused($focusedField, equals: .unit)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .city
                    }
                    .onChange(of: tempHome.address2) { oldValue, newValue in
                        // Advance to city if unit was skipped but city is populated (autofill)
                        if focusedField == .unit && !tempHome.city.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                focusedField = .city
                            }
                        }
                    }

                    TextField(
                        "City",
                        text: Binding(
                            get: { tempHome.city },
                            set: { tempHome.city = $0 }
                        )
                    )
                    .textContentType(.addressCity)
                    .focused($focusedField, equals: .city)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .state
                    }
                    .onChange(of: tempHome.city) { oldValue, newValue in
                        if focusedField == .city && !newValue.isEmpty && oldValue.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                focusedField = .state
                            }
                        }
                    }

                    TextField(
                        "State/Province",
                        text: Binding(
                            get: { tempHome.state },
                            set: { tempHome.state = $0 }
                        )
                    )
                    .textContentType(.addressState)
                    .focused($focusedField, equals: .state)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .zip
                    }
                    .onChange(of: tempHome.state) { oldValue, newValue in
                        if focusedField == .state && !newValue.isEmpty && oldValue.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                focusedField = .zip
                            }
                        }
                    }

                    TextField(
                        "ZIP/Postal Code",
                        text: Binding(
                            get: { tempHome.zip },
                            set: { tempHome.zip = $0 }
                        )
                    )
                    .textContentType(.postalCode)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .zip)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                    }
                    .onChange(of: tempHome.zip) { oldValue, newValue in
                        // If ZIP was populated via autofill, dismiss keyboard
                        if focusedField == .zip && !newValue.isEmpty && oldValue.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                focusedField = nil
                            }
                        }
                    }

                    Picker(
                        "Country",
                        selection: Binding(
                            get: { tempHome.country },
                            set: { tempHome.country = $0 }
                        )
                    ) {
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
                    if !displayHome.address1.isEmpty {
                        LabeledContent("Street", value: displayHome.address1)
                    }
                    if !displayHome.address2.isEmpty {
                        LabeledContent("Unit", value: displayHome.address2)
                    }
                    if !displayHome.city.isEmpty {
                        LabeledContent("City", value: displayHome.city)
                    }
                    if !displayHome.state.isEmpty {
                        LabeledContent("State", value: displayHome.state)
                    }
                    if !displayHome.zip.isEmpty {
                        LabeledContent("ZIP", value: displayHome.zip)
                    }
                    if !displayHome.country.isEmpty {
                        LabeledContent("Country", value: countryName(for: displayHome.country))
                    }
                }
            }

            if !isNewHome, let existingHome = home {
                Section("Organization") {
                    NavigationLink {
                        HomeLocationSettingsView(home: existingHome)
                    } label: {
                        Label("Locations", systemImage: "map")
                    }

                    NavigationLink {
                        HomeLabelSettingsView(home: existingHome)
                    } label: {
                        Label("Labels", systemImage: "tag")
                    }
                }
            }

            if !isNewHome && allHomes.count > 1 {
                Section {
                    Button(
                        role: .destructive,
                        action: {
                            showingDeleteConfirmation = true
                        }
                    ) {
                        Label("Delete Home", systemImage: "trash")
                    }
                } footer: {
                    Text(
                        "Deleting this home will also delete all associated locations and labels. Items will remain but will be unassigned."
                    )
                }
            }
        }
        .onAppear {
            // Ensure country always has a valid value to prevent picker warnings
            if tempHome.country.isEmpty {
                tempHome.country = Locale.current.region?.identifier ?? "US"
            }
        }
        .navigationTitle(isNewHome ? "Add Home" : displayHome.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNewHome {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        router.navigateBack()
                    }
                    .disabled(isCreating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await createHome()
                        }
                    }
                    .bold()
                    .disabled(tempHome.address1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            saveChanges()
                        }
                        isEditing.toggle()
                    }
                }
            }
        }
        .disabled(isCreating)
        .overlay {
            if isCreating {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .alert("Delete Home", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteHome()
            }
        } message: {
            Text(
                "Are you sure you want to delete \(displayHome.displayName)? This will also delete all locations and labels associated with this home. Items will remain but will be unassigned."
            )
        }
        .alert(
            "Cannot Delete",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK") { deleteError = nil }
        } message: {
            if let error = deleteError {
                Text(error)
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("OK") { saveError = nil }
        } message: {
            if let error = saveError {
                Text(error)
            }
        }
    }

    private func saveChanges() {
        guard let existingHome = home else { return }

        existingHome.name = tempHome.name
        existingHome.address1 = tempHome.address1
        existingHome.address2 = tempHome.address2
        existingHome.city = tempHome.city
        existingHome.state = tempHome.state
        existingHome.zip = tempHome.zip
        existingHome.country = tempHome.country
        existingHome.colorName = tempHome.colorName
        existingHome.isPrimary = tempHome.isPrimary

        do {
            try modelContext.save()
        } catch {
            saveError = "Failed to save changes: \(error.localizedDescription)"
        }
    }

    private func createHome() async {
        isCreating = true
        saveError = nil

        do {
            let trimmedName = tempHome.name.trimmingCharacters(in: .whitespacesAndNewlines)

            // Create new home with default locations and labels
            // Pass the name (which can be empty) - address is required and validated by save button
            let newHome = try await DefaultDataManager.createNewHome(
                name: trimmedName,
                modelContext: modelContext
            )

            // Copy all properties from tempHome to newHome
            newHome.address1 = tempHome.address1
            newHome.address2 = tempHome.address2
            newHome.city = tempHome.city
            newHome.state = tempHome.state
            newHome.zip = tempHome.zip
            newHome.country = tempHome.country
            newHome.colorName = tempHome.colorName

            // If this is the first home, make it primary
            if allHomes.isEmpty {
                newHome.isPrimary = true
                settings.activeHomeId = newHome.id.uuidString
            }

            // Save context
            try modelContext.save()

            // Track telemetry using displayName (name or address)
            TelemetryManager.shared.trackHomeCreated(name: newHome.displayName)

            // Navigate back
            await MainActor.run {
                router.navigateBack()
            }
        } catch {
            await MainActor.run {
                self.saveError = "Failed to create home: \(error.localizedDescription)"
                isCreating = false
            }
        }
    }

    private func deleteHome() {
        guard let homeToDelete = home else { return }

        // Validation: can't delete if only one home exists
        if allHomes.count == 1 {
            deleteError = "You must have at least one home. Cannot delete the last remaining home."
            return
        }

        // If deleting primary home, make another home primary first
        if homeToDelete.isPrimary {
            if let firstOtherHome = allHomes.first(where: { $0.id != homeToDelete.id }) {
                firstOtherHome.isPrimary = true
                settings.activeHomeId = firstOtherHome.id.uuidString
            }
        }

        // Delete all locations associated with this home
        let locationDescriptor = FetchDescriptor<InventoryLocation>()
        if let locations = try? modelContext.fetch(locationDescriptor) {
            for location in locations where location.home?.id == homeToDelete.id {
                // Unassign items from this location
                if let items = location.inventoryItems {
                    for item in items {
                        item.location = nil
                    }
                }
                modelContext.delete(location)
            }
        }

        // Delete all labels associated with this home
        let labelDescriptor = FetchDescriptor<InventoryLabel>()
        if let labels = try? modelContext.fetch(labelDescriptor) {
            for label in labels where label.home?.id == homeToDelete.id {
                // Unassign items from this label
                if let items = label.inventoryItems {
                    for item in items {
                        item.label = nil
                    }
                }
                modelContext.delete(label)
            }
        }

        // Delete the home itself
        modelContext.delete(homeToDelete)

        // Save changes
        do {
            try modelContext.save()
            router.navigateBack()
        } catch {
            deleteError = "Failed to delete home: \(error.localizedDescription)"
        }
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
            .foregroundColor(.red)
    }
}
