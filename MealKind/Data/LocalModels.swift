import Foundation
import SwiftData

enum LocalDateStamp {
    static func dateString(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 1970,
            components.month ?? 1,
            components.day ?? 1
        )
    }
}

@Model
final class StoredHabit {
    var id: UUID = UUID()
    var title: String = ""
    var anchor: String = ""
    var tinyBehavior: String = ""
    var celebration: String = ""
    var difficulty: Int = 1
    var frequencyRawValue: String = HabitFrequency.daily.rawValue
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        title: String,
        anchor: String,
        tinyBehavior: String,
        celebration: String,
        difficulty: Int,
        frequency: HabitFrequency,
        isActive: Bool,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.anchor = anchor
        self.tinyBehavior = tinyBehavior
        self.celebration = celebration
        self.difficulty = difficulty
        self.frequencyRawValue = frequency.rawValue
        self.isActive = isActive
        self.createdAt = createdAt
    }

    convenience init(_ habit: Habit) {
        self.init(
            id: habit.id,
            title: habit.title,
            anchor: habit.anchor,
            tinyBehavior: habit.tinyBehavior,
            celebration: habit.celebration,
            difficulty: habit.difficulty,
            frequency: habit.frequency,
            isActive: habit.isActive,
            createdAt: habit.createdAt
        )
    }

    var frequency: HabitFrequency {
        get { HabitFrequency(rawValue: frequencyRawValue) ?? .daily }
        set { frequencyRawValue = newValue.rawValue }
    }

    var habit: Habit {
        Habit(
            id: id,
            title: title,
            anchor: anchor,
            tinyBehavior: tinyBehavior,
            celebration: celebration,
            difficulty: difficulty,
            frequency: frequency,
            isActive: isActive,
            createdAt: createdAt
        )
    }
}

@Model
final class StoredDailyTask {
    var id: UUID = UUID()
    var title: String = ""
    var taskDescription: String = ""
    var habitId: UUID?
    var taskTypeRawValue: String = DailyTaskType.mealPhoto.rawValue
    var statusRawValue: String = TaskStatus.pending.rawValue
    var scheduledTime: Date?
    var completedAt: Date?
    var difficulty: Int = 1
    var createdAt: Date = Date()
    var localDate: String = ""
    var timezoneIdentifier: String = TimeZone.current.identifier

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        habitId: UUID? = nil,
        taskType: DailyTaskType,
        status: TaskStatus = .pending,
        scheduledTime: Date? = nil,
        completedAt: Date? = nil,
        difficulty: Int,
        createdAt: Date = Date(),
        timeZone: TimeZone = .current
    ) {
        self.id = id
        self.title = title
        self.taskDescription = description
        self.habitId = habitId
        self.taskTypeRawValue = taskType.rawValue
        self.statusRawValue = status.rawValue
        self.scheduledTime = scheduledTime
        self.completedAt = completedAt
        self.difficulty = difficulty
        self.createdAt = createdAt
        self.localDate = LocalDateStamp.dateString(for: scheduledTime ?? completedAt ?? createdAt, timeZone: timeZone)
        self.timezoneIdentifier = timeZone.identifier
    }

    convenience init(_ task: DailyTask) {
        self.init(
            id: task.id,
            title: task.title,
            description: task.description,
            habitId: task.habitId,
            taskType: task.taskType,
            status: task.status,
            scheduledTime: task.scheduledTime,
            completedAt: task.completedAt,
            difficulty: task.difficulty
        )
    }

    var taskType: DailyTaskType {
        get { DailyTaskType(rawValue: taskTypeRawValue) ?? .mealPhoto }
        set { taskTypeRawValue = newValue.rawValue }
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRawValue) ?? .pending }
        set { statusRawValue = newValue.rawValue }
    }

    var dailyTask: DailyTask {
        DailyTask(
            id: id,
            title: title,
            description: taskDescription,
            habitId: habitId,
            taskType: taskType,
            status: status,
            scheduledTime: scheduledTime,
            completedAt: completedAt,
            difficulty: difficulty
        )
    }
}

