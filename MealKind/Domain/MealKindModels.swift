import Foundation
import SwiftUI

enum DietPlan: String, CaseIterable, Identifiable {
    case lifestyleCut = "Lifestyle Cut"
    case carbStepDown = "531 Carb Step-down"
    case highProtein = "High Protein"

    var id: String { rawValue }

    var dailyDeficit: Int {
        switch self {
        case .lifestyleCut:
            450
        case .carbStepDown:
            520
        case .highProtein:
            400
        }
    }

    var simpleGuardrails: [String] {
        switch self {
        case .lifestyleCut:
            ["Prioritize protein", "Keep dinner light", "Save leftovers if full"]
        case .carbStepDown:
            ["Protein first", "Half rice at dinner", "Keep sauces light"]
        case .highProtein:
            ["Finish protein", "Add vegetables", "Keep snacks simple"]
        }
    }

    var nextMove: String {
        switch self {
        case .lifestyleCut:
            "Eat normally, just keep dinner light."
        case .carbStepDown:
            "Keep carbs lighter for your next meal."
        case .highProtein:
            "Build the next meal around protein."
        }
    }

    func localizedName(language: AppLanguage) -> String {
        let l10n = L10n(language: language)
        switch self {
        case .lifestyleCut:
            return l10n.t(.currentPlanLifestyleCut)
        case .carbStepDown:
            return l10n.t(.currentPlanCarbStepDown)
        case .highProtein:
            return l10n.t(.currentPlanHighProtein)
        }
    }

    func localizedGuardrails(language: AppLanguage) -> [String] {
        let l10n = L10n(language: language)
        switch self {
        case .lifestyleCut:
            return [
                l10n.t(.rulePrioritizeProtein),
                l10n.t(.ruleKeepDinnerLight),
                l10n.t(.ruleSaveLeftovers)
            ]
        case .carbStepDown:
            return [
                l10n.t(.ruleProteinFirst),
                l10n.t(.ruleHalfRiceDinner),
                l10n.t(.ruleKeepSaucesLight)
            ]
        case .highProtein:
            return [
                l10n.t(.ruleFinishProtein),
                l10n.t(.ruleAddVegetables),
                l10n.t(.ruleKeepSnacksSimple)
            ]
        }
    }

    func localizedNextMove(language: AppLanguage) -> String {
        let l10n = L10n(language: language)
        switch self {
        case .lifestyleCut:
            return l10n.t(.nextLifestyleCut)
        case .carbStepDown:
            return l10n.t(.nextCarbStepDown)
        case .highProtein:
            return l10n.t(.nextHighProtein)
        }
    }
}

struct UserEnergyProfile: Equatable {
    var basalMetabolicRate: Int
    var activityCalories: Int
    var exerciseCalories: Int
    var heightCentimeters: Double = 170
    var age: Int = 32
    var biologicalSex: BiologicalSex = .female
    var targetWeightKilograms: Double = 62
    var currentBodyFatPercentage: Double?
    var targetBodyFatPercentage: Double?
    var workEnvironment: WorkEnvironment = .office
    var hasExerciseHabit: Bool = true
    var weeklyWorkoutCount: Int = 3
    var restDayRawValue: Int = 7
    var fatLossWeeks: Int = 12
    var activityLevel: ActivityLevel = .light
    var trainingExperience: TrainingExperience = .none

    var derivedActivityLevel: ActivityLevel {
        let weeklyCount = hasExerciseHabit ? weeklyWorkoutCount : 0
        switch (workEnvironment.activityFactor, weeklyCount) {
        case let (factor, count) where factor >= 0.5 || count >= 5:
            return .active
        case let (factor, count) where factor >= 0.35 || count >= 3:
            return .moderate
        case let (factor, count) where factor >= 0.2 || count >= 1:
            return .light
        default:
            return .low
        }
    }
}

struct MealLog: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var calories: Int
    var protein: Int = 0
    var carbs: Int = 0
    var fat: Int = 0
    var servingDescription: String?
    var createdAt = Date()
    var source: MealSource = .manual
    var imageData: Data?
}

/// 一次体重记录，带录入时间，用于成长页的体重历史与 Before→Now。
struct WeightLog: Identifiable, Equatable {
    var id = UUID()
    var weightKilograms: Double
    var loggedAt = Date()
}

struct UserProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var gender: Gender?
    var birthYear: Int?
    var heightCm: Double?
    var currentWeightKg: Double?
    var targetWeightKg: Double?
    var activityLevel: ActivityLevel = .light
    var dietScenes: [DietScene] = []
    var failureScenes: [FailureScene] = []
    var preferences: DietPreferences = DietPreferences()
    var createdAt = Date()
    var updatedAt = Date()
}

enum Gender: String, Codable, CaseIterable, Identifiable {
    case female
    case male
    case other

