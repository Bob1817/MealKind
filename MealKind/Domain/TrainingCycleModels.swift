import Foundation

// MARK: - Enums

enum TrainingCycleGoal: String, Codable, CaseIterable, Identifiable, Equatable {
    case fatLoss
    case muscleGain

    var id: String { rawValue }

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .fatLoss: return "减脂"
            case .muscleGain: return "增肌"
            }
        }
        switch self {
        case .fatLoss: return "Fat Loss"
        case .muscleGain: return "Muscle Gain"
        }
    }
}

enum TrainingArrangement: String, Codable, CaseIterable, Identifiable, Equatable {
    case cyclic
    case weekly

    var id: String { rawValue }

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .cyclic: return "循环训练"
            case .weekly: return "按周训练"
            }
        }
        switch self {
        case .cyclic: return "Cyclic"
        case .weekly: return "Weekly"
        }
    }
}

enum TrainingBodyPart: String, Codable, CaseIterable, Identifiable, Equatable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case legs
    case glutes
    case core
    case cardio
    case fullBody

    var id: String { rawValue }

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .chest: return "胸"
            case .back: return "背"
            case .shoulders: return "肩"
            case .biceps: return "二头"
            case .triceps: return "三头"
            case .legs: return "腿"
            case .glutes: return "臀"
            case .core: return "核心"
            case .cardio: return "有氧"
            case .fullBody: return "全身"
            }
        }
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .legs: return "Legs"
        case .glutes: return "Glutes"
        case .core: return "Core"
        case .cardio: return "Cardio"
        case .fullBody: return "Full Body"
        }
    }

    var symbol: String {
        switch self {
        case .chest: return "figure.arms.open"
        case .back: return "figure.walk"
        case .shoulders: return "figure.strengthtraining.traditional"
        case .biceps: return "figure.curling"
        case .triceps: return "figure.roll"
        case .legs: return "figure.run"
        case .glutes: return "figure.walk"
        case .core: return "figure.core.training"
        case .cardio: return "figure.indoor.cycle"
        case .fullBody: return "figure.mixed.cardio"
        }
    }
}

enum CycleDietPlanType: String, Codable, CaseIterable, Identifiable, Equatable {
    case carbCycling
    case carbStepDown
    case intermittent16_8
    case keto
    case custom

    var id: String { rawValue }

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .carbCycling: return "碳循环"
            case .carbStepDown: return "碳水渐降"
            case .intermittent16_8: return "16+8 饮食"
            case .keto: return "生酮饮食"
            case .custom: return "自定义饮食"
            }
        }
        switch self {
        case .carbCycling: return "Carb Cycling"
        case .carbStepDown: return "Carb Step-down"
        case .intermittent16_8: return "16+8 Fasting"
        case .keto: return "Keto"
        case .custom: return "Custom"
        }
    }

    func localizedDescription(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .carbCycling: return "训练日高碳水，休息日低碳水，交替进行"
            case .carbStepDown: return "每周逐步减少碳水摄入，维持蛋白质不变"
            case .intermittent16_8: return "每天 16 小时禁食，8 小时进食窗口"
            case .keto: return "极低碳水（<50g/天），高脂肪，中等蛋白"
            case .custom: return "自行设置三大营养素的体重倍数"
            }
        }
        switch self {
        case .carbCycling: return "Higher carbs on training days, lower on rest days"
        case .carbStepDown: return "Gradual weekly carb reduction, protein stays constant"
        case .intermittent16_8: return "16-hour fast, 8-hour eating window daily"
        case .keto: return "Very low carb (<50g/day), high fat, moderate protein"
        case .custom: return "Set your own macro multipliers per kg bodyweight"
        }
    }
}

enum DurationUnit: String, Codable, CaseIterable, Identifiable, Equatable {
    case days
    case weeks
    case months

    var id: String { rawValue }

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .days: return "天"
            case .weeks: return "周"
            case .months: return "月"
            }
        }
        switch self {
        case .days: return "Days"
        case .weeks: return "Weeks"
        case .months: return "Months"
        }
    }
}

enum TrainingCycleStatus: String, Codable, CaseIterable, Identifiable, Equatable {
    case scheduled
    case active
    case completed
    case archived

    var id: String { rawValue }

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .scheduled: return "待开始"
            case .active: return "进行中"
            case .completed: return "已完成"
            case .archived: return "已归档"
            }
        }
        switch self {
        case .scheduled: return "Scheduled"
        case .active: return "Active"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }
}

