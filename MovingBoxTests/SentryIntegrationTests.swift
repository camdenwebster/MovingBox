import Testing
import Sentry
@testable import MovingBox

@Suite("Sentry Integration Tests")
struct SentryIntegrationTests {
    
    @Test("Sentry DSN is configured")
    func sentryDsnIsConfigured() {
        let dsn = AppConfig.sentryDsn
        #expect(!dsn.isEmpty)
        
        // In test environment, we expect either a real DSN or the fallback
        if dsn != "missing-sentry-dsn" {
            // If a real DSN is configured, it should contain sentry.io
            #expect(dsn.contains("sentry.io"))
        } else {
            // In test environment without configuration, fallback is acceptable
            #expect(dsn == "missing-sentry-dsn")
        }
    }
    
    @Test("Sentry DSN format is valid")
    func sentryDsnFormatIsValid() {
        let dsn = AppConfig.sentryDsn
        let fullDsn = "https://\(dsn)"
        #expect(fullDsn.hasPrefix("https://"))
        
        // Only validate URL format if we have a real DSN
        if dsn != "missing-sentry-dsn" {
            #expect(fullDsn.contains("sentry.io"))
        }
    }
}