@Model
final class StoredUserSettings {
    var selectedPlanRawValue: String = DietPlan.lifestyleCut.rawValue
    var basalMetabolicRate: Int = 1_520
    var activityCalories: Int = 420
    var exerciseCalories: Int = 180
    var heightCentimeters: Double?
    var age: Int?
    var biologicalSexRawValue: String?
    var targetWeightKilograms: Double?
    var currentBodyFatPercentage: Double?
    var targetBodyFatPercentage: Double?
    var workEnvironmentRawValue: String?
    var hasExerciseHabit: Bool?
    var weeklyWorkoutCount: Int?
    var restDayRawValue: Int?
    var fatLossWeeks: Int?
    var activityLevelRawValue: String?
    var trainingExperienceRawValue: String?
    var experienceModeRawValue: String?
    var fitnessIntentRawValue: String?
    var waterCups: Int = 0
    var weightKilograms: Double = 68.4
    // 普通版「活动」每日消耗能量目标（千卡），用户可自设，参考 Apple Fitness Move 环。
    var activityBurnGoal: Int = 300
    var hasCompletedOnboarding: Bool = false
    var hasSelectedLanguage: Bool = false
    // 注册/建档日期：设置行首次创建即记录，用于成长时间线起点。
    var registeredAt: Date = Date()
    var languageRawValue: String = AppLanguage.english.rawValue
    // 外观：跟随系统 / 浅色 / 深色。
    var appearanceRawValue: String = AppAppearance.system.rawValue
    var accountModeRawValue: String = AccountMode.guest.rawValue
    var subscriptionTierRawValue: String = SubscriptionTier.free.rawValue

    init(
        selectedPlan: DietPlan = .lifestyleCut,
        basalMetabolicRate: Int = 1_520,
        activityCalories: Int = 420,
        exerciseCalories: Int = 180,
        heightCentimeters: Double = 170,
        age: Int = 32,
        biologicalSex: BiologicalSex = .female,
        targetWeightKilograms: Double = 62,
        currentBodyFatPercentage: Double? = nil,
        targetBodyFatPercentage: Double? = nil,
        workEnvironment: WorkEnvironment = .office,
        hasExerciseHabit: Bool = true,
        weeklyWorkoutCount: Int = 3,
        restDayRawValue: Int = 7,
        fatLossWeeks: Int = 12,
        activityLevel: ActivityLevel = .light,
        trainingExperience: TrainingExperience = .none,
        experienceMode: AppExperienceMode = .lifestyle,
        fitnessIntent: FitnessIntent = .fatLoss,
        waterCups: Int = 0,
        weightKilograms: Double = 68.4,
        hasCompletedOnboarding: Bool = false,
        hasSelectedLanguage: Bool = false,
        language: AppLanguage = .english,
        accountMode: AccountMode = .guest,
        subscriptionTier: SubscriptionTier = .free
    ) {
        self.selectedPlanRawValue = selectedPlan.rawValue
        self.basalMetabolicRate = basalMetabolicRate
        self.activityCalories = activityCalories
        self.exerciseCalories = exerciseCalories
        self.heightCentimeters = heightCentimeters
        self.age = age
        self.biologicalSexRawValue = biologicalSex.rawValue
        self.targetWeightKilograms = targetWeightKilograms
        self.currentBodyFatPercentage = currentBodyFatPercentage
        self.targetBodyFatPercentage = targetBodyFatPercentage
        self.workEnvironmentRawValue = workEnvironment.rawValue
        self.hasExerciseHabit = hasExerciseHabit
        self.weeklyWorkoutCount = weeklyWorkoutCount
        self.restDayRawValue = restDayRawValue
        self.fatLossWeeks = fatLossWeeks
        self.activityLevelRawValue = activityLevel.rawValue
        self.trainingExperienceRawValue = trainingExperience.rawValue
        self.experienceModeRawValue = experienceMode.rawValue
        self.fitnessIntentRawValue = fitnessIntent.rawValue
        self.waterCups = waterCups
        self.weightKilograms = weightKilograms
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hasSelectedLanguage = hasSelectedLanguage
        self.languageRawValue = language.rawValue
        self.accountModeRawValue = accountMode.rawValue
        self.subscriptionTierRawValue = subscriptionTier.rawValue
    }

