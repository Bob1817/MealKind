import Foundation
import XCTest
@testable import MealKind

@MainActor
final class FoodAnalysisServiceTests: XCTestCase {
    func testFallbackMealFitsWhenBudgetIsEnough() async {
        let service = LocalFallbackFoodAnalysisService()

        let result = await service.analyzeMealImage(
            imageData: Data([1, 2, 3]),
            plan: .lifestyleCut,
            remainingCalories: 700,
            language: .english
        )

        XCTAssertEqual(result.decision, .fits)
        XCTAssertEqual(result.estimatedCalories, 540)
    }

    func testFallbackMealAsksForAdjustmentWhenBudgetIsLow() async {
        let service = LocalFallbackFoodAnalysisService()

        let result = await service.analyzeMealImage(
            imageData: Data([1, 2, 3]),
            plan: .carbStepDown,
            remainingCalories: 320,
            language: .english
        )

        XCTAssertEqual(result.decision, .adjust)
        XCTAssertTrue(result.plainAdvice.contains("Leave one third of the rice"))
        XCTAssertEqual(result.taskCompletionImpact, "Saving this will complete today's lunch photo task.")
    }

    func testFallbackMealLocalizesForSimplifiedChinese() async {
        let service = LocalFallbackFoodAnalysisService()

        let result = await service.analyzeMealImage(
            imageData: nil,
            plan: .lifestyleCut,
            remainingCalories: 320,
            language: .simplifiedChinese
        )

        XCTAssertEqual(result.mealName, "已扫描餐食")
        XCTAssertTrue(result.plainAdvice.contains("米饭留三分之一"))
        XCTAssertEqual(result.summary, "这顿可以吃，把主食稍微少一点就好。")
    }

    func testServerResponseMapsPRDJSONToDomainResult() throws {
        let json = """
        {
          "foods": [
            {
              "name": "beef burger",
              "portion": "1 regular burger",
              "estimatedCalories": 520,
              "protein": 28,
              "carbs": 46,
              "fat": 24,
              "confidence": 0.82
            },
            {
              "name": "fries",
              "portion": "small",
              "estimatedCalories": 240,
              "protein": 3,
              "carbs": 32,
              "fat": 12,
              "confidence": 0.72
            }
          ],
          "totalCalories": 760,
          "planFit": "adjustable",
          "recommendedAction": {
            "summary": "Eat the burger as the main meal and keep half of the fries for later.",
            "portionStrategy": [
              "Finish the patty and vegetables",
              "Keep half of the bun",
              "Share or save half of the fries"
            ],
            "nextMealAdjustment": "Choose a lighter protein-and-vegetable dinner if this is lunch.",
            "wasteAvoidance": "Save the remaining fries or share them."
          },
          "safetyFlags": [],
          "recordDraft": {
            "mealType": "lunch",
            "calories": 620,
            "protein": 30,
            "carbs": 58,
            "fat": 28
          }
        }
        """

        let response = try JSONDecoder().decode(FoodAnalysisResponse.self, from: Data(json.utf8))
        let result = response.domainResult(plan: .lifestyleCut, remainingCalories: 650)

        XCTAssertEqual(result.mealName, "beef burger, fries")
        XCTAssertEqual(result.estimatedCalories, 620)
        XCTAssertEqual(result.protein, 30)
        XCTAssertEqual(result.carbs, 58)
        XCTAssertEqual(result.fat, 28)
        XCTAssertEqual(result.confidence, .high)
        XCTAssertEqual(result.decision, .fits)
        XCTAssertEqual(result.actions.first, "Finish the patty and vegetables")
        XCTAssertEqual(result.plainAdvice.first, "Finish the patty and vegetables")
        XCTAssertEqual(result.taskCompletionImpact, "Saving this will complete today's lunch photo task.")
        XCTAssertEqual(result.summary, "Eat the burger as the main meal and keep half of the fries for later.")
    }

    func testWrappedFoodAnalysisResponseDecodesPayload() throws {
        let json = """
        {
          "functionName": "food_vision_analysis",
          "schemaVersion": "food_vision_analysis.v1",
          "payload": {
            "foods": [
              {
                "name": "chicken rice",
                "estimatedCalories": 610,
                "protein": 36,
                "carbs": 70,
                "fat": 18,
                "confidence": 0.74
              }
            ],
            "planFit": "adjustable",
            "recommendedAction": {
              "portionStrategy": ["Finish chicken", "Leave a little rice"]
            }
          }
        }
        """

        let response = try JSONDecoder.mealKind.decode(
            AIJSONFunctionResponse<FoodAnalysisResponse>.self,
            from: Data(json.utf8)
        )
        let result = response.payload.domainResult(plan: .carbStepDown, remainingCalories: 500)

        XCTAssertEqual(response.functionName, .foodVisionAnalysis)
        XCTAssertEqual(response.schemaVersion, FoodAnalysisRequest.schemaVersion)
        XCTAssertEqual(result.mealName, "chicken rice")
        XCTAssertEqual(result.decision, .adjust)
        XCTAssertEqual(result.actions, ["Finish chicken", "Leave a little rice"])
    }

    func testServerServicePostsImageAndParsesResponse() async throws {
        let json = """
        {
          "foods": [
            {
              "name": "salad bowl",
              "estimatedCalories": 430,
              "protein": 32,
              "carbs": 38,
              "fat": 16,
              "confidence": 0.9
            }
          ],
          "planFit": "fits",
          "recommendedAction": {
            "summary": "This bowl works well for your plan.",
            "portionStrategy": ["Finish the protein", "Keep dressing light"]
          },
          "recordDraft": {
            "calories": 430,
            "protein": 32,
            "carbs": 38,
            "fat": 16
          }
        }
        """
        let endpoint = URL(string: "https://api.example.com/analyze")!
        let loader = StubDataLoader(data: Data(json.utf8), statusCode: 200)
        let service = ServerFoodAnalysisService(
            config: FoodAnalysisConfig(endpoint: endpoint),
            dataLoader: { request in
                try await loader.data(for: request)
            },
            fallback: LocalFallbackFoodAnalysisService()
        )

        let result = await service.analyzeMealImage(
            imageData: Data([7, 8, 9]),
            plan: .highProtein,
            remainingCalories: 800,
            language: .english
        )

        let requestedURL = loader.lastRequest?.url
        let requestedMethod = loader.lastRequest?.httpMethod
        let requestBody = try XCTUnwrap(loader.lastRequest?.httpBody)
        let requestJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
        let payload = try XCTUnwrap(requestJSON["payload"] as? [String: Any])

        XCTAssertEqual(requestedURL, endpoint)
        XCTAssertEqual(requestedMethod, "POST")
        XCTAssertEqual(requestJSON["functionName"] as? String, "food_vision_analysis")
        XCTAssertEqual(requestJSON["schemaVersion"] as? String, FoodAnalysisRequest.schemaVersion)
        XCTAssertEqual(payload["locale"] as? String, AppLanguage.english.localeIdentifier)
        XCTAssertEqual(payload["imageBase64"] as? String, Data([7, 8, 9]).base64EncodedString())
        XCTAssertEqual(result.mealName, "salad bowl")
        XCTAssertEqual(result.decision, .fits)
        XCTAssertEqual(result.estimatedCalories, 430)
        XCTAssertEqual(result.actions, ["Finish the protein", "Keep dressing light"])
    }
}

@MainActor
private final class StubDataLoader {
    let data: Data
    let statusCode: Int
    private(set) var lastRequest: URLRequest?

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}
