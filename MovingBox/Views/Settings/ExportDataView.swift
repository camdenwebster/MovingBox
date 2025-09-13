import SwiftUI
import SwiftData

struct ExportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isProcessingExport = false
    @State private var archiveURL: URL?
    @State private var showShareSheet = false
    @State private var exportItems = true
    @State private var exportLocations = true
    @State private var exportLabels = true
    @State private var showNoOptionsAlert = false
    
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
    }
    
    @MainActor
    private func startExport() async {
        isProcessingExport = true
        defer { isProcessingExport = false }
        
        do {
            let timestamp = dateFormatter.string(from: Date())
            let fileName = "MovingBox-export-\(timestamp).zip"
            let config = DataManager.ExportConfig(
                includeItems: exportItems,
                includeLocations: exportLocations,
                includeLabels: exportLabels
            )
            let url = try await DataManager.shared.exportInventory(
                modelContext: modelContext,
                fileName: fileName,
                config: config
            )
            archiveURL = url
            showShareSheet = true
        } catch {
            print("❌ Export error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        ExportDataView()
            .environmentObject(Router())
    }
}