    var selectedPlan: DietPlan {
        get { DietPlan(rawValue: selectedPlanRawValue) ?? .lifestyleCut }
        set { selectedPlanRawValue = newValue.rawValue }
    }

    var profile: UserEnergyProfile {
        get {
            UserEnergyProfile(
                basalMetabolicRate: basalMetabolicRate,
                activityCalories: activityCalories,
                exerciseCalories: exerciseCalories,
                heightCentimeters: heightCentimeters ?? 170,
                age: age ?? 32,
                biologicalSex: biologicalSex,
                targetWeightKilograms: targetWeightKilograms ?? 62,
                currentBodyFatPercentage: currentBodyFatPercentage,
                targetBodyFatPercentage: targetBodyFatPercentage,
                workEnvironment: workEnvironment,
                hasExerciseHabit: hasExerciseHabit ?? true,
                weeklyWorkoutCount: weeklyWorkoutCount ?? 3,
                restDayRawValue: restDayRawValue ?? 7,
                fatLossWeeks: fatLossWeeks ?? 12,
                activityLevel: activityLevel,
                trainingExperience: trainingExperience
            )
        }
        set {
            basalMetabolicRate = newValue.basalMetabolicRate
            activityCalories = newValue.activityCalories
            exerciseCalories = newValue.exerciseCalories
            heightCentimeters = newValue.heightCentimeters
            age = newValue.age
            biologicalSex = newValue.biologicalSex
            targetWeightKilograms = newValue.targetWeightKilograms
            currentBodyFatPercentage = newValue.currentBodyFatPercentage
            targetBodyFatPercentage = newValue.targetBodyFatPercentage
            workEnvironment = newValue.workEnvironment
            hasExerciseHabit = newValue.hasExerciseHabit
            weeklyWorkoutCount = newValue.weeklyWorkoutCount
            restDayRawValue = newValue.restDayRawValue
            fatLossWeeks = newValue.fatLossWeeks
            activityLevel = newValue.activityLevel
            trainingExperience = newValue.trainingExperience
        }
    }

    var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRawValue ?? "") ?? .light }
        set { activityLevelRawValue = newValue.rawValue }
    }

    var trainingExperience: TrainingExperience {
        get { TrainingExperience(rawValue: trainingExperienceRawValue ?? "") ?? .none }
        set { trainingExperienceRawValue = newValue.rawValue }
    }

    var biologicalSex: BiologicalSex {
        get { BiologicalSex(rawValue: biologicalSexRawValue ?? "") ?? .female }
        set { biologicalSexRawValue = newValue.rawValue }
    }

    var workEnvironment: WorkEnvironment {
        get { WorkEnvironment(rawValue: workEnvironmentRawValue ?? "") ?? .office }
        set { workEnvironmentRawValue = newValue.rawValue }
    }

    var experienceMode: AppExperienceMode {
        get { AppExperienceMode(rawValue: experienceModeRawValue ?? "") ?? .lifestyle }
        set { experienceModeRawValue = newValue.rawValue }
    }

    var fitnessIntent: FitnessIntent {
        get { FitnessIntent(rawValue: fitnessIntentRawValue ?? "") ?? .fatLoss }
        set { fitnessIntentRawValue = newValue.rawValue }
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRawValue) ?? .english }
        set { languageRawValue = newValue.rawValue }
    }

    var accountMode: AccountMode {
        get { AccountMode(rawValue: accountModeRawValue) ?? .guest }
        set { accountModeRawValue = newValue.rawValue }
    }

    var subscriptionTier: SubscriptionTier {
        get { SubscriptionTier(rawValue: subscriptionTierRawValue) ?? .free }
        set { subscriptionTierRawValue = newValue.rawValue }
    }
}

