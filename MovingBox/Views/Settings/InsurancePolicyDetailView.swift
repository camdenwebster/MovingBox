//
//  InsurancePolicyDetailView.swift
//  MovingBox
//
//  Created by Claude on 1/18/26.
//

import SwiftData
import SwiftUI

struct InsurancePolicyDetailView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var router: Router
    @Query(sort: \Home.name) private var homes: [Home]

    let policy: InsurancePolicy?
    @State private var tempPolicy: InsurancePolicy
    @State private var isEditing = false
    @State private var selectedHomeIds: Set<UUID> = []
    @State private var showingDeleteConfirmation = false
    @State private var saveError: String?

    private var isNewPolicy: Bool {
        policy == nil
    }

    private var displayPolicy: InsurancePolicy {
        policy ?? tempPolicy
    }

    init(policy: InsurancePolicy?) {
        self.policy = policy
        if let policy = policy {
            _tempPolicy = State(initialValue: policy)
            _selectedHomeIds = State(initialValue: Set(policy.insuredHomes.map { $0.id }))
        } else {
            _tempPolicy = State(initialValue: InsurancePolicy())
            _isEditing = State(initialValue: true)
        }
    }

    var body: some View {
        Form {
            policyInfoSection
            assignedHomesSection
            policyDatesSection
            coverageDetailsSection
            deleteSection
        }
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert("Delete Policy", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deletePolicy()
            }
        } message: {
            Text("Are you sure you want to delete this insurance policy?")
        }
        .alert("Error", isPresented: hasError) {
            Button("OK") { saveError = nil }
        } message: {
            if let error = saveError {
                Text(error)
            }
        }
    }

    // MARK: - Computed Properties for UI

    private var navigationTitleText: String {
        isNewPolicy
            ? "New Policy"
            : (displayPolicy.providerName.isEmpty ? "Policy Details" : displayPolicy.providerName)
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }

    // MARK: - Sections

    @ViewBuilder
    private var policyInfoSection: some View {
        Section("Policy Information") {
            if isEditing {
                TextField("Provider Name", text: $tempPolicy.providerName)
                    .accessibilityIdentifier("policy-provider-field")
                TextField("Policy Number", text: $tempPolicy.policyNumber)
                    .accessibilityIdentifier("policy-number-field")
            } else {
                LabeledContent(
                    "Provider", value: displayPolicy.providerName.isEmpty ? "Not set" : displayPolicy.providerName)
                LabeledContent(
                    "Policy Number", value: displayPolicy.policyNumber.isEmpty ? "Not set" : displayPolicy.policyNumber)
            }
        }
    }

    @ViewBuilder
    private var assignedHomesSection: some View {
        Section {
            if homes.isEmpty {
                Text("No homes available")
                    .foregroundStyle(.secondary)
            } else if isEditing {
                ForEach(homes) { home in
                    homeToggleRow(home: home)
                }
            } else {
                if displayPolicy.insuredHomes.isEmpty {
                    Text("No homes assigned")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(displayPolicy.insuredHomes) { home in
                        homeDisplayRow(home: home)
                    }
                }
            }
        } header: {
            Text("Assigned Homes")
        } footer: {
            Text("Assign this policy to one or more homes to track their coverage.")
        }
    }

    @ViewBuilder
    private func homeToggleRow(home: Home) -> some View {
        Button {
            toggleHomeAssignment(home)
        } label: {
            HStack {
                Circle()
                    .fill(home.color)
                    .frame(width: 12, height: 12)
                Text(home.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                if selectedHomeIds.contains(home.id) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .accessibilityIdentifier("policy-home-toggle-\(home.id)")
    }

    @ViewBuilder
    private func homeDisplayRow(home: Home) -> some View {
        HStack {
            Circle()
                .fill(home.color)
                .frame(width: 12, height: 12)
            Text(home.displayName)
        }
    }

    @ViewBuilder
    private var policyDatesSection: some View {
        Section("Policy Dates") {
            if isEditing {
                DatePicker("Start Date", selection: $tempPolicy.startDate, displayedComponents: .date)
                    .accessibilityIdentifier("policy-start-date")
                DatePicker(
                    "End Date", selection: $tempPolicy.endDate, in: tempPolicy.startDate..., displayedComponents: .date
                )
                .accessibilityIdentifier("policy-end-date")
            } else {
                LabeledContent(
                    "Start Date", value: displayPolicy.startDate.formatted(date: .abbreviated, time: .omitted))
                HStack {
                    Text("End Date")
                    Spacer()
                    Text(displayPolicy.endDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(displayPolicy.endDate < Date() ? .red : .secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var coverageDetailsSection: some View {
        Section("Coverage Details") {
            CurrencyField(title: "Deductible", value: $tempPolicy.deductibleAmount, isEnabled: isEditing)
                .accessibilityIdentifier("policy-deductible")
            CurrencyField(title: "Dwelling Coverage", value: $tempPolicy.dwellingCoverageAmount, isEnabled: isEditing)
                .accessibilityIdentifier("policy-dwelling")
            CurrencyField(
                title: "Personal Property", value: $tempPolicy.personalPropertyCoverageAmount, isEnabled: isEditing
            )
            .accessibilityIdentifier("policy-personal-property")
            CurrencyField(title: "Loss of Use", value: $tempPolicy.lossOfUseCoverageAmount, isEnabled: isEditing)
                .accessibilityIdentifier("policy-loss-of-use")
            CurrencyField(title: "Liability", value: $tempPolicy.liabilityCoverageAmount, isEnabled: isEditing)
                .accessibilityIdentifier("policy-liability")
            CurrencyField(
                title: "Medical Payments", value: $tempPolicy.medicalPaymentsCoverageAmount, isEnabled: isEditing
            )
            .accessibilityIdentifier("policy-medical")
        }
    }

    @ViewBuilder
    private var deleteSection: some View {
        if !isNewPolicy {
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Policy", systemImage: "trash")
                }
                .accessibilityIdentifier("policy-delete-button")
            } footer: {
                Text("This will remove the policy. Associated homes will not be affected.")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isNewPolicy {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    router.navigateBack()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    createPolicy()
                }
                .bold()
                .disabled(tempPolicy.providerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("policy-save-button")
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        saveChanges()
                    }
                    isEditing.toggle()
                }
                .accessibilityIdentifier("policy-edit-button")
            }
        }
    }

    // MARK: - Actions

    private func toggleHomeAssignment(_ home: Home) {
        if selectedHomeIds.contains(home.id) {
            selectedHomeIds.remove(home.id)
        } else {
            selectedHomeIds.insert(home.id)
        }
    }

    private func createPolicy() {
        let newPolicy = InsurancePolicy(
            providerName: tempPolicy.providerName.trimmingCharacters(in: .whitespacesAndNewlines),
            policyNumber: tempPolicy.policyNumber,
            deductibleAmount: tempPolicy.deductibleAmount,
            dwellingCoverageAmount: tempPolicy.dwellingCoverageAmount,
            personalPropertyCoverageAmount: tempPolicy.personalPropertyCoverageAmount,
            lossOfUseCoverageAmount: tempPolicy.lossOfUseCoverageAmount,
            liabilityCoverageAmount: tempPolicy.liabilityCoverageAmount,
            medicalPaymentsCoverageAmount: tempPolicy.medicalPaymentsCoverageAmount,
            startDate: tempPolicy.startDate,
            endDate: tempPolicy.endDate
        )

        // Assign to selected homes
        let selectedHomes = homes.filter { selectedHomeIds.contains($0.id) }
        for home in selectedHomes {
            newPolicy.insuredHomes.append(home)
            home.insurancePolicies.append(newPolicy)
        }

        modelContext.insert(newPolicy)

        do {
            try modelContext.save()
            router.navigateBack()
        } catch {
            saveError = "Failed to save policy: \(error.localizedDescription)"
        }
    }

    private func saveChanges() {
        guard let existingPolicy = policy else { return }

        existingPolicy.providerName = tempPolicy.providerName
        existingPolicy.policyNumber = tempPolicy.policyNumber
        existingPolicy.deductibleAmount = tempPolicy.deductibleAmount
        existingPolicy.dwellingCoverageAmount = tempPolicy.dwellingCoverageAmount
        existingPolicy.personalPropertyCoverageAmount = tempPolicy.personalPropertyCoverageAmount
        existingPolicy.lossOfUseCoverageAmount = tempPolicy.lossOfUseCoverageAmount
        existingPolicy.liabilityCoverageAmount = tempPolicy.liabilityCoverageAmount
        existingPolicy.medicalPaymentsCoverageAmount = tempPolicy.medicalPaymentsCoverageAmount
        existingPolicy.startDate = tempPolicy.startDate
        existingPolicy.endDate = tempPolicy.endDate

        // Handle home assignment changes
        let currentHomeIds = Set(existingPolicy.insuredHomes.map { $0.id })

        // Remove from homes no longer selected
        for home in existingPolicy.insuredHomes {
            if !selectedHomeIds.contains(home.id) {
                home.insurancePolicies.removeAll { $0.id == existingPolicy.id }
            }
        }
        existingPolicy.insuredHomes.removeAll { !selectedHomeIds.contains($0.id) }

        // Add to newly selected homes
        for home in homes {
            if selectedHomeIds.contains(home.id) && !currentHomeIds.contains(home.id) {
                existingPolicy.insuredHomes.append(home)
                home.insurancePolicies.append(existingPolicy)
            }
        }

        do {
            try modelContext.save()
        } catch {
            saveError = "Failed to save changes: \(error.localizedDescription)"
        }
    }

    private func deletePolicy() {
        guard let policyToDelete = policy else { return }

        // Clear relationships
        for home in policyToDelete.insuredHomes {
            home.insurancePolicies.removeAll { $0.id == policyToDelete.id }
        }
        modelContext.delete(policyToDelete)

        do {
            try modelContext.save()
            router.navigateBack()
        } catch {
            saveError = "Failed to delete policy: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        InsurancePolicyDetailView(policy: nil)
            .environmentObject(Router())
    }
}
