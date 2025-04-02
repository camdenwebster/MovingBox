//
//  SnapshotTests.swift
//  MovingBoxTests
//
//  Created by Camden Webster on 4/2/25.
//

import SnapshotTesting
import Testing
import SwiftUI
@testable import MovingBox

@MainActor
struct SnapshotTests {
    // Helper property to generate snapshot names with UI testing suffix
    private var snapshotSuffix: String {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("UI-Testing")
        return isUITesting ? "_mockData" : ""
    }
    
    
    @Test func DashboardViewSnapshot() {
        let view = DashboardView()
            .frame(width: 390, height: 844) // iPhone 14 size
            .preferredColorScheme(.light) // Explicitly set light mode for consistency
        
        assertSnapshot(
            of: view,
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "dashboard_light_mode\(snapshotSuffix)"
        )
    }
}
