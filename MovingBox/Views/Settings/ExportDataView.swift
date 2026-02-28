import Dependencies
import SQLiteData
import SwiftUI
import SwiftUIBackports

struct ExportDataView: View {
    private enum ExportFormat: String, CaseIterable, Identifiable {
        case csvArchive
        case movingBoxDatabase

        var id: Self { self }

        var title: String {
            switch self {
            case .csvArchive:
                return "CSV Archive"
            case .movingBoxDatabase:
                return "MovingBox Database"
            }
        }
    }

    @Dependency(\.defaultDatabase) var database
    @FetchAll(SQLiteHome.order(by: \.name), animation: .default)
    private var homes: [SQLiteHome]

    @State private var exportCoordinator = ExportCoordinator()
    @State private var exportFormat: ExportFormat = .csvArchive
    @State private var selectedHomeIDs: Set<UUID> = []
    @State private var includePhotos = true
    @State private var initializedHomeSelection = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()

    private var sortedHomes: [SQLiteHome] {
        homes.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private var exportButtonTitle: String {
        switch exportFormat {
        case .csvArchive:
            return "Export CSV Archive"
        case .movingBoxDatabase:
            return "Export Database"
        }
    }

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Picker("Export Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("export-format-picker")
                } label: {
                    Label("Export Format", systemImage: "tray.and.arrow.up")
                }
            }

            if exportFormat == .csvArchive {
                csvOptionsSection
            }

            Section {
                Button {
                    Task { await exportButtonTapped() }
                } label: {
                    HStack {
                        if exportCoordinator.isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Exporting…")
                        } else {
                            Text(exportButtonTitle)
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .tint(.green)
                .disabled(exportCoordinator.isExporting)
                .listRowInsets(EdgeInsets())
                .backport.glassProminentButtonStyle()
                .accessibilityIdentifier("export-data-button")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if exportFormat == .csvArchive {
                        Text(
                            "Export a ZIP containing inventory CSVs (items, locations, labels, homes, and insurance policies) with optional photos."
                        )
                    } else {
                        Text(
                            "Export a ZIP containing your raw MovingBox SQLite database file."
                        )
                    }
                }
                .font(.footnote)
            }
        }
        .navigationTitle("Export Data")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            initializeHomeSelectionIfNeeded()
        }
        .onChange(of: homes.map(\.id)) { _, _ in
            synchronizeHomeSelection()
        }
        .sheet(
            isPresented: $exportCoordinator.showShareSheet,
            onDismiss: {
                exportCoordinator.showExportProgress = false
                exportCoordinator.archiveURL = nil
            }
        ) {
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
            Text(
                exportCoordinator.exportError?.localizedDescription
                    ?? "An error occurred while exporting data.")
        }
    }

    private var csvOptionsSection: some View {
        Section {
            ForEach(sortedHomes) { home in
                Toggle(isOn: $selectedHomeIDs[contains: home.id]) {
                    Label(home.displayName, systemImage: "house")
                }
                .accessibilityIdentifier("export-home-toggle-\(home.id.uuidString.lowercased())")
            }

            Toggle(isOn: $includePhotos) {
                Label("Include Photos", systemImage: "photo.on.rectangle")
            }
            .accessibilityIdentifier("export-photos-toggle")
        } header: {
            Text("CSV Archive Options")
        } footer: {
            Text("Locations and labels are always included in CSV exports.")
        }
    }

    private func initializeHomeSelectionIfNeeded() {
        guard !initializedHomeSelection else { return }
        selectedHomeIDs = Set(homes.map(\.id))
        initializedHomeSelection = true
    }

    private func synchronizeHomeSelection() {
        let currentHomeIDs = Set(homes.map(\.id))

        if !initializedHomeSelection {
            selectedHomeIDs = currentHomeIDs
            initializedHomeSelection = true
            return
        }

        let retainedHomeIDs = selectedHomeIDs.intersection(currentHomeIDs)
        let newHomeIDs = currentHomeIDs.subtracting(selectedHomeIDs)
        selectedHomeIDs = retainedHomeIDs.union(newHomeIDs)
    }

    @MainActor
    private func exportButtonTapped() async {
        let timestamp = dateFormatter.string(from: Date())

        switch exportFormat {
        case .movingBoxDatabase:
            await exportCoordinator.exportDatabaseArchive(
                database: database,
                fileName: "MovingBox-database-\(timestamp).zip"
            )

        case .csvArchive:
            let config = DataManager.ExportConfig(
                includeItems: true,
                includeLocations: true,
                includeLabels: true,
                includeHomes: true,
                includeInsurancePolicies: true,
                includePhotos: includePhotos,
                includedHomeIDs: selectedHomeIDs
            )

            await exportCoordinator.exportWithProgress(
                database: database,
                fileName: "MovingBox-export-\(timestamp).zip",
                config: config
            )
        }
    }
}

extension Set where Element: Hashable {
    fileprivate subscript(contains element: Element) -> Bool {
        get { contains(element) }
        set {
            if newValue {
                insert(element)
            } else {
                remove(element)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExportDataView()
            .environmentObject(Router())
    }
}