@Model
final class StoredMealRecord {
    var id: UUID = UUID()
    var name: String = ""
    var calories: Int = 0
    var protein: Int = 0
    var carbs: Int = 0
    var fat: Int = 0
    var servingDescription: String?
    var createdAt: Date = Date()
    var sourceRawValue: String = MealSource.manual.rawValue
    var localDate: String = ""
    var timezoneIdentifier: String = TimeZone.current.identifier
    @Attribute(.externalStorage) var imageData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        protein: Int = 0,
        carbs: Int = 0,
        fat: Int = 0,
        servingDescription: String? = nil,
        createdAt: Date = Date(),
        source: MealSource,
        imageData: Data? = nil,
        timeZone: TimeZone = .current
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.servingDescription = servingDescription
        self.createdAt = createdAt
        self.sourceRawValue = source.rawValue
        self.localDate = LocalDateStamp.dateString(for: createdAt, timeZone: timeZone)
        self.timezoneIdentifier = timeZone.identifier
        self.imageData = imageData
    }

    var source: MealSource {
        get { MealSource(rawValue: sourceRawValue) ?? .manual }
        set { sourceRawValue = newValue.rawValue }
    }

    var mealLog: MealLog {
        MealLog(
            id: id,
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            servingDescription: servingDescription,
            createdAt: createdAt,
            source: source,
            imageData: imageData
        )
    }
}

@Model
final class StoredSleepRecord {
    var id: UUID = UUID()
    var hoursSlept: Double = 0
    var qualityRawValue: String = SleepQuality.fair.rawValue
    var bedTime: Date?
    var wakeTime: Date?
    var note: String = ""
    var createdAt: Date = Date()
    var localDate: String = ""
    var timezoneIdentifier: String = TimeZone.current.identifier

    init(
        id: UUID = UUID(),
        hoursSlept: Double,
        quality: SleepQuality = .fair,
        bedTime: Date? = nil,
        wakeTime: Date? = nil,
        note: String = "",
        createdAt: Date = Date(),
        timeZone: TimeZone = .current
    ) {
        self.id = id
        self.hoursSlept = hoursSlept
        self.qualityRawValue = quality.rawValue
        self.bedTime = bedTime
        self.wakeTime = wakeTime
        self.note = note
        self.createdAt = createdAt
        self.localDate = LocalDateStamp.dateString(for: createdAt, timeZone: timeZone)
        self.timezoneIdentifier = timeZone.identifier
    }

    convenience init(_ log: SleepLog, timeZone: TimeZone = .current) {
        self.init(
            id: log.id,
            hoursSlept: log.hoursSlept,
            quality: log.quality,
            bedTime: log.bedTime,
            wakeTime: log.wakeTime,
            note: log.note,
            createdAt: log.createdAt,
            timeZone: timeZone
        )
    }

    var quality: SleepQuality {
        get { SleepQuality(rawValue: qualityRawValue) ?? .fair }
        set { qualityRawValue = newValue.rawValue }
    }

    var sleepLog: SleepLog {
        SleepLog(
            id: id,
            hoursSlept: hoursSlept,
            quality: quality,
            bedTime: bedTime,
            wakeTime: wakeTime,
            note: note,
            createdAt: createdAt
        )
    }
}

@Model
final class StoredWaterRecord {
    var id: UUID = UUID()
    var cupDelta: Int = 1
    var loggedAt: Date = Date()
    var note: String = ""
    var createdAt: Date = Date()
    var localDate: String = ""
    var timezoneIdentifier: String = TimeZone.current.identifier

    init(
        id: UUID = UUID(),
        cupDelta: Int,
        loggedAt: Date = Date(),
        note: String = "",
        createdAt: Date = Date(),
        timeZone: TimeZone = .current
    ) {
        self.id = id
        self.cupDelta = min(max(cupDelta, -20), 20)
        self.loggedAt = loggedAt
        self.note = note
        self.createdAt = createdAt
        self.localDate = LocalDateStamp.dateString(for: loggedAt, timeZone: timeZone)
        self.timezoneIdentifier = timeZone.identifier
    }

    convenience init(_ log: WaterLog, timeZone: TimeZone = .current) {
        self.init(
            id: log.id,
            cupDelta: log.cupDelta,
            loggedAt: log.loggedAt,
            note: log.note,
            createdAt: log.loggedAt,
            timeZone: timeZone
        )
    }

    var waterLog: WaterLog {
        WaterLog(
            id: id,
            cupDelta: cupDelta,
            loggedAt: loggedAt,
            note: note
        )
    }
}

