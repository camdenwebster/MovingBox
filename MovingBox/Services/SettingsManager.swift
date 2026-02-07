import Foundation
import RevenueCat
import StoreKit
import SwiftUI

@MainActor
class SettingsManager: ObservableObject {
    // Keys for UserDefaults
    private enum Keys {
        static let aiModel = "aiModel"
        static let temperature = "temperature"
        static let maxTokens = "maxTokens"
        static let apiKey = "apiKey"
        static let isHighDetail = "isHighDetail"
        static let highQualityAnalysisEnabled = "highQualityAnalysisEnabled"
        static let hasLaunched = "hasLaunched"
        static let isPro = "isPro"
        static let preferredCaptureMode = "preferredCaptureMode"
        static let successfulAIAnalysisCount = "successfulAIAnalysisCount"
        static let firstLaunchDate = "firstLaunchDate"
        static let hasRequestedReviewAfter30Days = "hasRequestedReviewAfter30Days"
        static let activeHomeId = "activeHomeId"
    }

    // Published properties that will update the UI
    @Published var aiModel: String {
        didSet {
            UserDefaults.standard.set(aiModel, forKey: Keys.aiModel)
        }
    }

    @Published var temperature: Double {
        didSet {
            UserDefaults.standard.set(temperature, forKey: Keys.temperature)
        }
    }

