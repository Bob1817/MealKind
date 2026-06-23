import Foundation

enum BodyOSUserMode: String, Codable, CaseIterable, Identifiable, Equatable {
    case lifestyle
    case advanced

    var id: String { rawValue }

    init(experienceMode: AppExperienceMode) {
        switch experienceMode {
        case .lifestyle:
            self = .lifestyle
        case .professional:
            self = .advanced
        }
    }
}

enum BodyOSGoalState: String, Codable, CaseIterable, Identifiable, Equatable {
    case fatLoss
    case maintenance
    case muscleGain
    case recovery

    var id: String { rawValue }
}

enum BodyOSTrainingState: String, Codable, CaseIterable, Identifiable, Equatable {
    case normalTraining
    case restDay
    case deload
    case stopped
    case injured
    case returning

    var id: String { rawValue }
}

enum BodyOSLifeState: String, Codable, CaseIterable, Identifiable, Equatable {
    case normal
    case travel
    case businessTrip
    case party
    case holiday
    case highStress
    case illness

    var id: String { rawValue }
}

enum BodyOSRecoveryState: String, Codable, CaseIterable, Identifiable, Equatable {
    case good
    case moderate
    case low
    case critical

    var id: String { rawValue }
}

enum BodyOSCycleType: String, Codable, CaseIterable, Identifiable, Equatable {
    case fatLoss
    case maintenance
    case muscleGain
    case recovery

    var id: String { rawValue }
}

enum BodyOSTrainingTemplate: String, Codable, CaseIterable, Identifiable, Equatable {
    case threeOnOneOff
    case pushPullLegs
    case upperLower
    case custom

    var id: String { rawValue }
}

enum BodyOSWorkoutFocus: String, Codable, CaseIterable, Identifiable, Equatable {
    case fullBody
    case push
    case pull
    case legs
    case upper
    case lower
    case rest
    case custom

    var id: String { rawValue }
}

struct BodyOSProfile: Codable, Equatable {
    var mode: BodyOSUserMode
    var sex: BiologicalSex
    var age: Int
    var heightCentimeters: Double
    var weightKilograms: Double
    var targetWeightKilograms: Double
    var activityLevel: ActivityLevel
    var trainingExperience: TrainingExperience
    var languageRawValue: String
    var timezone: String

    init(
        mode: BodyOSUserMode,
        sex: BiologicalSex = .female,
        age: Int = 32,
        heightCentimeters: Double = 170,
        weightKilograms: Double = 68,
        targetWeightKilograms: Double = 62,
        activityLevel: ActivityLevel = .light,
        trainingExperience: TrainingExperience = .none,
        language: AppLanguage = .english,
        timezone: String = TimeZone.current.identifier
    ) {
        self.mode = mode
        self.sex = sex
        self.age = age
        self.heightCentimeters = heightCentimeters
        self.weightKilograms = weightKilograms
        self.targetWeightKilograms = targetWeightKilograms
        self.activityLevel = activityLevel
        self.trainingExperience = trainingExperience
        self.languageRawValue = language.rawValue
        self.timezone = timezone
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRawValue) ?? .english }
        set { languageRawValue = newValue.rawValue }
    }
}

struct BodyOSCycle: Codable, Equatable {
    var type: BodyOSCycleType
    var template: BodyOSTrainingTemplate
    var dayIndex: Int
    var focus: BodyOSWorkoutFocus
    var isPlannedTrainingDay: Bool

    init(
        type: BodyOSCycleType = .fatLoss,
        template: BodyOSTrainingTemplate = .threeOnOneOff,
        dayIndex: Int = 1,
        focus: BodyOSWorkoutFocus = .fullBody,
        isPlannedTrainingDay: Bool = true
    ) {
        self.type = type
        self.template = template
        self.dayIndex = dayIndex
        self.focus = focus
        self.isPlannedTrainingDay = isPlannedTrainingDay
    }
}

struct CycleInput: Equatable {
    var type: BodyOSCycleType
    var template: BodyOSTrainingTemplate
    var startDate: Date
    var currentDate: Date
    var customTrainingPattern: [BodyOSWorkoutFocus]
    var calendar: Calendar

    init(
        type: BodyOSCycleType = .fatLoss,
        template: BodyOSTrainingTemplate = .threeOnOneOff,
        startDate: Date,
        currentDate: Date = Date(),
        customTrainingPattern: [BodyOSWorkoutFocus] = [],
        calendar: Calendar = .current
    ) {
        self.type = type
        self.template = template
        self.startDate = startDate
        self.currentDate = currentDate
        self.customTrainingPattern = customTrainingPattern
        self.calendar = calendar
    }
}

