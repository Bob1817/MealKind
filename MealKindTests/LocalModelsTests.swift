import XCTest
@testable import MealKind

final class LocalModelsTests: XCTestCase {
    func testStoredSettingsMapsPlanAndProfile() {
        let settings = StoredUserSettings()

        settings.selectedPlan = .carbStepDown
        settings.language = .simplifiedChinese
        settings.accountMode = .guest
        settings.subscriptionTier = .proPlus
        settings.profile = UserEnergyProfile(
            basalMetabolicRate: 1_610,
            activityCalories: 330,
            exerciseCalories: 210
        )

        XCTAssertEqual(settings.selectedPlan, .carbStepDown)
        XCTAssertEqual(settings.language, .simplifiedChinese)
        XCTAssertEqual(settings.accountMode, .guest)
        XCTAssertEqual(settings.subscriptionTier, .proPlus)
        XCTAssertEqual(settings.basalMetabolicRate, 1_610)
        XCTAssertEqual(settings.activityCalories, 330)
        XCTAssertEqual(settings.exerciseCalories, 210)
    }

    func testProPlusFeatureGatesRequireProPlusTier() {
        XCTAssertFalse(ProPlusFeature.sleepAnalysis.isUnlocked(for: .free))
        XCTAssertFalse(ProPlusFeature.sleepAnalysis.isUnlocked(for: .pro))
        XCTAssertTrue(ProPlusFeature.sleepAnalysis.isUnlocked(for: .proPlus))
        XCTAssertTrue(SubscriptionTier.proPlus.isPro)
        XCTAssertTrue(SubscriptionTier.proPlus.isProPlus)
    }

    func testStoredMealRecordMapsToMealLog() {
        let imageData = Data([1, 2, 3])
        let id = UUID()
        let date = Date()
        let stored = StoredMealRecord(
            id: id,
            name: "Camera meal",
            calories: 540,
            createdAt: date,
            source: .camera,
            imageData: imageData
        )

        let meal = stored.mealLog

        XCTAssertEqual(meal.id, id)
        XCTAssertEqual(meal.name, "Camera meal")
        XCTAssertEqual(meal.calories, 540)
        XCTAssertEqual(meal.createdAt, date)
        XCTAssertEqual(meal.source, .camera)
        XCTAssertEqual(meal.imageData, imageData)
    }

    func testStoredMealRecordStoresLocalDateAndTimezone() {
        let utcDate = Date(timeIntervalSince1970: 1_772_323_200)
        let shanghai = TimeZone(identifier: "Asia/Shanghai")!
        let stored = StoredMealRecord(
            name: "Late meal",
            calories: 520,
            createdAt: utcDate,
            source: .manual,
            timeZone: shanghai
        )

        XCTAssertEqual(stored.localDate, "2026-03-01")
        XCTAssertEqual(stored.timezoneIdentifier, "Asia/Shanghai")
    }

    func testLocalRecordRepositoryBuildsStoredMealRecord() {
        let date = Date(timeIntervalSince1970: 1_772_323_200)
        let shanghai = TimeZone(identifier: "Asia/Shanghai")!
        let meal = MealLog(
            name: "Dinner",
            calories: 620,
            protein: 31,
            carbs: 70,
            fat: 18,
            createdAt: date,
            source: .photoLibrary
        )

        let stored = LocalRecordRepository.storedMeal(meal, timeZone: shanghai)

        XCTAssertEqual(stored.name, "Dinner")
        XCTAssertEqual(stored.calories, 620)
        XCTAssertEqual(stored.source, .photoLibrary)
        XCTAssertEqual(stored.localDate, "2026-03-01")
        XCTAssertEqual(stored.timezoneIdentifier, "Asia/Shanghai")
    }

    func testStoredHabitMapsToHabit() {
        let id = UUID()
        let date = Date()
        let habit = Habit(
            id: id,
            title: "午餐前拍一下",
            anchor: "打开午餐后",
            tinyBehavior: "拍一张照片",
            celebration: "完成关键一步",
            difficulty: 1,
            frequency: .daily,
            isActive: true,
            createdAt: date
        )

        let stored = StoredHabit(habit)
        let mapped = stored.habit

        XCTAssertEqual(mapped.id, id)
        XCTAssertEqual(mapped.title, "午餐前拍一下")
        XCTAssertEqual(mapped.anchor, "打开午餐后")
        XCTAssertEqual(mapped.tinyBehavior, "拍一张照片")
        XCTAssertEqual(mapped.celebration, "完成关键一步")
        XCTAssertEqual(mapped.difficulty, 1)
        XCTAssertEqual(mapped.frequency, .daily)
        XCTAssertTrue(mapped.isActive)
        XCTAssertEqual(mapped.createdAt, date)
    }

