//
//  InventoryVideoLibraryTip.swift
//  MovingBox
//
//  Created by Codex on 2/6/26.
//

import SwiftUI
import TipKit

struct InventoryVideoLibraryTip: Tip {
    @Parameter
    static var inventoryListVisitCount: Int = 0

    @Parameter
    static var hasOpenedVideoLibrary: Bool = false

    var title: Text {
        Text("Analyze From Video")
    }

    var message: Text? {
        Text("Use this button to add a video, run analysis, and review potential duplicates.")
    }

    var image: Image? {
        Image(systemName: "video")
    }

    var rules: [Rule] {
        #Rule(Self.$inventoryListVisitCount) { $0 >= 2 }
        #Rule(Self.$hasOpenedVideoLibrary) { $0 == false }
    }
}