// MARK: - Data Models

struct CycleDaySchedule: Identifiable, Codable, Equatable {
    var id = UUID()
    var dayIndex: Int
    var bodyParts: [TrainingBodyPart]
    var isRestDay: Bool

    init(dayIndex: Int, bodyParts: [TrainingBodyPart] = [], isRestDay: Bool = false) {
        self.dayIndex = dayIndex
        self.bodyParts = bodyParts
        self.isRestDay = isRestDay
    }

    func dayLabel(language: AppLanguage, arrangement: TrainingArrangement, weekdayOffset: Int = 0) -> String {
        if arrangement == .weekly {
            let weekdays: [AppLanguage: [String]] = [
                .simplifiedChinese: ["周一", "周二", "周三", "周四", "周五", "周六", "周日"],
                .english: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            ]
            let names = weekdays[language] ?? weekdays[.english]!
            return names[(dayIndex - 1 + weekdayOffset) % 7]
        }
        if language == .simplifiedChinese {
            return "第 \(dayIndex) 天"
        }
        return "Day \(dayIndex)"
    }
}

struct CycleSupplement: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var dosage: String
    var category: SupplementCategory
    var isSystemRecommended: Bool

    init(
        name: String,
        dosage: String = "",
        category: SupplementCategory = .custom,
        isSystemRecommended: Bool = false
    ) {
        self.name = name
        self.dosage = dosage
        self.category = category
        self.isSystemRecommended = isSystemRecommended
    }

    static func systemRecommended(language: AppLanguage) -> [CycleSupplement] {
        [
            CycleSupplement(name: SupplementCategory.creatine.localizedName(language: language), dosage: "5g", category: .creatine, isSystemRecommended: true),
            CycleSupplement(name: SupplementCategory.fishOil.localizedName(language: language), dosage: "2g", category: .fishOil, isSystemRecommended: true),
            CycleSupplement(name: SupplementCategory.vitaminD.localizedName(language: language), dosage: "2000IU", category: .vitaminD, isSystemRecommended: true),
            CycleSupplement(name: SupplementCategory.magnesium.localizedName(language: language), dosage: "400mg", category: .magnesium, isSystemRecommended: true),
            CycleSupplement(name: SupplementCategory.electrolyte.localizedName(language: language), dosage: "1 serving", category: .electrolyte, isSystemRecommended: true),
            CycleSupplement(name: SupplementCategory.multivitamin.localizedName(language: language), dosage: "1 tablet", category: .multivitamin, isSystemRecommended: true),
        ]
    }
}

struct MacroMultiplier: Equatable {
    var protein: Double
    var carbs: Double
    var fat: Double
}

// MARK: - Training Cycle

struct TrainingCycle: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var goal: TrainingCycleGoal
    var startDate: Date
    var durationValue: Int
    var durationUnit: DurationUnit
    var arrangement: TrainingArrangement
    var cycleDayCount: Int?
    var daySchedules: [CycleDaySchedule]
    var dietPlanType: CycleDietPlanType
    var customProteinMultiplier: Double?
    var customCarbMultiplier: Double?
    var customFatMultiplier: Double?
    var supplements: [CycleSupplement]
    var status: TrainingCycleStatus
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        goal: TrainingCycleGoal = .fatLoss,
        startDate: Date = Date(),
        durationValue: Int = 8,
        durationUnit: DurationUnit = .weeks,
        arrangement: TrainingArrangement = .cyclic,
        cycleDayCount: Int? = 4,
        daySchedules: [CycleDaySchedule] = [],
        dietPlanType: CycleDietPlanType = .carbCycling,
        customProteinMultiplier: Double? = nil,
        customCarbMultiplier: Double? = nil,
        customFatMultiplier: Double? = nil,
        supplements: [CycleSupplement] = [],
        status: TrainingCycleStatus = .scheduled,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.goal = goal
        self.startDate = startDate
        self.durationValue = durationValue
        self.durationUnit = durationUnit
        self.arrangement = arrangement
        self.cycleDayCount = cycleDayCount
        self.daySchedules = daySchedules
        self.dietPlanType = dietPlanType
        self.customProteinMultiplier = customProteinMultiplier
        self.customCarbMultiplier = customCarbMultiplier
        self.customFatMultiplier = customFatMultiplier
        self.supplements = supplements
        self.status = status
        self.createdAt = createdAt
    }

    var endDate: Date {
        let calendar = Calendar.current
        switch durationUnit {
        case .days:
            return calendar.date(byAdding: .day, value: durationValue, to: startDate) ?? startDate
        case .weeks:
            return calendar.date(byAdding: .weekOfYear, value: durationValue, to: startDate) ?? startDate
        case .months:
            return calendar.date(byAdding: .month, value: durationValue, to: startDate) ?? startDate
        }
    }

    var durationDays: Int {
        max(Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1, 1)
    }

    var dailySleepHours: Double { 8 }

    var isActive: Bool { status == .active }
    var isScheduled: Bool { status == .scheduled }
    var isArchived: Bool { status == .archived }

    var currentDayIndex: Int {
        let elapsed = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(elapsed, 0)
    }
}

