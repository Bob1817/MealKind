import Foundation
import SwiftUI

enum AdvancedCycleKind: String, CaseIterable, Identifiable, Codable {
    case fatLoss
    case muscleGain
    case maintenance
    case recomposition
    case recovery
    case custom

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .fatLoss: return "减脂周期"
            case .muscleGain: return "增肌周期"
            case .maintenance: return "维持周期"
            case .recomposition: return "塑形周期"
            case .recovery: return "恢复周期"
            case .custom: return "自定义周期"
            }
        }

        switch self {
        case .fatLoss: return "Fat Loss"
        case .muscleGain: return "Muscle Gain"
        case .maintenance: return "Maintenance"
        case .recomposition: return "Recomposition"
        case .recovery: return "Recovery"
        case .custom: return "Custom Cycle"
        }
    }
}

enum AdvancedRiskLevel: String, Codable, CaseIterable, Identifiable {
    case low
    case moderate
    case high
    case critical

    var id: String { rawValue }

    var tint: Color {
        switch self {
        case .low: return MKColor.green
        case .moderate: return Color.blue
        case .high: return MKColor.citrus
        case .critical: return MKColor.coral
        }
    }

    func title(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .low: return "低风险"
            case .moderate: return "需观察"
            case .high: return "高风险"
            case .critical: return "关键风险"
            }
        }

        switch self {
        case .low: return "Low"
        case .moderate: return "Watch"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

enum AdvancedCycleStatus: String, Codable, CaseIterable, Identifiable {
    case notStarted
    case active
    case completed
    case abandoned

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .notStarted: return "未开始"
            case .active: return "进行中"
            case .completed: return "已完成"
            case .abandoned: return "已归档"
            }
        }

        switch self {
        case .notStarted: return "Not started"
        case .active: return "Active"
        case .completed: return "Completed"
        case .abandoned: return "Archived"
        }
    }
}

struct AdvancedBodyCycle: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var kind: AdvancedCycleKind
    var status: AdvancedCycleStatus
    var startDate: Date
    var endDate: Date
    var startWeightKg: Double
    var targetWeightKg: Double
    var currentWeightKg: Double
    var targetBodyFatPercent: Double?
    var startBodyFatPercentage: Double
    var currentBodyFatPercentage: Double
    var trainingStrategy: String
    var nutritionStrategy: String
    var supplementStrategy: String
    var recoveryStrategy: String

    var durationDays: Int {
        max(Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1, 1)
    }

    var elapsedDays: Int {
        min(max(Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0, 0), durationDays)
    }

    var progress: Double {
        min(max(Double(elapsedDays) / Double(durationDays), 0), 1)
    }

    var remainingDays: Int {
        max(durationDays - elapsedDays, 0)
    }

    var currentWeek: Int {
        min(max(elapsedDays / 7 + 1, 1), max(durationDays / 7, 1))
    }

    var weightProgress: Double {
        let total = targetWeightKg - startWeightKg
        guard abs(total) > 0.01 else { return 0 }
        return min(max((currentWeightKg - startWeightKg) / total, 0), 1)
    }
}

struct AdvancedTrainingPlan: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var weeklyFrequency: Int
    var deloadWeek: Int?
    var days: [AdvancedTrainingDay]
}

struct AdvancedTrainingDay: Identifiable, Codable, Equatable {
    var id = UUID()
    var weekday: Int
    var title: String
    var focus: String
    var exercises: [AdvancedExercise]
    var isRestDay: Bool
}

struct AdvancedExercise: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var sets: Int
    var reps: String
    var rpe: String
}

struct AdvancedNutritionPlan: Codable, Equatable {
    var strategy: String
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
}

struct AdvancedSupplementSchedule: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var dosage: String
    var timing: String
    var isTakenToday: Bool
    var inventoryDays: Int
}

struct AdvancedRecoverySnapshot: Codable, Equatable {
    var sleepHours: Double
    var hrv: Int
    var restingHeartRate: Int
    var fatigue: Int
    var trainingStress: Int
    var score: Int
}

struct AdvancedAIInsight: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var summary: String
    var evidence: [String]
    var riskLevel: AdvancedRiskLevel
}

