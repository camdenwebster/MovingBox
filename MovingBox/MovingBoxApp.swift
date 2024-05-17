//
//  MovingBoxApp.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import SwiftUI

@main
struct MovingBoxApp: App {
    @StateObject var inventoryItems = InventoryData()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(inventoryItems)
        }
    }
}
