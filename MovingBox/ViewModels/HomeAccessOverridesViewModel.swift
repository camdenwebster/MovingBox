import Foundation

@MainActor
final class HomeAccessOverridesViewModel: ObservableObject {
    let homeID: UUID

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var home: SQLiteHome?
    @Published var household: SQLiteHousehold?
    @Published var memberAccessStates: [MemberHomeAccessState] = []

    private let service = HouseholdSharingService()

    init(homeID: UUID) {
        self.homeID = homeID
    }

    var isPrivate: Bool {
        home?.isPrivate ?? false
    }

    var defaultAccessPolicy: HouseholdDefaultAccessPolicy {
        guard let raw = household?.defaultAccessPolicy else { return .allHomesShared }
        return HouseholdDefaultAccessPolicy(rawValue: raw) ?? .allHomesShared
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await service.loadSnapshot()
            household = snapshot.household
            home = snapshot.homes.first(where: { $0.id == homeID })
            memberAccessStates = try await service.loadHomeAccessStates(homeID: homeID)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load home access: \(error.localizedDescription)"
        }
    }

    func setPrivate(_ newValue: Bool) async {
        do {
            try await service.setHomePrivacy(homeID: homeID, isPrivate: newValue)
            await load()
        } catch {
            errorMessage = "Failed to update home privacy: \(error.localizedDescription)"
        }
    }

    func setOverride(memberID: UUID, decision: HomeAccessOverrideDecision?) async {
        do {
            try await service.upsertHomeAccessOverride(
                homeID: homeID,
                memberID: memberID,
                decision: decision
            )
            await load()
        } catch {
            errorMessage = "Failed to update member access: \(error.localizedDescription)"
        }
    }
}
