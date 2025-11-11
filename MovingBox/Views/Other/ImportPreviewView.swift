import SwiftUI
import SwiftData

struct ImportPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let previewData: DataManager.ImportResult
    let zipURL: URL
    let config: DataManager.ImportConfig
    let onImportComplete: (DataManager.ImportResult) -> Void
    
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var importError: Error?
    @State private var importTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                if let error = importError {
                    errorView(error)
                } else if isImporting {
                    importingView
                } else {
                    previewView
                }
                
                Spacer()
                
                if !isImporting && importError == nil {
                    actionButtons
                }
            }
            .padding()
            .navigationTitle("Ready to Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isImporting {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private var previewView: some View {
        VStack(spacing: 24) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Ready to Import")
                .font(.title2.bold())
            
            VStack(spacing: 16) {
                if config.includeItems && previewData.itemCount > 0 {
                    PreviewRow(
                        icon: "cube.box.fill",
                        count: previewData.itemCount,
                        label: previewData.itemCount == 1 ? "Item" : "Items"
                    )
                }
                
                if config.includeLocations && previewData.locationCount > 0 {
                    PreviewRow(
                        icon: "map.fill",
                        count: previewData.locationCount,
                        label: previewData.locationCount == 1 ? "Location" : "Locations"
                    )
                }
                
                if config.includeLabels && previewData.labelCount > 0 {
                    PreviewRow(
                        icon: "tag.fill",
                        count: previewData.labelCount,
                        label: previewData.labelCount == 1 ? "Label" : "Labels"
                    )
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            }
            
            Text("This data will be added to your existing inventory.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var importingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .controlSize(.large)
            
            Text("Importing your data...")
                .font(.headline)
            
            VStack(spacing: 8) {
                ProgressView(value: importProgress)
                    .progressViewStyle(.linear)
                    .tint(.green)
                
                Text("\(Int(importProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 300)
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Import Failed")
                .font(.title2.bold())
            
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: startImport) {
                HStack {
                    if isImporting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isImporting ? "Importing..." : "Import Data")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isImporting)
            
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
    }
    
    private func startImport() {
        isImporting = true
        print("🔵 ImportPreviewView: startImport() called")
        importTask = Task {
            do {
                print("🔵 ImportPreviewView: accessing security-scoped resource")
                guard zipURL.startAccessingSecurityScopedResource() else {
                    throw NSError(
                        domain: "ImportError",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to access the selected file"]
                    )
                }
                
                defer {
                    print("🔵 ImportPreviewView: stopping security-scoped resource access")
                    zipURL.stopAccessingSecurityScopedResource()
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
                
                print("🔵 ImportPreviewView: copying ZIP file")
                try FileManager.default.copyItem(at: zipURL, to: importURL)
                print("🔵 ImportPreviewView: ZIP copied, starting import")
                
                var progressCount = 0
                for try await progress in await DataManager.shared.importInventory(
                    from: importURL,
                    modelContext: modelContext,
                    config: config
                ) {
                    progressCount += 1
                    if progressCount % 50 == 0 {
                        print("🔵 ImportPreviewView: progress update #\(progressCount)")
                    }
                    
                    if Task.isCancelled {
                        print("🔵 ImportPreviewView: task cancelled")
                        try? FileManager.default.removeItem(at: importURL)
                        throw NSError(
                            domain: "ImportError",
                            code: -999,
                            userInfo: [NSLocalizedDescriptionKey: "Import cancelled by user"]
                        )
                    }
                    
                    switch progress {
                    case .progress(let value):
                        await MainActor.run {
                            importProgress = value
                        }
                    case .completed(let result):
                        print("🔵 ImportPreviewView: import completed with \(result.itemCount) items, \(result.locationCount) locations, \(result.labelCount) labels")
                        try? FileManager.default.removeItem(at: importURL)
                        if let contents = try? FileManager.default.contentsOfDirectory(
                            at: importDirectory,
                            includingPropertiesForKeys: nil
                        ), contents.isEmpty {
                            try? FileManager.default.removeItem(at: importDirectory)
                        }
                        
                        print("🔵 ImportPreviewView: calling onImportComplete on MainActor")
                        await MainActor.run {
                            print("🔵 ImportPreviewView: on MainActor, calling onImportComplete")
                            onImportComplete(result)
                            print("🔵 ImportPreviewView: onImportComplete called, NOT dismissing - success view will handle it")
                        }
                    case .error(let error):
                        print("🔵 ImportPreviewView: import error: \(error.localizedDescription)")
                        try? FileManager.default.removeItem(at: importURL)
                        await MainActor.run {
                            importError = error
                            isImporting = false
                        }
                    }
                }
                print("🔵 ImportPreviewView: for-await loop completed")
            } catch {
                print("🔵 ImportPreviewView: caught error: \(error.localizedDescription)")
                await MainActor.run {
                    importError = error
                    isImporting = false
                }
            }
        }
    }
}

struct PreviewRow: View {
    let icon: String
    let count: Int
    let label: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 40)
            
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Text(label)
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
}
