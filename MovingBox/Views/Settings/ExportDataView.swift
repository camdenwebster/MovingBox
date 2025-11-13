import SwiftUIBackports
import SwiftUI
import SwiftData

struct ExportDataView: View {
    @EnvironmentObject private var containerManager: ModelContainerManager
    @State private var exportCoordinator = ExportCoordinator()
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
                .accessibilityIdentifier("export-items-toggle")
                
                Toggle(isOn: $exportLocations) {
                    HStack {
                        Image(systemName: "map")
                            
                        Text("Export Locations")
                    }
                }
                .accessibilityIdentifier("export-locations-toggle")
                
                Toggle(isOn: $exportLabels) {
                    HStack {
                        Image(systemName: "tag")
                            
                        Text("Export Labels")
                    }
                }
                .accessibilityIdentifier("export-labels-toggle")
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
                        if exportCoordinator.isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Exporting…")
                        } else {
                            Text("Export Data")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .tint(.green)
                .disabled(exportCoordinator.isExporting || !hasExportOptionsSelected)
                .listRowInsets(EdgeInsets())
                .backport.glassProminentButtonStyle()
                .accessibilityIdentifier("export-data-button")
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
        .sheet(isPresented: $exportCoordinator.showShareSheet, onDismiss: {
            exportCoordinator.showExportProgress = false
            exportCoordinator.archiveURL = nil
        }) {
            if let url = exportCoordinator.archiveURL {
                ShareSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $exportCoordinator.showExportProgress) {
            ExportProgressView(
                phase: exportCoordinator.exportPhase,
                progress: exportCoordinator.exportProgress,
                onCancel: { exportCoordinator.cancelExport() }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert("Export Error", isPresented: $exportCoordinator.showExportError) {
            Button("OK") {
                exportCoordinator.exportError = nil
            }
        } message: {
            Text(exportCoordinator.exportError?.localizedDescription ?? "An error occurred while exporting data.")
        }
    }
    
    @MainActor
    private func startExport() async {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "MovingBox-export-\(timestamp).zip"
        let config = DataManager.ExportConfig(
            includeItems: exportItems,
            includeLocations: exportLocations,
            includeLabels: exportLabels
        )

        await exportCoordinator.exportWithProgress(
            modelContainer: containerManager.container,
            fileName: fileName,
            config: config
        )
    }
}

#Preview {
    NavigationStack {
        ExportDataView()
            .environmentObject(Router())
    }
}
