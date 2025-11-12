import SwiftUIBackports
import SwiftUI
import SwiftData

struct ImportPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let previewData: DataManager.ImportResult
    let zipURL: URL
    let config: DataManager.ImportConfig
    let onImportComplete: (DataManager.ImportResult) -> Void
    
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var importError: Error?
    @State private var importTask: Task<Void, Never>?
    
    private var backgroundImage: String {
        colorScheme == .dark ? "background-dark" : "background-light"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                if let image = UIImage(named: backgroundImage) {
                    Image(uiImage: image)
                        .resizable()
                        .renderingMode(.original)
                        .interpolation(.medium)
                        .scaledToFill()
                        .ignoresSafeArea()
                        .opacity(0.5)
                }
                
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
                .padding(.horizontal, 60)
             }
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
            }
            .tint(.green)
            .backport.glassProminentButtonStyle()
            .disabled(isImporting)
        }
        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
    }
    
     private func startImport() {
         isImporting = true
         importTask = Task {
             do {
                 guard zipURL.startAccessingSecurityScopedResource() else {
                     throw NSError(
                         domain: "ImportError",
                         code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Unable to access the selected file"]
                     )
                 }
                 
                 defer {
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
                
                try FileManager.default.copyItem(at: zipURL, to: importURL)
                
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
                        await MainActor.run {
                            importProgress = value
                        }
                    case .completed(let result):
                        try? FileManager.default.removeItem(at: importURL)
                        if let contents = try? FileManager.default.contentsOfDirectory(
                            at: importDirectory,
                            includingPropertiesForKeys: nil
                        ), contents.isEmpty {
                            try? FileManager.default.removeItem(at: importDirectory)
                         }
                         
                         await MainActor.run {
                             onImportComplete(result)
                         }
                    case .error(let error):
                        try? FileManager.default.removeItem(at: importURL)
                        await MainActor.run {
                            importError = error
                            isImporting = false
                        }
                    }
                }
             } catch {
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

struct ImportPreviewViewPreviewContainer: View {
    @State private var isImporting = false
    @State private var importProgress = 0.0
    @State private var importError: Error? = nil
    @Environment(\.colorScheme) private var colorScheme
    let previewData: DataManager.ImportResult
    let config: DataManager.ImportConfig
    let state: PreviewState
    
    enum PreviewState {
        case preview
        case importing(Double)
        case error(Error)
    }
    
    private var backgroundImage: String {
        colorScheme == .dark ? "background-dark" : "background-light"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                if let image = UIImage(named: backgroundImage) {
                    Image(uiImage: image)
                        .resizable()
                        .renderingMode(.original)
                        .interpolation(.medium)
                        .scaledToFill()
                        .ignoresSafeArea()
                        .opacity(0.5)
                }
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    switch state {
                    case .preview:
                        previewView
                    case .importing(let progress):
                        importingView(progress: progress)
                    case .error(let error):
                        errorView(error)
                    }
                    
                    Spacer()
                    
                    if case .preview = state {
                        actionButtons
                    }
                }
                .padding(.horizontal, 60)
            }
            .navigationTitle("Ready to Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if case .preview = state {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { }
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
    
    private func importingView(progress: Double) -> some View {
        VStack(spacing: 24) {
            ProgressView()
                .controlSize(.large)
            
            Text("Importing your data...")
                .font(.headline)
            
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.green)
                
                Text("\(Int(progress * 100))%")
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
            
            Button("Close") { }
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { }) {
                HStack {
                    Text("Import Data")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .tint(.green)
            .backport.glassProminentButtonStyle()
        }
        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
    }
}

#Preview("Preview State - All Data") {
    ImportPreviewViewPreviewContainer(
        previewData: DataManager.ImportResult(
            itemCount: 42,
            locationCount: 5,
            labelCount: 8
        ),
        config: DataManager.ImportConfig(
            includeItems: true,
            includeLocations: true,
            includeLabels: true
        ),
        state: .preview
    )
}

#Preview("Preview State - Items Only") {
    ImportPreviewViewPreviewContainer(
        previewData: DataManager.ImportResult(
            itemCount: 100,
            locationCount: 0,
            labelCount: 0
        ),
        config: DataManager.ImportConfig(
            includeItems: true,
            includeLocations: false,
            includeLabels: false
        ),
        state: .preview
    )
}

#Preview("Preview State - Single Item Each") {
    ImportPreviewViewPreviewContainer(
        previewData: DataManager.ImportResult(
            itemCount: 1,
            locationCount: 1,
            labelCount: 1
        ),
        config: DataManager.ImportConfig(
            includeItems: true,
            includeLocations: true,
            includeLabels: true
        ),
        state: .preview
    )
}

#Preview("Importing State - 25%") {
    ImportPreviewViewPreviewContainer(
        previewData: DataManager.ImportResult(
            itemCount: 42,
            locationCount: 5,
            labelCount: 8
        ),
        config: DataManager.ImportConfig(
            includeItems: true,
            includeLocations: true,
            includeLabels: true
        ),
        state: .importing(0.25)
    )
}

#Preview("Importing State - 50%") {
    ImportPreviewViewPreviewContainer(
        previewData: DataManager.ImportResult(
            itemCount: 42,
            locationCount: 5,
            labelCount: 8
        ),
        config: DataManager.ImportConfig(
            includeItems: true,
            includeLocations: true,
            includeLabels: true
        ),
        state: .importing(0.5)
    )
}

#Preview("Importing State - 75%") {
    ImportPreviewViewPreviewContainer(
        previewData: DataManager.ImportResult(
            itemCount: 42,
            locationCount: 5,
            labelCount: 8
        ),
        config: DataManager.ImportConfig(
            includeItems: true,
            includeLocations: true,
            includeLabels: true
        ),
        state: .importing(0.75)
    )
}

#Preview("Error State") {
    ImportPreviewViewPreviewContainer(
        previewData: DataManager.ImportResult(
            itemCount: 42,
            locationCount: 5,
            labelCount: 8
        ),
        config: DataManager.ImportConfig(
            includeItems: true,
            includeLocations: true,
            includeLabels: true
        ),
        state: .error(NSError(
            domain: "ImportError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to access the selected file. Please check permissions and try again."]
        ))
    )
}