@Model
final class StoredWeightRecord {
    var id: UUID = UUID()
    var weightKilograms: Double = 0
    var loggedAt: Date = Date()
    var createdAt: Date = Date()
    var localDate: String = ""
    var timezoneIdentifier: String = TimeZone.current.identifier

    init(
        id: UUID = UUID(),
        weightKilograms: Double,
        loggedAt: Date = Date(),
        timeZone: TimeZone = .current
    ) {
        self.id = id
        self.weightKilograms = weightKilograms
        self.loggedAt = loggedAt
        self.createdAt = loggedAt
        self.localDate = LocalDateStamp.dateString(for: loggedAt, timeZone: timeZone)
        self.timezoneIdentifier = timeZone.identifier
    }

    convenience init(_ log: WeightLog, timeZone: TimeZone = .current) {
        self.init(
            id: log.id,
            weightKilograms: log.weightKilograms,
            loggedAt: log.loggedAt,
            timeZone: timeZone
        )
    }

    var weightLog: WeightLog {
        WeightLog(id: id, weightKilograms: weightKilograms, loggedAt: loggedAt)
    }
}

@Model
final class StoredSupplementRecord {
    var id: UUID = UUID()
    var categoryRawValue: String = SupplementCategory.creatine.rawValue
    var name: String = ""
    var dosage: String = ""
    var takenAt: Date = Date()
    var note: String = ""
    var createdAt: Date = Date()
    var localDate: String = ""
    var timezoneIdentifier: String = TimeZone.current.identifier

    init(
        id: UUID = UUID(),
        category: SupplementCategory = .creatine,
        name: String,
        dosage: String = "",
        takenAt: Date = Date(),
        note: String = "",
        createdAt: Date = Date(),
        timeZone: TimeZone = .current
    ) {
        self.id = id
        self.categoryRawValue = category.rawValue
        self.name = name
        self.dosage = dosage
        self.takenAt = takenAt
        self.note = note
        self.createdAt = createdAt
        self.localDate = LocalDateStamp.dateString(for: takenAt, timeZone: timeZone)
        self.timezoneIdentifier = timeZone.identifier
    }

    convenience init(_ log: SupplementLog, timeZone: TimeZone = .current) {
        self.init(
            id: log.id,
            category: log.category,
            name: log.name,
            dosage: log.dosage,
            takenAt: log.takenAt,
            note: log.note,
            createdAt: log.createdAt,
            timeZone: timeZone
        )
    }

    var category: SupplementCategory {
        get { SupplementCategory(rawValue: categoryRawValue) ?? .custom }
        set { categoryRawValue = newValue.rawValue }
    }

    var supplementLog: SupplementLog {
        SupplementLog(
            id: id,
            category: category,
            name: name,
            dosage: dosage,
            takenAt: takenAt,
            note: note,
            createdAt: createdAt
        )
    }
}

@Model
final class StoredMeasurementRecord {
    var id: UUID = UUID()
    var kindRawValue: String = MeasurementKind.waist.rawValue
    var value: Double = 0
    var unit: String = "cm"
    var takenAt: Date = Date()
    var note: String = ""
    var createdAt: Date = Date()
    var localDate: String = ""
    var timezoneIdentifier: String = TimeZone.current.identifier

    init(
        id: UUID = UUID(),
        kind: MeasurementKind,
        value: Double,
        unit: String? = nil,
        takenAt: Date = Date(),
        note: String = "",
        createdAt: Date = Date(),
        timeZone: TimeZone = .current
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.value = value
        self.unit = unit ?? kind.defaultUnit
        self.takenAt = takenAt
        self.note = note
        self.createdAt = createdAt
        self.localDate = LocalDateStamp.dateString(for: takenAt, timeZone: timeZone)
        self.timezoneIdentifier = timeZone.identifier
    }

    convenience init(_ log: MeasurementLog, timeZone: TimeZone = .current) {
        self.init(
            id: log.id,
            kind: log.kind,
            value: log.value,
            unit: log.unit,
            takenAt: log.takenAt,
            note: log.note,
            createdAt: log.createdAt,
            timeZone: timeZone
        )
    }