    var id: String { rawValue }
}

enum AccountMode: String, Codable, CaseIterable, Identifiable {
    case guest
    case signedIn

    var id: String { rawValue }

    func localizedName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.guest, .simplifiedChinese):
            return "游客模式"
        case (.signedIn, .simplifiedChinese):
            return "已登录"
        case (.guest, _):
            return "Guest mode"
        case (.signedIn, _):
            return "Signed in"
        }
    }
}

enum SubscriptionTier: String, Codable, CaseIterable, Identifiable {
    case free
    case pro
    case proPlus

    var id: String { rawValue }

    func localizedName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.free, .simplifiedChinese):
            return "免费版"
        case (.pro, .simplifiedChinese):
            return "Pro 版"
        case (.proPlus, .simplifiedChinese):
            return "Pro Plus"
        case (.free, _):
            return "Free"
        case (.pro, _):
            return "Pro"
        case (.proPlus, _):
            return "Pro Plus"
        }
    }

    var isPro: Bool {
        self == .pro || self == .proPlus
    }

    var isProPlus: Bool {
        self == .proPlus
    }
}

enum ProPlusFeature: CaseIterable {
    case cycleManagement
    case recoveryAnalysis
    case sleepAnalysis
    case trainingSuggestions
    case nutritionSuggestions
    case supplementTracking
    case measurements

    func isUnlocked(for tier: SubscriptionTier) -> Bool {
        tier.isProPlus
    }

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .cycleManagement: return "周期管理"
            case .recoveryAnalysis: return "恢复分析"
            case .sleepAnalysis: return "睡眠分析"
            case .trainingSuggestions: return "AI 训练建议"
            case .nutritionSuggestions: return "AI 营养建议"
            case .supplementTracking: return "补剂打卡"
            case .measurements: return "围度与体脂"
            }
        }

        switch self {
        case .cycleManagement: return "Cycle management"
        case .recoveryAnalysis: return "Recovery analysis"
        case .sleepAnalysis: return "Sleep analysis"
        case .trainingSuggestions: return "AI training suggestions"
        case .nutritionSuggestions: return "AI nutrition suggestions"
        case .supplementTracking: return "Supplement tracking"
        case .measurements: return "Measurements"
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case low
    case light
    case moderate
    case active

    var id: String { rawValue }

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .low: return "低活动"
            case .light: return "轻度活动"
            case .moderate: return "中等活动"
            case .active: return "高活动"
            }
        }
        switch self {
        case .low: return "Low"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .active: return "Active"
        }
    }
}

enum TrainingExperience: String, Codable, CaseIterable, Identifiable {
    case none
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .none: return "无训练经验"
            case .beginner: return "入门（半年内）"
            case .intermediate: return "中级（半年到两年）"
            case .advanced: return "进阶（两年以上）"
            }
        }
        switch self {
        case .none: return "No experience"
        case .beginner: return "Beginner (<6 mo)"
        case .intermediate: return "Intermediate (6 mo–2 yr)"
        case .advanced: return "Advanced (>2 yr)"
        }
    }
}

enum DietScene: String, Codable, CaseIterable, Identifiable {
    case home
    case takeaway
    case diningOut
    case office

    var id: String { rawValue }
}

enum FailureScene: String, Codable, CaseIterable, Identifiable {
    case lateSnack
    case socialDinner
    case stressEating
    case skippedMeals

    var id: String { rawValue }
}

struct DietPreferences: Codable, Equatable {
    var avoidsSugaryDrinks = false
    var prefersSimpleMeals = true
    var reminderOptIn = true
}

struct Goal: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: GoalType = .fatLoss
    var targetWeightKg: Double?
    var targetDate: Date?
    var weeklyPace: WeeklyPace = .gentle
    var currentPhase: GoalPhase = .firstWeek
}

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case fatLoss
    case maintain
    case buildHabit

    var id: String { rawValue }
}

enum WeeklyPace: String, Codable, CaseIterable, Identifiable {
    case gentle
    case steady

    var id: String { rawValue }
}

enum GoalPhase: String, Codable, CaseIterable, Identifiable {
    case firstWeek
    case stabilizing
    case adjusting

    var id: String { rawValue }
}

