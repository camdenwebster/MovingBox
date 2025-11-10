import SwiftUI
import SwiftData

struct ExportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isProcessingExport = false
    @State private var exportProgress: Double = 0
    @State private var exportPhase: String = ""
    @State private var showExportLoading = false
    @State private var archiveURL: URL?
    @State private var showShareSheet = false
    @State private var exportItems = true
    @State private var exportLocations = true
    @State private var exportLabels = true
    @State private var showNoOptionsAlert = false
    @State private var exportError: Error?
    @State private var exportCompleted = false
    @State private var exportTask: Task<Void, Never>?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
    
    private var hasExportOptionsSelected: Bool {
        exportItems || exportLocations || exportLabels
    }
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $exportItems) {
                    HStack {
                        Image(systemName: "cube.box")
                            
                        Text("Export Items")
                    }
                }
                
                Toggle(isOn: $exportLocations) {
                    HStack {
                        Image(systemName: "map")
                            
                        Text("Export Locations")
                    }
                }
                
                Toggle(isOn: $exportLabels) {
                    HStack {
                        Image(systemName: "tag")
                            
                        Text("Export Labels")
                    }
                }
            }
            
            Section {
                Button {
                    if hasExportOptionsSelected {
                        Task {
                            await startExport()
                        }
                    } else {
                        showNoOptionsAlert = true
                    }
                } label: {
                    HStack {
                        if isProcessingExport {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Exporting…")
                        } else {
                            Text("Export Data")
                        }
                    }

                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.green)
                .cornerRadius(10)
                .disabled(isProcessingExport || !hasExportOptionsSelected)
                .listRowInsets(EdgeInsets())
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export a ZIP file containing the selected items and photos.")
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Cannot Export", isPresented: $showNoOptionsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please select at least one option to export.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let archiveURL {
                ShareSheet(activityItems: [archiveURL])
                    .onDisappear {
                        try? FileManager.default.removeItem(at: archiveURL)
                        self.archiveURL = nil
                    }
            }
        }
        .fullScreenCover(isPresented: $showExportLoading) {
            ExportLoadingView(
                isComplete: $showExportLoading,
                exportCompleted: exportCompleted,
                progress: exportProgress,
                phase: exportPhase,
                error: exportError,
                archiveURL: archiveURL,
                onCancel: cancelExport,
                onShare: handleExportShare
            )
        }
    }
    
    @MainActor
    private func startExport() async {
        exportTask = Task {
            do {
                exportError = nil
                exportProgress = 0
                exportCompleted = false
                exportPhase = ""
                showExportLoading = true
                
                let timestamp = dateFormatter.string(from: Date())
                let fileName = "MovingBox-export-\(timestamp).zip"
                let config = DataManager.ExportConfig(
                    includeItems: exportItems,
                    includeLocations: exportLocations,
                    includeLabels: exportLabels
                )
                
                for await progress in DataManager.shared.exportInventoryWithProgress(
                    modelContext: modelContext,
                    fileName: fileName,
                    config: config
                ) {
                    if Task.isCancelled {
                        throw NSError(
                            domain: "ExportError",
                            code: -999,
                            userInfo: [NSLocalizedDescriptionKey: "Export cancelled by user"]
                        )
                    }
                    
                    switch progress {
                    case .preparing:
                        exportPhase = "Preparing export..."
                        exportProgress = 0.0
                        
                    case .fetchingData(let phase, let progressValue):
                        exportPhase = "Fetching \(phase)..."
                        exportProgress = progressValue * 0.3
                        
                    case .writingCSV(let progressValue):
                        exportPhase = "Writing CSV files..."
                        exportProgress = 0.3 + (progressValue * 0.2)
                        
                    case .copyingPhotos(let current, let total):
                        exportPhase = "Copying photos (\(current)/\(total))..."
                        let photoProgress = Double(current) / Double(total)
                        exportProgress = 0.5 + (photoProgress * 0.3)
                        
                    case .creatingArchive(let progressValue):
                        exportPhase = "Creating archive..."
                        exportProgress = 0.8 + (progressValue * 0.2)
                        
                    case .completed(let result):
                        archiveURL = result.archiveURL
                        exportCompleted = true
                        // Don't auto-dismiss - let user tap Share button
                        
                    case .error(let error):
                        exportError = error
                        exportCompleted = false
                        showExportLoading = false
                    }
                }
            } catch {
                print("❌ Export error: \(error.localizedDescription)")
                exportError = error
                exportCompleted = false
                showExportLoading = false
            }
        }
    }
    
    private func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        showExportLoading = false
    }
    
    private func handleExportShare() {
        guard let archiveURL = archiveURL else { return }
        
        // Copy to Documents directory for better share sheet compatibility
        do {
            let documentsURL = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let shareableURL = documentsURL.appendingPathComponent(archiveURL.lastPathComponent)
            
            // Remove if exists
            try? FileManager.default.removeItem(at: shareableURL)
            
            // Copy file
            try FileManager.default.copyItem(at: archiveURL, to: shareableURL)
            
            // Update the archive URL to the new location
            self.archiveURL = shareableURL
            
            showExportLoading = false
            showShareSheet = true
        } catch {
            print("❌ Failed to prepare file for sharing: \(error)")
            exportError = error
            showExportLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        ExportDataView()
            .environmentObject(Router())
    }
}
