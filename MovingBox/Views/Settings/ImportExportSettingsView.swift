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
    @State private var importCompleted = false
    @State private var importProgress: Double = 0
    @State private var importError: Error?
    
    var body: some View {
        List {
            Section {
                Button {
                    showFileImporter = true
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
                Button {
                    Task {
                        await startExport()
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
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { result in
            Task { @MainActor in
                do {
                    // Reset state before starting import
                    importError = nil
                    importProgress = 0
                    importCompleted = false
                    showImportLoading = true
                    
                    let url = try result.get().first!
                    
                    for try await progress in await DataManager.shared.importInventory(
                        from: url,
                        modelContext: modelContext
                    ) {
                        switch progress {
                        case .progress(let value):
                            importProgress = value
                        case .completed(let result):
                            importedItemCount = result.itemCount
                            importedLocationCount = result.locationCount
                            importCompleted = true
                        case .error(let error):
                            importError = error
                            importCompleted = false
                        }
                    }
                } catch {
                    print("❌ Import error in settings view: \(error.localizedDescription)")
                    importError = error
                    importCompleted = false
                }
            }
        }
        .fullScreenCover(isPresented: $showImportLoading) {
            ImportLoadingView(
                importedItemCount: importedItemCount,
                importedLocationCount: importedLocationCount,
                isComplete: $showImportLoading,
                importCompleted: importCompleted,
                progress: importProgress,
                error: importError
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let archiveURL {
                ShareSheet(activityItems: [archiveURL])
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
            let url = try await DataManager.shared.exportInventory(modelContext: modelContext)
            archiveURL = url
            showShareSheet = true
        } catch {
            print("❌ Export error: \(error.localizedDescription)")
        }
    }
}

#Preview("ReportingSettingsView") {
    NavigationStack {
        ImportExportSettingsView()
            .environmentObject(Router())
    }
}
