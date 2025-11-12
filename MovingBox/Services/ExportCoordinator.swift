import SwiftUI
import SwiftData

@MainActor
@Observable
final class ExportCoordinator {
    var exportProgress: Double = 0
    var exportPhase: String = ""
    var showExportProgress = false
    var archiveURL: URL?
    var showShareSheet = false
    var exportError: DataManager.SendableError?
    var showExportError = false
    var isExporting = false
    
    private var exportTask: Task<Void, Never>?
    
    func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        showExportProgress = false
        isExporting = false
    }
    
    func exportWithProgress(
        modelContext: ModelContext,
        fileName: String,
        config: DataManager.ExportConfig
    ) async {
        exportTask = Task {
            do {
                exportError = nil
                exportProgress = 0
                exportPhase = ""
                showExportProgress = true
                isExporting = true
                
                for await progress in DataManager.shared.exportInventoryWithProgress(
                    modelContext: modelContext,
                    fileName: fileName,
                    config: config
                ) {
                    if Task.isCancelled {
                        throw NSError(
                            domain: "ExportError",
                            code: -999,
                            userInfo: [NSLocalizedDescriptionKey: "Export cancelled by user"]
                        )
                    }
                    
                    switch progress {
                    case .preparing:
                        exportPhase = "Preparing export..."
                        exportProgress = 0.0
                        
                    case .fetchingData(let phase, let progressValue):
                        exportPhase = "Fetching \(phase)..."
                        exportProgress = progressValue * 0.3
                        
                    case .writingCSV(let progressValue):
                        exportPhase = "Writing CSV files..."
                        exportProgress = 0.3 + (progressValue * 0.2)
                        
                    case .copyingPhotos(let current, let total):
                        exportPhase = "Copying photos (\(current)/\(total))..."
                        let photoProgress = Double(current) / Double(total)
                        exportProgress = 0.5 + (photoProgress * 0.3)
                        
                    case .creatingArchive(let progressValue):
                        exportPhase = "Creating archive..."
                        exportProgress = 0.8 + (progressValue * 0.2)
                        
                    case .completed(let result):
                        archiveURL = result.archiveURL
                        showShareSheet = true
                        
                    case .error(let sendableError):
                         exportError = sendableError
                         showExportProgress = false
                         showExportError = true
                    }
                }
            } catch {
                print("❌ Export error: \(error.localizedDescription)")
                exportError = DataManager.SendableError(error)
                showExportProgress = false
                showExportError = true
            }
            
            isExporting = false
        }
    }
    
    func exportSpecificItems(
        items: [InventoryItem],
        modelContext: ModelContext
    ) async {
        exportTask = Task {
            do {
                showExportProgress = true
                isExporting = true
                exportError = nil
                
                let url = try await DataManager.shared.exportSpecificItems(
                    items: items,
                    modelContext: modelContext
                )
                
                archiveURL = url
                showShareSheet = true
                
            } catch {
                showExportProgress = false
                exportError = DataManager.SendableError(error)
                showExportError = true
            }
            
            isExporting = false
        }
    }
}
