import Foundation

// Responses API contracts. Engine values are the source of truth; AI translates and explains.

struct StrategyExplanationRequest: Encodable, Equatable {
    static let schemaVersion = "strategy_explanation.v1"

    var locale: String
    var userMode: String
    var bodyState: BodyStatePayload
    var recoveryScore: Int
    var nutritionTarget: NutritionTargetPayload
    var dailyConsumed: DailyConsumedPayload
    var strategyItems: [StrategyItemPayload]
    var currentLocalDate: String

    struct BodyStatePayload: Encodable, Equatable {
        var goalState: String
        var trainingState: String
        var lifeState: String
        var recoveryState: String
    }

    struct NutritionTargetPayload: Encodable, Equatable {
        var calories: Int
        var protein: Int
        var carbs: Int
        var fat: Int
        var deficit: Int
        var tdee: Int
    }

    struct DailyConsumedPayload: Encodable, Equatable {
        var calories: Int
        var protein: Int
        var carbs: Int
        var fat: Int
    }

    struct StrategyItemPayload: Encodable, Equatable {
        var type: String
        var priority: Int
        var title: String
        var actions: [ActionPayload]

        struct ActionPayload: Encodable, Equatable {
            var code: String
            var label: String
            var reason: String
        }
    }
}

struct StrategyExplanationResponse: Decodable, Equatable {
    var headline: String
    var explanation: String
    var encouragement: String?
    var safetyFlags: [String]?
}

struct WeeklyReviewGenerationRequest: Encodable, Equatable {
    static let schemaVersion = "weekly_review_generation.v1"

    var locale: String
    var userMode: String
    var weekStartLocalDate: String
    var completedTaskCount: Int
    var taskCompletionRate: Double
    var strongestHabit: String?
    var biggestObstacle: String?
    var nextWeekFocus: String
    var adherence: AdherencePayload
    var weightTrend: WeightTrendPayload?

    struct AdherencePayload: Encodable, Equatable {
        var taskCompletionRate: Double
        var mealLoggedDayCount: Int
        var workoutDayCount: Int
        var sleepLoggedDayCount: Int
        var supplementDayCount: Int
    }

    struct WeightTrendPayload: Encodable, Equatable {
        var startKilograms: Double
        var endKilograms: Double
    }
}

struct WeeklyReviewGenerationResponse: Decodable, Equatable {
    var summary: String
    var strongestPattern: String?
    var nextFocus: String
    var encouragement: String?
}

struct SafetyClassificationRequest: Encodable, Equatable {
    static let schemaVersion = "safety_classification.v1"

    var locale: String
    var inputType: SafetyInputType
    var text: String?
    var imageBase64: String?
    var context: ContextPayload?

    enum SafetyInputType: String, Encodable, Equatable {
        case userMessage = "user_message"
        case mealPhoto = "meal_photo"
        case mealDescription = "meal_description"
    }

    struct ContextPayload: Encodable, Equatable {
        var userMode: String
        var goalState: String
        var trainingState: String
        var lifeState: String
    }
}

struct SafetyClassificationResponse: Decodable, Equatable {
    var classification: Classification
    var flags: [String]
    var rationale: String?

    enum Classification: String, Decodable, Equatable {
        case safe
        case gentleReminder = "gentle_reminder"
        case escalate
    }
}

enum AIFunctionPayloadFactory {
    static func strategyExplanation(
        locale: String,
        userMode: String,
        bodyState: BodyState,
        recovery: RecoveryScore,
        nutritionTarget: NutritionTarget,
        dailyConsumed: DailyNutritionSummary,
        strategy: TodayStrategy
    ) -> StrategyExplanationRequest {
        StrategyExplanationRequest(
            locale: locale,
            userMode: userMode,
            bodyState: .init(
                goalState: bodyState.goalState.rawValue,
                trainingState: bodyState.trainingState.rawValue,
                lifeState: bodyState.lifeState.rawValue,
                recoveryState: bodyState.recoveryState.rawValue
            ),
            recoveryScore: recovery.value,
            nutritionTarget: .init(
                calories: nutritionTarget.calories,
                protein: nutritionTarget.protein,
                carbs: nutritionTarget.carbs,
                fat: nutritionTarget.fat,
                deficit: nutritionTarget.deficit,
                tdee: nutritionTarget.tdee
            ),
            dailyConsumed: .init(
                calories: dailyConsumed.caloriesIn,
                protein: dailyConsumed.protein,
                carbs: dailyConsumed.carbs,
                fat: dailyConsumed.fat
            ),
            strategyItems: strategy.items.map { item in
                StrategyExplanationRequest.StrategyItemPayload(
                    type: item.type.rawValue,
                    priority: item.priority,
                    title: item.title,
                    actions: item.actions.map {
                        StrategyExplanationRequest.StrategyItemPayload.ActionPayload(
                            code: $0.code,
                            label: $0.label,
                            reason: $0.reason
                        )
                    }
                )
            },
            currentLocalDate: LocalDateStamp.dateString(for: strategy.localDate)
        )
    }

    static func weeklyReviewGeneration(
        locale: String,
        userMode: String,
        review: WeeklyReview,
        adherence: BodyOSAdherence,
        weightTrend: WeeklyReviewGenerationRequest.WeightTrendPayload? = nil
    ) -> WeeklyReviewGenerationRequest {
        WeeklyReviewGenerationRequest(
            locale: locale,
            userMode: userMode,
            weekStartLocalDate: LocalDateStamp.dateString(for: review.weekStartDate),
            completedTaskCount: review.completedTaskCount,
            taskCompletionRate: review.taskCompletionRate,
            strongestHabit: review.strongestHabit,
            biggestObstacle: review.biggestObstacle,
            nextWeekFocus: review.nextWeekFocus,
            adherence: .init(
                taskCompletionRate: adherence.taskCompletionRate,
                mealLoggedDayCount: adherence.mealLoggedDayCount,
                workoutDayCount: adherence.workoutDayCount,
                sleepLoggedDayCount: adherence.sleepLoggedDayCount,
                supplementDayCount: adherence.supplementDayCount
            ),
            weightTrend: weightTrend
        )
    }
}

extension APIClientProtocol {
    func requestStrategyExplanation(
        payload: StrategyExplanationRequest,
        endpoint: URL
    ) async throws -> StrategyExplanationResponse {
        let request = AIJSONFunctionRequest(
            functionName: .strategyExplanation,
            schemaVersion: StrategyExplanationRequest.schemaVersion,
            payload: payload
        )
        let response: AIJSONFunctionResponse<StrategyExplanationResponse> = try await post(request, to: endpoint)
        return response.payload
    }

    func requestWeeklyReview(
        payload: WeeklyReviewGenerationRequest,
        endpoint: URL
    ) async throws -> WeeklyReviewGenerationResponse {
        let request = AIJSONFunctionRequest(
            functionName: .weeklyReviewGeneration,
            schemaVersion: WeeklyReviewGenerationRequest.schemaVersion,
            payload: payload
        )
        let response: AIJSONFunctionResponse<WeeklyReviewGenerationResponse> = try await post(request, to: endpoint)
        return response.payload
    }

    func requestSafetyClassification(
        payload: SafetyClassificationRequest,
        endpoint: URL
    ) async throws -> SafetyClassificationResponse {
        let request = AIJSONFunctionRequest(
            functionName: .safetyClassification,
            schemaVersion: SafetyClassificationRequest.schemaVersion,
            payload: payload
        )
        let response: AIJSONFunctionResponse<SafetyClassificationResponse> = try await post(request, to: endpoint)
        return response.payload
    }
}