    func testLocalRecordRepositoryBuildsStoredHabitsAndTasks() {
        let habits = Habit.defaults(language: .simplifiedChinese)
        let tasks = DailyTask.defaults(from: habits, language: .simplifiedChinese)

        let storedHabits = LocalRecordRepository.storedHabits(habits)
        let storedTasks = LocalRecordRepository.storedTasks(tasks)

        XCTAssertEqual(storedHabits.count, 3)
        XCTAssertEqual(storedTasks.count, 3)
        XCTAssertEqual(storedHabits[0].title, habits[0].title)
        XCTAssertEqual(storedTasks[0].title, tasks[0].title)
        XCTAssertEqual(storedTasks[0].taskType, tasks[0].taskType)
    }

    func testStoredDailyTaskMapsToDailyTask() {
        let id = UUID()
        let habitId = UUID()
        let completedAt = Date()
        let task = DailyTask(
            id: id,
            title: "午餐前拍一下",
            description: "拍一张食物照片",
            habitId: habitId,
            taskType: .mealPhoto,
            status: .completed,
            completedAt: completedAt,
            difficulty: 1
        )

        let stored = StoredDailyTask(task)
        let mapped = stored.dailyTask

        XCTAssertEqual(mapped.id, id)
        XCTAssertEqual(mapped.title, "午餐前拍一下")
        XCTAssertEqual(mapped.description, "拍一张食物照片")
        XCTAssertEqual(mapped.habitId, habitId)
        XCTAssertEqual(mapped.taskType, .mealPhoto)
        XCTAssertEqual(mapped.status, .completed)
        XCTAssertEqual(mapped.completedAt, completedAt)
        XCTAssertEqual(mapped.difficulty, 1)
        XCTAssertFalse(stored.localDate.isEmpty)
        XCTAssertFalse(stored.timezoneIdentifier.isEmpty)
    }

    func testStoredDailyTaskUsesCompletedDateForLocalDate() {
        let completedAt = Date(timeIntervalSince1970: 1_772_323_200)
        let shanghai = TimeZone(identifier: "Asia/Shanghai")!
        let task = StoredDailyTask(
            title: "Review",
            description: "Read summary",
            taskType: .review,
            status: .completed,
            completedAt: completedAt,
            difficulty: 1,
            timeZone: shanghai
        )

        XCTAssertEqual(task.localDate, "2026-03-01")
        XCTAssertEqual(task.timezoneIdentifier, "Asia/Shanghai")
    }

    func testStoredWorkoutRecordMapsToWorkoutLog() {
        let imageData = Data([4, 5, 6])
        let id = UUID()
        let date = Date()
        let stored = StoredWorkoutRecord(
            id: id,
            type: .running,
            durationMinutes: 35,
            averageHeartRate: 142,
            calories: 360,
            note: "watch screenshot",
            createdAt: date,
            source: .screenshot,
            imageData: imageData
        )

        let workout = stored.workoutLog

        XCTAssertEqual(workout.id, id)
        XCTAssertEqual(workout.type, .running)
        XCTAssertEqual(workout.durationMinutes, 35)
        XCTAssertEqual(workout.averageHeartRate, 142)
        XCTAssertEqual(workout.calories, 360)
        XCTAssertEqual(workout.note, "watch screenshot")
        XCTAssertEqual(workout.createdAt, date)
        XCTAssertEqual(workout.source, .screenshot)
        XCTAssertEqual(workout.imageData, imageData)
        XCTAssertFalse(stored.localDate.isEmpty)
        XCTAssertFalse(stored.timezoneIdentifier.isEmpty)
    }

    func testLocalRecordRepositoryBuildsStoredWorkoutRecord() {
        let date = Date(timeIntervalSince1970: 1_772_323_200)
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        let workout = WorkoutLog(
            type: .strength,
            durationMinutes: 45,
            averageHeartRate: 126,
            calories: 240,
            note: "lower body",
            createdAt: date,
            source: .manual
        )

        let stored = LocalRecordRepository.storedWorkout(workout, timeZone: losAngeles)

        XCTAssertEqual(stored.type, .strength)
        XCTAssertEqual(stored.durationMinutes, 45)
        XCTAssertEqual(stored.averageHeartRate, 126)
        XCTAssertEqual(stored.localDate, "2026-02-28")
        XCTAssertEqual(stored.timezoneIdentifier, "America/Los_Angeles")
    }

    func testStoredSleepRecordMapsToSleepLog() {
        let date = Date(timeIntervalSince1970: 1_772_323_200)
        let shanghai = TimeZone(identifier: "Asia/Shanghai")!
        let stored = StoredSleepRecord(
            hoursSlept: 6.5,
            quality: .fair,
            note: "Light sleep",
            createdAt: date,
            timeZone: shanghai
        )

        let log = stored.sleepLog

        XCTAssertEqual(log.hoursSlept, 6.5)
        XCTAssertEqual(log.quality, .fair)
        XCTAssertEqual(log.note, "Light sleep")
        XCTAssertEqual(stored.localDate, "2026-03-01")
        XCTAssertEqual(stored.timezoneIdentifier, "Asia/Shanghai")
    }

