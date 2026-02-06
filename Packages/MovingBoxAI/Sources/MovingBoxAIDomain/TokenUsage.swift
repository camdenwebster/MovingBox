import Foundation

public struct TokenUsage: Decodable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
    public let promptTokensDetails: PromptTokensDetails?
    public let completionTokensDetails: CompletionTokensDetails?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case promptTokensDetails = "prompt_tokens_details"
        case completionTokensDetails = "completion_tokens_details"
    }

    public init(
        promptTokens: Int,
        completionTokens: Int,
        totalTokens: Int,
        promptTokensDetails: PromptTokensDetails? = nil,
        completionTokensDetails: CompletionTokensDetails? = nil
    ) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.promptTokensDetails = promptTokensDetails
        self.completionTokensDetails = completionTokensDetails
    }
}

public struct PromptTokensDetails: Decodable, Sendable {
    public let cachedTokens: Int?
    public let audioTokens: Int?

    enum CodingKeys: String, CodingKey {
        case cachedTokens = "cached_tokens"
        case audioTokens = "audio_tokens"
    }

    public init(cachedTokens: Int? = nil, audioTokens: Int? = nil) {
        self.cachedTokens = cachedTokens
        self.audioTokens = audioTokens
    }
}

public struct CompletionTokensDetails: Decodable, Sendable {
    public let reasoningTokens: Int?
    public let audioTokens: Int?
    public let acceptedPredictionTokens: Int?
    public let rejectedPredictionTokens: Int?

    enum CodingKeys: String, CodingKey {
        case reasoningTokens = "reasoning_tokens"
        case audioTokens = "audio_tokens"
        case acceptedPredictionTokens = "accepted_prediction_tokens"
        case rejectedPredictionTokens = "rejected_prediction_tokens"
    }

    public init(
        reasoningTokens: Int? = nil,
        audioTokens: Int? = nil,
        acceptedPredictionTokens: Int? = nil,
        rejectedPredictionTokens: Int? = nil
    ) {
        self.reasoningTokens = reasoningTokens
        self.audioTokens = audioTokens
        self.acceptedPredictionTokens = acceptedPredictionTokens
        self.rejectedPredictionTokens = rejectedPredictionTokens
    }
}
