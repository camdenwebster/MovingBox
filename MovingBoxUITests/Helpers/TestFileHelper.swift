import Foundation
import XCTest

class TestFileHelper {
    static let shared = TestFileHelper()
    
    private let fileManager = FileManager.default
    
    private lazy var testDocumentsDirectory: URL = {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let testDirectory = documentsDirectory.appendingPathComponent("UITestFiles", isDirectory: true)
        
        try? fileManager.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        return testDirectory
    }()
    
    func getExportedZipFileURL() -> URL? {
        do {
            let files = try fileManager.contentsOfDirectory(
                at: testDocumentsDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            let zipFiles = files.filter { $0.pathExtension.lowercased() == "zip" }
            return zipFiles.sorted { ($0.lastPathComponent) > ($1.lastPathComponent) }.first
        } catch {
            print("Error finding ZIP files: \(error)")
            return nil
        }
    }
    
    func clearTestFiles() {
        do {
            let files = try fileManager.contentsOfDirectory(
                at: testDocumentsDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            for file in files {
                try fileManager.removeItem(at: file)
            }
        } catch {
            print("Error clearing test files: \(error)")
        }
    }
    
    func getDownloadsDirectory() -> URL? {
        return fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
    }
    
    func findLatestDownloadedZip() -> URL? {
        guard let downloadsDir = getDownloadsDirectory() else { return nil }
        
        do {
            let files = try fileManager.contentsOfDirectory(
                at: downloadsDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            let zipFiles = files.filter { $0.pathExtension.lowercased() == "zip" }
            let sortedByDate = try zipFiles.sorted { url1, url2 in
                let date1 = try url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date(timeIntervalSince1970: 0)
                let date2 = try url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date(timeIntervalSince1970: 0)
                return date1 > date2
            }
            
            return sortedByDate.first
        } catch {
            print("Error finding downloaded ZIP files: \(error)")
            return nil
        }
    }
}
