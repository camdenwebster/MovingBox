import Foundation
import MovingBoxAIDomain

public enum AIResponseDecoder {
    public static func decodeImageDetails(from json: String) throws -> ImageDetails {
        guard let data = json.data(using: .utf8) else {
            throw OpenAIError.invalidData
        }
        do {
            return try JSONDecoder().decode(ImageDetails.self, from: data)
        } catch {
            throw OpenAIError.invalidData
        }
    }

    public static func decodeMultiItemResponse(from json: String) throws -> MultiItemAnalysisResponse {
        guard let data = json.data(using: .utf8) else {
            throw OpenAIError.invalidData
        }
        do {
            return try JSONDecoder().decode(MultiItemAnalysisResponse.self, from: data)
        } catch {
            throw OpenAIError.invalidData
        }
    }
}
