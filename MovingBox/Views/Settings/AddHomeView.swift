//
//  AddHomeView.swift
//  MovingBox
//
//  Created by Claude on 12/20/25.
//

import SwiftData
import SwiftUI

struct AddHomeView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager
    @Query private var existingHomes: [Home]

    @State private var homeName = ""
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField("Home Name", text: $homeName)
                    #if os(iOS)
                        .textInputAutocapitalization(.words)
                    #endif
            } header: {
                Text("Home Details")
            } footer: {
                Text("Give this home a name to help you identify it (e.g., 'Main House', 'Beach House', 'Apartment')")
            }

            if let error = error {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Add Home")
        .movingBoxNavigationTitleDisplayModeInline()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    router.navigateBack()
                }
                .disabled(isCreating)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await createHome()
                    }
                }
                .bold()
                .disabled(homeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            }
        }
        .disabled(isCreating)
        .overlay {
            if isCreating {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
    }

    private func createHome() async {
        isCreating = true
        error = nil

        do {
            let trimmedName = homeName.trimmingCharacters(in: .whitespacesAndNewlines)

            // Create new home with default locations and labels
            let newHome = try await DefaultDataManager.createNewHome(
                name: trimmedName,
                modelContext: modelContext
            )

            // If this is the first home, make it primary
            if existingHomes.isEmpty {
                newHome.isPrimary = true
                settings.activeHomeId = newHome.id.uuidString
            }

            // Save context
            try modelContext.save()

            // Track telemetry
            TelemetryManager.shared.trackHomeCreated(name: trimmedName)

            // Navigate back
            await MainActor.run {
                router.navigateBack()
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to create home: \(error.localizedDescription)"
                isCreating = false
            }
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Home.self, InventoryLocation.self, InventoryLabel.self, configurations: config)

        return AddHomeView()
            .modelContainer(container)
            .environmentObject(Router())
            .environmentObject(SettingsManager())
    } catch {
        return Text("Failed to set up preview: \(error.localizedDescription)")
            .foregroundColor(.red)
    }
}
