import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showFileImporter = false
    @State private var showImportLoading = false
    @State private var importedItemCount: Int = 0
    @State private var importedLocationCount: Int = 0
    @State private var importedLabelCount: Int = 0
    @State private var importCompleted = false
    @State private var importProgress: Double = 0
    @State private var importError: Error?
    @State private var showDuplicateWarning = false
    @State private var importItems = true
    @State private var importLocations = true
    @State private var importLabels = true
    @State private var importTask: Task<Void, Never>?
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: $importItems) {
                    HStack {
                        Image(systemName: "cube.box")
                            
                        Text("Import Items")
                    }
                }
                
                Toggle(isOn: $importLocations) {
                    HStack {
                        Image(systemName: "map")
                            
                        Text("Import Locations")
                    }
                }
                
                Toggle(isOn: $importLabels) {
                    HStack {
                        Image(systemName: "tag")
                            
                        Text("Import Labels")
                    }
                }
            }
            
            Section {
                Button {
                    if hasImportOptionsSelected {
                        showDuplicateWarning = true
                    }
                } label: {
                    Text("Import Data from ZIP")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .cornerRadius(10)
                }
                .disabled(!hasImportOptionsSelected || showImportLoading)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("Restore items from a previously exported ZIP file.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Warning", isPresented: $showDuplicateWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                showFileImporter = true
            }
        } message: {
            Text("The import process does not check for duplicate data. Importing the same data multiple times may result in duplicate items, locations, and labels.")
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { result in
            Task { @MainActor in
                if let url = try? result.get().first {
                    await handleImport(url: url)
                } else {
                    print("❌ Import error: No file selected")
                    importError = NSError(domain: "ImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No file selected"])
                    importCompleted = false
                }
            }
        }
        .fullScreenCover(isPresented: $showImportLoading) {
            ImportLoadingView(
                importedItemCount: importedItemCount,
                importedLocationCount: importedLocationCount,
                importedLabelCount: importedLabelCount,
                isComplete: $showImportLoading,
                importCompleted: importCompleted,
                progress: importProgress,
                error: importError,
                onCancel: cancelImport
            )
        }
    }
    
    private var hasImportOptionsSelected: Bool {
        importItems || importLocations || importLabels
    }
    
    private func handleImport(url: URL) async {
        importTask = Task {
            do {
                importError = nil
                importProgress = 0
                importCompleted = false
                showImportLoading = true
                
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(
                        domain: "ImportError",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to access the selected file"]
                    )
                }
                
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                let documentsDirectory = FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                ).first!
                let importDirectory = documentsDirectory.appendingPathComponent("Imports", isDirectory: true)
                
                if !FileManager.default.fileExists(atPath: importDirectory.path) {
                    try FileManager.default.createDirectory(
                        at: importDirectory,
                        withIntermediateDirectories: true
                    )
                }
                
                let importURL = importDirectory.appendingPathComponent(UUID().uuidString + ".zip")
                
                if FileManager.default.fileExists(atPath: importURL.path) {
                    try FileManager.default.removeItem(at: importURL)
                }
                
                print("📦 Copying file to: \(importURL.path)")
                
                try FileManager.default.copyItem(at: url, to: importURL)
                
                let config = DataManager.ImportConfig(
                    includeItems: importItems,
                    includeLocations: importLocations,
                    includeLabels: importLabels
                )
                
                for try await progress in await DataManager.shared.importInventory(
                    from: importURL,
                    modelContext: modelContext,
                    config: config
                ) {
                    if Task.isCancelled {
                        try? FileManager.default.removeItem(at: importURL)
                        throw NSError(
                            domain: "ImportError",
                            code: -999,
                            userInfo: [NSLocalizedDescriptionKey: "Import cancelled by user"]
                        )
                    }
                    
                    switch progress {
                    case .progress(let value):
                        importProgress = value
                    case .completed(let result):
                        importedItemCount = result.itemCount
                        importedLocationCount = result.locationCount
                        importedLabelCount = result.labelCount
                        importCompleted = true
                        try? FileManager.default.removeItem(at: importURL)
                        if let contents = try? FileManager.default.contentsOfDirectory(
                            at: importDirectory,
                            includingPropertiesForKeys: nil
                        ), contents.isEmpty {
                            try? FileManager.default.removeItem(at: importDirectory)
                        }
                    case .error(let error):
                        importError = error
                        importCompleted = false
                        try? FileManager.default.removeItem(at: importURL)
                    }
                }
            } catch {
                print("❌ Import error: \(error.localizedDescription)")
                importError = error
                importCompleted = false
            }
        }
    }
    
    private func cancelImport() {
        importTask?.cancel()
        importTask = nil
        showImportLoading = false
    }
}

#Preview {
    NavigationStack {
        ImportDataView()
            .environmentObject(Router())
    }
}
