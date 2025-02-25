//
//  OpenAIService.swift
//  MovingBox
//
//  Created by Camden Webster on 5/14/24.
//

import Foundation

enum HTTPMethod: String {
    case post = "POST"
    case get = "GET"
}

enum OpenAIError: Error {
    case invalidURL
    case invalidResponse
    case invalidData
}

struct FunctionParameter: Codable {
    let type: String
    let description: String?
    let enum_values: [String]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enum_values = "enum"
    }
}

struct FunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: Parameters
    
    struct Parameters: Codable {
        let type: String
        let properties: [String: FunctionParameter]
        let required: [String]
    }
}

class OpenAIService {
    
    
    
    var imageBase64: String
    var settings: SettingsManager
    
    init(imageBase64: String, settings: SettingsManager) {
        self.imageBase64 = imageBase64
        self.settings = settings
    }
    
    let itemModel = InventoryItem(title: "", quantityString: "1", quantityInt: 1, desc: "", serial: "", model: "", make: "", location: nil, label: nil, price: "", insured: false, assetId: "", notes: "", showInvalidQuantityAlert: false)
    
    private func generateURLRequest(httpMethod: HTTPMethod) throws -> URLRequest {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw OpenAIError.invalidURL
        }
        
        let categories = TestData().labels
        let locations = TestData().locations
        
        let imagePrompt = "Analyze this image and identify the item which is the primary subject of the photo, along with its attributes."
        
        let function = FunctionDefinition(
            name: "process_inventory_item",
            description: "Process and structure information about an inventory item",
            parameters: FunctionDefinition.Parameters(
                type: "object",
                properties: [
                    "title": FunctionParameter(
                        type: "string",
                        description: "A short description of the subject, to help the user identify the item from a list",
                        enum_values: nil
                    ),
                    "quantity": FunctionParameter(
                        type: "string",
                        description: "The number of instances of this item, or empty string if unclear",
                        enum_values: nil
                    ),
                    "description": FunctionParameter(
                        type: "string",
                        description: "A slightly longer description of the subject, limited to 160 characters",
                        enum_values: nil
                    ),
                    "make": FunctionParameter(
                        type: "string",
                        description: "The brand or manufacturer associated with the subject",
                        enum_values: nil
                    ),
                    "model": FunctionParameter(
                        type: "string",
                        description: "The model name or number associated with the subject",
                        enum_values: nil
                    ),
                    "category": FunctionParameter(
                        type: "string",
                        description: "The general category of household item",
                        enum_values: categories
                    ),
                    "location": FunctionParameter(
                        type: "string",
                        description: "The most likely room or location in the house",
                        enum_values: locations
                    ),
                    "price": FunctionParameter(
                        type: "string",
                        description: "The estimated original price in US dollars (e.g., $10.99). Provide a single value, not a range.",
                        enum_values: nil
                    )
                ],
                required: ["title", "quantity", "description", "make", "model", "category", "location", "price"]
            )
        )
        
        var urlRequest = URLRequest(url: url)
        
        urlRequest.httpMethod = httpMethod.rawValue
        
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if settings.apiKey.isEmpty {
            throw OpenAIError.invalidResponse 
        }
        urlRequest.addValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        
        let textMessage = MessageContent(type: "text", text: imagePrompt, image_url: nil)
        let imageMessage = MessageContent(type: "image_url", text: nil, image_url: ImageURL(url: "data:image/png:base64,\(imageBase64)", detail: "\(settings.isHighDetail ? "high" : "low")"))
        let message = Message(role: "user", content: [textMessage, imageMessage])
        let payload = GPTPayload(
            model: settings.aiModel,
            messages: [message],
            max_tokens: settings.maxTokens,
            functions: [function],
            function_call: ["name": "process_inventory_item"]
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let jsonData = try encoder.encode(payload)
            urlRequest.httpBody = jsonData
        } catch {
            print("Error encoding payload: \(error)")
        }
        
        return urlRequest
    }
    
    func getImageDetails() async throws -> ImageDetails {
        let urlRequest = try generateURLRequest(httpMethod: .post)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }
        
        do {
            let gptResponse = try JSONDecoder().decode(GPTResponse.self, from: data)
            let functionCallArgs = gptResponse.choices[0].message.function_call?.arguments ?? ""
            
            guard let responseData = functionCallArgs.data(using: .utf8) else {
                throw OpenAIError.invalidData
            }
            
            return try JSONDecoder().decode(ImageDetails.self, from: responseData)
        } catch {
            throw OpenAIError.invalidData
        }
    }
}

struct Message: Encodable {
    let role: String
    let content: [MessageContent]
}

struct MessageContent: Encodable {
    let type: String
    let text: String?
    let image_url: ImageURL?
}

struct ImageURL: Encodable {
    let url: String
    let detail: String
}

struct GPTPayload: Encodable {
    let model: String
    let messages: [Message]
    let max_tokens: Int
    let functions: [FunctionDefinition]
    let function_call: [String: String]
}

struct GPTResponse: Decodable {
    let choices: [GPTCompletionResponse]
}

struct GPTCompletionResponse: Decodable {
    let message: GPTMessageResponse
}

struct GPTMessageResponse: Decodable {
    let function_call: FunctionCall?
}

struct FunctionCall: Decodable {
    let name: String
    let arguments: String
}

struct ImageDetails: Decodable {
    let title: String
    let quantity: String
    let description: String
    let make: String
    let model: String
    let category: String
    let location: String
    let price: String
}
