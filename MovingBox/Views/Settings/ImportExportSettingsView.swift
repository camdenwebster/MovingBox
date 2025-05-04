//
//  ImportExportSettingsView.swift
//  MovingBox
//
//  Created by Camden Webster on 05/01/2025.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportExportSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isProcessingExport = false
    @State private var archiveURL: URL?
    @State private var showShareSheet = false
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
    @State private var exportItems = true
    @State private var exportLocations = true
    @State private var exportLabels = true
    @State private var showNoOptionsAlert = false
    @State private var noOptionsAlertType: NoOptionsAlertType = .export
    @State private var importTask: Task<Void, Never>?
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
    
    private enum NoOptionsAlertType {
        case export, importing
        
        var title: String {
            switch self {
            case .export: return "Cannot Export"
            case .importing: return "Cannot Import"
            }
        }
        
        var message: String {
            switch self {
            case .export: return "Please select at least one option to export."
            case .importing: return "Please select at least one option to import."
            }
        }
    }
    
    private var hasExportOptionsSelected: Bool {
        exportItems || exportLocations || exportLabels
    }
    
    private var hasImportOptionsSelected: Bool {
        importItems || importLocations || importLabels
    }
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: $importItems, label: {
                    Text("Import Items")
                })
                Toggle(isOn: $importLocations, label: {
                    Text("Import Locations ")
                })
                Toggle(isOn: $importLabels, label: {
                    Text("Import Labels")
                })
                Button {
                    if hasImportOptionsSelected {
                        showDuplicateWarning = true
                    } else {
                        noOptionsAlertType = .importing
                        showNoOptionsAlert = true
                    }
                } label: {
                    Text("Import Inventory")
                }
                .accessibilityIdentifier("importButton")
                .disabled(showImportLoading)
            } footer: {
                Text("Restore items from a previously exported ZIP file.")
                    .font(.footnote)
            }
            
            Section {
                Toggle(isOn: $exportItems, label: {
                    Text("Export Items")
                })
                Toggle(isOn: $exportLocations, label: {
                    Text("Export Locations ")
                })
                Toggle(isOn: $exportLabels, label: {
                    Text("Export Labels")
                })
                Button {
                    if hasExportOptionsSelected {
                        Task {
                            await startExport()
                        }
                    } else {
                        noOptionsAlertType = .export
                        showNoOptionsAlert = true
                    }
                } label: {
                    if isProcessingExport {
                        HStack {
                            ProgressView()
                            Text("Exporting…")
                        }
                    } else {
                        Text("Export Inventory")
                    }
                }
                .accessibilityIdentifier("exportButton")
                .disabled(isProcessingExport)
            } footer: {
                Text("Export a ZIP file containing all items and photos.")
                    .font(.footnote)
            }
        }
        .alert("Warning", isPresented: $showDuplicateWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                showFileImporter = true
            }
        } message: {
            Text("The import process does not check for duplicate data. Importing the same data multiple times may result in duplicate items, locations, and labels.")
        }
        .alert(noOptionsAlertType.title, isPresented: $showNoOptionsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(noOptionsAlertType.message)
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
                    print("❌ Import error in settings view: No file selected")
                    importError = NSError(domain: "ImportError", code: 0, userInfo: nil)
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
        .sheet(isPresented: $showShareSheet) {
            if let archiveURL {
                ShareSheet(activityItems: [archiveURL])
                    .onDisappear {
                        try? FileManager.default.removeItem(at: archiveURL)
                        self.archiveURL = nil
                    }
            }
        }
        .navigationTitle("Import & Export")
        .navigationBarTitleDisplayMode(.inline)
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
                print("❌ Import error in settings view: \(error.localizedDescription)")
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

#Preview("ReportingSettingsView") {
    NavigationStack {
        ImportExportSettingsView()
            .environmentObject(Router())
    }
}
