import Testing
import Sentry
@testable import MovingBox

@Suite("Sentry Integration Tests")
struct SentryIntegrationTests {
    
    @Test("Sentry DSN is configured")
    func sentryDsnIsConfigured() {
        let dsn = AppConfig.sentryDsn
        #expect(dsn != "missing-sentry-dsn")
        #expect(!dsn.isEmpty)
        #expect(dsn.contains("sentry.io"))
    }
    
    @Test("Sentry DSN format is valid")
    func sentryDsnFormatIsValid() {
        let fullDsn = "https://\(AppConfig.sentryDsn)"
        #expect(fullDsn.hasPrefix("https://"))
        #expect(fullDsn != "https://missing-sentry-dsn")
    }
}
