//
//  InsurancePolicyDetailView.swift
//  MovingBox
//
//  Created by Claude on 1/18/26.
//

import Dependencies
import SQLiteData
import SwiftUI

struct InsurancePolicyDetailView: View {
    @Dependency(\.defaultDatabase) var database
    @EnvironmentObject var router: Router

    @FetchAll(SQLiteHome.order(by: \.name), animation: .default)
    private var homes: [SQLiteHome]

    @FetchAll(SQLiteHomeInsurancePolicy.all)
    private var homePolicyJoins: [SQLiteHomeInsurancePolicy]

    let policyID: UUID?
    @State private var isEditing = false
    @State private var selectedHomeIds: Set<UUID> = []
    @State private var showingDeleteConfirmation = false
    @State private var saveError: String?

    // Form state
    @State private var providerName: String = ""
    @State private var policyNumber: String = ""
    @State private var deductibleAmount: Decimal = 0
    @State private var dwellingCoverageAmount: Decimal = 0
    @State private var personalPropertyCoverageAmount: Decimal = 0
    @State private var lossOfUseCoverageAmount: Decimal = 0
    @State private var liabilityCoverageAmount: Decimal = 0
    @State private var medicalPaymentsCoverageAmount: Decimal = 0
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var isLoaded = false

    private var isNewPolicy: Bool {
        policyID == nil
    }