struct Habit: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var anchor: String
    var tinyBehavior: String
    var celebration: String
    var difficulty: Int
    var frequency: HabitFrequency
    var isActive: Bool
    var createdAt = Date()

    static func defaults(language: AppLanguage) -> [Habit] {
        if language == .simplifiedChinese {
            return [
                Habit(title: "午餐前拍一下", anchor: "打开午餐或外卖包装后", tinyBehavior: "拍一张食物照片", celebration: "你完成了今天最关键的一步", difficulty: 1, frequency: .daily, isActive: true),
                Habit(title: "晚餐主食少一点", anchor: "准备开始吃晚餐时", tinyBehavior: "主食留三分之一", celebration: "这个调整已经足够温和", difficulty: 2, frequency: .daily, isActive: true),
                Habit(title: "睡前看一次总结", anchor: "准备洗漱或上床前", tinyBehavior: "看 30 秒今天完成了什么", celebration: "今天到这里就可以了", difficulty: 1, frequency: .daily, isActive: true)
            ]
        }

        return [
            Habit(title: "Snap lunch before eating", anchor: "After opening lunch or takeout", tinyBehavior: "Take one food photo", celebration: "You finished the most important small step today", difficulty: 1, frequency: .daily, isActive: true),
            Habit(title: "Leave a little dinner starch", anchor: "When dinner starts", tinyBehavior: "Leave one third of the starch", celebration: "That small adjustment is enough", difficulty: 2, frequency: .daily, isActive: true),
            Habit(title: "Read tonight's summary", anchor: "Before washing up or getting into bed", tinyBehavior: "Spend 30 seconds reviewing today", celebration: "This is enough for today", difficulty: 1, frequency: .daily, isActive: true)
        ]
    }
}

enum HabitFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekdays
    case weekly

    var id: String { rawValue }
}

struct DailyTask: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var description: String
    var habitId: UUID?
    var taskType: DailyTaskType
    var status: TaskStatus
    var scheduledTime: Date?
    var completedAt: Date?
    var difficulty: Int

    static func defaults(from habits: [Habit], language: AppLanguage) -> [DailyTask] {
        let activeHabits = Array(habits.filter(\.isActive).prefix(3))
        return activeHabits.map { habit in
            DailyTask(
                title: habit.title,
                description: habit.tinyBehavior,
                habitId: habit.id,
                taskType: taskType(for: habit.title),
                status: .pending,
                difficulty: habit.difficulty
            )
        }
    }

    private static func taskType(for title: String) -> DailyTaskType {
        if title.contains("午餐") || title.localizedCaseInsensitiveContains("lunch") {
            return .mealPhoto
        }
        if title.contains("睡前") || title.localizedCaseInsensitiveContains("summary") {
            return .review
        }
        return .portionAdjustment
    }
}

enum DailyTaskType: String, Codable, CaseIterable, Identifiable {
    case mealPhoto
    case portionAdjustment
    case review
    case weight

    var id: String { rawValue }
}

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case completed
    case skipped

    var id: String { rawValue }
}

struct WeeklyReview: Identifiable, Codable, Equatable {
    var id = UUID()
    var weekStartDate: Date
    var completedTaskCount: Int
    var taskCompletionRate: Double
    var strongestHabit: String?
    var biggestObstacle: String?
    var nextWeekFocus: String
    var aiSummary: String

    var difficultyAdjustment: WeeklyReviewDifficultyAdjustment {
        if completedTaskCount == 0 || taskCompletionRate < 0.34 {
            return .makeEasier
        }
        if let biggestObstacle,
           biggestObstacle.localizedCaseInsensitiveContains("too hard")
            || biggestObstacle.contains("太难") {
            return .makeEasier
        }
        return .keep
    }
}

enum WeeklyReviewDifficultyAdjustment: Equatable {
    case keep
    case makeEasier

    var rawValue: String {
        switch self {
        case .keep: return "keep"
        case .makeEasier: return "makeEasier"
        }
    }
}

struct WeeklyHabitProgress: Identifiable, Equatable {
    var id: UUID
    var title: String
    var completedCount: Int
    var plannedCount: Int
    var hasSkippedTask: Bool

    var completionRate: Double {
        guard plannedCount > 0 else { return 0 }
        return min(max(Double(completedCount) / Double(plannedCount), 0), 1)
    }
}

enum WeeklyReviewGenerator {
    static func make(
        tasks: [DailyTask],
        habits: [Habit],
        meals: [MealLog],
        language: AppLanguage,
        calendar: Calendar = .current,
        today: Date = Date()
    ) -> WeeklyReview {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let completedTasks = tasks.filter { task in
            guard task.status == .completed else { return false }
            guard let completedAt = task.completedAt else { return true }
            return completedAt >= weekStart && completedAt <= today
        }
        let activeTasks = tasks.filter { $0.status != .skipped || $0.completedAt.map { $0 >= weekStart } ?? true }
        let completionRate = activeTasks.isEmpty ? 0 : Double(completedTasks.count) / Double(activeTasks.count)
        let strongestHabit = strongestHabitTitle(from: completedTasks, habits: habits)
        let obstacle = biggestObstacle(from: tasks, meals: meals, language: language, calendar: calendar, weekStart: weekStart)
        let nextFocus = nextWeekFocus(strongestHabit: strongestHabit, language: language)

        return WeeklyReview(
            weekStartDate: weekStart,
            completedTaskCount: completedTasks.count,
            taskCompletionRate: min(max(completionRate, 0), 1),
            strongestHabit: strongestHabit,
            biggestObstacle: obstacle,
            nextWeekFocus: nextFocus,
            aiSummary: summary(completedCount: completedTasks.count, completionRate: completionRate, language: language)
        )
    }

