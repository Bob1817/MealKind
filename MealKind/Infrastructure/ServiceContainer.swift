import Foundation
import SwiftData
import SwiftUI
import UserNotifications

struct ServiceContainer {
    var analyzeMealImage: @MainActor (
        _ imageData: Data?,
        _ plan: DietPlan,
        _ remainingCalories: Int,
        _ language: AppLanguage,
        _ bodyOSContext: BodyOSAnalysisContext?
    ) async -> FoodAnalysisResult

    init(
        analyzeMealImage: @escaping @MainActor (
            _ imageData: Data?,
            _ plan: DietPlan,
            _ remainingCalories: Int,
            _ language: AppLanguage,
            _ bodyOSContext: BodyOSAnalysisContext?
        ) async -> FoodAnalysisResult
    ) {
        self.analyzeMealImage = analyzeMealImage
    }

    static let live = ServiceContainer { imageData, plan, remainingCalories, language, context in
        await ServerFoodAnalysisService().analyzeMealImage(
            imageData: imageData,
            plan: plan,
            remainingCalories: remainingCalories,
            language: language,
            bodyOSContext: context
        )
    }
}

private struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue = ServiceContainer.live
}

extension EnvironmentValues {
    var services: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

enum ReminderNotificationScheduler {
    static func requestPermissionAndSchedule(language: AppLanguage) async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return false }

            center.removePendingNotificationRequests(withIdentifiers: ReminderType.allCases.map(notificationIdentifier))
            try await scheduleDefaults(language: language, center: center)
            return true
        } catch {
            return false
        }
    }

    private static func scheduleDefaults(language: AppLanguage, center: UNUserNotificationCenter) async throws {
        let reminders = ReminderPlanner.defaults(language: language)
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: ReminderPlanner.defaultDateComponents(for: reminder.type),
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: notificationIdentifier(for: reminder.type),
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }
    }

    private static func notificationIdentifier(for type: ReminderType) -> String {
        "mealkind.reminder.\(type.rawValue)"
    }
}

enum LocalRecordRepository {
    @MainActor
    static func settings(from storedSettings: [StoredUserSettings], modelContext: ModelContext) -> StoredUserSettings {
        if let existing = storedSettings.first {
            return existing
        }
        let created = StoredUserSettings()
        modelContext.insert(created)
        return created
    }

    static func storedMeal(_ meal: MealLog, timeZone: TimeZone = .current) -> StoredMealRecord {
        StoredMealRecord(
            id: meal.id,
            name: meal.name,
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fat: meal.fat,
            servingDescription: meal.servingDescription,
            createdAt: meal.createdAt,
            source: meal.source,
            imageData: meal.imageData,
            timeZone: timeZone
        )
    }

    static func storedWorkout(_ workout: WorkoutLog, timeZone: TimeZone = .current) -> StoredWorkoutRecord {
        StoredWorkoutRecord(
            id: workout.id,
            type: workout.type,
            durationMinutes: workout.durationMinutes,
            averageHeartRate: workout.averageHeartRate,
            calories: workout.calories,
            note: workout.note,
            createdAt: workout.createdAt,
            source: workout.source,
            imageData: workout.imageData,
            timeZone: timeZone
        )
    }

    static func storedHabits(_ habits: [Habit]) -> [StoredHabit] {
        habits.map(StoredHabit.init)
    }

    static func storedTasks(_ tasks: [DailyTask]) -> [StoredDailyTask] {
        tasks.map(StoredDailyTask.init)
    }

    @MainActor
    static func seedHabitSystemIfNeeded(
        language: AppLanguage,
        storedHabits: [StoredHabit],
        storedTasks: [StoredDailyTask],
        modelContext: ModelContext
    ) {
        let resolvedHabits: [Habit]
        if storedHabits.isEmpty {
            resolvedHabits = Habit.defaults(language: language)
            Self.storedHabits(resolvedHabits).forEach { modelContext.insert($0) }
        } else {
            resolvedHabits = storedHabits.map(\.habit)
        }

        if storedTasks.isEmpty {
            let tasks = DailyTask.defaults(from: resolvedHabits, language: language)
            Self.storedTasks(tasks).forEach { modelContext.insert($0) }
        }
        try? modelContext.save()
    }

    @MainActor
    static func completeTask(id: UUID, in storedTasks: [StoredDailyTask], modelContext: ModelContext) {
        guard let storedTask = storedTasks.first(where: { $0.id == id }) else { return }
        let completedAt = Date()
        storedTask.status = .completed
        storedTask.completedAt = completedAt
        storedTask.localDate = LocalDateStamp.dateString(for: completedAt)
        storedTask.timezoneIdentifier = TimeZone.current.identifier
        try? modelContext.save()
    }

