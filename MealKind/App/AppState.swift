import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppState {
    var selectedPlan: DietPlan
    var profile: UserEnergyProfile
    var meals: [MealLog]
    var workouts: [WorkoutLog]
    var waterCups: Int
    var waterLogs: [WaterLog]
    var weightKilograms: Double
    // 普通版「活动」每日消耗能量目标（千卡）。
    var activityBurnGoal: Int = 300
    // 注册/建档日期，用于成长时间线起点。
    var registeredAt: Date = Date()
    var hasCompletedOnboarding: Bool
    var hasSelectedLanguage: Bool
    var language: AppLanguage
    var appearance: AppAppearance = .system
    var experienceMode: AppExperienceMode
    var fitnessIntent: FitnessIntent
    var habits: [Habit]
    var dailyTasks: [DailyTask]
    var latestCelebration: String?
    var accountMode: AccountMode
    var subscriptionTier: SubscriptionTier
    var sleepLogs: [SleepLog]
    var supplementLogs: [SupplementLog]
    var measurementLogs: [MeasurementLog]
    var persistedStrategy: TodayStrategy?
    var persistedWeeklyReview: WeeklyReview?
    var trainingCycles: [TrainingCycle] = []

    init(
        selectedPlan: DietPlan,
        profile: UserEnergyProfile,
        meals: [MealLog],
        workouts: [WorkoutLog] = [],
        waterCups: Int,
        waterLogs: [WaterLog] = [],
        weightKilograms: Double,
        hasCompletedOnboarding: Bool = false,
        hasSelectedLanguage: Bool = false,
        language: AppLanguage = .english,
        experienceMode: AppExperienceMode = .lifestyle,
        fitnessIntent: FitnessIntent = .fatLoss,
        habits: [Habit]? = nil,
        dailyTasks: [DailyTask]? = nil,
        latestCelebration: String? = nil,
        accountMode: AccountMode = .guest,
        subscriptionTier: SubscriptionTier = .free,
        sleepLogs: [SleepLog] = [],
        supplementLogs: [SupplementLog] = [],
        measurementLogs: [MeasurementLog] = [],
        persistedStrategy: TodayStrategy? = nil,
        persistedWeeklyReview: WeeklyReview? = nil
    ) {
        self.selectedPlan = selectedPlan
        self.profile = profile
        self.meals = meals
        self.workouts = workouts
        self.waterCups = waterCups
        self.waterLogs = waterLogs
        self.weightKilograms = weightKilograms
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hasSelectedLanguage = hasSelectedLanguage
        self.language = language
        self.experienceMode = experienceMode
        self.fitnessIntent = fitnessIntent
        let resolvedHabits = habits ?? Habit.defaults(language: language)
        self.habits = resolvedHabits
        self.dailyTasks = dailyTasks ?? DailyTask.defaults(from: resolvedHabits, language: language)
        self.latestCelebration = latestCelebration
        self.accountMode = accountMode
        self.subscriptionTier = subscriptionTier
        self.sleepLogs = sleepLogs
        self.supplementLogs = supplementLogs
        self.measurementLogs = measurementLogs
        self.persistedStrategy = persistedStrategy
        self.persistedWeeklyReview = persistedWeeklyReview
    }

    static let sample = AppState(
        selectedPlan: .lifestyleCut,
        profile: UserEnergyProfile(
            basalMetabolicRate: 1_520,
            activityCalories: 420,
            exerciseCalories: 180
        ),
        meals: [],
        workouts: [],
        waterCups: 0,
        waterLogs: [],
        weightKilograms: 68.4,
        hasCompletedOnboarding: false,
        hasSelectedLanguage: false,
        language: .english,
        experienceMode: .lifestyle,
        fitnessIntent: .fatLoss
    )

    var todayMeals: [MealLog] {
        meals.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    var activeHabits: [Habit] {
        habits.filter(\.isActive)
    }

    var todayTasks: [DailyTask] {
        Array(dailyTasks.prefix(3))
    }

    var completedTodayTaskCount: Int {
        todayTasks.filter { $0.status == .completed }.count
    }

    var todayCompletionText: String {
        "\(completedTodayTaskCount) / \(max(todayTasks.count, 1))"
    }

    var todayCompletionRate: Double {
        guard !todayTasks.isEmpty else { return 0 }
        return Double(completedTodayTaskCount) / Double(todayTasks.count)
    }

    var gentleTodayMessage: String {
        if language == .simplifiedChinese {
            if completedTodayTaskCount == 0 {
                return "今天先完成一个小动作。"
            }
            if completedTodayTaskCount < todayTasks.count {
                return "已经开始了，剩下的慢慢来。"
            }
            return "今天已经足够好了。"
        }

        if completedTodayTaskCount == 0 {
            return "Start with one small action today."
        }
        if completedTodayTaskCount < todayTasks.count {
            return "You have started. Keep the rest light."
        }
        return "This is enough for today."
    }

    var weeklyReview: WeeklyReview {
        if let persistedWeeklyReview, isPersistedReviewCurrent(persistedWeeklyReview) {
            return persistedWeeklyReview
        }
        return WeeklyReviewGenerator.make(
            tasks: dailyTasks,
            habits: habits,
            meals: meals,
            language: language
        )
    }

    var latestSleepLog: SleepLog? {
        sleepLogs
            .filter { Calendar.current.isDateInToday($0.createdAt) || isWithinLastNight($0.createdAt) }
            .max { $0.createdAt < $1.createdAt }
    }

    var todaySupplementLogs: [SupplementLog] {
        supplementLogs.filter { Calendar.current.isDateInToday($0.takenAt) }
    }

    var latestMeasurements: [MeasurementLog] {
        let grouped = Dictionary(grouping: measurementLogs, by: \.kind)
        return grouped.values.compactMap { $0.max { $0.takenAt < $1.takenAt } }
    }

    private func isWithinLastNight(_ date: Date) -> Bool {
        let cutoff = Calendar.current.date(byAdding: .hour, value: -18, to: Date()) ?? Date()
        return date >= cutoff
    }

    private func isPersistedReviewCurrent(_ review: WeeklyReview) -> Bool {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return Calendar.current.isDate(review.weekStartDate, inSameDayAs: weekStart)
    }

    var weekMeals: [MealLog] {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return meals.filter { $0.createdAt >= weekStart }
    }

    var eatenCalories: Int {
        todayMeals.map(\.calories).reduce(0, +)
    }

    var eatenMacros: MacroTarget {
        MacroTarget(
            protein: todayMeals.map(\.protein).reduce(0, +),
            carbs: todayMeals.map(\.carbs).reduce(0, +),
            fat: todayMeals.map(\.fat).reduce(0, +)
        )
    }

    var todayWorkouts: [WorkoutLog] {
        workouts.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    var loggedExerciseCalories: Int {
        todayWorkouts.map(\.calories).reduce(0, +)
    }

    var activeProfile: UserEnergyProfile {
        var copy = profile
        copy.exerciseCalories = profile.exerciseCalories + loggedExerciseCalories
        return copy
    }

    var budget: CalorieBudget {
        CalorieBudget(
            profile: activeProfile,
            plan: selectedPlan,
            eatenCalories: eatenCalories
        )
    }

    var macroTarget: MacroTarget {
        PlanEngine.macroTarget(
            plan: selectedPlan,
            profile: activeProfile,
            currentWeight: weightKilograms,
            dailyGoal: budget.dailyGoal,
            mode: experienceMode
        )
    }

    var macroProgress: MacroProgress {
        MacroProgress(eaten: eatenMacros, target: macroTarget)
    }

    var insightsSummary: InsightsSummary {
        InsightsSummary.make(
            meals: meals,
            profile: activeProfile,
            plan: selectedPlan,
            workouts: workouts,
            sleepLogs: sleepLogs,
            supplementLogs: supplementLogs,
            dailyTasks: dailyTasks
        )
    }

    var bodyOSProfile: BodyOSProfile {
        let resolvedActivityLevel: ActivityLevel = activeProfile.activityLevel == .light
            ? activeProfile.derivedActivityLevel
            : activeProfile.activityLevel
        return BodyOSProfile(
            mode: BodyOSUserMode(experienceMode: experienceMode),
            sex: activeProfile.biologicalSex,
            age: activeProfile.age,
            heightCentimeters: activeProfile.heightCentimeters,
            weightKilograms: weightKilograms,
            targetWeightKilograms: activeProfile.targetWeightKilograms,
            activityLevel: resolvedActivityLevel,
            trainingExperience: activeProfile.trainingExperience,
            language: language,
            timezone: TimeZone.current.identifier
        )
    }

    var bodyOSCycle: BodyOSCycle {
        let startDate = Calendar.current.date(byAdding: .day, value: -max(activeProfile.fatLossWeeks, 1) * 7 + 7, to: Date()) ?? Date()
        return CycleEngine().resolve(
            input: CycleInput(
                type: bodyOSGoalState == .muscleGain ? .muscleGain : .fatLoss,
                template: .threeOnOneOff,
                startDate: startDate,
                currentDate: Date()
            )
        )
    }

    var bodyOSRecoveryScore: RecoveryScore {
        let sleep = latestSleepLog
        var fatigue: Int? = todayWorkouts.count >= 2 ? 7 : nil
        if let quality = sleep?.quality, quality == .poor {
            fatigue = max(fatigue ?? 0, 8)
        }
        return RecoveryEngine().calculate(
            input: RecoveryInput(
                sleepHours: sleep?.hoursSlept,
                waterCups: waterCups,
                fatigueRating: fatigue
            )
        )
    }

    var bodyOSBodyState: BodyState {
        StateEngine().resolve(
            input: BodyOSStateInput(
                profile: bodyOSProfile,
                goalState: bodyOSGoalState,
                plannedTrainingState: bodyOSCycle.isPlannedTrainingDay ? .normalTraining : .restDay,
                cycle: bodyOSCycle,
                recoveryScore: bodyOSRecoveryScore,
                events: bodyOSEvents
            )
        )
    }

    var bodyOSNutritionTarget: NutritionTarget {
        NutritionEngine().calculateTarget(
            input: NutritionInput(
                profile: bodyOSProfile,
                goalState: bodyOSGoalState,
                bodyState: bodyOSBodyState,
                basalMetabolicRate: activeProfile.basalMetabolicRate,
                activityCalories: activeProfile.activityCalories,
                exerciseCalories: activeProfile.exerciseCalories
            )
        )
    }

    var bodyOSTodayStrategy: TodayStrategy {
        if let persistedStrategy, Calendar.current.isDateInToday(persistedStrategy.localDate) {
            return persistedStrategy
        }
        return regeneratedTodayStrategy()
    }

    var bodyOSStrategyExplanation: TodayStrategyExplanation {
        StrategyExplanationLayer.explain(
            strategy: bodyOSTodayStrategy,
            bodyState: bodyOSBodyState,
            nutritionTarget: bodyOSNutritionTarget,
            dailySummary: DailyNutritionSummary(
                caloriesIn: eatenCalories,
                protein: eatenMacros.protein,
                carbs: eatenMacros.carbs,
                fat: eatenMacros.fat
            ),
            userMode: bodyOSProfile.mode,
            language: language
        )
    }

    func regeneratedTodayStrategy() -> TodayStrategy {
        StrategyEngine().generate(
            input: StrategyInput(
                profile: bodyOSProfile,
                bodyState: bodyOSBodyState,
                cycle: bodyOSCycle,
                nutritionTarget: bodyOSNutritionTarget,
                dailySummary: DailyNutritionSummary(
                    caloriesIn: eatenCalories,
                    protein: eatenMacros.protein,
                    carbs: eatenMacros.carbs,
                    fat: eatenMacros.fat
                ),
                recoveryScore: bodyOSRecoveryScore
            ),
            localDate: Date()
        )
    }

    private var bodyOSGoalState: BodyOSGoalState {
        switch fitnessIntent {
        case .fatLoss:
            return .fatLoss
        case .fitness:
            return .muscleGain
        }
    }

    private var bodyOSEvents: [BodyOSEvent] {
        var events: [BodyOSEvent] = []
        if todayWorkouts.map(\.calories).reduce(0, +) >= 900 {
            events.append(BodyOSEvent(type: .highExpenditure, title: "High expenditure day"))
        }
        if waterCups <= 2 {
            events.append(BodyOSEvent(type: .lowRecovery, title: "Low hydration"))
        }
        if let sleep = latestSleepLog, sleep.hoursSlept > 0, sleep.hoursSlept < 5.5 {
            events.append(BodyOSEvent(type: .sleepDebt, title: "Sleep debt", severity: 2))
        }
        return events
    }

    func apply(
        settings: StoredUserSettings,
        records: [StoredMealRecord],
        workoutRecords: [StoredWorkoutRecord] = [],
        storedHabits: [StoredHabit] = [],
        storedTasks: [StoredDailyTask] = [],
        sleepRecords: [StoredSleepRecord] = [],
        waterRecords: [StoredWaterRecord] = [],
        supplementRecords: [StoredSupplementRecord] = [],
        measurementRecords: [StoredMeasurementRecord] = [],
        storedStrategies: [StoredDailyStrategy] = [],
        storedReviews: [StoredWeeklyReview] = [],
        storedCycles: [StoredTrainingCycle] = []
    ) {
        selectedPlan = settings.selectedPlan
        profile = settings.profile
        waterLogs = waterRecords
            .sorted { $0.loggedAt < $1.loggedAt }
            .map(\.waterLog)
        waterCups = Self.todayWaterCups(from: waterLogs)
        weightKilograms = settings.weightKilograms
        activityBurnGoal = settings.activityBurnGoal
        registeredAt = settings.registeredAt
        hasCompletedOnboarding = settings.hasCompletedOnboarding
        hasSelectedLanguage = settings.hasSelectedLanguage
        language = settings.language
        appearance = AppAppearance(rawValue: settings.appearanceRawValue) ?? .system
        experienceMode = settings.experienceMode
        fitnessIntent = settings.fitnessIntent
        accountMode = settings.accountMode
        subscriptionTier = settings.subscriptionTier
        meals = records
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.mealLog)
        workouts = workoutRecords
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.workoutLog)
        habits = storedHabits
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.habit)
        if habits.isEmpty {
            habits = Habit.defaults(language: language)
        }
        dailyTasks = storedTasks
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.dailyTask)
        if dailyTasks.isEmpty {
            dailyTasks = DailyTask.defaults(from: habits, language: language)
        }
        sleepLogs = sleepRecords
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.sleepLog)
        supplementLogs = supplementRecords
            .sorted { $0.takenAt < $1.takenAt }
            .map(\.supplementLog)
        measurementLogs = measurementRecords
            .sorted { $0.takenAt < $1.takenAt }
            .map(\.measurementLog)

        let todayLocalDate = LocalDateStamp.dateString(for: Date())
        persistedStrategy = storedStrategies
            .first(where: { $0.localDate == todayLocalDate })
            .flatMap(\.strategy)
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekStartLocal = LocalDateStamp.dateString(for: weekStart)
        persistedWeeklyReview = storedReviews
            .first(where: { $0.weekStartLocalDate == weekStartLocal })
            .flatMap(\.review)
        trainingCycles = storedCycles
            .sorted { $0.createdAt < $1.createdAt }
            .map(\.trainingCycle)
    }

    func persist(to settings: StoredUserSettings) {
        settings.selectedPlan = selectedPlan
        settings.profile = profile
        settings.waterCups = waterCups
        settings.weightKilograms = weightKilograms
        settings.activityBurnGoal = activityBurnGoal
        settings.hasCompletedOnboarding = hasCompletedOnboarding
        settings.hasSelectedLanguage = hasSelectedLanguage
        settings.language = language
        settings.appearanceRawValue = appearance.rawValue
        settings.experienceMode = experienceMode
        settings.fitnessIntent = fitnessIntent
        settings.accountMode = accountMode
        settings.subscriptionTier = subscriptionTier
    }

    func saveScannedMeal(
        result: FoodAnalysisResult? = nil,
        source: MealSource = .camera,
        imageData: Data? = nil,
        modelContext: ModelContext? = nil
    ) {
        let meal = MealLog(
            name: result?.mealName ?? L10n(language: language).t(.scannedMeal),
            calories: result?.estimatedCalories ?? 540,
            protein: result?.protein ?? 0,
            carbs: result?.carbs ?? 0,
            fat: result?.fat ?? 0,
            servingDescription: result?.servingDescription,
            createdAt: Date(),
            source: source,
            imageData: imageData
        )
        meals.append(meal)

        LocalRecordRepository.saveMeal(meal, to: modelContext)

        completeFirstPendingTask(ofType: .mealPhoto)
        if let celebration = result?.celebration {
            latestCelebration = celebration
        }
    }

    func saveManualMeal(_ meal: MealLog, modelContext: ModelContext? = nil) {
        meals.append(meal)

        LocalRecordRepository.saveMeal(meal, to: modelContext)
    }

    func deleteMeal(id: UUID, modelContext: ModelContext? = nil) {
        meals.removeAll { $0.id == id }
        guard let modelContext else { return }
        let storedMeals = (try? modelContext.fetch(FetchDescriptor<StoredMealRecord>())) ?? []
        storedMeals
            .filter { $0.id == id }
            .forEach { modelContext.delete($0) }
        try? modelContext.save()
    }

    func saveWorkout(_ workout: WorkoutLog, modelContext: ModelContext? = nil) {
        workouts.append(workout)

        LocalRecordRepository.saveWorkout(workout, to: modelContext)
    }

    func saveSleep(_ log: SleepLog, modelContext: ModelContext? = nil) {
        sleepLogs.append(log)
        LocalRecordRepository.saveSleep(log, to: modelContext)
    }

    func setActivityBurnGoal(_ goal: Int, modelContext: ModelContext? = nil) {
        activityBurnGoal = min(max(goal, 100), 1500)
        guard let modelContext else { return }
        let existing = (try? modelContext.fetch(FetchDescriptor<StoredUserSettings>())) ?? []
        let settings = LocalRecordRepository.settings(from: existing, modelContext: modelContext)
        settings.activityBurnGoal = activityBurnGoal
        try? modelContext.save()
    }

    func saveWaterChange(_ delta: Int, modelContext: ModelContext? = nil) {
        let resolvedDelta = delta < 0 && waterCups <= 0 ? 0 : delta
        guard resolvedDelta != 0 else { return }

        let log = WaterLog(cupDelta: resolvedDelta)
        waterLogs.append(log)
        waterCups = min(max(waterCups + resolvedDelta, 0), 20)
        LocalRecordRepository.saveWater(log, to: modelContext)
    }

    func deleteSleep(id: UUID, modelContext: ModelContext? = nil) {
        sleepLogs.removeAll { $0.id == id }
        guard let modelContext else { return }
        let storedSleep = (try? modelContext.fetch(FetchDescriptor<StoredSleepRecord>())) ?? []
        storedSleep
            .filter { $0.id == id }
            .forEach { modelContext.delete($0) }
        try? modelContext.save()
    }

    func deleteWater(id: UUID, modelContext: ModelContext? = nil) {
        waterLogs.removeAll { $0.id == id }
        waterCups = Self.todayWaterCups(from: waterLogs)
        guard let modelContext else { return }
        let storedWater = (try? modelContext.fetch(FetchDescriptor<StoredWaterRecord>())) ?? []
        storedWater
            .filter { $0.id == id }
            .forEach { modelContext.delete($0) }
        try? modelContext.save()
    }

    func saveSupplement(_ log: SupplementLog, modelContext: ModelContext? = nil) {
        supplementLogs.append(log)
        LocalRecordRepository.saveSupplement(log, to: modelContext)
    }

    func saveMeasurement(_ log: MeasurementLog, modelContext: ModelContext? = nil) {
        measurementLogs.append(log)
        LocalRecordRepository.saveMeasurement(log, to: modelContext)
    }

    /// 更新当前体重，并在体重变化时写入一条带时间戳的体重历史记录（供成长页使用）。
    func saveWeight(_ kilograms: Double, modelContext: ModelContext? = nil) {
        let changed = abs(kilograms - weightKilograms) > 0.001
        weightKilograms = kilograms

        guard let modelContext else { return }
        if changed {
            LocalRecordRepository.saveWeight(WeightLog(weightKilograms: kilograms), to: modelContext)
        }
        let existing = (try? modelContext.fetch(FetchDescriptor<StoredUserSettings>())) ?? []
        let settings = LocalRecordRepository.settings(from: existing, modelContext: modelContext)
        settings.weightKilograms = kilograms
        try? modelContext.save()
    }

    // MARK: - Training Cycles

    func saveTrainingCycle(_ cycle: TrainingCycle, modelContext: ModelContext?) {
        var newCycle = cycle
        if newCycle.startDate <= Date() {
            newCycle.status = .active
        }
        trainingCycles.append(newCycle)
        LocalRecordRepository.saveTrainingCycle(newCycle, to: modelContext)
    }

    func updateTrainingCycle(_ cycle: TrainingCycle, modelContext: ModelContext?) {
        var updatedCycle = cycle
        if updatedCycle.status != .archived && updatedCycle.status != .completed {
            updatedCycle.status = updatedCycle.startDate <= Date() ? .active : .scheduled
        }
        if let index = trainingCycles.firstIndex(where: { $0.id == updatedCycle.id }) {
            trainingCycles[index] = updatedCycle
        } else {
            trainingCycles.append(updatedCycle)
        }
        guard let modelContext else { return }
        let existing = (try? modelContext.fetch(FetchDescriptor<StoredTrainingCycle>())) ?? []
        LocalRecordRepository.updateTrainingCycle(updatedCycle, existing: existing, modelContext: modelContext)
    }

    func hasOverlappingCycle(for newCycle: TrainingCycle) -> TrainingCycle? {
        trainingCycles.first { existing in
            (existing.status == .active || existing.status == .scheduled)
            && newCycle.startDate < existing.endDate
            && newCycle.endDate > existing.startDate
        }
    }

    func archiveOverlappingCycles(for newCycle: TrainingCycle, modelContext: ModelContext?) {
        for i in trainingCycles.indices {
            if (trainingCycles[i].status == .active || trainingCycles[i].status == .scheduled)
                && newCycle.startDate < trainingCycles[i].endDate
                && newCycle.endDate > trainingCycles[i].startDate {
                trainingCycles[i].status = .archived
                guard let modelContext else { continue }
                let existing = (try? modelContext.fetch(FetchDescriptor<StoredTrainingCycle>())) ?? []
                LocalRecordRepository.updateTrainingCycleStatus(
                    id: trainingCycles[i].id,
                    status: .archived,
                    existing: existing,
                    modelContext: modelContext
                )
            }
        }
    }

    func foodAnalysisContext() -> BodyOSAnalysisContext {
        let state = bodyOSBodyState
        let target = bodyOSNutritionTarget
        let strategy = bodyOSTodayStrategy
        let recovery = bodyOSRecoveryScore
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        return BodyOSAnalysisContext(
            userMode: bodyOSProfile.mode.rawValue,
            goalState: state.goalState.rawValue,
            trainingState: state.trainingState.rawValue,
            lifeState: state.lifeState.rawValue,
            recoveryState: state.recoveryState.rawValue,
            recoveryScore: recovery.value,
            nutritionTarget: .init(
                calories: target.calories,
                protein: target.protein,
                carbs: target.carbs,
                fat: target.fat,
                deficit: target.deficit,
                tdee: target.tdee
            ),
            dailyConsumed: .init(
                calories: eatenCalories,
                protein: eatenMacros.protein,
                carbs: eatenMacros.carbs,
                fat: eatenMacros.fat
            ),
            todayStrategySummary: strategy.items.prefix(3).map { item in
                "\(item.type.rawValue): \(item.title)"
            },
            currentLocalTime: formatter.string(from: Date())
        )
    }

    func refreshPersistedStrategy(
        existing: [StoredDailyStrategy],
        modelContext: ModelContext?
    ) {
        let regenerated = regeneratedTodayStrategy()
        persistedStrategy = regenerated
        let localDate = LocalDateStamp.dateString(for: regenerated.localDate)
        LocalRecordRepository.upsertDailyStrategy(
            regenerated,
            localDate: localDate,
            existing: existing,
            modelContext: modelContext
        )
    }

    func refreshPersistedWeeklyReview(
        existing: [StoredWeeklyReview],
        modelContext: ModelContext?
    ) {
        let review = WeeklyReviewGenerator.make(
            tasks: dailyTasks,
            habits: habits,
            meals: meals,
            language: language
        )
        persistedWeeklyReview = review
        LocalRecordRepository.upsertWeeklyReview(
            review,
            existing: existing,
            modelContext: modelContext
        )
    }

    func finishOnboarding(settings: StoredUserSettings? = nil) {
        hasCompletedOnboarding = true
        if let settings {
            persist(to: settings)
        }
    }

    func setLanguage(_ language: AppLanguage, settings: StoredUserSettings? = nil) {
        self.language = language
        hasSelectedLanguage = true
        if let settings {
            persist(to: settings)
        }
    }

    func applyOnboardingProfile(
        profile: UserEnergyProfile,
        weightKilograms: Double,
        plan: DietPlan,
        mode: AppExperienceMode,
        intent: FitnessIntent,
        settings: StoredUserSettings? = nil
    ) {
        self.profile = profile
        self.weightKilograms = weightKilograms
        self.selectedPlan = plan
        self.experienceMode = mode
        self.fitnessIntent = intent
        self.hasCompletedOnboarding = true
        if let settings {
            persist(to: settings)
        }
    }

    func completeTask(id: UUID) {
        guard let index = dailyTasks.firstIndex(where: { $0.id == id }) else { return }
        guard dailyTasks[index].status != .completed else { return }

        dailyTasks[index].status = .completed
        dailyTasks[index].completedAt = Date()
        latestCelebration = celebration(for: dailyTasks[index])
    }

    func completeFirstPendingTask(ofType taskType: DailyTaskType) {
        guard let task = dailyTasks.first(where: { $0.taskType == taskType && $0.status == .pending }) else { return }
        completeTask(id: task.id)
    }

    func makeTaskEasier(id: UUID) {
        guard let index = dailyTasks.firstIndex(where: { $0.id == id }) else { return }
        dailyTasks[index].difficulty = max(1, dailyTasks[index].difficulty - 1)
        if language == .simplifiedChinese {
            dailyTasks[index].description = "只做最小一步：\(dailyTasks[index].description)"
            latestCelebration = "任务已经变简单了，今天只做一点就好。"
        } else {
            dailyTasks[index].description = "Do the smallest version: \(dailyTasks[index].description)"
            latestCelebration = "The task is easier now. One small step is enough."
        }
    }

    func resetDefaultHabitSystem() {
        habits = Habit.defaults(language: language)
        dailyTasks = DailyTask.defaults(from: habits, language: language)
        latestCelebration = nil
    }

    private func celebration(for task: DailyTask) -> String {
        if let habit = habits.first(where: { $0.id == task.habitId }) {
            return habit.celebration
        }
        return language == .simplifiedChinese ? "你完成了一个小动作。" : "You completed one small action."
    }

    private static func todayWaterCups(from records: [WaterLog]) -> Int {
        let calendar = Calendar.current
        let total = records
            .filter { calendar.isDateInToday($0.loggedAt) }
            .map(\.cupDelta)
            .reduce(0, +)
        return min(max(total, 0), 20)
    }
}
