import SwiftUIBackports
import SwiftUI
import SwiftData

/// Protocol for data deletion operations - enables dependency injection and testing
@MainActor
protocol DataDeletionServiceProtocol {
    var isDeleting: Bool { get }
    var lastError: Error? { get }
    var deletionCompleted: Bool { get }
    
    func deleteAllData(scope: DeletionScope) async
    func resetState()
}

/// Default implementation of data deletion service
@MainActor
@Observable
final class DataDeletionService: DataDeletionServiceProtocol {
    private(set) var isDeleting = false
    private(set) var lastError: Error?
    private(set) var deletionCompleted = false
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func deleteAllData(scope: DeletionScope) async {
        guard !isDeleting else { return }
        
        isDeleting = true
        lastError = nil
        deletionCompleted = false
        
        defer { isDeleting = false }
        
        do {
            try await performDeletion(scope: scope)
            deletionCompleted = true
        } catch {
            lastError = error
            print("❌ Error deleting data: \(error)")
        }
    }
    
    func resetState() {
        lastError = nil
        deletionCompleted = false
    }
    
    private func performDeletion(scope: DeletionScope) async throws {
        try await deleteSwiftDataContent()
        await clearImageCache()
        
        if scope == .localAndICloud {
            print("🗑️ Deleted all data including iCloud sync")
        } else {
            print("🗑️ Deleted local data only")
        }
    }
    
    private func deleteSwiftDataContent() async throws {
        let itemDescriptor = FetchDescriptor<InventoryItem>()
        let items = try modelContext.fetch(itemDescriptor)
        for item in items {
            modelContext.delete(item)
        }
        
        let locationDescriptor = FetchDescriptor<InventoryLocation>()
        let locations = try modelContext.fetch(locationDescriptor)
        for location in locations {
            modelContext.delete(location)
        }
        
        let labelDescriptor = FetchDescriptor<InventoryLabel>()
        let labels = try modelContext.fetch(labelDescriptor)
        for label in labels {
            modelContext.delete(label)
        }
        
        let homeDescriptor = FetchDescriptor<Home>()
        let homes = try modelContext.fetch(homeDescriptor)
        for home in homes {
            modelContext.delete(home)
        }
        
        let policyDescriptor = FetchDescriptor<InsurancePolicy>()
        let policies = try modelContext.fetch(policyDescriptor)
        for policy in policies {
            modelContext.delete(policy)
        }
        
        try modelContext.save()
    }
    
    private func clearImageCache() async {
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
    @State private var confirmationText = ""
    @State private var showFinalConfirmation = false
    @State private var showErrorAlert = false
    @State private var deletionService: DataDeletionServiceProtocol?
    
    private let requiredConfirmationText = "DELETE"
    
    // Dependency injection initializer for testing
    init(deletionService: DataDeletionServiceProtocol? = nil) {
        self._deletionService = State(initialValue: deletionService)
    }
    
    private var isConfirmationValid: Bool {
        confirmationText.uppercased() == requiredConfirmationText
    }
    
    private var isDeleting: Bool {
        deletionService?.isDeleting ?? false
    }
    
    private var errorMessage: String {
        deletionService?.lastError?.localizedDescription ?? ""
    }
    
    private var hasError: Bool {
        deletionService?.lastError != nil
    }
    
    var body: some View {
        List {
            warningSection
            scopeSelectionSection
            confirmationSection
        }
        .navigationTitle("Delete All Data")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if deletionService == nil {
                deletionService = DataDeletionService(modelContext: modelContext)
            }
        }
        .alert("Final Confirmation", isPresented: $showFinalConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All Data", role: .destructive) {
                Task {
                    await handleDeleteAllData()
                }
            }
        } message: {
            Text("This action cannot be undone. Are you sure you want to delete all your inventory data?")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { 
                deletionService?.resetState()
            }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: hasError) { _, hasError in
            showErrorAlert = hasError
        }
        .onChange(of: deletionService?.deletionCompleted) { _, completed in
            if completed == true {
                dismiss()
            }
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
                                    .foregroundStyle(selectedScope == scope ? .green : .secondary)
                                Text(scope.rawValue)
                                    .foregroundStyle(.primary)
                                    .font(.headline)
                            }
                            Text(scope.description)
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        Spacer()
                        Image(systemName: selectedScope == scope ? "checkmark.circle.fill" : "circle")
                            
                            .font(.title)
                            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.wholeSymbol), options: .nonRepeating))
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
                    .foregroundColor(isConfirmationValid && !isDeleting ? Color.red : Color.gray)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .cornerRadius(UIConstants.cornerRadius)
                }
                .backport.glassButtonStyle()
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
    private func handleDeleteAllData() async {
        guard let deletionService = deletionService else { return }
        await deletionService.deleteAllData(scope: selectedScope)
    }
}

#Preview {
    NavigationStack {
        DataDeletionView()
    }
}
