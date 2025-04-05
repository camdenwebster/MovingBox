//
//  RCTestView.swift
//  MovingBox
//
//  Created by Camden Webster on 4/2/25.
//

import SwiftUI

import RevenueCat
import RevenueCatUI

struct RCTestView: View {
    var body: some View {
        DashboardView()
//            .presentPaywallIfNeeded(
//                requiredEntitlementIdentifier: "pro",
//                purchaseCompleted: { customerInfo in
//                    print("Purchase completed: \(customerInfo.entitlements)")
//                },
//                restoreCompleted: { customerInfo in
//                    // Paywall will be dismissed automatically if "pro" is now active.
//                    print("Purchases restored: \(customerInfo.entitlements)")
//                }
//            )
    }
}

#Preview {
    RCTestView()
}