    static func habitProgress(
        habits: [Habit],
        tasks: [DailyTask],
        calendar: Calendar = .current,
        today: Date = Date()
    ) -> [WeeklyHabitProgress] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today

        return habits
            .filter(\.isActive)
            .prefix(3)
            .map { habit in
                let habitTasks = tasks.filter { $0.habitId == habit.id }
                let completedCount = habitTasks.filter { task in
                    guard task.status == .completed else { return false }
                    guard let completedAt = task.completedAt else { return true }
                    return completedAt >= weekStart && completedAt <= today
                }.count
                let plannedCount = max(habitTasks.filter { task in
                    task.status != .skipped || (task.completedAt.map { $0 >= weekStart && $0 <= today } ?? false)
                }.count, 1)

                return WeeklyHabitProgress(
                    id: habit.id,
                    title: habit.title,
                    completedCount: completedCount,
                    plannedCount: plannedCount,
                    hasSkippedTask: habitTasks.contains { $0.status == .skipped }
                )
            }
    }

    private static func strongestHabitTitle(from tasks: [DailyTask], habits: [Habit]) -> String? {
        let counts = Dictionary(grouping: tasks.compactMap(\.habitId), by: { $0 })
            .mapValues(\.count)
        guard !counts.isEmpty else {
            return habits.first(where: \.isActive)?.title
        }
        return habits
            .filter(\.isActive)
            .max { left, right in
                let leftCount = counts[left.id, default: 0]
                let rightCount = counts[right.id, default: 0]
                if leftCount == rightCount {
                    guard let leftIndex = habits.firstIndex(where: { $0.id == left.id }),
                          let rightIndex = habits.firstIndex(where: { $0.id == right.id }) else {
                        return false
                    }
                    return leftIndex > rightIndex
                }
                return leftCount < rightCount
            }?
            .title
    }

    private static func biggestObstacle(
        from tasks: [DailyTask],
        meals: [MealLog],
        language: AppLanguage,
        calendar: Calendar,
        weekStart: Date
    ) -> String {
        if tasks.contains(where: { $0.status == .skipped }) {
            return language == .simplifiedChinese ? "有任务感觉太难" : "Some tasks felt too hard"
        }

        let lateMeals = meals.filter { meal in
            meal.createdAt >= weekStart && calendar.component(.hour, from: meal.createdAt) >= 21
        }
        if !lateMeals.isEmpty {
            return language == .simplifiedChinese ? "晚间加餐更容易发生" : "Late snacks showed up more often"
        }

        return language == .simplifiedChinese ? "还在观察最容易卡住的场景" : "Still learning the hardest scene"
    }

    private static func nextWeekFocus(strongestHabit: String?, language: AppLanguage) -> String {
        if let strongestHabit {
            return language == .simplifiedChinese
                ? "继续保留「\(strongestHabit)」，下周只额外关注一个小动作。"
                : "Keep “\(strongestHabit)” and add only one small focus next week."
        }

        return language == .simplifiedChinese
            ? "下周只保持一个动作：午餐前拍一下。"
            : "Next week, keep one action: snap lunch before eating."
    }

    private static func summary(completedCount: Int, completionRate: Double, language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            if completedCount == 0 {
                return "这周先不评价结果。我们只把任务降到更容易开始。"
            }
            if completionRate >= 0.67 {
                return "本周你完成了 \(completedCount) 次小任务。重点不是完美，而是已经有动作开始稳定出现。"
            }
            return "本周你完成了 \(completedCount) 次小任务。下周先减少难度，让动作更容易发生。"
        }

        if completedCount == 0 {
            return "No judgment this week. Start by making the task easier to begin."
        }
        if completionRate >= 0.67 {
            return "You completed \(completedCount) small tasks this week. The point is not perfection; the behavior is starting to show up."
        }
        return "You completed \(completedCount) small tasks this week. Next week, lower the difficulty so the behavior is easier to start."
    }
}

enum ReminderType: String, Codable, CaseIterable, Identifiable {
    case mealBefore
    case sleepBefore
    case lowActivity
    case weeklyReview
    case sceneBased

    var id: String { rawValue }
}

struct GentleReminder: Identifiable, Equatable {
    var id = UUID()
    var type: ReminderType
    var title: String
    var body: String
}

