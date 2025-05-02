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
    @State private var isProcessingImport = false
    @State private var isProcessingExport = false
    @State private var archiveURL: URL?
    @State private var showShareSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String = ""
    @State private var showFileImporter = false
    @State private var showImportSuccess = false
    @State private var importedItemCount: Int = 0
    @State private var importedLocationCount: Int = 0
    
    var body: some View {
        List {
            Section {
                Button {
                    showFileImporter = true
                } label: {
                    if isProcessingImport {
                        HStack {
                            ProgressView()
                            Text("Importing…")
                        }
                    } else {
                        Text("Import Inventory")
                    }
                }
                .accessibilityIdentifier("importButton")
                .disabled(isProcessingImport)
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
        .navigationTitle("Import & Export")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Export Failed", isPresented: $showErrorAlert) {
        } message: {
            Text(errorMessage)
        }
        .alert("Import Successful", isPresented: $showImportSuccess) {
        } message: {
            Text("Successfully imported:\n- \(importedItemCount) items\n- \(importedLocationCount) locations")
        }
        .sheet(isPresented: $showShareSheet) {
            if let archiveURL {
                ShareSheet(activityItems: [archiveURL])
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { result in
            Task {
                do {
                    let url = try result.get().first!
                    isProcessingImport = true
                    defer { isProcessingImport = false }
                    
                    let importResult = try await DataManager.shared.importInventory(
                        from: url,
                        modelContext: modelContext
                    )
                    importedItemCount = importResult.itemCount
                    importedLocationCount = importResult.locationCount
                    showImportSuccess = true
                } catch {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
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
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

#Preview("ReportingSettingsView") {
    NavigationStack {
        ImportExportSettingsView()
            .environmentObject(Router())
    }
}