    var kind: MeasurementKind {
        get { MeasurementKind(rawValue: kindRawValue) ?? .waist }
        set { kindRawValue = newValue.rawValue }
    }

    var measurementLog: MeasurementLog {
        MeasurementLog(
            id: id,
            kind: kind,
            value: value,
            unit: unit,
            takenAt: takenAt,
            note: note,
            createdAt: createdAt
        )
    }
}

@Model
final class StoredDailyStrategy {
    var id: UUID = UUID()
    var localDate: String = ""
    var timezoneIdentifier: String = TimeZone.current.identifier
    var generatedAt: Date = Date()
    var payload: Data = Data()

    init(
        id: UUID = UUID(),
        localDate: String,
        timezoneIdentifier: String = TimeZone.current.identifier,
        generatedAt: Date = Date(),
        payload: Data
    ) {
        self.id = id
        self.localDate = localDate
        self.timezoneIdentifier = timezoneIdentifier
        self.generatedAt = generatedAt
        self.payload = payload
    }

    var strategy: TodayStrategy? {
        try? JSONDecoder().decode(TodayStrategy.self, from: payload)
    }
}

@Model
final class StoredWeeklyReview {
    var id: UUID = UUID()
    var weekStartLocalDate: String = ""
    var generatedAt: Date = Date()
    var timezoneIdentifier: String = TimeZone.current.identifier
    var payload: Data = Data()

    init(
        id: UUID = UUID(),
        weekStartLocalDate: String,
        timezoneIdentifier: String = TimeZone.current.identifier,
        generatedAt: Date = Date(),
        payload: Data
    ) {
        self.id = id
        self.weekStartLocalDate = weekStartLocalDate
        self.timezoneIdentifier = timezoneIdentifier
        self.generatedAt = generatedAt
        self.payload = payload
    }

    var review: WeeklyReview? {
        try? JSONDecoder().decode(WeeklyReview.self, from: payload)
    }
}

@Model
final class StoredWorkoutRecord {
    var id: UUID = UUID()
    var typeRawValue: String = WorkoutType.other.rawValue
    var durationMinutes: Int = 0
    var averageHeartRate: Int?
    var calories: Int = 0
    var note: String = ""
    var createdAt: Date = Date()
    var sourceRawValue: String = WorkoutSource.manual.rawValue
    var localDate: String = ""
    var timezoneIdentifier: String = TimeZone.current.identifier
    @Attribute(.externalStorage) var imageData: Data?

    init(
        id: UUID = UUID(),
        type: WorkoutType,
        durationMinutes: Int,
        averageHeartRate: Int? = nil,
        calories: Int,
        note: String = "",
        createdAt: Date = Date(),
        source: WorkoutSource = .manual,
        imageData: Data? = nil,
        timeZone: TimeZone = .current
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.durationMinutes = durationMinutes
        self.averageHeartRate = averageHeartRate
        self.calories = calories
        self.note = note
        self.createdAt = createdAt
        self.sourceRawValue = source.rawValue
        self.localDate = LocalDateStamp.dateString(for: createdAt, timeZone: timeZone)
        self.timezoneIdentifier = timeZone.identifier
        self.imageData = imageData
    }

    var type: WorkoutType {
        get { WorkoutType(rawValue: typeRawValue) ?? .other }
        set { typeRawValue = newValue.rawValue }
    }

    var source: WorkoutSource {
        get { WorkoutSource(rawValue: sourceRawValue) ?? .manual }
        set { sourceRawValue = newValue.rawValue }
    }

    var workoutLog: WorkoutLog {
        WorkoutLog(
            id: id,
            type: type,
            durationMinutes: durationMinutes,
            averageHeartRate: averageHeartRate,
            calories: calories,
            note: note,
            createdAt: createdAt,
            source: source,
            imageData: imageData
        )
    }
}