enum BodyOSEventType: String, Codable, CaseIterable, Identifiable, Equatable {
    case injury
    case illness
    case businessTrip
    case travel
    case party
    case holiday
    case trainingStopped
    case highExpenditure
    case lowRecovery
    case highStress
    case sleepDebt

    var id: String { rawValue }
}

struct BodyOSEvent: Identifiable, Codable, Equatable {
    var id: UUID
    var type: BodyOSEventType
    var title: String
    var severity: Int
    var affectedBodyParts: [String]

    init(
        id: UUID = UUID(),
        type: BodyOSEventType,
        title: String = "",
        severity: Int = 1,
        affectedBodyParts: [String] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.severity = min(max(severity, 1), 5)
        self.affectedBodyParts = affectedBodyParts
    }
}

struct BodyOSStateInput: Equatable {
    var profile: BodyOSProfile
    var goalState: BodyOSGoalState
    var plannedTrainingState: BodyOSTrainingState
    var cycle: BodyOSCycle
    var recoveryScore: RecoveryScore?
    var events: [BodyOSEvent]

    init(
        profile: BodyOSProfile,
        goalState: BodyOSGoalState = .fatLoss,
        plannedTrainingState: BodyOSTrainingState = .normalTraining,
        cycle: BodyOSCycle = BodyOSCycle(),
        recoveryScore: RecoveryScore? = nil,
        events: [BodyOSEvent] = []
    ) {
        self.profile = profile
        self.goalState = goalState
        self.plannedTrainingState = plannedTrainingState
        self.cycle = cycle
        self.recoveryScore = recoveryScore
        self.events = events
    }
}

struct BodyState: Codable, Equatable {
    var goalState: BodyOSGoalState
    var trainingState: BodyOSTrainingState
    var lifeState: BodyOSLifeState
    var recoveryState: BodyOSRecoveryState
    var priority: Int
    var reasons: [String]

    var shouldOverridePlannedTraining: Bool {
        trainingState == .injured || trainingState == .stopped || recoveryState == .critical || lifeState == .illness
    }
}

struct RecoveryInput: Equatable {
    var sleepHours: Double?
    var hrv: Double?
    var restingHeartRate: Int?
    var waterCups: Int
    var fatigueRating: Int?

    init(
        sleepHours: Double? = nil,
        hrv: Double? = nil,
        restingHeartRate: Int? = nil,
        waterCups: Int = 0,
        fatigueRating: Int? = nil
    ) {
        self.sleepHours = sleepHours
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.waterCups = waterCups
        self.fatigueRating = fatigueRating
    }
}

struct RecoveryScore: Codable, Equatable {
    var value: Int
    var state: BodyOSRecoveryState
    var factors: [String]
}

struct NutritionInput: Equatable {
    var profile: BodyOSProfile
    var goalState: BodyOSGoalState
    var bodyState: BodyState
    var basalMetabolicRate: Int
    var activityCalories: Int
    var exerciseCalories: Int

    init(
        profile: BodyOSProfile,
        goalState: BodyOSGoalState = .fatLoss,
        bodyState: BodyState,
        basalMetabolicRate: Int,
        activityCalories: Int,
        exerciseCalories: Int
    ) {
        self.profile = profile
        self.goalState = goalState
        self.bodyState = bodyState
        self.basalMetabolicRate = basalMetabolicRate
        self.activityCalories = activityCalories
        self.exerciseCalories = exerciseCalories
    }
}

struct NutritionTarget: Codable, Equatable {
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var deficit: Int
    var tdee: Int
    var shouldHideMacroDetails: Bool
}

struct DailyNutritionSummary: Codable, Equatable {
    var caloriesIn: Int
    var protein: Int
    var carbs: Int
    var fat: Int

    static let empty = DailyNutritionSummary(caloriesIn: 0, protein: 0, carbs: 0, fat: 0)
}

enum StrategyType: String, Codable, CaseIterable, Identifiable, Equatable {
    case nutrition
    case training
    case recovery
    case supplement
    case habit

    var id: String { rawValue }
}

struct StrategyAction: Identifiable, Codable, Equatable {
    var id: UUID
    var code: String
    var label: String
    var reason: String

    init(id: UUID = UUID(), code: String, label: String, reason: String) {
        self.id = id
        self.code = code
        self.label = label
        self.reason = reason
    }
}

