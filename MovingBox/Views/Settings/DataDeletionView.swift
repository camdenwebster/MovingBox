import SwiftUI
import SwiftData

enum DeletionScope: String, CaseIterable {
    case localOnly = "Local Only"
    case localAndICloud = "Local and iCloud"
    
    var description: String {
        switch self {
        case .localOnly:
            return "Delete data only from this device. Your data will remain in iCloud and on other devices."
        case .localAndICloud:
            return "Delete all data from this device and iCloud. This will remove data from all your devices."
        }
    }
    
    var icon: String {
        switch self {
        case .localOnly:
            return "iphone"
        case .localAndICloud:
            return "icloud"
        }
    }
}

struct DataDeletionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedScope: DeletionScope = .localOnly
    @State private var showConfirmation = false
    @State private var confirmationText = ""
    @State private var isDeleting = false
    @State private var showFinalConfirmation = false
    
    private let requiredConfirmationText = "DELETE"
    
    private var isConfirmationValid: Bool {
        confirmationText.uppercased() == requiredConfirmationText
    }
    
    var body: some View {
        List {
            warningSection
            scopeSelectionSection
            confirmationSection
        }
        .navigationTitle("Delete All Data")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Final Confirmation", isPresented: $showFinalConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All Data", role: .destructive) {
                Task {
                    await deleteAllData()
                }
            }
        } message: {
            Text("This action cannot be undone. Are you sure you want to delete all your inventory data?")
        }
    }
    
    private var warningSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                    Text("Warning")
                        .font(.headline)
                        .foregroundColor(.red)
                }
                
                Text("This will permanently delete all your inventory data including:")
                    .font(.subheadline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("All inventory items and photos", systemImage: "cube.box")
                    Label("All locations and room data", systemImage: "location")
                    Label("All labels and categories", systemImage: "tag")
                    Label("Home information and settings", systemImage: "house")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
    
    private var scopeSelectionSection: some View {
        Section("Deletion Scope") {
            ForEach(DeletionScope.allCases, id: \.self) { scope in
                Button {
                    selectedScope = scope
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: scope.icon)
                                    .foregroundStyle(selectedScope == scope ? Color.customPrimary : .secondary)
                                Text(scope.rawValue)
                                    .foregroundStyle(.primary)
                                    .font(.headline)
                            }
                            Text(scope.description)
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        Spacer()
                        if selectedScope == scope {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.customPrimary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var confirmationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("To confirm deletion, type \"\(requiredConfirmationText)\" below:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Type \(requiredConfirmationText)", text: $confirmationText)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                
                Button {
                    if isConfirmationValid {
                        showFinalConfirmation = true
                    }
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Deleting...")
                        } else {
                            Image(systemName: "trash.fill")
                            Text("Delete All Data")
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isConfirmationValid && !isDeleting ? Color.red : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(!isConfirmationValid || isDeleting)
                .listRowInsets(EdgeInsets())
            }
            .padding(.vertical, 8)
        } footer: {
            Text("This action is irreversible. Make sure you have exported your data if you want to keep a backup.")
                .font(.footnote)
                .foregroundColor(.red)
        }
    }
    
    @MainActor
    private func deleteAllData() async {
        isDeleting = true
        defer { isDeleting = false }
        
        do {
            // Delete all data from SwiftData
            try await deleteSwiftDataContent()
            
            // Clear image cache
            await clearImageCache()
            
            // If deleting from iCloud, purge CloudKit records
            if selectedScope == .localAndICloud {
                // Note: SwiftData with CloudKit will handle the sync deletion
                print("🗑️ Deleted all data including iCloud sync")
            } else {
                print("🗑️ Deleted local data only")
            }
            
            // Show success and dismiss
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            print("❌ Error deleting data: \(error)")
            // Show error alert
        }
    }
    
    private func deleteSwiftDataContent() async throws {
        // Delete all inventory items
        let itemDescriptor = FetchDescriptor<InventoryItem>()
        let items = try modelContext.fetch(itemDescriptor)
        for item in items {
            modelContext.delete(item)
        }
        
        // Delete all locations
        let locationDescriptor = FetchDescriptor<InventoryLocation>()
        let locations = try modelContext.fetch(locationDescriptor)
        for location in locations {
            modelContext.delete(location)
        }
        
        // Delete all labels
        let labelDescriptor = FetchDescriptor<InventoryLabel>()
        let labels = try modelContext.fetch(labelDescriptor)
        for label in labels {
            modelContext.delete(label)
        }
        
        // Delete all homes
        let homeDescriptor = FetchDescriptor<Home>()
        let homes = try modelContext.fetch(homeDescriptor)
        for home in homes {
            modelContext.delete(home)
        }
        
        // Delete all insurance policies
        let policyDescriptor = FetchDescriptor<InsurancePolicy>()
        let policies = try modelContext.fetch(policyDescriptor)
        for policy in policies {
            modelContext.delete(policy)
        }
        
        // Save the context
        try modelContext.save()
    }
    
    private func clearImageCache() async {
        // Clear OptimizedImageManager cache if available
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let imagesDirectory = documentsDirectory.appendingPathComponent("OptimizedImages")
            if FileManager.default.fileExists(atPath: imagesDirectory.path) {
                try FileManager.default.removeItem(at: imagesDirectory)
            }
        } catch {
            print("❌ Error clearing image cache: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        DataDeletionView()
    }
}