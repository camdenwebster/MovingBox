import XCTest

@testable import MovingBoxAIDomain

final class OpenAIErrorTests: XCTestCase {
    func testRetryableClassification() {
        XCTAssertTrue(OpenAIError.networkTimeout.isRetryable)
        XCTAssertTrue(OpenAIError.rateLimitExceeded.isRetryable)
        XCTAssertTrue(OpenAIError.serverError("x").isRetryable)

        XCTAssertFalse(OpenAIError.invalidData.isRetryable)
        XCTAssertFalse(OpenAIError.invalidURL.isRetryable)
    }

    func testUserFriendlyMessageExtractsServerErrorMessageWhenJSON() {
        let raw = "{\"error\":\"bad request\"}"
        let value = OpenAIError.invalidResponse(statusCode: 400, responseData: raw).userFriendlyMessage
        XCTAssertEqual(value, "Server Error (400): bad request")
    }
}