enum ReminderPlanner {
    static func defaults(language: AppLanguage) -> [GentleReminder] {
        if language == .simplifiedChinese {
            return [
                GentleReminder(type: .mealBefore, title: "午餐前拍一下就好", body: "只需要一张照片，不用计算。"),
                GentleReminder(type: .sleepBefore, title: "睡前 30 秒", body: "看一下今天完成了什么就好。"),
                GentleReminder(type: .weeklyReview, title: "本周温和复盘", body: "只看一个最稳定的习惯和下周一个重点。")
            ]
        }

        return [
            GentleReminder(type: .mealBefore, title: "Snap lunch first", body: "One photo is enough. No counting needed."),
            GentleReminder(type: .sleepBefore, title: "30 seconds before bed", body: "Just see what you completed today."),
            GentleReminder(type: .weeklyReview, title: "Gentle weekly review", body: "Look at one stable habit and one focus for next week.")
        ]
    }

    static func defaultDateComponents(for type: ReminderType) -> DateComponents {
        var components = DateComponents()

        switch type {
        case .mealBefore:
            components.hour = 11
            components.minute = 45
        case .sleepBefore:
            components.hour = 22
            components.minute = 15
        case .weeklyReview:
            components.weekday = 1
            components.hour = 20
            components.minute = 30
        case .lowActivity:
            components.hour = 18
            components.minute = 30
        case .sceneBased:
            components.hour = 17
            components.minute = 30
        }

        return components
    }
}

enum AICoachAdvisor {
    static func reply(to text: String, language: AppLanguage) -> String {
        let lower = text.lowercased()

        if language == .simplifiedChinese {
            if lower.contains("吃多") || lower.contains("没坚持") || lower.contains("超") || lower.contains("补救") {
                return "不用补偿，也不要跳过下一餐。下一餐只做一个小调整：蛋白质和蔬菜正常吃，主食少三分之一，饮料换无糖或少喝一点。"
            }
            if lower.contains("零食") || lower.contains("夜宵") {
                return "先喝一杯水，等 5 分钟。如果还想吃，选一小份明确的东西，坐下来吃，吃完就结束。"
            }
            if lower.contains("聚餐") || lower.contains("外卖") {
                return "先选一个最容易做到的规则：先吃蛋白质和蔬菜；主食不用禁，少一点就好；饮料优先无糖。"
            }
            if lower.contains("米饭") || lower.contains("主食") {
                return "可以吃主食。今天先不做极端限制，只把主食留三分之一，蛋白质和蔬菜正常吃。"
            }
            return "今天不追求完美，只选一个最小动作完成。"
        }

        if lower.contains("ate") || lower.contains("over") || lower.contains("fix") || lower.contains("failed") {
            return "No compensation and no skipped meals. Make one small adjustment next time: keep protein and vegetables normal, leave one third of the starch, and keep the drink unsweetened or smaller."
        }
        if lower.contains("snack") || lower.contains("night") {
            return "Drink water first and wait 5 minutes. If you still want it, choose one small clear portion, sit down, eat it, and stop there."
        }
        if lower.contains("social") || lower.contains("takeout") || lower.contains("restaurant") {
            return "Pick one easy rule: protein and vegetables first, do not ban starch, just keep it smaller, and choose an unsweetened drink."
        }
        if lower.contains("rice") || lower.contains("starch") || lower.contains("carb") {
            return "Yes, you can eat starch. Keep it gentle: leave about one third, and eat protein and vegetables normally."
        }
        return "Today only needs one small completed action."
    }
}

struct DataExportSnapshot: Codable, Equatable {
    var generatedAt: Date
    var currentWeightKg: Double
    var targetWeightKg: Double
    var habits: [ExportHabit]
    var tasks: [ExportTask]
    var meals: [ExportMeal]
    var weeklyReview: WeeklyReview
    var weeklyReviewDifficultyAdjustment: String
    var weeklyHabitProgress: [ExportHabitProgress]

    static func make(
        generatedAt: Date = Date(),
        currentWeightKg: Double,
        targetWeightKg: Double,
        habits: [Habit],
        tasks: [DailyTask],
        meals: [MealLog],
        weeklyReview: WeeklyReview
    ) -> DataExportSnapshot {
        DataExportSnapshot(
            generatedAt: generatedAt,
            currentWeightKg: currentWeightKg,
            targetWeightKg: targetWeightKg,
            habits: habits.map(ExportHabit.init),
            tasks: tasks.map(ExportTask.init),
            meals: meals.map(ExportMeal.init),
            weeklyReview: weeklyReview,
            weeklyReviewDifficultyAdjustment: weeklyReview.difficultyAdjustment.rawValue,
            weeklyHabitProgress: WeeklyReviewGenerator.habitProgress(
                habits: habits,
                tasks: tasks,
                today: generatedAt
            ).map(ExportHabitProgress.init)
        )
    }