// MARK: - Nutrition Calculator

enum CycleNutritionCalculator {

    struct MacroResult {
        let proteinMultiplier: Double
        let carbMultiplier: Double
        let fatMultiplier: Double
        let proteinGrams: Int
        let carbGrams: Int
        let fatGrams: Int
        let totalCalories: Int

        func formattedDescription(weightKg: Double, language: AppLanguage) -> [String] {
            let kg = String(format: "%.0f", weightKg)
            let proteinStr = String(format: "%.1f", proteinMultiplier)
            let carbStr = String(format: "%.1f", carbMultiplier)
            let fatStr = String(format: "%.1f", fatMultiplier)

            if language == .simplifiedChinese {
                return [
                    "蛋白质：体重 \(kg)kg \u{00D7} \(proteinStr) = \(proteinGrams)g",
                    "碳水：体重 \(kg)kg \u{00D7} \(carbStr) = \(carbGrams)g",
                    "脂肪：体重 \(kg)kg \u{00D7} \(fatStr) = \(fatGrams)g",
                    "总热量：约 \(totalCalories) kcal"
                ]
            }
            return [
                "Protein: \(kg)kg \u{00D7} \(proteinStr) = \(proteinGrams)g",
                "Carbs: \(kg)kg \u{00D7} \(carbStr) = \(carbGrams)g",
                "Fat: \(kg)kg \u{00D7} \(fatStr) = \(fatGrams)g",
                "Total: ~\(totalCalories) kcal"
            ]
        }
    }

    static func recommendedMacros(
        goal: TrainingCycleGoal,
        dietPlan: CycleDietPlanType,
        weightKg: Double,
        isTrainingDay: Bool = true
    ) -> MacroResult {
        let pm: Double
        let cm: Double
        let fm: Double

        switch goal {
        case .fatLoss:
            pm = 1.8
            fm = 0.9
            switch dietPlan {
            case .carbCycling:
                cm = isTrainingDay ? 3.0 : 1.5
            case .carbStepDown:
                cm = 2.5
            case .intermittent16_8:
                cm = 2.0
            case .keto:
                cm = 0.5
            case .custom:
                cm = 2.0
            }
        case .muscleGain:
            pm = 2.0
            fm = 1.1
            switch dietPlan {
            case .carbCycling:
                cm = isTrainingDay ? 5.0 : 3.5
            case .carbStepDown:
                cm = 4.5
            case .intermittent16_8:
                cm = 4.0
            case .keto:
                cm = 1.0
            case .custom:
                cm = 4.0
            }
        }

        let proteinG = Int((weightKg * pm).rounded())
        let carbG = Int((weightKg * cm).rounded())
        let fatG = Int((weightKg * fm).rounded())
        let totalCal = proteinG * 4 + carbG * 4 + fatG * 9

        return MacroResult(
            proteinMultiplier: pm,
            carbMultiplier: cm,
            fatMultiplier: fm,
            proteinGrams: proteinG,
            carbGrams: carbG,
            fatGrams: fatG,
            totalCalories: totalCal
        )
    }

    static func customMacros(
        weightKg: Double,
        proteinMultiplier: Double,
        carbMultiplier: Double,
        fatMultiplier: Double
    ) -> MacroResult {
        let proteinG = Int((weightKg * proteinMultiplier).rounded())
        let carbG = Int((weightKg * carbMultiplier).rounded())
        let fatG = Int((weightKg * fatMultiplier).rounded())
        let totalCal = proteinG * 4 + carbG * 4 + fatG * 9

        return MacroResult(
            proteinMultiplier: proteinMultiplier,
            carbMultiplier: carbMultiplier,
            fatMultiplier: fatMultiplier,
            proteinGrams: proteinG,
            carbGrams: carbG,
            fatGrams: fatG,
            totalCalories: totalCal
        )
    }
}
