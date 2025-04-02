//
//  SnapshotTests.swift
//  MovingBoxTests
//
//  Created by Camden Webster on 4/2/25.
//

import SnapshotTesting
import Testing
import SwiftUI
import SwiftData
@testable import MovingBox

@MainActor
struct SnapshotTests {
    // Helper property to generate snapshot names with UI testing suffix
    private var shouldLoadMockData: Bool {
        return ProcessInfo.processInfo.arguments.contains("Mock-Data")
    }
    
    private var snapshotSuffix: String {
        return shouldLoadMockData ? "_mockData" : ""
    }
    
    
    @Test func DashboardViewSnapshot() async {
        // Create an in-memory container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Home.self, InventoryLabel.self, InventoryItem.self, InventoryLocation.self, InsurancePolicy.self, configurations: config)
        
        // Load test data
        if shouldLoadMockData {
            await DefaultDataManager.populateTestData(modelContext: container.mainContext)
        }
        
        let view = DashboardView()
            .frame(width: 390, height: 844) // iPhone 14 size
            .preferredColorScheme(.light) // Explicitly set light mode for consistency
            .modelContainer(container)
        
        // Wait a moment for SwiftData to process changes
        try! await Task.sleep(for: .seconds(1))
        
        assertSnapshot(
            of: view,
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "dashboard_light_mode\(snapshotSuffix)"
        )
    }
}
