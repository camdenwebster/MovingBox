import Testing

@testable import MovingBox

@Suite("Feature Flags")
struct FeatureFlagsTests {
    @Test("familySharingScopingEnabled defaults off in every distribution")
    func familySharingScopingDefaultsOff() {
        let debugFlags = FeatureFlags(distribution: .debug, launchArguments: [])
        let betaFlags = FeatureFlags(distribution: .beta, launchArguments: [])
        let appStoreFlags = FeatureFlags(distribution: .appstore, launchArguments: [])

        #expect(debugFlags.familySharingScopingEnabled == false)
        #expect(betaFlags.familySharingScopingEnabled == false)
        #expect(appStoreFlags.familySharingScopingEnabled == false)
    }

    @Test("Enable-Family-Sharing-Scoping launch arg enables scoping in debug and beta")
    func launchArgumentEnablesScoping() {
        let args = ["Enable-Family-Sharing-Scoping"]

        let debugFlags = FeatureFlags(distribution: .debug, launchArguments: args)
        let betaFlags = FeatureFlags(distribution: .beta, launchArguments: args)
        let appStoreFlags = FeatureFlags(distribution: .appstore, launchArguments: args)

        #expect(debugFlags.familySharingScopingEnabled == true)
        #expect(betaFlags.familySharingScopingEnabled == true)
        #expect(appStoreFlags.familySharingScopingEnabled == false)
    }
}
