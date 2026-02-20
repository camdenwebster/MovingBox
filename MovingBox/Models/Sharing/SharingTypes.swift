import Foundation

enum HouseholdDefaultAccessPolicy: String, CaseIterable, Sendable {
    case allHomesShared
    case ownerScopesHomes
}

enum HouseholdMemberRole: String, CaseIterable, Sendable {
    case owner
    case member
}

enum HouseholdMemberStatus: String, CaseIterable, Sendable {
    case active
    case revoked
}

enum HouseholdInviteStatus: String, CaseIterable, Sendable {
    case pending
    case accepted
    case revoked
}

enum HomeAccessOverrideDecision: String, CaseIterable, Sendable {
    case allow
    case deny
}

enum HomeAccessSource: String, Sendable {
    case inherited
    case overriddenAllow
    case overriddenDeny
    case privateHome
    case noMembership
}
