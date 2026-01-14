import Foundation
import SwiftData
import Testing

@testable import MovingBox

@MainActor
struct ProgressMapperTests {
    @Test("Export progress values increase monotonically")
    func exportProgressIncreasesMonotonically() {
        let phases: [DataManager.ExportProgress] = [
            .preparing,
            .fetchingData(phase: "items", progress: 0.0),
            .fetchingData(phase: "items", progress: 0.5),
            .fetchingData(phase: "items", progress: 1.0),
            .writingCSV(progress: 0.0),
            .writingCSV(progress: 0.5),
            .writingCSV(progress: 1.0),
            .copyingPhotos(current: 0, total: 100),
            .copyingPhotos(current: 50, total: 100),
            .copyingPhotos(current: 100, total: 100),
            .creatingArchive(progress: 0.0),
            .creatingArchive(progress: 0.5),
            .creatingArchive(progress: 1.0),
        ]

        var lastProgress = 0.0
        for phase in phases {
            let mapped = ProgressMapper.mapExportProgress(phase)
            #expect(
                mapped.progress >= lastProgress,
                "Progress should never decrease. Got \(mapped.progress) after \(lastProgress)")
            lastProgress = mapped.progress
        }
    }

    @Test("Export progress weights sum to 1.0")
    func exportWeightsSumToOne() {
        let weights = ProgressMapper.ExportWeights.self
        let sum = weights.dataFetching + weights.csvWriting + weights.photoCopying + weights.archiving
        #expect(sum == 1.0, "Export weights should sum to 1.0, got \(sum)")
    }

    @Test("Import progress weights sum to 1.0")
    func importWeightsSumToOne() {
        let weights = ProgressMapper.ImportWeights.self
        let sum =
            weights.unzipping + weights.readingCSV + weights.processingData + weights.copyingPhotos
        #expect(sum == 1.0, "Import weights should sum to 1.0, got \(sum)")
    }

    @Test("Photo threshold adapts to count")
    func photoThresholdAdaptsToCount() {
        #expect(ProgressMapper.photoProgressThreshold(for: 0) == 1)
        #expect(ProgressMapper.photoProgressThreshold(for: 10) == 1)
        #expect(ProgressMapper.photoProgressThreshold(for: 49) == 1)
        #expect(ProgressMapper.photoProgressThreshold(for: 50) == 5)
        #expect(ProgressMapper.photoProgressThreshold(for: 100) == 5)
        #expect(ProgressMapper.photoProgressThreshold(for: 199) == 5)
        #expect(ProgressMapper.photoProgressThreshold(for: 200) == 10)
        #expect(ProgressMapper.photoProgressThreshold(for: 500) == 10)
        #expect(ProgressMapper.photoProgressThreshold(for: 1000) == 10)
    }

    @Test("Progress values are within 0-1 range")
    func progressValuesWithinRange() {
        let testCases: [DataManager.ExportProgress] = [
            .preparing,
            .fetchingData(phase: "test", progress: 0.0),
            .fetchingData(phase: "test", progress: 0.5),
            .fetchingData(phase: "test", progress: 1.0),
            .writingCSV(progress: 0.0),
            .writingCSV(progress: 1.0),
            .copyingPhotos(current: 0, total: 100),
            .copyingPhotos(current: 100, total: 100),
            .creatingArchive(progress: 0.0),
            .creatingArchive(progress: 1.0),
        ]

        for testCase in testCases {
            let mapped = ProgressMapper.mapExportProgress(testCase)
            #expect(mapped.progress >= 0.0, "Progress should be >= 0.0, got \(mapped.progress)")
            #expect(mapped.progress <= 1.0, "Progress should be <= 1.0, got \(mapped.progress)")
        }
    }

    @Test("Phase descriptions are not empty for active phases")
    func phaseDescriptionsNotEmpty() {
        let phases: [DataManager.ExportProgress] = [
            .preparing,
            .fetchingData(phase: "items", progress: 0.5),
            .writingCSV(progress: 0.5),
            .copyingPhotos(current: 50, total: 100),
            .creatingArchive(progress: 0.5),
        ]

        for phase in phases {
            let mapped = ProgressMapper.mapExportProgress(phase)
            #expect(!mapped.phase.isEmpty, "Active phases should have non-empty descriptions")
        }
    }

    @Test("Completed and error phases return 1.0 progress")
    func terminalPhasesReturnFullProgress() async throws {
        let container = try ModelContainer(
            for: InventoryItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let item = InventoryItem()
        item.title = "Test"
        context.insert(item)
        try context.save()

        let result = DataManager.ExportResult(
            archiveURL: URL(fileURLWithPath: "/tmp/test.zip"),
            itemCount: 1,
            locationCount: 0,
            labelCount: 0,
            photoCount: 0
        )

        let completedProgress = ProgressMapper.mapExportProgress(.completed(result))
        #expect(completedProgress.progress == 1.0)
        #expect(completedProgress.phase.isEmpty)

        let errorProgress = ProgressMapper.mapExportProgress(
            .error(DataManager.SendableError(NSError(domain: "test", code: 0))))
        #expect(errorProgress.progress == 1.0)
        #expect(errorProgress.phase.isEmpty)
    }

    @Test("Photo progress handles zero total correctly")
    func photoProgressHandlesZeroTotal() {
        let progress = ProgressMapper.mapExportProgress(.copyingPhotos(current: 0, total: 0))

        #expect(progress.progress >= 0.0)
        #expect(progress.progress <= 1.0)
        #expect(!progress.phase.isEmpty)
    }

    @Test("Progress phases use expected weight ranges")
    func progressPhasesUseExpectedRanges() {
        let dataFetchingEnd = ProgressMapper.mapExportProgress(
            .fetchingData(phase: "test", progress: 1.0))
        #expect(dataFetchingEnd.progress == 0.30)

        let csvEnd = ProgressMapper.mapExportProgress(.writingCSV(progress: 1.0))
        #expect(csvEnd.progress == 0.50)

        let photosEnd = ProgressMapper.mapExportProgress(.copyingPhotos(current: 100, total: 100))
        #expect(photosEnd.progress == 0.80)

        let archiveEnd = ProgressMapper.mapExportProgress(.creatingArchive(progress: 1.0))
        #expect(archiveEnd.progress == 1.00)
    }
}
