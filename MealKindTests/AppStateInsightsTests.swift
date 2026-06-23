import XCTest
@testable import MealKind

@MainActor
final class AppStateInsightsTests: XCTestCase {
    func testBudgetOnlyCountsTodayMeals() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let state = AppState(
            selectedPlan: .lifestyleCut,
            profile: UserEnergyProfile(basalMetabolicRate: 1_520, activityCalories: 420, exerciseCalories: 180),
            meals: [
                MealLog(name: "Today", calories: 400, createdAt: today),
                MealLog(name: "Yesterday", calories: 900, createdAt: yesterday)
            ],
            waterCups: 0,
            weightKilograms: 68
        )

        XCTAssertEqual(state.eatenCalories, 400)
        XCTAssertEqual(state.budget.remaining, 1_270)
    }

    func testInsightsSummaryUsesSevenDayRecords() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let older = calendar.date(byAdding: .day, value: -8, to: today)!
        let summary = InsightsSummary.make(
            meals: [
                MealLog(name: "Lunch", calories: 1_700, createdAt: today),
                MealLog(name: "Dinner", calories: 1_800, createdAt: yesterday),
                MealLog(name: "Old", calories: 3_000, createdAt: older)
            ],
            profile: UserEnergyProfile(basalMetabolicRate: 1_520, activityCalories: 420, exerciseCalories: 180),
            plan: .lifestyleCut,
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(summary.loggedMeals, 2)
        XCTAssertEqual(summary.days.count, 7)
        XCTAssertEqual(summary.weeklyBalance, 160)
    }

    func testInsightsSummaryCountsLoggedDaysAndCurrentStreak() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: today)!
        let summary = InsightsSummary.make(
            meals: [
                MealLog(name: "Today", calories: 420, createdAt: today),
                MealLog(name: "Yesterday", calories: 520, createdAt: oneDayAgo),
                MealLog(name: "Two days ago", calories: 480, createdAt: twoDaysAgo),
                MealLog(name: "Four days ago", calories: 610, createdAt: fourDaysAgo)
            ],
            profile: UserEnergyProfile(basalMetabolicRate: 1_520, activityCalories: 420, exerciseCalories: 180),
            plan: .lifestyleCut,
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(summary.loggedDayCount, 4)
        XCTAssertEqual(summary.currentLoggingStreak, 3)
    }

    func testDefaultHabitSystemCreatesThreeDailyTasks() {
        let state = AppState(
            selectedPlan: .lifestyleCut,
            profile: UserEnergyProfile(basalMetabolicRate: 1_520, activityCalories: 420, exerciseCalories: 180),
            meals: [],
            waterCups: 0,
            weightKilograms: 68,
            language: .simplifiedChinese
        )

        XCTAssertEqual(state.activeHabits.count, 3)
        XCTAssertEqual(state.todayTasks.count, 3)
        XCTAssertEqual(state.completedTodayTaskCount, 0)
    }

    func testCompletingTaskUpdatesProgressAndCelebration() {
        let state = AppState(
            selectedPlan: .lifestyleCut,
            profile: UserEnergyProfile(basalMetabolicRate: 1_520, activityCalories: 420, exerciseCalories: 180),
            meals: [],
            waterCups: 0,
            weightKilograms: 68,
            language: .simplifiedChinese
        )

        let firstTask = state.todayTasks[0]
        state.completeTask(id: firstTask.id)

        XCTAssertEqual(state.completedTodayTaskCount, 1)
        XCTAssertEqual(state.todayCompletionText, "1 / 3")
        XCTAssertFalse(state.latestCelebration?.isEmpty ?? true)
    }

    func testSavingScannedMealCompletesMealPhotoTask() {
        let state = AppState(
            selectedPlan: .lifestyleCut,
            profile: UserEnergyProfile(basalMetabolicRate: 1_520, activityCalories: 420, exerciseCalories: 180),
            meals: [],
            waterCups: 0,
            weightKilograms: 68,
            language: .simplifiedChinese
        )

        state.saveScannedMeal()

        XCTAssertEqual(state.todayMeals.count, 1)
        XCTAssertEqual(state.todayTasks.first(where: { $0.taskType == .mealPhoto })?.status, .completed)
    }

    func testReminderPlannerUsesGentlePromptLanguage() {
        let reminders = ReminderPlanner.defaults(language: .simplifiedChinese)

        XCTAssertEqual(reminders.map(\.type), [.mealBefore, .sleepBefore, .weeklyReview])
        XCTAssertFalse(reminders.contains { $0.title.contains("还没") || $0.body.contains("落后") })
    }

    func testReminderPlannerDefaultScheduleTimes() {
        let meal = ReminderPlanner.defaultDateComponents(for: .mealBefore)
        let sleep = ReminderPlanner.defaultDateComponents(for: .sleepBefore)
        let review = ReminderPlanner.defaultDateComponents(for: .weeklyReview)

        XCTAssertEqual(meal.hour, 11)
        XCTAssertEqual(meal.minute, 45)
        XCTAssertEqual(sleep.hour, 22)
        XCTAssertEqual(sleep.minute, 15)
        XCTAssertEqual(review.weekday, 1)
        XCTAssertEqual(review.hour, 20)
        XCTAssertEqual(review.minute, 30)
    }

    func testAICoachAvoidsPunitiveAdvice() {
        let reply = AICoachAdvisor.reply(to: "今天吃多了怎么办", language: .simplifiedChinese)

        XCTAssertTrue(reply.contains("不用补偿"))
        XCTAssertTrue(reply.contains("不要跳过下一餐"))
        XCTAssertFalse(reply.contains("惩罚"))
    }

    func testWeeklyReviewGeneratorSummarizesBehaviorProgress() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 6, day: 17, hour: 12))!
        let habits = Habit.defaults(language: .simplifiedChinese)
        var tasks = DailyTask.defaults(from: habits, language: .simplifiedChinese)
        tasks[0].status = .completed
        tasks[0].completedAt = today
        tasks[1].status = .completed
        tasks[1].completedAt = today
        tasks[2].status = .pending

        let review = WeeklyReviewGenerator.make(
            tasks: tasks,
            habits: habits,
            meals: [],
            language: .simplifiedChinese,
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(review.completedTaskCount, 2)
        XCTAssertEqual(review.taskCompletionRate, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(review.strongestHabit, habits[0].title)
        XCTAssertTrue(review.aiSummary.contains("本周你完成了 2 次小任务"))
        XCTAssertEqual(review.difficultyAdjustment, .keep)
    }

    func testWeeklyReviewGeneratorFlagsSkippedTaskAsObstacle() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 6, day: 17, hour: 12))!
        let habits = Habit.defaults(language: .simplifiedChinese)
        var tasks = DailyTask.defaults(from: habits, language: .simplifiedChinese)
        tasks[0].status = .skipped

        let review = WeeklyReviewGenerator.make(
            tasks: tasks,
            habits: habits,
            meals: [],
            language: .simplifiedChinese,
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(review.biggestObstacle, "有任务感觉太难")
        XCTAssertEqual(review.difficultyAdjustment, .makeEasier)
    }

    func testWeeklyReviewGeneratorSuggestsEasierDifficultyWhenCompletionIsLow() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 6, day: 17, hour: 12))!
        let habits = Habit.defaults(language: .english)
        var tasks = DailyTask.defaults(from: habits, language: .english)
        tasks[0].status = .completed
        tasks[0].completedAt = today
        tasks[1].status = .pending
        tasks[2].status = .pending

        let review = WeeklyReviewGenerator.make(
            tasks: tasks,
            habits: habits,
            meals: [],
            language: .english,
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(review.taskCompletionRate, 1.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(review.difficultyAdjustment, .makeEasier)
    }

    func testWeeklyHabitProgressCountsHabitCompletions() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 6, day: 17, hour: 12))!
        let habits = Habit.defaults(language: .simplifiedChinese)
        var tasks = DailyTask.defaults(from: habits, language: .simplifiedChinese)
        tasks[0].status = .completed
        tasks[0].completedAt = today
        tasks[1].status = .skipped
        tasks[2].status = .pending

        let progress = WeeklyReviewGenerator.habitProgress(
            habits: habits,
            tasks: tasks,
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(progress.count, 3)
        XCTAssertEqual(progress[0].title, habits[0].title)
        XCTAssertEqual(progress[0].completedCount, 1)
        XCTAssertEqual(progress[0].plannedCount, 1)
        XCTAssertEqual(progress[0].completionRate, 1)
        XCTAssertTrue(progress[1].hasSkippedTask)
    }

    func testBodyOSAdherenceReflectsTaskSleepAndWorkoutSignals() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.date(from: DateComponents(year: 2026, month: 6, day: 17))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        var tasks = DailyTask.defaults(from: Habit.defaults(language: .english), language: .english)
        tasks[0].status = .completed
        tasks[0].completedAt = today
        tasks[1].status = .completed
        tasks[1].completedAt = yesterday
        tasks[2].status = .pending

        let summary = InsightsSummary.make(
            meals: [
                MealLog(name: "Lunch", calories: 480, createdAt: today),
                MealLog(name: "Lunch", calories: 510, createdAt: yesterday)
            ],
            profile: UserEnergyProfile(basalMetabolicRate: 1_520, activityCalories: 420, exerciseCalories: 180),
            plan: .lifestyleCut,
            workouts: [
                WorkoutLog(type: .strength, durationMinutes: 30, calories: 240, createdAt: yesterday)
            ],
            sleepLogs: [
                SleepLog(hoursSlept: 7.5, quality: .good, createdAt: today),
                SleepLog(hoursSlept: 6.5, quality: .fair, createdAt: yesterday),
                SleepLog(hoursSlept: 6.0, quality: .fair, createdAt: twoDaysAgo)
            ],
            supplementLogs: [
                SupplementLog(category: .creatine, name: "Creatine", takenAt: today),
                SupplementLog(category: .fishOil, name: "Fish oil", takenAt: yesterday)
            ],
            dailyTasks: tasks,
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(summary.adherence.mealLoggedDayCount, 2)
        XCTAssertEqual(summary.adherence.workoutDayCount, 1)
        XCTAssertEqual(summary.adherence.sleepLoggedDayCount, 3)
        XCTAssertEqual(summary.adherence.supplementDayCount, 2)
        XCTAssertEqual(summary.adherence.taskCompletionRate, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertGreaterThan(summary.adherence.overallRate, 0.3)
    }

    func testFoodAnalysisContextReflectsBodyOSState() {
        let state = AppState(
            selectedPlan: .lifestyleCut,
            profile: UserEnergyProfile(basalMetabolicRate: 1_520, activityCalories: 420, exerciseCalories: 180),
            meals: [
                MealLog(name: "Lunch", calories: 540, protein: 28, carbs: 60, fat: 18)
            ],
            waterCups: 4,
            weightKilograms: 68,
            language: .english,
            experienceMode: .professional
        )

        let context = state.foodAnalysisContext()

        XCTAssertEqual(context.userMode, "advanced")
        XCTAssertEqual(context.dailyConsumed.calories, 540)
        XCTAssertEqual(context.dailyConsumed.protein, 28)
        XCTAssertGreaterThan(context.nutritionTarget.calories, 0)
        XCTAssertFalse(context.todayStrategySummary.isEmpty)
    }

    func testSavingSleepFeedsRecoveryEngine() {
        let state = AppState(
            selectedPlan: .lifestyleCut,
            profile: UserEnergyProfile(basalMetabolicRate: 1_520, activityCalories: 420, exerciseCalories: 180),
            meals: [],
            waterCups: 5,
            weightKilograms: 68,
            language: .english
        )

        let baseline = state.bodyOSRecoveryScore
        state.saveSleep(SleepLog(hoursSlept: 8, quality: .good))
        let withSleep = state.bodyOSRecoveryScore

        XCTAssertGreaterThan(withSleep.value, baseline.value)
        XCTAssertTrue(withSleep.factors.contains("sleep_good"))
    }

    func testSavingShortSleepRaisesSleepDebtSignal() {
        let state = AppState(
            selectedPlan: .lifestyleCut,
            profile: UserEnergyProfile(basalMetabolicRate: 1_520, activityCalories: 420, exerciseCalories: 180),
            meals: [],
            waterCups: 5,
            weightKilograms: 68,
            language: .english
        )

        state.saveSleep(SleepLog(hoursSlept: 4.5, quality: .poor))
        let recovery = state.bodyOSRecoveryScore

        XCTAssertTrue(recovery.factors.contains("sleep_debt"))
    }

    func testDataExportSnapshotIncludesHabitTaskMealAndReview() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let habits = Habit.defaults(language: .simplifiedChinese)
        var tasks = DailyTask.defaults(from: habits, language: .simplifiedChinese)
        tasks[0].status = .completed
        tasks[0].completedAt = date
        let meals = [
            MealLog(name: "午餐", calories: 520, protein: 28, carbs: 58, fat: 16, createdAt: date, source: .camera)
        ]
        let review = WeeklyReviewGenerator.make(
            tasks: tasks,
            habits: habits,
            meals: meals,
            language: .simplifiedChinese,
            today: date
        )

        let snapshot = DataExportSnapshot.make(
            generatedAt: date,
            currentWeightKg: 68,
            targetWeightKg: 62,
            habits: habits,
            tasks: tasks,
            meals: meals,
            weeklyReview: review
        )
        let json = snapshot.jsonString()

        XCTAssertTrue(json.contains("\"habits\""))
        XCTAssertTrue(json.contains("\"tasks\""))
        XCTAssertTrue(json.contains("\"meals\""))
        XCTAssertTrue(json.contains("\"weeklyReview\""))
        XCTAssertTrue(json.contains("\"weeklyReviewDifficultyAdjustment\""))
        XCTAssertTrue(json.contains("\"weeklyHabitProgress\""))
        XCTAssertTrue(json.contains("\"completionRate\""))
        XCTAssertTrue(json.contains("\"makeEasier\""))
        XCTAssertTrue(json.contains("午餐"))
    }
}