struct AdvancedCycleRecord: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var kind: AdvancedCycleKind
    var status: AdvancedCycleStatus
    var startDate: Date
    var endDate: Date
    var completionRate: Double
    var executedDays: Int
    var keyResult: String
    var aiReview: String
    var trainingCount: Int? = nil
    var weightChangeKg: Double? = nil
    var bodyFatChangePercent: Double? = nil
    var score: Int {
        let baseScore = completionRate * 100
        let daysBonus = min(Double(executedDays) / 30.0, 1.0) * 10
        return min(Int(baseScore + daysBonus), 100)
    }
    var scoreLevel: String {
        if score >= 90 { return "perfect" }
        if score >= 80 { return "excellent" }
        if score >= 60 { return "qualified" }
        return "failed"
    }
    var isPerfect: Bool { score >= 90 }
}

struct AdvancedDailyCompletion: Identifiable, Codable, Equatable {
    var id = UUID()
    var dayLabel: String
    var nutrition: Double
    var training: Double
    var recovery: Double
    var supplement: Double
}

struct AdvancedCalendarDay: Identifiable, Codable, Equatable {
    var id: Date
    var date: Date
    var dayLabel: String
    var dayNumber: Int
    var dimensions: [Double]
}

struct AdvancedAchievement: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var detail: String
    var symbol: String
    var isUnlocked: Bool
    var progress: Double
}

struct AdvancedTrendPoint: Identifiable, Codable, Equatable {
    var id = UUID()
    var label: String
    var value: Double
}

enum AdvancedTrainingLogSource: String, Equatable {
    case manual
    case appleFitness
    case appleHealth

    func title(language: AppLanguage) -> String {
        switch self {
        case .manual:
            return language == .simplifiedChinese ? "手动录入" : "Manual"
        case .appleFitness:
            return "Apple Fitness"
        case .appleHealth:
            return "Apple Health"
        }
    }
}

enum AdvancedWorkoutType: String, CaseIterable, Identifiable, Equatable {
    case traditionalStrengthTraining
    case functionalStrengthTraining
    case running
    case walking
    case cycling
    case hiit
    case yoga
    case swimming
    case rowing
    case elliptical
    case stairStepper
    case pilates
    case coreTraining
    case flexibility
    case cooldown
    case other

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        let isChinese = language == .simplifiedChinese
        switch self {
        case .traditionalStrengthTraining: return isChinese ? "传统力量训练" : "Traditional Strength"
        case .functionalStrengthTraining: return isChinese ? "功能力量训练" : "Functional Strength"
        case .running: return isChinese ? "跑步" : "Running"
        case .walking: return isChinese ? "步行" : "Walking"
        case .cycling: return isChinese ? "骑行" : "Cycling"
        case .hiit: return "HIIT"
        case .yoga: return isChinese ? "瑜伽" : "Yoga"
        case .swimming: return isChinese ? "游泳" : "Swimming"
        case .rowing: return isChinese ? "划船" : "Rowing"
        case .elliptical: return isChinese ? "椭圆机" : "Elliptical"
        case .stairStepper: return isChinese ? "爬楼机" : "Stair Stepper"
        case .pilates: return isChinese ? "普拉提" : "Pilates"
        case .coreTraining: return isChinese ? "核心训练" : "Core Training"
        case .flexibility: return isChinese ? "柔韧训练" : "Flexibility"
        case .cooldown: return isChinese ? "整理放松" : "Cooldown"
        case .other: return isChinese ? "其他" : "Other"
        }
    }
}

struct AdvancedTrainingLog: Identifiable, Equatable {
    var id = UUID()
    var workoutType: AdvancedWorkoutType = .traditionalStrengthTraining
    var durationMinutes: Int = 0
    var caloriesBurned: Int = 0
    var recordedAt: Date = Date()
    var source: AdvancedTrainingLogSource = .manual

    var contentSummary: String {
        "\(durationMinutes) min · \(caloriesBurned) kcal"
    }
}

struct AdvancedSleepLog: Equatable {
    var bedTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    var wakeTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()

    init() {}

    init(hours: Double) {
        let resolvedHours = min(max(hours, 0), 14)
        let wake = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        let bed = Calendar.current.date(byAdding: .minute, value: -Int(resolvedHours * 60), to: wake) ?? wake
        self.bedTime = bed
        self.wakeTime = wake
    }

