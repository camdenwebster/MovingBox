//
//  AddHomeView.swift
//  MovingBox
//
//  Created by Claude on 12/20/25.
//

import Dependencies
import SQLiteData
import SwiftUI

struct AddHomeView: View {
    @Dependency(\.defaultDatabase) var database
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var router: Router
    @EnvironmentObject var settings: SettingsManager

    @FetchAll(SQLiteHome.order(by: \.name), animation: .default)
    private var existingHomes: [SQLiteHome]

    @State private var homeName = ""
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField("Home Name", text: $homeName)
                    .textInputAutocapitalization(.words)
            } header: {
                Text("Home Details")
            } footer: {
                Text("Give this home a name to help you identify it (e.g., 'Main House', 'Beach House', 'Apartment')")
            }

            if let error = error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Add Home")
        .navigationBarTitleDisplayMode(.inline)
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
            let newHomeID = UUID()
            let shouldBePrimary = existingHomes.isEmpty
            let defaultRooms = TestData.defaultRooms

            try await database.write { db in
                try SQLiteHome.insert {
                    SQLiteHome(
                        id: newHomeID,
                        name: trimmedName,
                        isPrimary: shouldBePrimary,
                        colorName: "green"
                    )
                }.execute(db)

                // Create default locations for the new home
                for roomData in defaultRooms {
                    try SQLiteInventoryLocation.insert {
                        SQLiteInventoryLocation(
                            id: UUID(),
                            name: roomData.name,
                            desc: roomData.desc,
                            sfSymbolName: roomData.sfSymbol,
                            homeID: newHomeID
                        )
                    }.execute(db)
                }
            }

            if shouldBePrimary {
                settings.activeHomeId = newHomeID.uuidString
            }

            TelemetryManager.shared.trackHomeCreated(name: trimmedName)

            router.navigateBack()
        } catch {
            self.error = "Failed to create home: \(error.localizedDescription)"
            isCreating = false
        }
    }
}

#Preview {
    let _ = try! prepareDependencies {
        $0.defaultDatabase = try appDatabase()
    }
    AddHomeView()
        .environmentObject(Router())
        .environmentObject(SettingsManager())
}
