//
//  ImportExportSettingsView.swift
//  MovingBox
//
//  Created by Camden Webster on 05/01/2025.
//

import SwiftUI
import SwiftData

struct ImportExportSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isProcessing = false
    @State private var archiveURL: URL?
    @State private var showShareSheet = false
    @State private var showErrorAlert = false
    @State private var exportError: String = ""

    var body: some View {
        List {
            Section {
                Button {
                    Task {
                        await startExport()
                    }
                } label: {
                    if isProcessing {
                        HStack {
                            ProgressView()
                            Text("Exporting…")
                        }
                    } else {
                        Text("Export Inventory")
                    }
                }
                .disabled(isProcessing)
            } footer: {
                Text("Generates a CSV file containing all items plus a folder of photos, then compresses everything into a zip archive.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Import & Export")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Export Failed", isPresented: $showErrorAlert, actions: {}) {
            Text(exportError)
        }
        .sheet(isPresented: $showShareSheet) {
            if let archiveURL {
                ShareSheet(activityItems: [archiveURL])
            }
        }
    }

    @MainActor
    private func startExport() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let url = try await ExportManager.shared.exportInventory(modelContext: modelContext)
            archiveURL = url
            showShareSheet = true
        } catch {
            exportError = error.localizedDescription
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