    @MainActor
    static func syncTask(_ task: DailyTask, in storedTasks: [StoredDailyTask], modelContext: ModelContext) {
        guard let storedTask = storedTasks.first(where: { $0.id == task.id }) else { return }
        storedTask.title = task.title
        storedTask.taskDescription = task.description
        storedTask.taskType = task.taskType
        storedTask.status = task.status
        storedTask.scheduledTime = task.scheduledTime
        storedTask.completedAt = task.completedAt
        storedTask.difficulty = task.difficulty
        storedTask.localDate = LocalDateStamp.dateString(for: task.scheduledTime ?? task.completedAt ?? storedTask.createdAt)
        storedTask.timezoneIdentifier = TimeZone.current.identifier
        try? modelContext.save()
    }

    @MainActor
    static func saveMeal(_ meal: MealLog, to modelContext: ModelContext?) {
        guard let modelContext else { return }
        modelContext.insert(storedMeal(meal))
    }

    @MainActor
    static func saveWorkout(_ workout: WorkoutLog, to modelContext: ModelContext?) {
        guard let modelContext else { return }
        modelContext.insert(storedWorkout(workout))
    }

    @MainActor
    static func saveSleep(_ log: SleepLog, to modelContext: ModelContext?) {
        guard let modelContext else { return }
        modelContext.insert(StoredSleepRecord(log))
        try? modelContext.save()
    }

    @MainActor
    static func saveWater(_ log: WaterLog, to modelContext: ModelContext?) {
        guard let modelContext else { return }
        modelContext.insert(StoredWaterRecord(log))
        try? modelContext.save()
    }

    @MainActor
    static func saveSupplement(_ log: SupplementLog, to modelContext: ModelContext?) {
        guard let modelContext else { return }
        modelContext.insert(StoredSupplementRecord(log))
        try? modelContext.save()
    }

    @MainActor
    static func saveMeasurement(_ log: MeasurementLog, to modelContext: ModelContext?) {
        guard let modelContext else { return }
        modelContext.insert(StoredMeasurementRecord(log))
        try? modelContext.save()
    }

    @MainActor
    static func saveWeight(_ log: WeightLog, to modelContext: ModelContext?) {
        guard let modelContext else { return }
        modelContext.insert(StoredWeightRecord(log))
        try? modelContext.save()
    }

    @MainActor
    static func saveTrainingCycle(_ cycle: TrainingCycle, to modelContext: ModelContext?) {
        guard let modelContext else { return }
        let stored = StoredTrainingCycle(
            id: cycle.id,
            title: cycle.title,
            goal: cycle.goal,
            startDate: cycle.startDate,
            durationValue: cycle.durationValue,
            durationUnit: cycle.durationUnit,
            arrangement: cycle.arrangement,
            cycleDayCount: cycle.cycleDayCount,
            daySchedules: cycle.daySchedules,
            dietPlanType: cycle.dietPlanType,
            customProteinMultiplier: cycle.customProteinMultiplier,
            customCarbMultiplier: cycle.customCarbMultiplier,
            customFatMultiplier: cycle.customFatMultiplier,
            supplements: cycle.supplements,
            status: cycle.status,
            createdAt: cycle.createdAt
        )
        modelContext.insert(stored)
        try? modelContext.save()
    }

    @MainActor
    static func updateTrainingCycle(_ cycle: TrainingCycle, existing: [StoredTrainingCycle], modelContext: ModelContext?) {
        guard let modelContext else { return }
        guard let stored = existing.first(where: { $0.id == cycle.id }) else {
            saveTrainingCycle(cycle, to: modelContext)
            return
        }
        stored.title = cycle.title
        stored.goal = cycle.goal
        stored.startDate = cycle.startDate
        stored.durationValue = cycle.durationValue
        stored.durationUnit = cycle.durationUnit
        stored.arrangement = cycle.arrangement
        stored.cycleDayCount = cycle.cycleDayCount
        stored.daySchedulesData = (try? JSONEncoder().encode(cycle.daySchedules)) ?? Data()
        stored.dietPlanType = cycle.dietPlanType
        stored.customProteinMultiplier = cycle.customProteinMultiplier
        stored.customCarbMultiplier = cycle.customCarbMultiplier
        stored.customFatMultiplier = cycle.customFatMultiplier
        stored.supplementsData = (try? JSONEncoder().encode(cycle.supplements)) ?? Data()
        stored.status = cycle.status
        stored.createdAt = cycle.createdAt
        try? modelContext.save()
    }

