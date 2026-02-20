import Dependencies
import SQLiteData
import SwiftUI
import SwiftUIBackports

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

    private let database: any DatabaseWriter

    init(database: any DatabaseWriter) {
        self.database = database
    }

    func deleteAllData(scope: DeletionScope) async {
        guard !isDeleting else { return }

        isDeleting = true
        lastError = nil
        deletionCompleted = false

        defer { isDeleting = false }

        do {
            try await performDeletion(scope: scope)

            // Brief delay to let @FetchAll results refresh
            try await Task.sleep(for: .seconds(1))

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
        try await deleteSQLiteContent()
        await clearImageCache()
        try await createInitialHome()

        if scope == .localAndICloud {
            print("🗑️ Deleted all data including iCloud sync")
        } else {
            print("🗑️ Deleted local data only")
        }
    }

    private func createInitialHome() async throws {
        let newHomeID = UUID()
        try await database.write { db in
            try SQLiteHome.insert {
                SQLiteHome(
                    id: newHomeID,
                    name: "My Home",
                    isPrimary: true,
                    colorName: "green"
                )
            }.execute(db)
        }

        UserDefaults.standard.set(newHomeID.uuidString, forKey: "activeHomeId")
        print("🏠 Created initial home after data deletion")
    }

    private func deleteSQLiteContent() async throws {
        try await database.write { db in
            // Delete join tables first (foreign key safety)
            try SQLiteInventoryItemLabel.delete().execute(db)
            try SQLiteHomeInsurancePolicy.delete().execute(db)
            // Then child tables
            try SQLiteInventoryItem.delete().execute(db)
            try SQLiteInventoryLocation.delete().execute(db)
            try SQLiteInventoryLabel.delete().execute(db)
            try SQLiteInsurancePolicy.delete().execute(db)
            // Then parent table
            try SQLiteHome.delete().execute(db)
        }
    }

    private func clearImageCache() async {
        do {
            guard
                let documentsDirectory = FileManager.default.urls(
                    for: .documentDirectory, in: .userDomainMask
                ).first
            else {
                print("❌ DataDeletionView - Cannot access documents directory")
                return
            }
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
            return
                "Delete data only from this device. Your data will remain in iCloud and on other devices."
        case .localAndICloud:
            return
                "Delete all data from this device and iCloud. This will remove data from all your devices."
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
    @Dependency(\.defaultDatabase) var database
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: Router
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
                deletionService = DataDeletionService(database: database)
            }
        }
        .alert("Final Confirmation", isPresented: $showFinalConfirmation) {
            Button("Cancel", role: .cancel) {}
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
                // Dismiss back to settings and clear navigation stack
                // We stay in settings to avoid Dashboard which may have stale results
                Task {
                    // First dismiss this view
                    await MainActor.run {
                        dismiss()
                    }

                    // Give time for dismiss animation and SwiftData to process changes
                    // The 1s delay in the service + 500ms here = 1.5s total
                    try? await Task.sleep(for: .milliseconds(500))

                    // Clear navigation to go back to top-level settings view
                    // User can manually navigate to Dashboard when ready
                    await MainActor.run {
                        router.navigateToRoot()
                    }
                }
            }
        }
    }

    private var warningSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.title2)
                    Text("Warning")
                        .font(.headline)
                        .foregroundStyle(.red)
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
                .foregroundStyle(.secondary)
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
                            .contentTransition(
                                .symbolEffect(.replace.magic(fallback: .downUp.wholeSymbol), options: .nonRepeating)
                            )
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
                    .foregroundStyle(.secondary)

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
                    .foregroundStyle(isConfirmationValid && !isDeleting ? Color.red : Color.gray)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .clipShape(.rect(cornerRadius: UIConstants.cornerRadius))
                }
                .backport.glassButtonStyle()
                .disabled(!isConfirmationValid || isDeleting)
                .listRowInsets(EdgeInsets())
            }
            .padding(.vertical, 8)
        } footer: {
            Text(
                "This action is irreversible. Make sure you have exported your data if you want to keep a backup."
            )
            .font(.footnote)
            .foregroundStyle(.red)
        }
    }

    @MainActor
    private func handleDeleteAllData() async {
        guard let deletionService = deletionService else { return }
        await deletionService.deleteAllData(scope: selectedScope)
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    NavigationStack {
        DataDeletionView()
            .environmentObject(Router())
    }
}