struct StrategyItem: Identifiable, Codable, Equatable {
    var id: UUID
    var type: StrategyType
    var priority: Int
    var title: String
    var actions: [StrategyAction]

    init(id: UUID = UUID(), type: StrategyType, priority: Int, title: String, actions: [StrategyAction]) {
        self.id = id
        self.type = type
        self.priority = priority
        self.title = title
        self.actions = actions
    }
}

struct StrategyInput: Equatable {
    var profile: BodyOSProfile
    var bodyState: BodyState
    var cycle: BodyOSCycle
    var nutritionTarget: NutritionTarget
    var dailySummary: DailyNutritionSummary
    var recoveryScore: RecoveryScore?
}

struct TodayStrategy: Codable, Equatable {
    var localDate: Date
    var items: [StrategyItem]
}

struct TodayStrategyExplanation: Equatable {
    var headline: String
    var primaryAction: String
    var supportingText: String
    var sourceStrategyType: StrategyType?
}

enum StrategyExplanationLayer {
    static func explain(
        strategy: TodayStrategy,
        bodyState: BodyState,
        nutritionTarget: NutritionTarget,
        dailySummary: DailyNutritionSummary,
        userMode: BodyOSUserMode,
        language: AppLanguage
    ) -> TodayStrategyExplanation {
        let primaryItem = strategy.items.first
        let primaryAction = primaryItem?.actions.first?.label ?? defaultAction(language: language)

        return TodayStrategyExplanation(
            headline: headline(
                for: primaryItem,
                bodyState: bodyState,
                userMode: userMode,
                language: language
            ),
            primaryAction: primaryAction,
            supportingText: supportingText(
                bodyState: bodyState,
                nutritionTarget: nutritionTarget,
                dailySummary: dailySummary,
                userMode: userMode,
                language: language
            ),
            sourceStrategyType: primaryItem?.type
        )
    }

    private static func headline(
        for item: StrategyItem?,
        bodyState: BodyState,
        userMode: BodyOSUserMode,
        language: AppLanguage
    ) -> String {
        if language == .simplifiedChinese {
            if bodyState.shouldOverridePlannedTraining {
                return "今天先照顾身体"
            }
            if bodyState.lifeState == .party {
                return "聚餐也不用慌"
            }
            if bodyState.lifeState == .travel || bodyState.lifeState == .businessTrip {
                return "路上简单记就好"
            }
            if bodyState.recoveryState == .low || bodyState.recoveryState == .critical {
                return "今天把节奏放慢"
            }
            if userMode == .advanced, item?.type == .nutrition {
                return "先把吃饭安排稳"
            }
            return item?.title ?? "今天做一件小事"
        }

        if bodyState.shouldOverridePlannedTraining {
            return "Take care of your body first"
        }
        if bodyState.lifeState == .party {
            return "Social meals can stay calm"
        }
        if bodyState.lifeState == .travel || bodyState.lifeState == .businessTrip {
            return "Keep logging simple on the road"
        }
        if bodyState.recoveryState == .low || bodyState.recoveryState == .critical {
            return "Slow the pace today"
        }
        if userMode == .advanced, item?.type == .nutrition {
            return "Keep food steady first"
        }
        return item?.title ?? "Do one small thing today"
    }

    private static func supportingText(
        bodyState: BodyState,
        nutritionTarget: NutritionTarget,
        dailySummary: DailyNutritionSummary,
        userMode: BodyOSUserMode,
        language: AppLanguage
    ) -> String {
        let remaining = nutritionTarget.calories - dailySummary.caloriesIn

        if language == .simplifiedChinese {
            if bodyState.shouldOverridePlannedTraining {
                return "训练和饮食都不用硬扛，先把今天过稳。"
            }
            if remaining < 0 {
                return "已经多吃了一点也没关系，下一餐清爽一点。"
            }
            if userMode == .advanced {
                return "目标和宏量已经算好，你只需要按下一步执行。"
            }
            return "不用算太细，照着下一步做就够。"
        }

        if bodyState.shouldOverridePlannedTraining {
            return "No need to push training or food today. Keep the day steady."
        }
        if remaining < 0 {
            return "A little over is okay. Keep the next meal simple."
        }
        if userMode == .advanced {
            return "Targets and macros are already calculated. Follow the next step."
        }
        return "No need to calculate. Just follow the next step."
    }

    private static func defaultAction(language: AppLanguage) -> String {
        language == .simplifiedChinese
            ? "先记录一件和身体有关的小事"
            : "Log one small body-related thing"
    }
}
