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

class OpenAIService {
    var imageBase64: String
    
    init(imageBase64: String) {
        self.imageBase64 = imageBase64
    }
    
    let itemModel = InventoryItem()
    
    private func generateURLRequest(httpMethod: HTTPMethod) throws -> URLRequest {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw OpenAIError.invalidURL
        }
        
        let categories = itemModel.categories
        let locations = itemModel.locations
        
        let imagePrompt = """
        Act as a helpful AI backend for a home inventory application which will help users automatically identify and categorize their possessions based on the contents of an image. Identify the item which is the primary subject of this photo, along with your best guess at the following 5 attributes related to the item:
        - Title: a short description of the subject, to help the user identify the item from a list
        - Quantity: If there are multiple instances of the subject in the image, count up the number of instances and return a number (for example, if an image shows 4 dinner places of the same variety, return "4"). Return an empty string if it's difficult to determine, or if there are several different types of objects in the image
        - Description: a slightly longer description of the subject, limited to 160 characters
        - Make: the brand or manufacturer associated with the subject (return a blank string if it's difficult to determine)
        - Model: the model name or number associated with the subject (return a blank string if it's difficult to determine)
        - Category: the general category of household item that could be assigned to the subject. Choose from one of the following options, or return "None" if none of the options fit: \(categories)
        - Location: the most likely room or location in the house in which the subject could be found. Choose from one of the following options, or return "None" if none of the options fit: \(locations)
        - Price: the estimated original price (in US dollars, for example $10.99) of the subject based on any online shop listings you can find, such as on Amazon.com (return a blank string if it's difficult to determine)
        Return only JSON output following this schema:
        {"title": "Title of the item", "quantity": "1", "description": "A short description of the item", "make": "brandOrManufacturerName", "model": "modelNameOrNumber", "category": "categoryName", "location": "locationName, "price": "$1.00"}
        """
        
        var jsonData = Data()
        var urlRequest = URLRequest(url: url)
        
        // Method
        urlRequest.httpMethod = httpMethod.rawValue
        
        // Header
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("Bearer \(Secrets.apiKey)", forHTTPHeaderField: "Authorization")
        
        // Body
        let textMessage = MessageContent(type: "text", text: imagePrompt, image_url: nil)
        let imageMessage = MessageContent(type: "image_url", text: nil, image_url: ImageURL(url: "data:image/png:base64,\(imageBase64)"))
        let message = Message(role: "user", content: [textMessage, imageMessage])
        let payload = GPTPayload(model: "gpt-4o", messages: [message], max_tokens: 300)
        
        let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
        
        do {
            jsonData = try encoder.encode(payload)
        } catch {
            print("Error encoding inventory item: \(error)")
        }
        
        urlRequest.httpBody = jsonData
        
        return urlRequest
    }
    
    func getImageDetails() async throws -> ImageDetails {
        let urlRequest = try generateURLRequest(httpMethod: .post)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }
        
        do {
//            let decoder = JSONDecoder()
//            decoder.keyDecodingStrategy = .convertFromSnakeCase
            print(String(data: data, encoding: .utf8)!)
            let gptResponse = try JSONDecoder().decode(GPTResponse.self, from: data)
            let responseString = removeCharacters(from: { gptResponse.choices[0].message.content }())
            guard let responseData = responseString.data(using: .utf8) else {
                throw OpenAIError.invalidData
            }
            let imageDetails = try JSONDecoder().decode(ImageDetails.self, from: responseData)
            return imageDetails
        } catch {
            throw OpenAIError.invalidData
        }
    }
}

func removeCharacters(from input: String) -> String {
    var modifiedString = input
    
    // Remove "```json" from the start if it exists
    let startPattern = "```json"
    if modifiedString.hasPrefix(startPattern) {
        modifiedString.removeFirst(startPattern.count)
    }
    
    // Remove "```" from the end if it exists
    let endPattern = "```"
    if modifiedString.hasSuffix(endPattern) {
        modifiedString.removeLast(endPattern.count)
    }
    
    return modifiedString
}

// JSON Call Body
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
    let detail: String = "low"
}

struct GPTPayload: Encodable {
    let model: String
    let messages: [Message]
    let max_tokens: Int
}


// JSON Response Body
struct GPTResponse: Decodable {
    let choices: [GPTCompletionResponse]
}

struct GPTCompletionResponse: Decodable {
    let message: GPTMessageResponse
}

struct GPTMessageResponse: Decodable {
    let content: String
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