    func jsonString() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    struct ExportHabit: Codable, Equatable {
        var title: String
        var anchor: String
        var tinyBehavior: String
        var difficulty: Int
        var isActive: Bool

        init(_ habit: Habit) {
            title = habit.title
            anchor = habit.anchor
            tinyBehavior = habit.tinyBehavior
            difficulty = habit.difficulty
            isActive = habit.isActive
        }
    }

    struct ExportTask: Codable, Equatable {
        var title: String
        var description: String
        var type: String
        var status: String
        var difficulty: Int
        var completedAt: Date?

        init(_ task: DailyTask) {
            title = task.title
            description = task.description
            type = task.taskType.rawValue
            status = task.status.rawValue
            difficulty = task.difficulty
            completedAt = task.completedAt
        }
    }

    struct ExportHabitProgress: Codable, Equatable {
        var title: String
        var completedCount: Int
        var plannedCount: Int
        var completionRate: Double
        var hasSkippedTask: Bool

        init(_ progress: WeeklyHabitProgress) {
            title = progress.title
            completedCount = progress.completedCount
            plannedCount = progress.plannedCount
            completionRate = progress.completionRate
            hasSkippedTask = progress.hasSkippedTask
        }
    }

    struct ExportMeal: Codable, Equatable {
        var name: String
        var calories: Int
        var protein: Int
        var carbs: Int
        var fat: Int
        var createdAt: Date
        var source: String

        init(_ meal: MealLog) {
            name = meal.name
            calories = meal.calories
            protein = meal.protein
            carbs = meal.carbs
            fat = meal.fat
            createdAt = meal.createdAt
            source = meal.source.rawValue
        }
    }
}

enum MealSource: String, Equatable {
    case manual
    case camera
    case photoLibrary
}

enum BiologicalSex: String, CaseIterable, Codable, Equatable {
    case female
    case male

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            return self == .female ? "女性" : "男性"
        }
        return self == .female ? "Female" : "Male"
    }
}

enum AppAppearance: String, CaseIterable, Identifiable, Equatable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    func localizedName(language: AppLanguage) -> String {
        switch self {
        case .system: return language == .simplifiedChinese ? "跟随系统" : "System"
        case .light: return language == .simplifiedChinese ? "浅色" : "Light"
        case .dark: return language == .simplifiedChinese ? "深色" : "Dark"
        }
    }

    /// 应用到 `.preferredColorScheme`；跟随系统时返回 nil。
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AppExperienceMode: String, CaseIterable, Identifiable, Equatable {
    case lifestyle
    case professional

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .lifestyle:
            return "person.fill"
        case .professional:
            return "chart.pie.fill"
        }
    }

    func localizedName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.lifestyle, .simplifiedChinese):
            return "普通版"
        case (.professional, .simplifiedChinese):
            return "专业版"
        case (.lifestyle, _):
            return "Standard"
        case (.professional, _):
            return "Pro"
        }
    }

    func localizedSubtitle(language: AppLanguage) -> String {
        switch (self, language) {
        case (.lifestyle, .simplifiedChinese):
            return "以热量差打卡和生活建议为核心"
        case (.professional, .simplifiedChinese):
            return "严格记录三大营养素、饮水和补剂"
        case (.lifestyle, _):
            return "Calorie-gap check-ins and simple daily guidance"
        case (.professional, _):
            return "Precise macros, water, and supplement tracking"
        }
    }
}

enum FitnessIntent: String, CaseIterable, Identifiable, Equatable {
    case fatLoss
    case fitness

    var id: String { rawValue }

    func localizedName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.fatLoss, .simplifiedChinese):
            return "减脂"
        case (.fitness, .simplifiedChinese):
            return "健身塑形"
        case (.fatLoss, _):
            return "Fat loss"
        case (.fitness, _):
            return "Fitness"
        }
    }
}

enum WorkEnvironment: String, CaseIterable, Identifiable, Equatable {
    case office
    case driver
    case retail
    case kitchen
    case construction
    case fieldWork

    var id: String { rawValue }

    var activityFactor: Double {
        switch self {
        case .office:
            return 0.22
        case .driver:
            return 0.18
        case .retail:
            return 0.34
        case .kitchen:
            return 0.42
        case .construction:
            return 0.58
        case .fieldWork:
            return 0.50
        }
    }

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .office:
                return "办公室久坐"
            case .driver:
                return "司机/长时间坐着"
            case .retail:
                return "门店/站立走动"
            case .kitchen:
                return "后厨/高频走动"
            case .construction:
                return "工地/重体力"
            case .fieldWork:
                return "户外/巡检跑动"
            }
        }

        switch self {
        case .office:
            return "Office"
        case .driver:
            return "Driver"
        case .retail:
            return "Retail"
        case .kitchen:
            return "Kitchen"
        case .construction:
            return "Construction"
        case .fieldWork:
            return "Field work"
        }
    }
}

