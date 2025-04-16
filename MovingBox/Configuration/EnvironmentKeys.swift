import SwiftUI

struct IsOnboardingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isOnboarding: Bool {
        get { self[IsOnboardingKey.self] }
        set { self[IsOnboardingKey.self] = newValue }
    }
}

// ADD: New environment key for snapshot testing
private struct IsSnapshotTestingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isSnapshotTesting: Bool {
        get { self[IsSnapshotTestingKey.self] }
        set { self[IsSnapshotTestingKey.self] = newValue }
    }
}

private struct DisableAnimationsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var disableAnimations: Bool {
        get { self[DisableAnimationsKey.self] }
        set { self[DisableAnimationsKey.self] = newValue }
    }
}
