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