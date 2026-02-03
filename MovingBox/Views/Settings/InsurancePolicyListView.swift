//
//  InsurancePolicyListView.swift
//  MovingBox
//
//  Created by Claude on 1/18/26.
//

import Dependencies
import SQLiteData
import SwiftUI

struct InsurancePolicyListView: View {
    @Dependency(\.defaultDatabase) var database
    @EnvironmentObject var router: Router

    @FetchAll(SQLiteInsurancePolicy.order(by: \.providerName), animation: .default)
    private var allPolicies: [SQLiteInsurancePolicy]

    @FetchAll(SQLiteHomeInsurancePolicy.all)
    private var homePolicyJoins: [SQLiteHomeInsurancePolicy]

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
                    NavigationLink(value: Router.Destination.insurancePolicyDetailView(policyID: policy.id)) {
                        InsurancePolicyRow(
                            policy: policy,
                            homeCount: homePolicyJoins.filter { $0.insurancePolicyID == policy.id }.count
                        )
                    }
                    .accessibilityIdentifier("policy-row-\(policy.id)")
                }
                .onDelete(perform: deletePolicy)
            }
        }
        .accessibilityIdentifier("insurance-policies-list")
        .navigationTitle("Insurance Policies")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") {
                    router.navigate(to: .insurancePolicyDetailView(policyID: nil))
                }
                .accessibilityIdentifier("insurance-add-button")
            }
        }
    }

    private func deletePolicy(at offsets: IndexSet) {
        for index in offsets {
            let policyToDelete = allPolicies[index]
            try? database.write { db in
                // Delete join table entries first
                try SQLiteHomeInsurancePolicy
                    .where { $0.insurancePolicyID == policyToDelete.id }
                    .delete()
                    .execute(db)
                // Delete the policy
                try SQLiteInsurancePolicy.find(policyToDelete.id).delete().execute(db)
            }
        }
    }
}

// MARK: - Policy Row Component
private struct InsurancePolicyRow: View {
    let policy: SQLiteInsurancePolicy
    let homeCount: Int

    private var homeCountText: String {
        switch homeCount {
        case 0:
            return "No homes"
        case 1:
            return "1 home"
        default:
            return "\(homeCount) homes"
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
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    NavigationStack {
        InsurancePolicyListView()
            .environmentObject(Router())
    }
}