    @Published var maxTokens: Int {
        didSet {
            UserDefaults.standard.set(maxTokens, forKey: Keys.maxTokens)
        }
    }

    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: Keys.apiKey)
        }
    }

    @Published var isHighDetail: Bool {
        didSet {
            UserDefaults.standard.set(isHighDetail, forKey: Keys.isHighDetail)
        }
    }

    @Published var hasLaunched: Bool {
        didSet {
            UserDefaults.standard.set(hasLaunched, forKey: Keys.hasLaunched)
        }
    }

    @Published var isPro: Bool {
        didSet {
            let proValue = ProcessInfo.processInfo.arguments.contains("Is-Pro") ? true : isPro
            UserDefaults.standard.set(proValue, forKey: Keys.isPro)
        }
    }

    @Published var highQualityAnalysisEnabled: Bool {
        didSet {
            print("📱 SettingsManager - highQualityAnalysisEnabled changed to: \(highQualityAnalysisEnabled)")
            UserDefaults.standard.set(highQualityAnalysisEnabled, forKey: Keys.highQualityAnalysisEnabled)
        }
    }

    @Published var preferredCaptureMode: Int {
        didSet {
            UserDefaults.standard.set(preferredCaptureMode, forKey: Keys.preferredCaptureMode)
        }
    }

    @Published var successfulAIAnalysisCount: Int {
        didSet {
            UserDefaults.standard.set(successfulAIAnalysisCount, forKey: Keys.successfulAIAnalysisCount)
        }
    }

    @Published var activeHomeId: String? {
        didSet {
            if let id = activeHomeId {
                UserDefaults.standard.set(id, forKey: Keys.activeHomeId)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.activeHomeId)
            }
        }
    }

    /// Convenience property that converts activeHomeId string to UUID.
    /// Returns nil if activeHomeId is nil or not a valid UUID string.
    var activeHomeIdAsUUID: UUID? {
        activeHomeId.flatMap { UUID(uuidString: $0) }
    }

    var firstLaunchDate: Date {
        if let date = UserDefaults.standard.object(forKey: Keys.firstLaunchDate) as? Date {
            return date
        } else {
            let now = Date()
            UserDefaults.standard.set(now, forKey: Keys.firstLaunchDate)
            return now
        }
    }

    var hasRequestedReviewAfter30Days: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.hasRequestedReviewAfter30Days)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.hasRequestedReviewAfter30Days)
        }
    }

    // Pro feature constants
    public struct AppConstants: Sendable {
        static let maxFreeAiScans = 50
    }

    private let revenueCatManager = RevenueCatManager.shared

    // Default values
    private let defaultAIModel = "google/gemini-3-flash-preview"
    private let defaultTemperature = 0.7
    private let defaultMaxTokens = 3000
    private let defaultApiKey = ""
    private let isHighDetailDefault = false
    private let highQualityAnalysisEnabledDefault = false
    private let hasLaunchedDefault = false
    private let preferredCaptureModeDefault = 0  // 0 = singleItem, 1 = multiItem

    init() {
        // Initialize with default values first
        self.aiModel = defaultAIModel
        self.temperature = defaultTemperature
        self.maxTokens = defaultMaxTokens
        self.apiKey = defaultApiKey
        self.isHighDetail = isHighDetailDefault
        self.highQualityAnalysisEnabled = highQualityAnalysisEnabledDefault
        self.hasLaunched = hasLaunchedDefault
        self.isPro = ProcessInfo.processInfo.arguments.contains("Is-Pro")
        self.preferredCaptureMode = preferredCaptureModeDefault
        self.successfulAIAnalysisCount = UserDefaults.standard.integer(forKey: Keys.successfulAIAnalysisCount)
        self.activeHomeId = UserDefaults.standard.string(forKey: Keys.activeHomeId)

        print("📱 SettingsManager - Initial isPro value: \(self.isPro)")

        if ProcessInfo.processInfo.arguments.contains("Is-Pro") {
            print("📱 SettingsManager - Setting Pro status to true due to Is-Pro argument")
            UserDefaults.standard.set(true, forKey: Keys.isPro)
        }

        Task {
            await setupInitialState()
        }
    }

    private func setupInitialState() async {
        print("📱 SettingsManager - Beginning setupInitialState")
        print("📱 SettingsManager - Is-Pro argument present: \(ProcessInfo.processInfo.arguments.contains("Is-Pro"))")

        // Check launch arguments first before loading any defaults
        if ProcessInfo.processInfo.arguments.contains("Is-Pro") {
            print("📱 SettingsManager - Setting isPro to true due to launch argument")
            self.isPro = true
            UserDefaults.standard.set(true, forKey: Keys.isPro)
            // Skip RevenueCat check entirely when Is-Pro is present
            print("📱 SettingsManager - Skipping RevenueCat check due to Is-Pro argument")
            return
        }

        // Load other values from UserDefaults
        self.aiModel = UserDefaults.standard.string(forKey: Keys.aiModel) ?? defaultAIModel
        self.temperature = UserDefaults.standard.double(forKey: Keys.temperature)
        self.maxTokens = UserDefaults.standard.integer(forKey: Keys.maxTokens)
        self.apiKey = UserDefaults.standard.string(forKey: Keys.apiKey) ?? defaultApiKey
        self.isHighDetail = UserDefaults.standard.bool(forKey: Keys.isHighDetail)
        self.hasLaunched = UserDefaults.standard.bool(forKey: Keys.hasLaunched)
        self.preferredCaptureMode = UserDefaults.standard.integer(forKey: Keys.preferredCaptureMode)

        // Set high quality default based on Pro status, but allow override
        if !UserDefaults.standard.contains(key: Keys.highQualityAnalysisEnabled) {
            print(
                "📱 SettingsManager - No saved highQualityAnalysisEnabled, setting default: \(self.isPro ? highQualityAnalysisEnabledDefault : false)"
            )
            self.highQualityAnalysisEnabled = self.isPro ? highQualityAnalysisEnabledDefault : false
        } else {
            let savedValue = UserDefaults.standard.bool(forKey: Keys.highQualityAnalysisEnabled)
            print("📱 SettingsManager - Loading saved highQualityAnalysisEnabled: \(savedValue)")
            self.highQualityAnalysisEnabled = savedValue
        }

        if self.temperature == 0.0 { self.temperature = defaultTemperature }
        if self.maxTokens == 0 || self.maxTokens < 3000 { self.maxTokens = defaultMaxTokens }

        // Only check RevenueCat if Is-Pro is NOT present
        if !ProcessInfo.processInfo.arguments.contains("Is-Pro") {
            do {
                print("📱 SettingsManager - Checking RevenueCat status")
                let customerInfo = try await Purchases.shared.customerInfo()
                let isPro = customerInfo.entitlements["Pro"]?.isActive == true
                print("📱 SettingsManager - RevenueCat status: \(isPro)")
                self.isPro = isPro

                // Re-evaluate high quality setting if Pro status changed and no explicit setting exists
                if !UserDefaults.standard.contains(key: Keys.highQualityAnalysisEnabled) {
                    self.highQualityAnalysisEnabled = self.isPro ? highQualityAnalysisEnabledDefault : false
                }
            } catch {
                print("⚠️ SettingsManager - Error fetching customer info: \(error)")
                self.isPro = UserDefaults.standard.bool(forKey: Keys.isPro)

                // Re-evaluate high quality setting if Pro status changed and no explicit setting exists
                if !UserDefaults.standard.contains(key: Keys.highQualityAnalysisEnabled) {
                    self.highQualityAnalysisEnabled = self.isPro ? highQualityAnalysisEnabledDefault : false
                }
            }
        }

        print("📱 SettingsManager - Final isPro value: \(self.isPro)")
    }

    private func setupSubscriptionMonitoring() {
        // Listen for subscription status changes
        NotificationCenter.default.addObserver(
            forName: .subscriptionStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            if let isPro = notification.userInfo?["isProActive"] as? Bool {
                print("📱 SettingsManager - Received subscription status change: isPro = \(isPro)")

                // Handle actor-isolated property on main actor
                Task { @MainActor in
                    self.isPro = isPro

                    // Post notification for successful purchase
                    if isPro {
                        NotificationCenter.default.post(name: .purchaseCompleted, object: nil)
                    }
                }
            }
        }
    }

    // MARK: - AI Analysis Configuration

    /// Effective AI model based on Pro status and quality settings
    var effectiveAIModel: String {
        // For now, use the same model for all tiers
        // Can differentiate with thinking levels later
        return "google/gemini-3-flash-preview"
    }

    /// Effective image resolution for AI processing based on Pro status and quality settings
    var effectiveImageResolution: CGFloat {
        if isPro && highQualityAnalysisEnabled {
            return 1250.0
        }
        return 512.0
    }

    /// Effective detail parameter for AI image processing based on Pro status and quality settings
    var effectiveDetailLevel: String {
        if isPro && highQualityAnalysisEnabled {
            return "high"
        }
        return "low"
    }

    /// Whether high quality analysis toggle should be available (Pro users only)
    var isHighQualityToggleAvailable: Bool {
        return isPro
    }

    // MARK: - Pro Feature Checks

    func shouldShowPaywall() -> Bool {
        !isPro
    }

    func shouldShowPaywallForAiScan(currentCount: Int) -> Bool {
        print("📱 SettingsManager - Checking shouldShowPaywallForAiScan")
        print("📱 SettingsManager - Current isPro: \(isPro)")
        print("📱 SettingsManager - Current count of items which have used AI scan: \(currentCount)")
        return !isPro && currentCount >= AppConstants.maxFreeAiScans
    }

    // MARK: - Purchase Flow

    func purchasePro() {
        print("📱 SettingsManager - Initiating Pro purchase")
        Task {
            do {
                try await revenueCatManager.purchasePro()
                // Customer info will be updated via notification
            } catch {
                print("⚠️ SettingsManager - Error purchasing pro: \(error)")
            }
        }
    }

    func restorePurchases() async throws {
        print("📱 SettingsManager - Initiating purchase restoration")
        try await RevenueCatManager.shared.restorePurchases()
        // Customer info will be updated via notification
    }

    // MARK: - Reset Settings

    func resetToDefaults() {
        aiModel = defaultAIModel
        temperature = defaultTemperature
        maxTokens = defaultMaxTokens
        apiKey = defaultApiKey
        isHighDetail = isHighDetailDefault
        highQualityAnalysisEnabled = false
        hasLaunched = hasLaunchedDefault
        isPro = false
        successfulAIAnalysisCount = 0

        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("Is-Pro") {
                isPro = true
            }
        #endif
    }

    // MARK: - App Store Review Request

    func incrementSuccessfulAIAnalysis() {
        successfulAIAnalysisCount += 1
        print("📱 SettingsManager - Successful AI analysis count: \(successfulAIAnalysisCount)")
    }

    func shouldRequestReview() -> Bool {
        // Condition 1: After exactly 3 successful AI analyses
        if successfulAIAnalysisCount == 3 {
            return true
        }

        // Condition 2: After 30 days + 50 items analyzed (only once)
        if !hasRequestedReviewAfter30Days && hasUsedAppFor30Days() && successfulAIAnalysisCount >= 50 {
            hasRequestedReviewAfter30Days = true
            return true
        }

        return false
    }

    private func hasUsedAppFor30Days() -> Bool {
        let daysSinceFirstLaunch = Calendar.current.dateComponents([.day], from: firstLaunchDate, to: Date()).day ?? 0
        return daysSinceFirstLaunch >= 30
    }
}

extension Notification.Name {
    static let purchaseCompleted = Notification.Name("PurchaseCompletedNotification")
}

extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