enum WorkoutType: String, CaseIterable, Identifiable, Equatable {
    case walking
    case running
    case cycling
    case strength
    case yoga
    case swimming
    case other

    var id: String { rawValue }

    var met: Double {
        switch self {
        case .walking:
            3.5
        case .running:
            8.3
        case .cycling:
            7.0
        case .strength:
            5.0
        case .yoga:
            2.5
        case .swimming:
            7.0
        case .other:
            4.0
        }
    }

    func localizedName(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .walking:
                return "快走"
            case .running:
                return "跑步"
            case .cycling:
                return "骑行"
            case .strength:
                return "力量训练"
            case .yoga:
                return "瑜伽"
            case .swimming:
                return "游泳"
            case .other:
                return "其他运动"
            }
        }

        switch self {
        case .walking:
            return "Walking"
        case .running:
            return "Running"
        case .cycling:
            return "Cycling"
        case .strength:
            return "Strength"
        case .yoga:
            return "Yoga"
        case .swimming:
            return "Swimming"
        case .other:
            return "Other"
        }
    }
}

enum WorkoutSource: String, Equatable {
    case manual
    case screenshot
    case camera
}

struct WorkoutLog: Identifiable, Equatable {
    var id = UUID()
    var type: WorkoutType
    var durationMinutes: Int
    var averageHeartRate: Int?
    var calories: Int
    var note: String = ""
    var createdAt = Date()
    var source: WorkoutSource = .manual
    var imageData: Data?
}

enum EnergyCalculator {
    static func basalMetabolicRate(
        sex: BiologicalSex,
        weightKilograms: Double,
        heightCentimeters: Double,
        age: Int
    ) -> Int {
        let base = (10 * weightKilograms) + (6.25 * heightCentimeters) - (5 * Double(age))
        let adjusted = sex == .male ? base + 5 : base - 161
        return max(1_000, Int(adjusted.rounded()))
    }

    static func workoutCalories(
        type: WorkoutType,
        weightKilograms: Double,
        durationMinutes: Int,
        averageHeartRate: Int? = nil,
        age: Int = 32
    ) -> Int {
        let minutes = max(durationMinutes, 1)
        let metCalories = type.met * 3.5 * weightKilograms / 200 * Double(minutes)

        guard let averageHeartRate, averageHeartRate > 60 else {
            return max(1, Int(metCalories.rounded()))
        }

        let heartRateFactor = min(max(Double(averageHeartRate) / 130, 0.78), 1.32)
        let ageFactor = min(max(1 + (Double(age) - 35) / 220, 0.92), 1.12)
        return max(1, Int((metCalories * heartRateFactor * ageFactor).rounded()))
    }

    static func activityCalories(
        basalMetabolicRate: Int,
        workEnvironment: WorkEnvironment,
        hasExerciseHabit: Bool,
        weeklyWorkoutCount: Int
    ) -> Int {
        let habitBoost = hasExerciseHabit ? min(Double(max(weeklyWorkoutCount, 0)) * 0.018, 0.10) : 0
        return Int((Double(basalMetabolicRate) * (workEnvironment.activityFactor + habitBoost)).rounded())
    }

    static func plannedExerciseCalories(
        weightKilograms: Double,
        weeklyWorkoutCount: Int,
        hasExerciseHabit: Bool
    ) -> Int {
        guard hasExerciseHabit, weeklyWorkoutCount > 0 else { return 0 }
        let sessionCalories = workoutCalories(
            type: .strength,
            weightKilograms: weightKilograms,
            durationMinutes: 45
        )
        return Int((Double(sessionCalories * weeklyWorkoutCount) / 7.0).rounded())
    }
}

struct MacroTarget: Equatable {
    var protein: Int
    var carbs: Int
    var fat: Int
}

struct MacroProgress: Equatable {
    var eaten: MacroTarget
    var target: MacroTarget

    func progress(for macro: MacroKind) -> Double {
        let current = macro.value(in: eaten)
        let goal = max(macro.value(in: target), 1)
        return Double(current) / Double(goal)
    }

    func remainingText(for macro: MacroKind, language: AppLanguage) -> String {
        let current = macro.value(in: eaten)
        let goal = macro.value(in: target)
        let delta = goal - current
        if language == .simplifiedChinese {
            return delta >= 0 ? "还差 \(delta)g" : "超出 \(abs(delta))g"
        }
        return delta >= 0 ? "\(delta)g left" : "\(abs(delta))g over"
    }
}