    var totalHours: Double {
        let cal = Calendar.current
        let bed = cal.dateComponents([.hour, .minute], from: bedTime)
        let wake = cal.dateComponents([.hour, .minute], from: wakeTime)
        let bedMin = (bed.hour ?? 0) * 60 + (bed.minute ?? 0)
        let wakeMin = (wake.hour ?? 0) * 60 + (wake.minute ?? 0)
        let diff = wakeMin >= bedMin ? wakeMin - bedMin : 1440 - bedMin + wakeMin
        return Double(diff) / 60.0
    }
}

struct AdvancedSupplementIntake: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var dosage: String
    var isTaken: Bool
    var recordedAt: Date = Date()
}

struct AdvancedModeSnapshot {
    var cycle: AdvancedBodyCycle
    var trainingPlan: AdvancedTrainingPlan
    var nutritionPlan: AdvancedNutritionPlan
    var supplements: [AdvancedSupplementSchedule]
    var recovery: AdvancedRecoverySnapshot
    var insights: [AdvancedAIInsight]
    var weightTrend: [AdvancedTrendPoint]
    var calorieTrend: [AdvancedTrendPoint]
    var proteinTrend: [AdvancedTrendPoint]
    var trainingTrend: [AdvancedTrendPoint]
    var recoveryTrend: [AdvancedTrendPoint]
    var currentCycleCompletions: [AdvancedDailyCompletion]
    var cycleHistory: [AdvancedCycleRecord]
    var achievements: [AdvancedAchievement]