    @MainActor
    static func updateTrainingCycleStatus(
        id: UUID,
        status: TrainingCycleStatus,
        existing: [StoredTrainingCycle],
        modelContext: ModelContext?
    ) {
        guard let modelContext else { return }
        guard let stored = existing.first(where: { $0.id == id }) else { return }
        stored.statusRawValue = status.rawValue
        try? modelContext.save()
    }

    @MainActor
    static func upsertDailyStrategy(
        _ strategy: TodayStrategy,
        localDate: String,
        timeZone: TimeZone = .current,
        existing: [StoredDailyStrategy],
        modelContext: ModelContext?
    ) {
        guard let modelContext else { return }
        guard let payload = try? JSONEncoder().encode(strategy) else { return }

        if let match = existing.first(where: { $0.localDate == localDate }) {
            match.payload = payload
            match.generatedAt = Date()
            match.timezoneIdentifier = timeZone.identifier
        } else {
            let record = StoredDailyStrategy(
                localDate: localDate,
                timezoneIdentifier: timeZone.identifier,
                payload: payload
            )
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    @MainActor
    static func upsertWeeklyReview(
        _ review: WeeklyReview,
        timeZone: TimeZone = .current,
        existing: [StoredWeeklyReview],
        modelContext: ModelContext?
    ) {
        guard let modelContext else { return }
        guard let payload = try? JSONEncoder().encode(review) else { return }

        let weekStartLocal = LocalDateStamp.dateString(for: review.weekStartDate, timeZone: timeZone)
        if let match = existing.first(where: { $0.weekStartLocalDate == weekStartLocal }) {
            match.payload = payload
            match.generatedAt = Date()
            match.timezoneIdentifier = timeZone.identifier
        } else {
            let record = StoredWeeklyReview(
                weekStartLocalDate: weekStartLocal,
                timezoneIdentifier: timeZone.identifier,
                payload: payload
            )
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    @MainActor
    static func resetHabitSystem(
        language: AppLanguage,
        storedHabits: [StoredHabit],
        storedTasks: [StoredDailyTask],
        modelContext: ModelContext
    ) -> (habits: [Habit], tasks: [DailyTask]) {
        storedTasks.forEach { modelContext.delete($0) }
        storedHabits.forEach { modelContext.delete($0) }

        let habits = Habit.defaults(language: language)
        let tasks = DailyTask.defaults(from: habits, language: language)
        Self.storedHabits(habits).forEach { modelContext.insert($0) }
        Self.storedTasks(tasks).forEach { modelContext.insert($0) }
        try? modelContext.save()
        return (habits, tasks)
    }

    @MainActor
    static func deleteLocalRecords(
        storedMeals: [StoredMealRecord],
        storedWorkouts: [StoredWorkoutRecord],
        storedHabits: [StoredHabit],
        storedTasks: [StoredDailyTask],
        storedSleep: [StoredSleepRecord] = [],
        storedWater: [StoredWaterRecord] = [],
        storedWeight: [StoredWeightRecord] = [],
        storedSupplements: [StoredSupplementRecord] = [],
        storedMeasurements: [StoredMeasurementRecord] = [],
        storedStrategies: [StoredDailyStrategy] = [],
        storedReviews: [StoredWeeklyReview] = [],
        storedCycles: [StoredTrainingCycle] = [],
        modelContext: ModelContext
    ) {
        storedMeals.forEach { modelContext.delete($0) }
        storedWorkouts.forEach { modelContext.delete($0) }
        storedTasks.forEach { modelContext.delete($0) }
        storedHabits.forEach { modelContext.delete($0) }
        storedSleep.forEach { modelContext.delete($0) }
        storedWater.forEach { modelContext.delete($0) }
        storedWeight.forEach { modelContext.delete($0) }
        storedSupplements.forEach { modelContext.delete($0) }
        storedMeasurements.forEach { modelContext.delete($0) }
        storedStrategies.forEach { modelContext.delete($0) }
        storedReviews.forEach { modelContext.delete($0) }
        storedCycles.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }

    @MainActor
    static func applyRemoteExport(
        _ export: RemotePersistenceExport,
        settings: StoredUserSettings,
        storedHabits: [StoredHabit],
        storedTasks: [StoredDailyTask],
        storedMeals: [StoredMealRecord],
        storedWorkouts: [StoredWorkoutRecord],
        storedSleep: [StoredSleepRecord],
        storedWater: [StoredWaterRecord],
        storedWeight: [StoredWeightRecord],
        storedSupplements: [StoredSupplementRecord],
        storedMeasurements: [StoredMeasurementRecord],
        storedStrategies: [StoredDailyStrategy],
        storedReviews: [StoredWeeklyReview],
        storedCycles: [StoredTrainingCycle],
        modelContext: ModelContext
    ) {
        if let remoteSettings = export.records(for: "settings").first {
            applyRemoteSettings(remoteSettings.values, to: settings)
        }

        upsertRemoteHabits(export.records(for: "habits"), existing: storedHabits, modelContext: modelContext)
        upsertRemoteTasks(export.records(for: "dailyTasks"), existing: storedTasks, modelContext: modelContext)
        upsertRemoteMeals(export.records(for: "mealRecords"), existing: storedMeals, modelContext: modelContext)
        upsertRemoteWorkouts(export.records(for: "workoutRecords"), existing: storedWorkouts, modelContext: modelContext)
        upsertRemoteSleep(export.records(for: "sleepRecords"), existing: storedSleep, modelContext: modelContext)
        upsertRemoteWater(export.records(for: "waterRecords"), existing: storedWater, modelContext: modelContext)
        upsertRemoteWeight(export.records(for: "weightRecords"), existing: storedWeight, modelContext: modelContext)
        upsertRemoteSupplements(export.records(for: "supplementRecords"), existing: storedSupplements, modelContext: modelContext)
        upsertRemoteMeasurements(export.records(for: "measurementRecords"), existing: storedMeasurements, modelContext: modelContext)
        upsertRemoteStrategies(export.records(for: "dailyStrategies"), existing: storedStrategies, modelContext: modelContext)
        upsertRemoteReviews(export.records(for: "weeklyReviews"), existing: storedReviews, modelContext: modelContext)
        upsertRemoteCycles(export.records(for: "trainingCycles"), existing: storedCycles, modelContext: modelContext)
        try? modelContext.save()
    }

    private static func applyRemoteSettings(_ values: [String: RemoteJSONValue], to settings: StoredUserSettings) {
        settings.selectedPlanRawValue = values.string("selectedPlan") ?? settings.selectedPlanRawValue
        if let profile = values.object("profile") {
            settings.basalMetabolicRate = profile.int("basalMetabolicRate") ?? settings.basalMetabolicRate
            settings.activityCalories = profile.int("activityCalories") ?? settings.activityCalories
            settings.exerciseCalories = profile.int("exerciseCalories") ?? settings.exerciseCalories
            settings.heightCentimeters = profile.double("heightCentimeters") ?? settings.heightCentimeters
            settings.age = profile.int("age") ?? settings.age
            settings.biologicalSexRawValue = profile.string("biologicalSex") ?? settings.biologicalSexRawValue
            settings.targetWeightKilograms = profile.double("targetWeightKilograms") ?? settings.targetWeightKilograms
            settings.currentBodyFatPercentage = profile.double("currentBodyFatPercentage") ?? settings.currentBodyFatPercentage
            settings.targetBodyFatPercentage = profile.double("targetBodyFatPercentage") ?? settings.targetBodyFatPercentage
            settings.workEnvironmentRawValue = profile.string("workEnvironment") ?? settings.workEnvironmentRawValue
            settings.hasExerciseHabit = profile.bool("hasExerciseHabit") ?? settings.hasExerciseHabit
            settings.weeklyWorkoutCount = profile.int("weeklyWorkoutCount") ?? settings.weeklyWorkoutCount
            settings.restDayRawValue = profile.int("restDayRawValue") ?? settings.restDayRawValue
            settings.fatLossWeeks = profile.int("fatLossWeeks") ?? settings.fatLossWeeks
            settings.activityLevelRawValue = profile.string("activityLevel") ?? settings.activityLevelRawValue
            settings.trainingExperienceRawValue = profile.string("trainingExperience") ?? settings.trainingExperienceRawValue
        }
        settings.waterCups = values.int("waterCups") ?? settings.waterCups
        settings.weightKilograms = values.double("weightKilograms") ?? settings.weightKilograms
        settings.activityBurnGoal = values.int("activityBurnGoal") ?? settings.activityBurnGoal
        settings.hasCompletedOnboarding = values.bool("hasCompletedOnboarding") ?? settings.hasCompletedOnboarding
        settings.hasSelectedLanguage = values.bool("hasSelectedLanguage") ?? settings.hasSelectedLanguage
        settings.registeredAt = values.date("registeredAt") ?? settings.registeredAt
        settings.languageRawValue = values.string("language") ?? settings.languageRawValue
        settings.appearanceRawValue = values.string("appearance") ?? settings.appearanceRawValue
        settings.accountModeRawValue = values.string("accountMode") ?? settings.accountModeRawValue
        settings.subscriptionTierRawValue = values.string("subscriptionTier") ?? settings.subscriptionTierRawValue
    }

    private static func upsertRemoteHabits(_ records: [RemotePayload], existing: [StoredHabit], modelContext: ModelContext) {
        for values in records.map(\.values) {
            guard let id = values.uuid("id") else { continue }
            let target = existing.first(where: { $0.id == id }) ?? {
                let created = StoredHabit(
                    id: id,
                    title: values.string("title") ?? "",
                    anchor: values.string("anchor") ?? "",
                    tinyBehavior: values.string("tinyBehavior") ?? "",
                    celebration: values.string("celebration") ?? "",
                    difficulty: values.int("difficulty") ?? 1,
                    frequency: HabitFrequency(rawValue: values.string("frequency") ?? "") ?? .daily,
                    isActive: values.bool("isActive") ?? true,
                    createdAt: values.date("createdAt") ?? Date()
                )
                modelContext.insert(created)
                return created
            }()
            target.title = values.string("title") ?? target.title
            target.anchor = values.string("anchor") ?? target.anchor
            target.tinyBehavior = values.string("tinyBehavior") ?? target.tinyBehavior
            target.celebration = values.string("celebration") ?? target.celebration
            target.difficulty = values.int("difficulty") ?? target.difficulty
            target.frequencyRawValue = values.string("frequency") ?? target.frequencyRawValue
            target.isActive = values.bool("isActive") ?? target.isActive
            target.createdAt = values.date("createdAt") ?? target.createdAt
        }
    }

    private static func upsertRemoteTasks(_ records: [RemotePayload], existing: [StoredDailyTask], modelContext: ModelContext) {
        for values in records.map(\.values) {
            guard let id = values.uuid("id") else { continue }
            let target = existing.first(where: { $0.id == id }) ?? {
                let created = StoredDailyTask(
                    id: id,
                    title: values.string("title") ?? "",
                    description: values.string("description") ?? "",
                    habitId: values.uuid("habitId"),
                    taskType: DailyTaskType(rawValue: values.string("taskType") ?? "") ?? .mealPhoto,
                    status: TaskStatus(rawValue: values.string("status") ?? "") ?? .pending,
                    scheduledTime: values.date("scheduledTime"),
                    completedAt: values.date("completedAt"),
                    difficulty: values.int("difficulty") ?? 1,
                    createdAt: values.date("createdAt") ?? Date()
                )
                modelContext.insert(created)
                return created
            }()
            target.title = values.string("title") ?? target.title
            target.taskDescription = values.string("description") ?? target.taskDescription
            target.habitId = values.uuid("habitId") ?? target.habitId
            target.taskTypeRawValue = values.string("taskType") ?? target.taskTypeRawValue
            target.statusRawValue = values.string("status") ?? target.statusRawValue
            target.scheduledTime = values.date("scheduledTime") ?? target.scheduledTime
            target.completedAt = values.date("completedAt") ?? target.completedAt
            target.difficulty = values.int("difficulty") ?? target.difficulty
            target.createdAt = values.date("createdAt") ?? target.createdAt
            target.localDate = values.string("localDate") ?? target.localDate
            target.timezoneIdentifier = values.string("timezoneIdentifier") ?? target.timezoneIdentifier
        }
    }

    private static func upsertRemoteMeals(_ records: [RemotePayload], existing: [StoredMealRecord], modelContext: ModelContext) {
        for values in records.map(\.values) {
            guard let id = values.uuid("id") else { continue }
            let source = MealSource(rawValue: values.string("source") ?? "") ?? .manual
            let target = existing.first(where: { $0.id == id }) ?? {
                let created = StoredMealRecord(
                    id: id,
                    name: values.string("name") ?? "",
                    calories: values.int("calories") ?? 0,
                    protein: values.int("protein") ?? 0,
                    carbs: values.int("carbs") ?? 0,
                    fat: values.int("fat") ?? 0,
                    servingDescription: values.string("servingDescription"),
                    createdAt: values.date("createdAt") ?? Date(),
                    source: source,
                    imageData: values.data("imageBase64")
                )
                modelContext.insert(created)
                return created
            }()
            target.name = values.string("name") ?? target.name
            target.calories = values.int("calories") ?? target.calories
            target.protein = values.int("protein") ?? target.protein
            target.carbs = values.int("carbs") ?? target.carbs
            target.fat = values.int("fat") ?? target.fat
            target.servingDescription = values.string("servingDescription") ?? target.servingDescription
            target.createdAt = values.date("createdAt") ?? target.createdAt
            target.sourceRawValue = values.string("source") ?? target.sourceRawValue
            target.localDate = values.string("localDate") ?? target.localDate
            target.timezoneIdentifier = values.string("timezoneIdentifier") ?? target.timezoneIdentifier
            target.imageData = values.data("imageBase64") ?? target.imageData
        }
    }

    private static func upsertRemoteWorkouts(_ records: [RemotePayload], existing: [StoredWorkoutRecord], modelContext: ModelContext) {
        for values in records.map(\.values) {
            guard let id = values.uuid("id") else { continue }
            let target = existing.first(where: { $0.id == id }) ?? {
                let created = StoredWorkoutRecord(
                    id: id,
                    type: WorkoutType(rawValue: values.string("type") ?? "") ?? .other,
                    durationMinutes: values.int("durationMinutes") ?? 0,
                    averageHeartRate: values.int("averageHeartRate"),
                    calories: values.int("calories") ?? 0,
                    note: values.string("note") ?? "",
                    createdAt: values.date("createdAt") ?? Date(),
                    source: WorkoutSource(rawValue: values.string("source") ?? "") ?? .manual,
                    imageData: values.data("imageBase64")
                )
                modelContext.insert(created)
                return created
            }()
            target.typeRawValue = values.string("type") ?? target.typeRawValue
            target.durationMinutes = values.int("durationMinutes") ?? target.durationMinutes
            target.averageHeartRate = values.int("averageHeartRate") ?? target.averageHeartRate
            target.calories = values.int("calories") ?? target.calories
            target.note = values.string("note") ?? target.note
            target.createdAt = values.date("createdAt") ?? target.createdAt
            target.sourceRawValue = values.string("source") ?? target.sourceRawValue
            target.localDate = values.string("localDate") ?? target.localDate
            target.timezoneIdentifier = values.string("timezoneIdentifier") ?? target.timezoneIdentifier
            target.imageData = values.data("imageBase64") ?? target.imageData
        }
    }

    private static func upsertRemoteSleep(_ records: [RemotePayload], existing: [StoredSleepRecord], modelContext: ModelContext) {
        for values in records.map(\.values) {
            guard let id = values.uuid("id") else { continue }
            let target = existing.first(where: { $0.id == id }) ?? {
                let created = StoredSleepRecord(
                    id: id,
                    hoursSlept: values.double("hoursSlept") ?? 0,
                    quality: SleepQuality(rawValue: values.string("quality") ?? "") ?? .fair,
                    bedTime: values.date("bedTime"),
                    wakeTime: values.date("wakeTime"),
                    note: values.string("note") ?? "",
                    createdAt: values.date("createdAt") ?? Date()
                )
                modelContext.insert(created)
                return created
            }()
            target.hoursSlept = values.double("hoursSlept") ?? target.hoursSlept
            target.qualityRawValue = values.string("quality") ?? target.qualityRawValue
            target.bedTime = values.date("bedTime") ?? target.bedTime
            target.wakeTime = values.date("wakeTime") ?? target.wakeTime
            target.note = values.string("note") ?? target.note
            target.createdAt = values.date("createdAt") ?? target.createdAt
            target.localDate = values.string("localDate") ?? target.localDate
            target.timezoneIdentifier = values.string("timezoneIdentifier") ?? target.timezoneIdentifier
        }
    }

    private static func upsertRemoteWater(_ records: [RemotePayload], existing: [StoredWaterRecord], modelContext: ModelContext) {
        for values in records.map(\.values) {
            guard let id = values.uuid("id") else { continue }
            let target = existing.first(where: { $0.id == id }) ?? {
                let created = StoredWaterRecord(
                    id: id,
                    cupDelta: values.int("cupDelta") ?? 0,
                    loggedAt: values.date("loggedAt") ?? Date(),
                    note: values.string("note") ?? "",
                    createdAt: values.date("createdAt") ?? Date()
                )
                modelContext.insert(created)
                return created
            }()
            target.cupDelta = values.int("cupDelta") ?? target.cupDelta
            target.loggedAt = values.date("loggedAt") ?? target.loggedAt
            target.note = values.string("note") ?? target.note
            target.createdAt = values.date("createdAt") ?? target.createdAt
            target.localDate = values.string("localDate") ?? target.localDate
            target.timezoneIdentifier = values.string("timezoneIdentifier") ?? target.timezoneIdentifier
        }
    }

    private static func upsertRemoteWeight(_ records: [RemotePayload], existing: [StoredWeightRecord], modelContext: ModelContext) {
        for values in records.map(\.values) {
            guard let id = values.uuid("id") else { continue }
            let target = existing.first(where: { $0.id == id }) ?? {
                let created = StoredWeightRecord(
                    id: id,
                    weightKilograms: values.double("weightKilograms") ?? 0,
                    loggedAt: values.date("loggedAt") ?? Date()
                )
                modelContext.insert(created)
                return created
            }()
            target.weightKilograms = values.double("weightKilograms") ?? target.weightKilograms
            target.loggedAt = values.date("loggedAt") ?? target.loggedAt
            target.createdAt = values.date("createdAt") ?? target.createdAt
            target.localDate = values.string("localDate") ?? target.localDate
            target.timezoneIdentifier = values.string("timezoneIdentifier") ?? target.timezoneIdentifier
        }
    }

    private static func upsertRemoteSupplements(_ records: [RemotePayload], existing: [StoredSupplementRecord], modelContext: ModelContext) {
        for values in records.map(\.values) {
            guard let id = values.uuid("id") else { continue }
            let target = existing.first(where: { $0.id == id }) ?? {
                let created = StoredSupplementRecord(
                    id: id,
                    category: SupplementCategory(rawValue: values.string("category") ?? "") ?? .custom,
                    name: values.string("name") ?? "",
                    dosage: values.string("dosage") ?? "",
                    takenAt: values.date("takenAt") ?? Date(),
                    note: values.string("note") ?? "",
                    createdAt: values.date("createdAt") ?? Date()
                )
                modelContext.insert(created)
                return created
            }()
            target.categoryRawValue = values.string("category") ?? target.categoryRawValue
            target.name = values.string("name") ?? target.name
            target.dosage = values.string("dosage") ?? target.dosage
            target.takenAt = values.date("takenAt") ?? target.takenAt
            target.note = values.string("note") ?? target.note
            target.createdAt = values.date("createdAt") ?? target.createdAt
            target.localDate = values.string("localDate") ?? target.localDate
            target.timezoneIdentifier = values.string("timezoneIdentifier") ?? target.timezoneIdentifier
        }
    }

    private static func upsertRemoteMeasurements(_ records: [RemotePayload], existing: [StoredMeasurementRecord], modelContext: ModelContext) {
        for values in records.map(\.values) {
            guard let id = values.uuid("id") else { continue }
            let target = existing.first(where: { $0.id == id }) ?? {
                let kind = MeasurementKind(rawValue: values.string("kind") ?? "") ?? .waist
                let created = StoredMeasurementRecord(
                    id: id,
                    kind: kind,
                    value: values.double("value") ?? 0,
                    unit: values.string("unit"),
                    takenAt: values.date("takenAt") ?? Date(),
                    note: values.string("note") ?? "",
                    createdAt: values.date("createdAt") ?? Date()
                )
                modelContext.insert(created)
                return created
            }()
            target.kindRawValue = values.string("kind") ?? target.kindRawValue
            target.value = values.double("value") ?? target.value
            target.unit = values.string("unit") ?? target.unit
            target.takenAt = values.date("takenAt") ?? target.takenAt
            target.note = values.string("note") ?? target.note
            target.createdAt = values.date("createdAt") ?? target.createdAt
            target.localDate = values.string("localDate") ?? target.localDate
            target.timezoneIdentifier = values.string("timezoneIdentifier") ?? target.timezoneIdentifier
        }
    }

    private static func upsertRemoteStrategies(_ records: [RemotePayload], existing: [StoredDailyStrategy], modelContext: ModelContext) {
        for values in records.map(\.values) {
            guard let id = values.uuid("id"), let payload = values.data("payloadBase64") else { continue }
            let target = existing.first(where: { $0.id == id }) ?? {
                let created = StoredDailyStrategy(
                    id: id,
                    localDate: values.string("localDate") ?? "",
                    timezoneIdentifier: values.string("timezoneIdentifier") ?? TimeZone.current.identifier,
                    generatedAt: values.date("generatedAt") ?? Date(),
                    payload: payload
                )
                modelContext.insert(created)
                return created
            }()
            target.localDate = values.string("localDate") ?? target.localDate
            target.timezoneIdentifier = values.string("timezoneIdentifier") ?? target.timezoneIdentifier
            target.generatedAt = values.date("generatedAt") ?? target.generatedAt
            target.payload = payload
        }
    }

    private static func upsertRemoteReviews(_ records: [RemotePayload], existing: [StoredWeeklyReview], modelContext: ModelContext) {
        for values in records.map(\.values) {
            guard let id = values.uuid("id"), let payload = values.data("payloadBase64") else { continue }
            let target = existing.first(where: { $0.id == id }) ?? {
                let created = StoredWeeklyReview(
                    id: id,
                    weekStartLocalDate: values.string("weekStartLocalDate") ?? "",
                    timezoneIdentifier: values.string("timezoneIdentifier") ?? TimeZone.current.identifier,
                    generatedAt: values.date("generatedAt") ?? Date(),
                    payload: payload
                )
                modelContext.insert(created)
                return created
            }()
            target.weekStartLocalDate = values.string("weekStartLocalDate") ?? target.weekStartLocalDate
            target.timezoneIdentifier = values.string("timezoneIdentifier") ?? target.timezoneIdentifier
            target.generatedAt = values.date("generatedAt") ?? target.generatedAt
            target.payload = payload
        }
    }

    private static func upsertRemoteCycles(_ records: [RemotePayload], existing: [StoredTrainingCycle], modelContext: ModelContext) {
        for values in records.map(\.values) {
            guard let id = values.uuid("id") else { continue }
            let target = existing.first(where: { $0.id == id }) ?? {
                let created = StoredTrainingCycle(
                    id: id,
                    title: values.string("title") ?? "",
                    goal: TrainingCycleGoal(rawValue: values.string("goal") ?? "") ?? .fatLoss,
                    startDate: values.date("startDate") ?? Date(),
                    durationValue: values.int("durationValue") ?? 8,
                    durationUnit: DurationUnit(rawValue: values.string("durationUnit") ?? "") ?? .weeks,
                    arrangement: TrainingArrangement(rawValue: values.string("arrangement") ?? "") ?? .cyclic,
                    cycleDayCount: values.int("cycleDayCount"),
                    daySchedules: [],
                    dietPlanType: CycleDietPlanType(rawValue: values.string("dietPlanType") ?? "") ?? .carbCycling,
                    customProteinMultiplier: values.double("customProteinMultiplier"),
                    customCarbMultiplier: values.double("customCarbMultiplier"),
                    customFatMultiplier: values.double("customFatMultiplier"),
                    supplements: [],
                    status: TrainingCycleStatus(rawValue: values.string("status") ?? "") ?? .scheduled,
                    createdAt: values.date("createdAt") ?? Date()
                )
                modelContext.insert(created)
                return created
            }()
            target.title = values.string("title") ?? target.title
            target.goalRawValue = values.string("goal") ?? target.goalRawValue
            target.startDate = values.date("startDate") ?? target.startDate
            target.durationValue = values.int("durationValue") ?? target.durationValue
            target.durationUnitRawValue = values.string("durationUnit") ?? target.durationUnitRawValue
            target.arrangementRawValue = values.string("arrangement") ?? target.arrangementRawValue
            target.cycleDayCount = values.int("cycleDayCount") ?? target.cycleDayCount
            target.daySchedulesData = values.data("daySchedulesBase64") ?? target.daySchedulesData
            target.dietPlanTypeRawValue = values.string("dietPlanType") ?? target.dietPlanTypeRawValue
            target.customProteinMultiplier = values.double("customProteinMultiplier") ?? target.customProteinMultiplier
            target.customCarbMultiplier = values.double("customCarbMultiplier") ?? target.customCarbMultiplier
            target.customFatMultiplier = values.double("customFatMultiplier") ?? target.customFatMultiplier
            target.supplementsData = values.data("supplementsBase64") ?? target.supplementsData
            target.statusRawValue = values.string("status") ?? target.statusRawValue
            target.createdAt = values.date("createdAt") ?? target.createdAt
            target.localDate = values.string("localDate") ?? target.localDate
            target.timezoneIdentifier = values.string("timezoneIdentifier") ?? target.timezoneIdentifier
        }
    }
}

private extension Dictionary where Key == String, Value == RemoteJSONValue {
    func string(_ key: String) -> String? { self[key]?.stringValue }
    func int(_ key: String) -> Int? { self[key]?.intValue }
    func double(_ key: String) -> Double? { self[key]?.doubleValue }
    func bool(_ key: String) -> Bool? { self[key]?.boolValue }
    func date(_ key: String) -> Date? { self[key]?.dateValue }
    func data(_ key: String) -> Data? { self[key]?.dataValue }
    func uuid(_ key: String) -> UUID? { self[key]?.uuidValue }
    func object(_ key: String) -> [String: RemoteJSONValue]? {
        guard case .object(let object)? = self[key] else { return nil }
        return object
    }
}
