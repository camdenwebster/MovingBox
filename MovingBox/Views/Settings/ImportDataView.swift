import SwiftData
import SwiftUI
import SwiftUIBackports
import UniformTypeIdentifiers

struct ImportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var router: Router
    @State private var showFileImporter = false
    @State private var showPreviewView = false
    @State private var showSuccessView = false
    @State private var previewData: DataManager.ImportResult?
    @State private var selectedZipURL: URL?
    @State private var isValidatingZip = false
    @State private var validationError: Error?
    @State private var showDuplicateWarning = false
    @State private var importItems = true
    @State private var importLocations = true
    @State private var importLabels = true
    @State private var importResult: DataManager.ImportResult?
    @State private var didCompleteImport = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $importItems) {
                    HStack {
                        Image(systemName: "cube.box")

                        Text("Import Items")
                    }
                }
                .accessibilityIdentifier("import-items-toggle")

                Toggle(isOn: $importLocations) {
                    HStack {
                        Image(systemName: "map")

                        Text("Import Locations")
                    }
                }
                .accessibilityIdentifier("import-locations-toggle")

                Toggle(isOn: $importLabels) {
                    HStack {
                        Image(systemName: "tag")

                        Text("Import Labels")
                    }
                }
                .accessibilityIdentifier("import-labels-toggle")
            }

            Section {
                Button {
                    if hasImportOptionsSelected {
                        showDuplicateWarning = true
                    }
                } label: {
                    HStack {
                        if isValidatingZip {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isValidatingZip ? "Validating..." : "Select ZIP File")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .tint(.green)
                .backport.glassProminentButtonStyle()
                .disabled(!hasImportOptionsSelected || isValidatingZip)
                .listRowInsets(EdgeInsets())
                .accessibilityIdentifier("import-select-file-button")
            } footer: {
                Text(
                    "Restore data from a ZIP file that was previously exported from MovingBox. Files from other apps cannot be imported."
                )
                .font(.footnote)
            }
        }
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Warning", isPresented: $showDuplicateWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Continue") {
                showFileImporter = true
            }
        } message: {
            Text(
                "The import process does not check for duplicate data. Importing the same data multiple times may result in duplicate items, locations, and labels."
            )
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { result in
            Task { @MainActor in
                if let url = try? result.get().first {
                    await validateAndPreview(url: url)
                } else {
                    validationError = NSError(
                        domain: "ImportError", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "No file selected"])
                }
            }
        }
        .fullScreenCover(isPresented: $showPreviewView) {
            if let result = importResult {
                ImportSuccessView(importResult: result)
                    .environmentObject(router)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)))
            } else if let previewData = previewData, let zipURL = selectedZipURL {
                ImportPreviewView(
                    previewData: previewData,
                    zipURL: zipURL,
                    config: DataManager.ImportConfig(
                        includeItems: importItems,
                        includeLocations: importLocations,
                        includeLabels: importLabels
                    ),
                    onImportComplete: { result in
                        importResult = result
                        didCompleteImport = true
                    }
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: didCompleteImport)
        .alert("Validation Error", isPresented: .constant(validationError != nil)) {
            Button("OK") {
                validationError = nil
            }
        } message: {
            if let error = validationError {
                Text(error.localizedDescription)
            }
        }
    }

    private var hasImportOptionsSelected: Bool {
        importItems || importLocations || importLabels
    }

    private func validateAndPreview(url: URL) async {
        isValidatingZip = true
        validationError = nil

        do {
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

            let config = DataManager.ImportConfig(
                includeItems: importItems,
                includeLocations: importLocations,
                includeLabels: importLabels
            )

            let preview = try await DataManager.shared.previewImport(from: url, config: config)

            selectedZipURL = url
            previewData = preview
            isValidatingZip = false
            showPreviewView = true

        } catch {
            validationError = error
            isValidatingZip = false
        }
    }
}

#Preview {
    NavigationStack {
        ImportDataView()
            .environmentObject(Router())
    }
}
