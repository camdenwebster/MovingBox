//
//  InsurancePolicyListView.swift
//  MovingBox
//
//  Created by Claude on 1/18/26.
//

import SwiftData
import SwiftUI

struct InsurancePolicyListView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @Query(sort: \InsurancePolicy.providerName) private var allPolicies: [InsurancePolicy]

    var body: some View {
        List {
            if allPolicies.isEmpty {
                ContentUnavailableView(
                    "No Insurance Policies",
                    systemImage: "shield",
                    description: Text("Add insurance policies to track coverage for your homes.")
                )
            } else {
                ForEach(allPolicies) { policy in
                    NavigationLink(value: Router.Destination.insurancePolicyDetailView(policy: policy)) {
                        InsurancePolicyRow(policy: policy)
                    }
                    .accessibilityIdentifier("policy-row-\(policy.id)")
                }
                .onDelete(perform: deletePolicy)
            }
        }
        .accessibilityIdentifier("insurance-policies-list")
        .navigationTitle("Insurance Policies")
        .movingBoxNavigationTitleDisplayModeInline()
        .toolbar {
            ToolbarItem(placement: .movingBoxTrailing) {
                Button("Add", systemImage: "plus") {
                    router.navigate(to: .insurancePolicyDetailView(policy: nil))
                }
                .accessibilityIdentifier("insurance-add-button")
            }
        }
    }

    private func deletePolicy(at offsets: IndexSet) {
        for index in offsets {
            let policyToDelete = allPolicies[index]
            // Clear relationships from homes before deleting
            for home in policyToDelete.insuredHomes {
                home.insurancePolicies.removeAll { $0.id == policyToDelete.id }
            }
            modelContext.delete(policyToDelete)
        }
        try? modelContext.save()
    }
}

// MARK: - Policy Row Component
private struct InsurancePolicyRow: View {
    let policy: InsurancePolicy

    private var homeCountText: String {
        let count = policy.insuredHomes.count
        switch count {
        case 0:
            return "No homes"
        case 1:
            return "1 home"
        default:
            return "\(count) homes"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(policy.providerName.isEmpty ? "Unnamed Policy" : policy.providerName)
                    .font(.headline)
                Spacer()
                Text(homeCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(.rect(cornerRadius: 4))
            }

            if !policy.policyNumber.isEmpty {
                Text("Policy #\(policy.policyNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Coverage: \(policy.personalPropertyCoverageAmount, format: .currency(code: "USD"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Expires: \(policy.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(policy.endDate < Date() ? .red : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        InsurancePolicyListView()
            .environmentObject(Router())
    }
}