enum MacroKind: String, CaseIterable, Identifiable {
    case protein
    case carbs
    case fat

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .protein:
            return MKColor.green
        case .carbs:
            return MKColor.sky
        case .fat:
            return MKColor.citrus
        }
    }

    func title(language: AppLanguage) -> String {
        let l10n = L10n(language: language)
        switch self {
        case .protein:
            return l10n.t(.protein)
        case .carbs:
            return l10n.t(.carbs)
        case .fat:
            return l10n.t(.fat)
        }
    }

    func value(in target: MacroTarget) -> Int {
        switch self {
        case .protein:
            return target.protein
        case .carbs:
            return target.carbs
        case .fat:
            return target.fat
        }
    }
}

struct PlanRecommendation: Identifiable, Equatable {
    var id: DietPlan { plan }
    var plan: DietPlan
    var difficulty: Int
    var dailyDeficit: Int
    var weeklyLossKilograms: Double
    var note: String
}

enum PlanEngine {
    static func recommendations(
        profile: UserEnergyProfile,
        currentWeight: Double,
        intent: FitnessIntent,
        language: AppLanguage
    ) -> [PlanRecommendation] {
        let loss = max(currentWeight - profile.targetWeightKilograms, 0.5)
        let weeklyNeeded = loss / Double(max(profile.fatLossWeeks, 1))

        return DietPlan.allCases.map { plan in
            let expectedWeekly = Double(plan.dailyDeficit * 7) / 7_700.0
            let gap = abs(expectedWeekly - weeklyNeeded)
            let environmentPenalty = profile.workEnvironment == .construction || profile.workEnvironment == .fieldWork ? -1 : 0
            let habitPenalty = profile.hasExerciseHabit ? -1 : 1
            let intentPenalty = intent == .fitness && plan == .carbStepDown ? 1 : 0
            let rawDifficulty = Int((gap * 6).rounded()) + habitPenalty + intentPenalty + environmentPenalty + 2
            let difficulty = min(max(rawDifficulty, 1), 5)
            let note: String
            if language == .simplifiedChinese {
                note = expectedWeekly >= weeklyNeeded
                    ? "速度匹配，执行压力较清晰"
                    : "更温和，可能需要更长时间"
            } else {
                note = expectedWeekly >= weeklyNeeded
                    ? "Matches the pace with clear structure"
                    : "Gentler, may need more time"
            }
            return PlanRecommendation(
                plan: plan,
                difficulty: difficulty,
                dailyDeficit: plan.dailyDeficit,
                weeklyLossKilograms: expectedWeekly,
                note: note
            )
        }
        .sorted { $0.difficulty < $1.difficulty }
    }

    static func macroTarget(
        plan: DietPlan,
        profile: UserEnergyProfile,
        currentWeight: Double,
        dailyGoal: Int,
        mode: AppExperienceMode
    ) -> MacroTarget {
        let proteinPerKg: Double
        let fatRatio: Double
        switch plan {
        case .lifestyleCut:
            proteinPerKg = mode == .professional ? 1.5 : 1.2
            fatRatio = 0.28
        case .carbStepDown:
            proteinPerKg = 1.7
            fatRatio = 0.32
        case .highProtein:
            proteinPerKg = 1.9
            fatRatio = 0.27
        }

        let protein = Int((currentWeight * proteinPerKg).rounded())
        let fat = Int((Double(dailyGoal) * fatRatio / 9.0).rounded())
        let usedCalories = protein * 4 + fat * 9
        let carbs = max(60, Int((Double(dailyGoal - usedCalories) / 4.0).rounded()))
        return MacroTarget(protein: protein, carbs: carbs, fat: fat)
    }
}

struct DayCheckIn: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var detail: String
    var symbol: String
}

struct FoodAnalysisResult: Identifiable, Equatable {
    let id = UUID()
    var mealName: String
    var estimatedCalories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var servingDescription: String?
    var confidence: AnalysisConfidence
    var decision: MealDecision
    var actions: [String]
    var summary: String?
    var plainAdvice: [String] = []
    var taskCompletionImpact: String?
    var celebration: String?
}

enum AnalysisConfidence: String, Equatable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

extension AnalysisConfidence {
    func localizedName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.low, .simplifiedChinese):
            return "低"
        case (.medium, .simplifiedChinese):
            return "中"
        case (.high, .simplifiedChinese):
            return "高"
        default:
            return rawValue
        }
    }
}

enum MealDecision: Equatable {
    case fits
    case adjust

    var title: String {
        switch self {
        case .fits:
            "This meal can fit."
        case .adjust:
            "This meal needs a small adjustment."
        }
    }

    var tintKind: DecisionTint {
        switch self {
        case .fits:
            .positive
        case .adjust:
            .attention
        }
    }
}

extension MealDecision {
    func localizedTitle(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .fits:
                return "这餐可以纳入计划。"
            case .adjust:
                return "这餐稍微调整一下更好。"
            }
        }

        return title
    }
}

enum DecisionTint {
    case positive
    case attention
}
