import SwiftData
import SwiftUI
import SwiftUIBackports

struct ImportPreviewView: View {
    @Environment(ModelContainerManager.self) private var containerManager
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
        ImportPreviewContentView(
            previewData: previewData,
            config: config,
            isImporting: isImporting,
            importProgress: importProgress,
            importError: importError,
            onStartImport: startImport,
            onDismiss: { dismiss() }
        )
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

                guard
                    let documentsDirectory = FileManager.default.urls(
                        for: .documentDirectory,
                        in: .userDomainMask
                    ).first
                else {
                    throw NSError(
                        domain: "ImportPreviewView", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot access documents directory"])
                }
                let importDirectory = documentsDirectory.appendingPathComponent(
                    "Imports", isDirectory: true)

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
                    modelContainer: containerManager.container,
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
                    case .error(let sendableError):
                        try? FileManager.default.removeItem(at: importURL)
                        await MainActor.run {
                            importError = sendableError.toError()
                            isImporting = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    importError = NSError(
                        domain: "ImportError", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                    isImporting = false
                }
            }
        }
    }
}

struct ImportPreviewContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var previousState: ViewState = .preview

    let previewData: DataManager.ImportResult
    let config: DataManager.ImportConfig
    let isImporting: Bool
    let importProgress: Double
    let importError: Error?
    let onStartImport: () -> Void
    let onDismiss: () -> Void

    enum ViewState: Equatable {
        case preview
        case importing
        case error

        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.preview, .preview), (.importing, .importing), (.error, .error):
                return true
            default:
                return false
            }
        }
    }

    private var currentState: ViewState {
        if importError != nil {
            return .error
        } else if isImporting {
            return .importing
        } else {
            return .preview
        }
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

                    if let error = importError {
                        errorView(error)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    } else if isImporting {
                        importingView
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    } else {
                        previewView
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    }

                    Spacer()

                    if !isImporting && importError == nil {
                        actionButtons
                    }
                }
                .padding(.horizontal, 60)
                .animation(.easeInOut(duration: 0.3), value: currentState)
            }
            .navigationTitle("Ready to Import")
            .movingBoxNavigationTitleDisplayModeInline()
            .toolbar {
                if !isImporting {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            onDismiss()
                        }
                        .accessibilityIdentifier("import-preview-dismiss-button")
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
            Spacer()

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Import Failed")
                .font(.title2.bold())

            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Text("Close")
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .tint(.red)
            .backport.glassProminentButtonStyle()
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onStartImport) {
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
            .accessibilityIdentifier("import-preview-start-button")
        }
        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
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

#Preview("Preview State - All Data") {
    ImportPreviewContentView(
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
        isImporting: false,
        importProgress: 0,
        importError: nil,
        onStartImport: {},
        onDismiss: {}
    )
}

#Preview("Preview State - Items Only") {
    ImportPreviewContentView(
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
        isImporting: false,
        importProgress: 0,
        importError: nil,
        onStartImport: {},
        onDismiss: {}
    )
}

#Preview("Preview State - Single Item Each") {
    ImportPreviewContentView(
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
        isImporting: false,
        importProgress: 0,
        importError: nil,
        onStartImport: {},
        onDismiss: {}
    )
}

#Preview("Importing State - 25%") {
    ImportPreviewContentView(
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
        isImporting: true,
        importProgress: 0.25,
        importError: nil,
        onStartImport: {},
        onDismiss: {}
    )
}

#Preview("Importing State - 50%") {
    ImportPreviewContentView(
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
        isImporting: true,
        importProgress: 0.5,
        importError: nil,
        onStartImport: {},
        onDismiss: {}
    )
}

#Preview("Importing State - 75%") {
    ImportPreviewContentView(
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
        isImporting: true,
        importProgress: 0.75,
        importError: nil,
        onStartImport: {},
        onDismiss: {}
    )
}

#Preview("Error State") {
    ImportPreviewContentView(
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
        isImporting: false,
        importProgress: 0,
        importError: NSError(
            domain: "ImportError",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Unable to access the selected file. Please check permissions and try again."
            ]
        ),
        onStartImport: {},
        onDismiss: {}
    )
}
