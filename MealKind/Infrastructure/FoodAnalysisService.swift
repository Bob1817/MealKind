import Foundation

protocol FoodAnalysisService {
    func analyzeMealImage(imageData: Data?, plan: DietPlan, remainingCalories: Int, language: AppLanguage) async -> FoodAnalysisResult
    func analyzeMealImage(
        imageData: Data?,
        plan: DietPlan,
        remainingCalories: Int,
        language: AppLanguage,
        bodyOSContext: BodyOSAnalysisContext?
    ) async -> FoodAnalysisResult
}

extension FoodAnalysisService {
    func analyzeMealImage(
        imageData: Data?,
        plan: DietPlan,
        remainingCalories: Int,
        language: AppLanguage,
        bodyOSContext: BodyOSAnalysisContext?
    ) async -> FoodAnalysisResult {
        await analyzeMealImage(
            imageData: imageData,
            plan: plan,
            remainingCalories: remainingCalories,
            language: language
        )
    }
}

struct BodyOSAnalysisContext: Encodable, Equatable {
    var userMode: String
    var goalState: String
    var trainingState: String
    var lifeState: String
    var recoveryState: String
    var recoveryScore: Int
    var nutritionTarget: NutritionTargetPayload
    var dailyConsumed: DailyConsumedPayload
    var todayStrategySummary: [String]
    var currentLocalTime: String

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
}

struct FoodAnalysisConfig {
    var endpoint: URL?

    static var appDefault: FoodAnalysisConfig {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: "FoodAnalysisEndpoint") as? String
        return FoodAnalysisConfig(endpoint: rawValue.flatMap(URL.init(string:)))
    }
}

struct ServerFoodAnalysisService: FoodAnalysisService {
    typealias DataLoader = @MainActor (URLRequest) async throws -> (Data, URLResponse)

    var config: FoodAnalysisConfig
    var apiClient: APIClientProtocol
    var fallback: FoodAnalysisService

    init(
        config: FoodAnalysisConfig = .appDefault,
        dataLoader: @escaping DataLoader = { request in
            try await URLSession.shared.data(for: request)
        },
        fallback: FoodAnalysisService = LocalFallbackFoodAnalysisService()
    ) {
        self.config = config
        self.apiClient = APIClient(dataLoader: dataLoader)
        self.fallback = fallback
    }

    init(
        config: FoodAnalysisConfig = .appDefault,
        apiClient: APIClientProtocol,
        fallback: FoodAnalysisService = LocalFallbackFoodAnalysisService()
    ) {
        self.config = config
        self.apiClient = apiClient
        self.fallback = fallback
    }

    func analyzeMealImage(imageData: Data?, plan: DietPlan, remainingCalories: Int, language: AppLanguage) async -> FoodAnalysisResult {
        await analyzeMealImage(
            imageData: imageData,
            plan: plan,
            remainingCalories: remainingCalories,
            language: language,
            bodyOSContext: nil
        )
    }

    func analyzeMealImage(
        imageData: Data?,
        plan: DietPlan,
        remainingCalories: Int,
        language: AppLanguage,
        bodyOSContext: BodyOSAnalysisContext?
    ) async -> FoodAnalysisResult {
        guard let endpoint = config.endpoint else {
            return await fallback.analyzeMealImage(
                imageData: imageData,
                plan: plan,
                remainingCalories: remainingCalories,
                language: language,
                bodyOSContext: bodyOSContext
            )
        }

        do {
            let request = AIJSONFunctionRequest(
                functionName: .foodVisionAnalysis,
                schemaVersion: FoodAnalysisRequest.schemaVersion,
                payload: FoodAnalysisRequest(
                    imageBase64: imageData?.base64EncodedString(),
                    plan: .init(plan),
                    remainingCalories: remainingCalories,
                    locale: language.localeIdentifier,
                    bodyOSContext: bodyOSContext
                )
            )

            let decoded: AIJSONFunctionResponse<FoodAnalysisResponse> = try await apiClient.post(request, to: endpoint)
            return decoded.payload.domainResult(plan: plan, remainingCalories: remainingCalories, language: language)
        } catch {
            return await fallback.analyzeMealImage(
                imageData: imageData,
                plan: plan,
                remainingCalories: remainingCalories,
                language: language,
                bodyOSContext: bodyOSContext
            )
        }
    }
}

struct LocalFallbackFoodAnalysisService: FoodAnalysisService {
    func analyzeMealImage(imageData: Data?, plan: DietPlan, remainingCalories: Int, language: AppLanguage = .english) async -> FoodAnalysisResult {
        let calories = 540
        let decision: MealDecision = remainingCalories >= calories ? .fits : .adjust
        let l10n = L10n(language: language)

        return FoodAnalysisResult(
            mealName: imageData == nil ? l10n.t(.scannedMeal) : l10n.t(.burgerMeal),
            estimatedCalories: calories,
            protein: 28,
            carbs: 52,
            fat: 24,
            confidence: .medium,
            decision: decision,
            actions: gentleAdvice(decision: decision, language: language),
            summary: decision == .fits
                ? l10n.t(.fallbackFitSummary)
                : l10n.t(.fallbackAdjustSummary),
            plainAdvice: gentleAdvice(decision: decision, language: language),
            taskCompletionImpact: language == .simplifiedChinese ? "保存后，今天午餐任务就完成了。" : "Saving this will complete today's lunch photo task.",
            celebration: language == .simplifiedChinese ? "你完成了今天最关键的一步。" : "You completed the most important small step today."
        )
    }