@Model
final class StoredTrainingCycle {
    var id: UUID = UUID()
    var title: String = ""
    var goalRawValue: String = TrainingCycleGoal.fatLoss.rawValue
    var startDate: Date = Date()
    var durationValue: Int = 8
    var durationUnitRawValue: String = DurationUnit.weeks.rawValue
    var arrangementRawValue: String = TrainingArrangement.cyclic.rawValue
    var cycleDayCount: Int?
    var daySchedulesData: Data = Data()
    var dietPlanTypeRawValue: String = CycleDietPlanType.carbCycling.rawValue
    var customProteinMultiplier: Double?
    var customCarbMultiplier: Double?
    var customFatMultiplier: Double?
    var supplementsData: Data = Data()
    var statusRawValue: String = TrainingCycleStatus.scheduled.rawValue
    var createdAt: Date = Date()
    var localDate: String = ""
    var timezoneIdentifier: String = TimeZone.current.identifier

    init(
        id: UUID = UUID(),
        title: String,
        goal: TrainingCycleGoal,
        startDate: Date,
        durationValue: Int,
        durationUnit: DurationUnit,
        arrangement: TrainingArrangement,
        cycleDayCount: Int? = nil,
        daySchedules: [CycleDaySchedule] = [],
        dietPlanType: CycleDietPlanType,
        customProteinMultiplier: Double? = nil,
        customCarbMultiplier: Double? = nil,
        customFatMultiplier: Double? = nil,
        supplements: [CycleSupplement] = [],
        status: TrainingCycleStatus,
        createdAt: Date = Date(),
        timeZone: TimeZone = .current
    ) {
        self.id = id
        self.title = title
        self.goalRawValue = goal.rawValue
        self.startDate = startDate
        self.durationValue = durationValue
        self.durationUnitRawValue = durationUnit.rawValue
        self.arrangementRawValue = arrangement.rawValue
        self.cycleDayCount = cycleDayCount
        self.daySchedulesData = (try? JSONEncoder().encode(daySchedules)) ?? Data()
        self.dietPlanTypeRawValue = dietPlanType.rawValue
        self.customProteinMultiplier = customProteinMultiplier
        self.customCarbMultiplier = customCarbMultiplier
        self.customFatMultiplier = customFatMultiplier
        self.supplementsData = (try? JSONEncoder().encode(supplements)) ?? Data()
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.localDate = LocalDateStamp.dateString(for: createdAt, timeZone: timeZone)
        self.timezoneIdentifier = timeZone.identifier
    }

    var goal: TrainingCycleGoal {
        get { TrainingCycleGoal(rawValue: goalRawValue) ?? .fatLoss }
        set { goalRawValue = newValue.rawValue }
    }

    var durationUnit: DurationUnit {
        get { DurationUnit(rawValue: durationUnitRawValue) ?? .weeks }
        set { durationUnitRawValue = newValue.rawValue }
    }

    var arrangement: TrainingArrangement {
        get { TrainingArrangement(rawValue: arrangementRawValue) ?? .cyclic }
        set { arrangementRawValue = newValue.rawValue }
    }

    var dietPlanType: CycleDietPlanType {
        get { CycleDietPlanType(rawValue: dietPlanTypeRawValue) ?? .carbCycling }
        set { dietPlanTypeRawValue = newValue.rawValue }
    }

    var status: TrainingCycleStatus {
        get { TrainingCycleStatus(rawValue: statusRawValue) ?? .scheduled }
        set { statusRawValue = newValue.rawValue }
    }

    var daySchedules: [CycleDaySchedule] {
        (try? JSONDecoder().decode([CycleDaySchedule].self, from: daySchedulesData)) ?? []
    }

    var supplements: [CycleSupplement] {
        (try? JSONDecoder().decode([CycleSupplement].self, from: supplementsData)) ?? []
    }

    var trainingCycle: TrainingCycle {
        TrainingCycle(
            id: id,
            title: title,
            goal: goal,
            startDate: startDate,
            durationValue: durationValue,
            durationUnit: durationUnit,
            arrangement: arrangement,
            cycleDayCount: cycleDayCount,
            daySchedules: daySchedules,
            dietPlanType: dietPlanType,
            customProteinMultiplier: customProteinMultiplier,
            customCarbMultiplier: customCarbMultiplier,
            customFatMultiplier: customFatMultiplier,
            supplements: supplements,
            status: status,
            createdAt: createdAt
        )
    }
}