    func testStoredWaterRecordMapsToWaterLog() {
        let date = Date(timeIntervalSince1970: 1_772_323_200)
        let shanghai = TimeZone(identifier: "Asia/Shanghai")!
        let stored = StoredWaterRecord(
            cupDelta: 1,
            loggedAt: date,
            note: "morning",
            timeZone: shanghai
        )

        let log = stored.waterLog

        XCTAssertEqual(log.cupDelta, 1)
        XCTAssertEqual(log.loggedAt, date)
        XCTAssertEqual(log.note, "morning")
        XCTAssertEqual(stored.localDate, "2026-03-01")
        XCTAssertEqual(stored.timezoneIdentifier, "Asia/Shanghai")
    }

    func testStoredSupplementRecordMapsToSupplementLog() {
        let date = Date(timeIntervalSince1970: 1_772_323_200)
        let stored = StoredSupplementRecord(
            category: .creatine,
            name: "Creatine",
            dosage: "5g",
            takenAt: date
        )

        let log = stored.supplementLog

        XCTAssertEqual(log.category, .creatine)
        XCTAssertEqual(log.name, "Creatine")
        XCTAssertEqual(log.dosage, "5g")
        XCTAssertEqual(log.takenAt, date)
    }

    func testStoredMeasurementRecordMapsToMeasurementLog() {
        let date = Date(timeIntervalSince1970: 1_772_323_200)
        let stored = StoredMeasurementRecord(
            kind: .waist,
            value: 78.5,
            takenAt: date
        )

        let log = stored.measurementLog

        XCTAssertEqual(log.kind, .waist)
        XCTAssertEqual(log.value, 78.5)
        XCTAssertEqual(log.unit, "cm")
        XCTAssertEqual(log.takenAt, date)
    }

    func testMeasurementBodyFatUsesPercentDefaultUnit() {
        let log = MeasurementLog(kind: .bodyFatPercentage, value: 18.4)
        XCTAssertEqual(log.unit, "%")
    }

    func testStoredDailyStrategyRoundTripsThroughPayload() throws {
        let strategy = TodayStrategy(
            localDate: Date(timeIntervalSince1970: 1_772_323_200),
            items: [
                StrategyItem(
                    type: .nutrition,
                    priority: 80,
                    title: "今日轻量推进",
                    actions: [
                        StrategyAction(code: "snap_one_meal", label: "拍一餐", reason: "记录稳定优先")
                    ]
                )
            ]
        )
        let payload = try JSONEncoder().encode(strategy)
        let stored = StoredDailyStrategy(
            localDate: "2026-03-01",
            payload: payload
        )

        let decoded = try XCTUnwrap(stored.strategy)
        XCTAssertEqual(decoded.items.count, 1)
        XCTAssertEqual(decoded.items.first?.title, "今日轻量推进")
        XCTAssertEqual(decoded.items.first?.actions.first?.code, "snap_one_meal")
    }

    func testStoredWeeklyReviewRoundTripsThroughPayload() throws {
        let review = WeeklyReview(
            weekStartDate: Date(timeIntervalSince1970: 1_772_323_200),
            completedTaskCount: 4,
            taskCompletionRate: 0.6,
            strongestHabit: "午餐前拍一下",
            biggestObstacle: nil,
            nextWeekFocus: "保持现在的节奏",
            aiSummary: "本周完成了 4 次小任务"
        )
        let payload = try JSONEncoder().encode(review)
        let stored = StoredWeeklyReview(
            weekStartLocalDate: "2026-03-01",
            payload: payload
        )

        let decoded = try XCTUnwrap(stored.review)
        XCTAssertEqual(decoded.completedTaskCount, 4)
        XCTAssertEqual(decoded.taskCompletionRate, 0.6, accuracy: 0.001)
        XCTAssertEqual(decoded.strongestHabit, "午餐前拍一下")
    }

    func testEnergyCalculatorUsesProfileInputs() {
        let bmr = EnergyCalculator.basalMetabolicRate(
            sex: .female,
            weightKilograms: 68,
            heightCentimeters: 170,
            age: 32
        )
        let workout = EnergyCalculator.workoutCalories(
            type: .running,
            weightKilograms: 68,
            durationMinutes: 30,
            averageHeartRate: 145,
            age: 32
        )

        XCTAssertEqual(bmr, 1_422)
        XCTAssertGreaterThan(workout, 260)
    }
}