    private func gentleAdvice(decision: MealDecision, language: AppLanguage) -> [String] {
        if language == .simplifiedChinese {
            return decision == .fits
                ? ["肉和蔬菜正常吃", "米饭留一点也可以", "饮料尽量少喝或换无糖"]
                : ["米饭留三分之一", "肉和蔬菜正常吃", "饮料少喝一点"]
        }

        return decision == .fits
            ? ["Eat the protein and vegetables normally", "Leave a little rice if you feel full", "Keep the drink light or unsweetened"]
            : ["Leave one third of the rice", "Eat the protein and vegetables normally", "Drink a little less"]
    }
}

struct FoodAnalysisRequest: Encodable {
    static let schemaVersion = "food_vision_analysis.v1"

    var imageBase64: String?
    var plan: PlanPayload
    var remainingCalories: Int
    var locale: String
    var bodyOSContext: BodyOSAnalysisContext?

    struct PlanPayload: Encodable {
        var id: String
        var name: String
        var dailyDeficit: Int
        var guardrails: [String]

        init(_ plan: DietPlan) {
            id = plan.id
            name = plan.rawValue
            dailyDeficit = plan.dailyDeficit
            guardrails = plan.simpleGuardrails
        }
    }
}

struct FoodAnalysisResponse: Decodable {
    var foods: [RecognizedFood]?
    var totalCalories: Int?
    var planFit: String?
    var recommendedAction: RecommendedAction?
    var safetyFlags: [String]?
    var recordDraft: RecordDraft?

    func domainResult(plan: DietPlan, remainingCalories: Int, language: AppLanguage = .english) -> FoodAnalysisResult {
        let estimatedCalories = recordDraft?.calories ?? totalCalories ?? foods?.map(\.estimatedCalories).reduce(0, +) ?? 0
        let decision: MealDecision = planFit == "fits" || remainingCalories >= estimatedCalories ? .fits : .adjust
        let actions = actionList(for: plan, decision: decision, language: language)

        return FoodAnalysisResult(
            mealName: mealName(language: language),
            estimatedCalories: estimatedCalories,
            protein: recordDraft?.protein ?? foods?.map(\.protein).reduce(0, +) ?? 0,
            carbs: recordDraft?.carbs ?? foods?.map(\.carbs).reduce(0, +) ?? 0,
            fat: recordDraft?.fat ?? foods?.map(\.fat).reduce(0, +) ?? 0,
            servingDescription: servingDescription,
            confidence: confidence,
            decision: decision,
            actions: actions,
            summary: recommendedAction?.summary,
            plainAdvice: actions,
            taskCompletionImpact: recommendedAction?.taskCompletionImpact ?? defaultTaskImpact(language: language),
            celebration: recommendedAction?.celebration ?? defaultCelebration(language: language)
        )
    }

    private func mealName(language: AppLanguage) -> String {
        let names = foods?.compactMap(\.name).filter { !$0.isEmpty } ?? []
        if names.isEmpty {
            return L10n(language: language).t(.scannedMeal)
        }
        return names.prefix(2).joined(separator: ", ")
    }

    private var servingDescription: String? {
        let portions = foods?
            .compactMap(\.portion)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        guard !portions.isEmpty else { return nil }
        return portions.prefix(2).joined(separator: " + ")
    }

    private var confidence: AnalysisConfidence {
        let rawConfidence = foods?.compactMap(\.confidence).max() ?? 0
        if rawConfidence >= 0.8 {
            return .high
        }
        if rawConfidence >= 0.55 {
            return .medium
        }
        return .low
    }

    private func actionList(for plan: DietPlan, decision: MealDecision, language: AppLanguage) -> [String] {
        var actions = recommendedAction?.portionStrategy ?? []

        if let nextMealAdjustment = recommendedAction?.nextMealAdjustment {
            actions.append(nextMealAdjustment)
        }

        if actions.isEmpty {
            let l10n = L10n(language: language)
            actions = [
                plan.localizedGuardrails(language: language)[0],
                decision == .fits ? l10n.t(.ruleSaveLeftovers) : l10n.t(.savePartForLater)
            ]
        }

        return Array(actions.prefix(3))
    }

    private func defaultTaskImpact(language: AppLanguage) -> String {
        language == .simplifiedChinese
            ? "保存后，今天午餐任务就完成了。"
            : "Saving this will complete today's lunch photo task."
    }

    private func defaultCelebration(language: AppLanguage) -> String {
        language == .simplifiedChinese
            ? "你完成了今天最关键的一步。"
            : "You completed the most important small step today."
    }

    struct RecognizedFood: Decodable {
        var name: String?
        var portion: String?
        var estimatedCalories: Int
        var protein: Int
        var carbs: Int
        var fat: Int
        var confidence: Double?
    }

    struct RecommendedAction: Decodable {
        var summary: String?
        var portionStrategy: [String]?
        var nextMealAdjustment: String?
        var wasteAvoidance: String?
        var taskCompletionImpact: String?
        var celebration: String?
    }

    struct RecordDraft: Decodable {
        var mealType: String?
        var calories: Int?
        var protein: Int?
        var carbs: Int?
        var fat: Int?
    }
}
