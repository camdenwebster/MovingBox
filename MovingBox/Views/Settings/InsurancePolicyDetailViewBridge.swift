//
//  InsurancePolicyDetailViewBridge.swift
//  MovingBox
//
//  This bridge is no longer needed — InsurancePolicyDetailView accepts policyID directly.
//  This file can be removed from the project.
//

import SwiftUI

struct InsurancePolicyDetailViewBridge: View {
    let policyID: UUID?

    var body: some View {
        InsurancePolicyDetailView(policyID: policyID)
    }
}
