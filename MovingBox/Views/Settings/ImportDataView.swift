import SwiftUI
import SwiftUIBackports
import UniformTypeIdentifiers

struct ImportDataView: View {
    @EnvironmentObject private var router: Router
    @State private var showFileImporter = false
    @State private var showPreviewView = false
    @State private var previewData: DataManager.ImportResult?
    @State private var selectedZipURL: URL?
    @State private var isValidatingZip = false
    @State private var validationError: Error?
    @State private var showImportWarning = false
    @State private var importFormat: DataManager.ImportFormat = .csvArchive
    @State private var importItems = true
    @State private var importLocations = true
    @State private var importLabels = true
    @State private var importHomes = true
    @State private var importInsurancePolicies = true
    @State private var importResult: DataManager.ImportResult?
    @State private var didCompleteImport = false

    var body: some View {
        List {
            Section {
                LabeledContent {
                    Picker("Import Format", selection: $importFormat) {
                        Text("CSV Archive").tag(DataManager.ImportFormat.csvArchive)
                        Text("MovingBox Database").tag(DataManager.ImportFormat.movingBoxDatabase)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("import-format-picker")
                } label: {
                    Label("Import Format", systemImage: "tray.and.arrow.down")
                }
            }

            if importFormat == .csvArchive {
                Section("CSV Import Options") {
                    Toggle(isOn: $importItems) {
                        Label("Import Items", systemImage: "cube.box")
                    }
                    .accessibilityIdentifier("import-items-toggle")

                    Toggle(isOn: $importLocations) {
                        Label("Import Locations", systemImage: "map")
                    }
                    .accessibilityIdentifier("import-locations-toggle")

                    Toggle(isOn: $importLabels) {
                        Label("Import Labels", systemImage: "tag")
                    }
                    .accessibilityIdentifier("import-labels-toggle")

                    Toggle(isOn: $importHomes) {
                        Label("Import Homes", systemImage: "house")
                    }
                    .accessibilityIdentifier("import-homes-toggle")

                    Toggle(isOn: $importInsurancePolicies) {
                        Label("Import Insurance Policies", systemImage: "doc.text")
                    }
                    .accessibilityIdentifier("import-insurance-policies-toggle")
                }
            }

            Section {
                Button {
                    if hasImportOptionsSelected {
                        showImportWarning = true
                    }
                } label: {
                    HStack {
                        if isValidatingZip {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isValidatingZip ? "Validating..." : selectFileButtonTitle)
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
                Text(footerText)
                    .font(.footnote)
            }
        }
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Warning", isPresented: $showImportWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Continue") {
                showFileImporter = true
            }
        } message: {
            Text(warningText)
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
                    config: importConfig,
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
        if importFormat == .movingBoxDatabase {
            return true
        }
        return importItems || importLocations || importLabels || importHomes || importInsurancePolicies
    }

    private var importConfig: DataManager.ImportConfig {
        DataManager.ImportConfig(
            format: importFormat,
            includeItems: importItems,
            includeLocations: importLocations,
            includeLabels: importLabels,
            includeHomes: importHomes,
            includeInsurancePolicies: importInsurancePolicies
        )
    }

    private var selectFileButtonTitle: String {
        switch importFormat {
        case .csvArchive:
            return "Select ZIP File"
        case .movingBoxDatabase:
            return "Select Database Backup"
        }
    }

    private var footerText: String {
        switch importFormat {
        case .csvArchive:
            return
                "Restore data from a ZIP file that was previously exported from MovingBox. Files from other apps cannot be imported."
        case .movingBoxDatabase:
            return
                "Restore a full MovingBox SQLite database backup. This replaces your current local database after restart."
        }
    }

    private var warningText: String {
        switch importFormat {
        case .csvArchive:
            return
                "The import process does not check for duplicate data. Importing the same data multiple times may result in duplicate items, locations, labels, homes, and insurance policies."
        case .movingBoxDatabase:
            return
                "Importing a database backup replaces your current local data on next launch. You can restart immediately after import, or later."
        }
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

            let preview = try await DataManager.shared.previewImport(from: url, config: importConfig)

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
