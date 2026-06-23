import Foundation

protocol APIClientProtocol {
    func post<Body: Encodable, Response: Decodable>(
        _ body: Body,
        to endpoint: URL
    ) async throws -> Response
}

struct APIClient: APIClientProtocol {
    typealias DataLoader = @MainActor (URLRequest) async throws -> (Data, URLResponse)

    var dataLoader: DataLoader

    init(
        dataLoader: @escaping DataLoader = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.dataLoader = dataLoader
    }

    func post<Body: Encodable, Response: Decodable>(
        _ body: Body,
        to endpoint: URL
    ) async throws -> Response {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder.mealKind.encode(body)

        let (data, response) = try await dataLoader(request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            200..<300 ~= httpResponse.statusCode
        else {
            throw APIClientError.badResponse
        }

        return try JSONDecoder.mealKind.decode(Response.self, from: data)
    }
}

enum APIClientError: Error {
    case badResponse
}

enum AIJSONFunctionName: String, Codable, CaseIterable {
    case onboardingProfileExtraction = "onboarding_profile_extraction"
    case naturalLanguageEventParser = "natural_language_event_parser"
    case foodVisionAnalysis = "food_vision_analysis"
    case strategyExplanation = "strategy_explanation"
    case weeklyReviewGeneration = "weekly_review_generation"
    case safetyClassification = "safety_classification"
}

struct AIJSONFunctionRequest<Payload: Encodable>: Encodable {
    var functionName: AIJSONFunctionName
    var schemaVersion: String
    var payload: Payload
}

struct AIJSONFunctionResponse<Payload: Decodable>: Decodable {
    var functionName: AIJSONFunctionName?
    var schemaVersion: String?
    var payload: Payload

    private enum CodingKeys: String, CodingKey {
        case functionName
        case schemaVersion
        case payload
    }

    init(functionName: AIJSONFunctionName? = nil, schemaVersion: String? = nil, payload: Payload) {
        self.functionName = functionName
        self.schemaVersion = schemaVersion
        self.payload = payload
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let payload = try? container.decode(Payload.self, forKey: .payload) {
            self.functionName = try container.decodeIfPresent(AIJSONFunctionName.self, forKey: .functionName)
            self.schemaVersion = try container.decodeIfPresent(String.self, forKey: .schemaVersion)
            self.payload = payload
            return
        }

        functionName = nil
        schemaVersion = nil
        payload = try Payload(from: decoder)
    }
}

extension JSONEncoder {
    static var mealKind: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }
}

extension JSONDecoder {
    static var mealKind: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }
}