    var currentCycleCalendarDays: [AdvancedCalendarDay] {
        let calendar = Calendar.current
        let duration = cycle.durationDays
        return (0..<duration).compactMap { offset -> AdvancedCalendarDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: cycle.startDate) else { return nil }
            let dims: [Double]
            if offset < currentCycleCompletions.count {
                let c = currentCycleCompletions[offset]
                dims = [c.nutrition, c.training, c.recovery, c.supplement]
            } else {
                dims = [0, 0, 0, 0]
            }
            return AdvancedCalendarDay(
                id: calendar.startOfDay(for: date),
                date: date,
                dayLabel: "D\(offset + 1)",
                dayNumber: calendar.component(.day, from: date),
                dimensions: dims
            )
        }
    }

    @MainActor
    static func make(from appState: AppState) -> AdvancedModeSnapshot {
        let calendar = Calendar.current
        let targetCalories = appState.bodyOSNutritionTarget.calories
        let targetMacros = appState.macroTarget
        let eaten = appState.eatenMacros
        let sleep = appState.latestSleepLog?.hoursSlept ?? 6.7
        let recoveryScore = appState.bodyOSRecoveryScore.value
        let language = appState.language
        let isChinese = language == .simplifiedChinese

        // ── 使用真实训练周期（如有） ──
        let activeCycle = appState.trainingCycles.first { $0.isActive || $0.isScheduled }

        let cycle: AdvancedBodyCycle
        let trainingPlan: AdvancedTrainingPlan
        let supplements: [AdvancedSupplementSchedule]
        let nutritionPlan: AdvancedNutritionPlan

        if let tc = activeCycle {
            // 转换目标
            let kind: AdvancedCycleKind = tc.goal == .fatLoss ? .fatLoss : .muscleGain
            let status: AdvancedCycleStatus = tc.isActive ? .active : .notStarted

            // 训练策略文字
            let arrangementLabel = tc.arrangement.localizedName(language: language)
            let dayCount = tc.daySchedules.filter({ !$0.isRestDay }).count
            let trainingStrategyStr = isChinese
                ? "\(arrangementLabel) / \(dayCount) 个训练日"
                : "\(arrangementLabel) / \(dayCount) training days"
            // 营养策略文字
            let nutritionStrategyStr = tc.dietPlanType.localizedName(language: language)
            // 补剂策略文字
            let suppNames = tc.supplements.prefix(3).map(\.name).joined(separator: " / ")
            let supplementStrategyStr = suppNames.isEmpty
                ? (isChinese ? "无补剂" : "No supplements")
                : suppNames
            // 恢复策略
            let recoveryStrategyStr = isChinese
                ? "睡眠 \(Int(tc.dailySleepHours))h"
                : "\(Int(tc.dailySleepHours))h sleep"

            // 目标体重估算
            let targetWeight: Double = {
                let profile = appState.activeProfile
                if profile.targetWeightKilograms > 0 { return profile.targetWeightKilograms }
                return tc.goal == .fatLoss
                    ? appState.weightKilograms * 0.95
                    : appState.weightKilograms * 1.05
            }()

            cycle = AdvancedBodyCycle(
                name: tc.title,
                kind: kind,
                status: status,
                startDate: tc.startDate,
                endDate: tc.endDate,
                startWeightKg: appState.weightKilograms,
                targetWeightKg: targetWeight,
                currentWeightKg: appState.weightKilograms,
                targetBodyFatPercent: appState.activeProfile.targetBodyFatPercentage,
                startBodyFatPercentage: appState.activeProfile.currentBodyFatPercentage ?? 0,
                currentBodyFatPercentage: appState.activeProfile.currentBodyFatPercentage ?? 0,
                trainingStrategy: trainingStrategyStr,
                nutritionStrategy: nutritionStrategyStr,
                supplementStrategy: supplementStrategyStr,
                recoveryStrategy: recoveryStrategyStr
            )

            // 训练计划
            let planDays: [AdvancedTrainingDay] = tc.daySchedules.enumerated().map { idx, ds in
                let bodyPartNames = ds.bodyParts.map { $0.localizedName(language: language) }
                let title: String
                if ds.isRestDay {
                    title = isChinese ? "休息" : "Rest"
                } else if bodyPartNames.isEmpty {
                    title = isChinese ? "训练日 \(ds.dayIndex)" : "Training Day \(ds.dayIndex)"
                } else {
                    title = bodyPartNames.joined(separator: " / ")
                }
                return AdvancedTrainingDay(
                    weekday: ds.dayIndex,
                    title: title,
                    focus: ds.isRestDay ? "Rest" : "Training",
                    exercises: [],
                    isRestDay: ds.isRestDay
                )
            }

            let nonRestDays = tc.daySchedules.filter { !$0.isRestDay }.count
            trainingPlan = AdvancedTrainingPlan(
                name: tc.title,
                weeklyFrequency: nonRestDays,
                deloadWeek: nil,
                days: planDays.isEmpty
                    ? [AdvancedTrainingDay(weekday: 1, title: isChinese ? "待配置" : "Not set", focus: "", exercises: [], isRestDay: false)]
                    : planDays
            )

            // 补剂
            supplements = tc.supplements.map { s in
                AdvancedSupplementSchedule(
                    name: s.name,
                    dosage: s.dosage.isEmpty ? "—" : s.dosage,
                    timing: isChinese ? "按需" : "As needed",
                    isTakenToday: appState.todaySupplementLogs.contains {
                        $0.name.localizedCaseInsensitiveContains(s.name)
                    },
                    inventoryDays: 30
                )
            }

            // 营养计划 —— 使用 CycleNutritionCalculator
            let macros = CycleNutritionCalculator.recommendedMacros(
                goal: tc.goal,
                dietPlan: tc.dietPlanType,
                weightKg: appState.weightKilograms
            )
            nutritionPlan = AdvancedNutritionPlan(
                strategy: nutritionStrategyStr,
                calories: macros.totalCalories,
                protein: macros.proteinGrams,
                carbs: macros.carbGrams,
                fat: macros.fatGrams
            )
        } else {
            // ── 无周期时回退到硬编码展示 ──
            let durationWeeks = max(appState.activeProfile.fatLossWeeks, 8)
            let startDate = calendar.date(byAdding: .day, value: -21, to: Date()) ?? Date()
            let endDate = calendar.date(byAdding: .weekOfYear, value: durationWeeks, to: startDate) ?? Date()
            let targetWeight = appState.activeProfile.targetWeightKilograms
            let startWeight = max(appState.weightKilograms + 2.1, appState.weightKilograms)

            cycle = AdvancedBodyCycle(
                name: isChinese ? "8 周减脂周期" : "8 Week Cut",
                kind: .fatLoss,
                status: .active,
                startDate: startDate,
                endDate: endDate,
                startWeightKg: startWeight,
                targetWeightKg: targetWeight,
                currentWeightKg: appState.weightKilograms,
                targetBodyFatPercent: appState.activeProfile.targetBodyFatPercentage,
                startBodyFatPercentage: appState.activeProfile.currentBodyFatPercentage ?? 0,
                currentBodyFatPercentage: appState.activeProfile.currentBodyFatPercentage ?? 0,
                trainingStrategy: isChinese ? "五分化训练 / Week 4 Deload" : "5-day split / Week 4 deload",
                nutritionStrategy: isChinese ? "高蛋白 + 碳循环" : "High protein + carb cycling",
                supplementStrategy: isChinese ? "肌酸 / 鱼油 / 电解质" : "Creatine / fish oil / electrolytes",
                recoveryStrategy: isChinese ? "睡眠 7.5h + HRV 监测" : "7.5h sleep + HRV monitoring"
            )

            trainingPlan = AdvancedTrainingPlan(
                name: isChinese ? "五分化训练" : "Five-Day Split",
                weeklyFrequency: 5,
                deloadWeek: 4,
                days: [
                    AdvancedTrainingDay(weekday: 1, title: isChinese ? "胸背" : "Chest / Back", focus: "Volume", exercises: [
                        AdvancedExercise(name: isChinese ? "卧推" : "Bench Press", sets: 4, reps: "6-8", rpe: "8"),
                        AdvancedExercise(name: isChinese ? "划船" : "Barbell Row", sets: 4, reps: "8-10", rpe: "8")
                    ], isRestDay: false),
                    AdvancedTrainingDay(weekday: 2, title: isChinese ? "肩手" : "Shoulders / Arms", focus: "Hypertrophy", exercises: [
                        AdvancedExercise(name: isChinese ? "推举" : "Overhead Press", sets: 3, reps: "6-8", rpe: "8"),
                        AdvancedExercise(name: isChinese ? "侧平举" : "Lateral Raise", sets: 4, reps: "12-15", rpe: "7")
                    ], isRestDay: false),
                    AdvancedTrainingDay(weekday: 3, title: isChinese ? "恢复" : "Recovery", focus: "Rest", exercises: [], isRestDay: true),
                    AdvancedTrainingDay(weekday: 4, title: isChinese ? "胸背" : "Chest / Back", focus: "Intensity", exercises: [
                        AdvancedExercise(name: isChinese ? "上斜卧推" : "Incline Press", sets: 4, reps: "8-10", rpe: "8"),
                        AdvancedExercise(name: isChinese ? "引体向上" : "Pull-up", sets: 4, reps: "AMRAP", rpe: "8")
                    ], isRestDay: false),
                    AdvancedTrainingDay(weekday: 5, title: isChinese ? "臀腿" : "Glutes / Legs", focus: "Strength", exercises: [
                        AdvancedExercise(name: isChinese ? "深蹲" : "Squat", sets: 4, reps: "5-6", rpe: "8"),
                        AdvancedExercise(name: isChinese ? "罗马尼亚硬拉" : "RDL", sets: 3, reps: "8-10", rpe: "8")
                    ], isRestDay: false)
                ]
            )

            supplements = [
                AdvancedSupplementSchedule(name: isChinese ? "肌酸" : "Creatine", dosage: "5g", timing: isChinese ? "训练后" : "Post-workout", isTakenToday: appState.todaySupplementLogs.contains { $0.name.localizedCaseInsensitiveContains("creatine") || $0.name.contains("肌酸") }, inventoryDays: 24),
                AdvancedSupplementSchedule(name: isChinese ? "鱼油" : "Fish Oil", dosage: "2g", timing: isChinese ? "早餐" : "Breakfast", isTakenToday: false, inventoryDays: 9),
                AdvancedSupplementSchedule(name: isChinese ? "电解质" : "Electrolytes", dosage: "1 serving", timing: isChinese ? "训练中" : "During training", isTakenToday: false, inventoryDays: 15)
            ]

            nutritionPlan = AdvancedNutritionPlan(
                strategy: cycle.nutritionStrategy,
                calories: targetCalories,
                protein: targetMacros.protein,
                carbs: targetMacros.carbs,
                fat: targetMacros.fat
            )
        }

        // ── 通用部分（与周期无关） ──
        let insights = [
            AdvancedAIInsight(
                title: isChinese ? "热量缺口偏高" : "Deficit running high",
                summary: isChinese ? "最近 14 天估算平均缺口约 920 kcal，建议回落至 650-750 kcal 区间。" : "Estimated 14-day average deficit is near 920 kcal. Consider moving back toward 650-750 kcal.",
                evidence: ["14d avg deficit: 920 kcal", "Protein: \(max(eaten.protein, 118))g", "Weight velocity: -0.9kg/wk"],
                riskLevel: .high
            ),
            AdvancedAIInsight(
                title: isChinese ? "蛋白质需要补足" : "Protein needs attention",
                summary: isChinese ? "今日蛋白质距离目标仍有明显缺口，晚餐建议优先补足 30-40g。" : "Protein is still behind target today. Prioritize 30-40g at dinner.",
                evidence: ["Remaining: \(max(targetMacros.protein - eaten.protein, 0))g", "Target: \(targetMacros.protein)g"],
                riskLevel: .moderate
            ),
            AdvancedAIInsight(
                title: isChinese ? "恢复状态可训练" : "Recovery supports training",
                summary: isChinese ? "恢复评分处于可训练区间，但建议把今日 RPE 上限控制在 8。" : "Readiness is trainable, but cap today's top sets around RPE 8.",
                evidence: ["Recovery score: \(recoveryScore)", "Sleep: \(String(format: "%.1f", sleep))h"],
                riskLevel: .low
            )
        ]

        let cycleHistory: [AdvancedCycleRecord] = {
            // 从 appState.trainingCycles 中提取已归档/已完成的周期
            let archived = appState.trainingCycles.filter { $0.isArchived || $0.status == .completed }
            if !archived.isEmpty {
                return archived.map { tc in
                    let kind: AdvancedCycleKind = tc.goal == .fatLoss ? .fatLoss : .muscleGain
                    let status: AdvancedCycleStatus = tc.status == .completed ? .completed : .abandoned
                    let workoutCount = appState.workouts.filter { workout in
                        workout.createdAt >= tc.startDate && workout.createdAt <= tc.endDate
                    }.count
                    let executedDays = min(tc.currentDayIndex, tc.durationDays)
                    return AdvancedCycleRecord(
                        name: tc.title,
                        kind: kind,
                        status: status,
                        startDate: tc.startDate,
                        endDate: tc.endDate,
                        completionRate: Double(tc.currentDayIndex) / Double(max(tc.durationDays, 1)),
                        executedDays: executedDays,
                        keyResult: isChinese ? "已执行 \(executedDays) 天，训练 \(workoutCount) 次" : "\(executedDays) days executed, \(workoutCount) workouts",
                        aiReview: isChinese ? "周期已归档。" : "Cycle archived.",
                        trainingCount: workoutCount
                    )
                }
            }
            return [
                AdvancedCycleRecord(
                    name: isChinese ? "基础减脂周期" : "Base Cut",
                    kind: .fatLoss,
                    status: .completed,
                    startDate: calendar.date(byAdding: .day, value: -96, to: Date()) ?? Date(),
                    endDate: calendar.date(byAdding: .day, value: -41, to: Date()) ?? Date(),
                    completionRate: 0.86,
                    executedDays: 56,
                    keyResult: isChinese ? "体重 -3.8kg，训练 23 次" : "-3.8kg, 23 workouts",
                    aiReview: isChinese ? "热量控制稳定，后半程恢复压力升高，下周期建议提前安排 Deload。" : "Calorie control was stable. Recovery pressure rose late; schedule deload earlier next cycle.",
                    trainingCount: 23,
                    weightChangeKg: -3.8
                ),
                AdvancedCycleRecord(
                    name: isChinese ? "夏季塑形周期" : "Summer Recomp",
                    kind: .recomposition,
                    status: .abandoned,
                    startDate: calendar.date(byAdding: .day, value: -35, to: Date()) ?? Date(),
                    endDate: calendar.date(byAdding: .day, value: -15, to: Date()) ?? Date(),
                    completionRate: 0.52,
                    executedDays: 20,
                    keyResult: isChinese ? "已执行 20 天，训练 8 次" : "20 days executed, 8 workouts",
                    aiReview: isChinese ? "周期已归档。饮食记录完整度较高，训练频率受日程影响，可作为下次计划参考。" : "Cycle archived. Nutrition logging was strong; training frequency was schedule-limited and useful for the next plan.",
                    trainingCount: 8
                )
            ]
        }()

        let achievements = [
            AdvancedAchievement(title: isChinese ? "周期执行者" : "Cycle Executor", detail: isChinese ? "创建并执行周期计划" : "Created and executed a cycle plan", symbol: "calendar.badge.checkmark", isUnlocked: activeCycle != nil, progress: activeCycle != nil ? 1 : 0),
            AdvancedAchievement(title: isChinese ? "减脂执行者" : "Cut Executor", detail: isChinese ? "完成第一个减脂周期" : "Completed the first fat-loss cycle", symbol: "chart.line.downtrend.xyaxis", isUnlocked: appState.trainingCycles.contains { $0.goal == .fatLoss && $0.status == .completed }, progress: appState.trainingCycles.contains { $0.goal == .fatLoss && $0.status == .completed } ? 1 : 0),
            AdvancedAchievement(title: isChinese ? "自律训练者" : "Consistent Trainer", detail: isChinese ? "累计训练 50 次" : "Complete 50 workouts", symbol: "figure.strengthtraining.traditional", isUnlocked: false, progress: 0.68),
            AdvancedAchievement(title: isChinese ? "稳定补剂者" : "Supplement Stable", detail: isChinese ? "补剂连续完成 30 天" : "Complete supplements for 30 days", symbol: "pills", isUnlocked: false, progress: 0.42),
            AdvancedAchievement(title: isChinese ? "恢复管理者" : "Recovery Manager", detail: isChinese ? "完成 Deload 周" : "Complete a deload week", symbol: "bed.double", isUnlocked: false, progress: 0.35)
        ]

        return AdvancedModeSnapshot(
            cycle: cycle,
            trainingPlan: trainingPlan,
            nutritionPlan: nutritionPlan,
            supplements: supplements,
            recovery: AdvancedRecoverySnapshot(
                sleepHours: sleep,
                hrv: 62,
                restingHeartRate: 58,
                fatigue: recoveryScore < 55 ? 7 : 4,
                trainingStress: appState.todayWorkouts.isEmpty ? 42 : 76,
                score: recoveryScore
            ),
            insights: insights,
            weightTrend: Self.points(base: appState.weightKilograms + 1.6, delta: -0.22, count: 8, suffix: "W"),
            calorieTrend: Self.points(base: Double(targetCalories + 180), delta: -28, count: 8, suffix: "D"),
            proteinTrend: Self.points(base: Double(max(targetMacros.protein - 28, 90)), delta: 4, count: 8, suffix: "D"),
            trainingTrend: Self.points(base: 42, delta: 6.5, count: 8, suffix: "W"),
            recoveryTrend: Self.points(base: Double(max(recoveryScore - 10, 45)), delta: 1.8, count: 8, suffix: "D"),
            currentCycleCompletions: [
                AdvancedDailyCompletion(dayLabel: "D1", nutrition: 0.92, training: 1.0, recovery: 0.80, supplement: 1.0),
                AdvancedDailyCompletion(dayLabel: "D2", nutrition: 0.86, training: 1.0, recovery: 0.72, supplement: 0.66),
                AdvancedDailyCompletion(dayLabel: "D3", nutrition: 0.78, training: 0.0, recovery: 0.88, supplement: 0.66),
                AdvancedDailyCompletion(dayLabel: "D4", nutrition: 0.94, training: 1.0, recovery: 0.70, supplement: 1.0),
                AdvancedDailyCompletion(dayLabel: "D5", nutrition: 0.83, training: 1.0, recovery: 0.68, supplement: 0.66)
            ],
            cycleHistory: cycleHistory,
            achievements: achievements
        )
    }

    private static func points(base: Double, delta: Double, count: Int, suffix: String) -> [AdvancedTrendPoint] {
        (0..<count).map { index in
            let wobble = index.isMultiple(of: 2) ? 0.8 : -0.5
            return AdvancedTrendPoint(label: "\(suffix)\(index + 1)", value: base + Double(index) * delta + wobble)
        }
    }
}