    init(policyID: UUID?) {
        self.policyID = policyID
        if policyID == nil {
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
        .task(id: policyID) {
            await loadPolicyData()
        }
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

    // MARK: - Data Loading

    private func loadPolicyData() async {
        guard let policyID, !isLoaded else { return }
        do {
            let policy = try await database.read { db in
                try SQLiteInsurancePolicy.find(policyID).fetchOne(db)
            }
            if let policy {
                providerName = policy.providerName
                policyNumber = policy.policyNumber
                deductibleAmount = policy.deductibleAmount
                dwellingCoverageAmount = policy.dwellingCoverageAmount
                personalPropertyCoverageAmount = policy.personalPropertyCoverageAmount
                lossOfUseCoverageAmount = policy.lossOfUseCoverageAmount
                liabilityCoverageAmount = policy.liabilityCoverageAmount
                medicalPaymentsCoverageAmount = policy.medicalPaymentsCoverageAmount
                startDate = policy.startDate
                endDate = policy.endDate
            }
            // Load assigned home IDs from join table (@FetchAll provides live data)
            selectedHomeIds = Set(homePolicyJoins.filter { $0.insurancePolicyID == policyID }.map { $0.homeID })
            isLoaded = true
        } catch {
            saveError = "Failed to load policy: \(error.localizedDescription)"
        }
    }

    // MARK: - Computed Properties for UI

    private var navigationTitleText: String {
        isNewPolicy
            ? "New Policy"
            : (providerName.isEmpty ? "Policy Details" : providerName)
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }

    // MARK: - Assigned Homes (display)

    private var assignedHomes: [SQLiteHome] {
        homes.filter { selectedHomeIds.contains($0.id) }
    }

    // MARK: - Sections

    @ViewBuilder
    private var policyInfoSection: some View {
        Section("Policy Information") {
            if isEditing {
                TextField("Provider Name", text: $providerName)
                    .accessibilityIdentifier("policy-provider-field")
                TextField("Policy Number", text: $policyNumber)
                    .accessibilityIdentifier("policy-number-field")
            } else {
                LabeledContent(
                    "Provider", value: providerName.isEmpty ? "Not set" : providerName)
                LabeledContent(
                    "Policy Number", value: policyNumber.isEmpty ? "Not set" : policyNumber)
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
                if assignedHomes.isEmpty {
                    Text("No homes assigned")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(assignedHomes) { home in
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
    private func homeToggleRow(home: SQLiteHome) -> some View {
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
    private func homeDisplayRow(home: SQLiteHome) -> some View {
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
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    .accessibilityIdentifier("policy-start-date")
                DatePicker(
                    "End Date", selection: $endDate, in: startDate..., displayedComponents: .date
                )
                .accessibilityIdentifier("policy-end-date")
            } else {
                LabeledContent(
                    "Start Date", value: startDate.formatted(date: .abbreviated, time: .omitted))
                HStack {
                    Text("End Date")
                    Spacer()
                    Text(endDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(endDate < Date() ? .red : .secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var coverageDetailsSection: some View {
        Section("Coverage Details") {
            CurrencyField(title: "Deductible", value: $deductibleAmount, isEnabled: isEditing)
                .accessibilityIdentifier("policy-deductible")
            CurrencyField(title: "Dwelling Coverage", value: $dwellingCoverageAmount, isEnabled: isEditing)
                .accessibilityIdentifier("policy-dwelling")
            CurrencyField(
                title: "Personal Property", value: $personalPropertyCoverageAmount, isEnabled: isEditing
            )
            .accessibilityIdentifier("policy-personal-property")
            CurrencyField(title: "Loss of Use", value: $lossOfUseCoverageAmount, isEnabled: isEditing)
                .accessibilityIdentifier("policy-loss-of-use")
            CurrencyField(title: "Liability", value: $liabilityCoverageAmount, isEnabled: isEditing)
                .accessibilityIdentifier("policy-liability")
            CurrencyField(
                title: "Medical Payments", value: $medicalPaymentsCoverageAmount, isEnabled: isEditing
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
                .disabled(providerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private func toggleHomeAssignment(_ home: SQLiteHome) {
        if selectedHomeIds.contains(home.id) {
            selectedHomeIds.remove(home.id)
        } else {
            selectedHomeIds.insert(home.id)
        }
    }

    private func createPolicy() {
        let trimmedName = providerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newPolicyID = UUID()

        // Capture all values for the closure
        let pNum = policyNumber
        let deductible = deductibleAmount
        let dwelling = dwellingCoverageAmount
        let personal = personalPropertyCoverageAmount
        let lossOfUse = lossOfUseCoverageAmount
        let liability = liabilityCoverageAmount
        let medical = medicalPaymentsCoverageAmount
        let start = startDate
        let end = endDate
        let homeIds = selectedHomeIds

        do {
            try database.write { db in
                try SQLiteInsurancePolicy.insert {
                    SQLiteInsurancePolicy(
                        id: newPolicyID,
                        providerName: trimmedName,
                        policyNumber: pNum,
                        deductibleAmount: deductible,
                        dwellingCoverageAmount: dwelling,
                        personalPropertyCoverageAmount: personal,
                        lossOfUseCoverageAmount: lossOfUse,
                        liabilityCoverageAmount: liability,
                        medicalPaymentsCoverageAmount: medical,
                        startDate: start,
                        endDate: end
                    )
                }.execute(db)

                // Create join table entries for selected homes
                for homeId in homeIds {
                    try SQLiteHomeInsurancePolicy.insert {
                        SQLiteHomeInsurancePolicy(
                            id: UUID(),
                            homeID: homeId,
                            insurancePolicyID: newPolicyID
                        )
                    }.execute(db)
                }
            }
            router.navigateBack()
        } catch {
            saveError = "Failed to save policy: \(error.localizedDescription)"
        }
    }

    private func saveChanges() {
        guard let policyID else { return }

        let trimmedName = providerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let pNum = policyNumber
        let deductible = deductibleAmount
        let dwelling = dwellingCoverageAmount
        let personal = personalPropertyCoverageAmount
        let lossOfUse = lossOfUseCoverageAmount
        let liability = liabilityCoverageAmount
        let medical = medicalPaymentsCoverageAmount
        let start = startDate
        let end = endDate
        let homeIds = selectedHomeIds

        do {
            try database.write { db in
                // Update policy
                try SQLiteInsurancePolicy.find(policyID).update {
                    $0.providerName = trimmedName
                    $0.policyNumber = pNum
                    $0.deductibleAmount = deductible
                    $0.dwellingCoverageAmount = dwelling
                    $0.personalPropertyCoverageAmount = personal
                    $0.lossOfUseCoverageAmount = lossOfUse
                    $0.liabilityCoverageAmount = liability
                    $0.medicalPaymentsCoverageAmount = medical
                    $0.startDate = start
                    $0.endDate = end
                }.execute(db)

                // Replace join table entries: delete all, re-insert selected
                try SQLiteHomeInsurancePolicy
                    .where { $0.insurancePolicyID == policyID }
                    .delete()
                    .execute(db)

                for homeId in homeIds {
                    try SQLiteHomeInsurancePolicy.insert {
                        SQLiteHomeInsurancePolicy(
                            id: UUID(),
                            homeID: homeId,
                            insurancePolicyID: policyID
                        )
                    }.execute(db)
                }
            }
        } catch {
            saveError = "Failed to save changes: \(error.localizedDescription)"
        }
    }

    private func deletePolicy() {
        guard let policyID else { return }

        do {
            try database.write { db in
                // Delete join table entries
                try SQLiteHomeInsurancePolicy
                    .where { $0.insurancePolicyID == policyID }
                    .delete()
                    .execute(db)
                // Delete the policy
                try SQLiteInsurancePolicy.find(policyID).delete().execute(db)
            }
            router.navigateBack()
        } catch {
            saveError = "Failed to delete policy: \(error.localizedDescription)"
        }
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    NavigationStack {
        InsurancePolicyDetailView(policyID: nil)
            .environmentObject(Router())
    }
}
