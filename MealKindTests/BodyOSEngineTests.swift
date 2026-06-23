import XCTest
@testable import MealKind

final class BodyOSEngineTests: XCTestCase {
    private let profile = BodyOSProfile(
        mode: .advanced,
        sex: .male,
        age: 34,
        heightCentimeters: 178,
        weightKilograms: 80
    )

    func testCycleEngineResolvesThreeOnOneOffRestDay() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let current = calendar.date(from: DateComponents(year: 2026, month: 6, day: 4))!

        let cycle = CycleEngine().resolve(
            input: CycleInput(
                template: .threeOnOneOff,
                startDate: start,
                currentDate: current,
                calendar: calendar
            )
        )

        XCTAssertEqual(cycle.dayIndex, 4)
        XCTAssertEqual(cycle.focus, .rest)
        XCTAssertFalse(cycle.isPlannedTrainingDay)
    }

    func testCycleEngineResolvesPushPullLegsFocus() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let current = calendar.date(from: DateComponents(year: 2026, month: 6, day: 3))!

        let cycle = CycleEngine().resolve(
            input: CycleInput(
                template: .pushPullLegs,
                startDate: start,
                currentDate: current,
                calendar: calendar
            )
        )

        XCTAssertEqual(cycle.dayIndex, 3)
        XCTAssertEqual(cycle.focus, .legs)
        XCTAssertTrue(cycle.isPlannedTrainingDay)
    }

    func testCycleEngineUsesCustomPattern() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let current = calendar.date(from: DateComponents(year: 2026, month: 6, day: 2))!

        let cycle = CycleEngine().resolve(
            input: CycleInput(
                template: .custom,
                startDate: start,
                currentDate: current,
                customTrainingPattern: [.upper, .rest],
                calendar: calendar
            )
        )

        XCTAssertEqual(cycle.focus, .rest)
        XCTAssertFalse(cycle.isPlannedTrainingDay)
    }

    func testStateEngineInjuryOverridesPlannedTraining() {
        let input = BodyOSStateInput(
            profile: profile,
            plannedTrainingState: .normalTraining,
            recoveryScore: RecoveryScore(value: 82, state: .good, factors: []),
            events: [BodyOSEvent(type: .injury, title: "Knee pain", severity: 3)]
        )

        let state = StateEngine().resolve(input: input)

        XCTAssertEqual(state.trainingState, .injured)
        XCTAssertEqual(state.priority, 100)
        XCTAssertTrue(state.shouldOverridePlannedTraining)
    }

    func testStateEngineCriticalRecoveryDeloadsTraining() {
        let input = BodyOSStateInput(
            profile: profile,
            plannedTrainingState: .normalTraining,
            recoveryScore: RecoveryScore(value: 32, state: .critical, factors: ["sleep_debt"])
        )

        let state = StateEngine().resolve(input: input)

        XCTAssertEqual(state.trainingState, .deload)
        XCTAssertEqual(state.recoveryState, .critical)
        XCTAssertTrue(state.shouldOverridePlannedTraining)
    }

    func testRecoveryEngineClassifiesCriticalRecovery() {
        let score = RecoveryEngine().calculate(
            input: RecoveryInput(
                sleepHours: 4.5,
                hrv: 30,
                restingHeartRate: 82,
                waterCups: 1,
                fatigueRating: 9
            )
        )

        XCTAssertEqual(score.state, .critical)
        XCTAssertTrue(score.factors.contains("sleep_debt"))
        XCTAssertTrue(score.factors.contains("fatigue_high"))
    }

    func testNutritionEngineLowersLifestyleDeficitForTravelAndLowRecovery() {
        let lifestyleProfile = BodyOSProfile(mode: .lifestyle, weightKilograms: 68)
        let state = BodyState(
            goalState: .fatLoss,
            trainingState: .stopped,
            lifeState: .businessTrip,
            recoveryState: .low,
            priority: 80,
            reasons: ["business_trip"]
        )

        let target = NutritionEngine().calculateTarget(
            input: NutritionInput(
                profile: lifestyleProfile,
                bodyState: state,
                basalMetabolicRate: 1_500,
                activityCalories: 420,
                exerciseCalories: 100
            )
        )

        XCTAssertEqual(target.tdee, 2_020)
        XCTAssertEqual(target.deficit, 250)
        XCTAssertEqual(target.calories, 1_770)
        XCTAssertTrue(target.shouldHideMacroDetails)
    }

    func testNutritionEngineKeepsAdvancedProteinWhenInjured() {
        let state = BodyState(
            goalState: .fatLoss,
            trainingState: .injured,
            lifeState: .normal,
            recoveryState: .moderate,
            priority: 100,
            reasons: ["injury"]
        )

        let target = NutritionEngine().calculateTarget(
            input: NutritionInput(
                profile: profile,
                bodyState: state,
                basalMetabolicRate: 1_800,
                activityCalories: 500,
                exerciseCalories: 0
            )
        )

        XCTAssertEqual(target.protein, 160)
        XCTAssertEqual(target.deficit, 500)
        XCTAssertFalse(target.shouldHideMacroDetails)
    }

    func testStrategyEnginePartyDayAvoidsCompensationLanguage() {
        let state = BodyState(
            goalState: .fatLoss,
            trainingState: .normalTraining,
            lifeState: .party,
            recoveryState: .moderate,
            priority: 70,
            reasons: ["party"]
        )
        let target = NutritionTarget(calories: 1_900, protein: 110, carbs: 190, fat: 60, deficit: 400, tdee: 2_300, shouldHideMacroDetails: true)

        let strategy = StrategyEngine().generate(
            input: StrategyInput(
                profile: BodyOSProfile(mode: .lifestyle, weightKilograms: 68),
                bodyState: state,
                cycle: BodyOSCycle(),
                nutritionTarget: target,
                dailySummary: .empty,
                recoveryScore: nil
            ),
            localDate: Date(timeIntervalSince1970: 0)
        )

        let text = strategy.items.flatMap(\.actions).map(\.label).joined(separator: " ")
        XCTAssertTrue(text.contains("不用饿回来"))
        XCTAssertFalse(text.contains("惩罚"))
        XCTAssertFalse(text.contains("失败"))
    }

    func testStrategyEngineHighCaloriesGivesRecoveryPlan() {
        let state = BodyState(
            goalState: .fatLoss,
            trainingState: .normalTraining,
            lifeState: .normal,
            recoveryState: .moderate,
            priority: 30,
            reasons: []
        )
        let target = NutritionTarget(calories: 1_800, protein: 120, carbs: 170, fat: 55, deficit: 450, tdee: 2_250, shouldHideMacroDetails: true)

        let strategy = StrategyEngine().generate(
            input: StrategyInput(
                profile: BodyOSProfile(mode: .lifestyle, weightKilograms: 68),
                bodyState: state,
                cycle: BodyOSCycle(),
                nutritionTarget: target,
                dailySummary: DailyNutritionSummary(caloriesIn: 2_200, protein: 80, carbs: 260, fat: 80),
                recoveryScore: nil
            ),
            localDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(strategy.items.first?.title, "今天慢慢收回来")
        let text = strategy.items.flatMap(\.actions).map { "\($0.label) \($0.reason)" }.joined(separator: " ")
        XCTAssertTrue(text.contains("明天照常继续"))
        XCTAssertFalse(text.contains("失败"))
    }

    func testStrategyExplanationLayerTranslatesEngineOutputForLifestyleUser() {
        let state = BodyState(
            goalState: .fatLoss,
            trainingState: .normalTraining,
            lifeState: .normal,
            recoveryState: .moderate,
            priority: 30,
            reasons: []
        )
        let target = NutritionTarget(calories: 1_800, protein: 120, carbs: 170, fat: 55, deficit: 450, tdee: 2_250, shouldHideMacroDetails: true)
        let strategy = StrategyEngine().generate(
            input: StrategyInput(
                profile: BodyOSProfile(mode: .lifestyle, weightKilograms: 68),
                bodyState: state,
                cycle: BodyOSCycle(),
                nutritionTarget: target,
                dailySummary: DailyNutritionSummary(caloriesIn: 2_200, protein: 80, carbs: 260, fat: 80),
                recoveryScore: nil
            ),
            localDate: Date(timeIntervalSince1970: 0)
        )

        let explanation = StrategyExplanationLayer.explain(
            strategy: strategy,
            bodyState: state,
            nutritionTarget: target,
            dailySummary: DailyNutritionSummary(caloriesIn: 2_200, protein: 80, carbs: 260, fat: 80),
            userMode: .lifestyle,
            language: .simplifiedChinese
        )

        XCTAssertEqual(explanation.primaryAction, strategy.items.first?.actions.first?.label)
        XCTAssertEqual(explanation.sourceStrategyType, .nutrition)
        XCTAssertTrue(explanation.supportingText.contains("下一餐"))
        XCTAssertFalse(explanation.supportingText.contains("失败"))
    }

    func testStrategyExplanationLayerPrioritizesBodyStateWhenInjured() {
        let state = BodyState(
            goalState: .fatLoss,
            trainingState: .injured,
            lifeState: .normal,
            recoveryState: .moderate,
            priority: 100,
            reasons: ["injury"]
        )
        let target = NutritionTarget(calories: 1_900, protein: 130, carbs: 160, fat: 60, deficit: 300, tdee: 2_200, shouldHideMacroDetails: false)
        let strategy = TodayStrategy(
            localDate: Date(timeIntervalSince1970: 0),
            items: [
                StrategyItem(
                    type: .training,
                    priority: 95,
                    title: "今天训练先放一放",
                    actions: [
                        StrategyAction(code: "avoid_intensity", label: "受伤的地方今天别硬练", reason: "先让身体缓一缓。")
                    ]
                )
            ]
        )

        let explanation = StrategyExplanationLayer.explain(
            strategy: strategy,
            bodyState: state,
            nutritionTarget: target,
            dailySummary: .empty,
            userMode: .advanced,
            language: .simplifiedChinese
        )

        XCTAssertEqual(explanation.headline, "今天先照顾身体")
        XCTAssertEqual(explanation.primaryAction, "受伤的地方今天别硬练")
        XCTAssertTrue(explanation.supportingText.contains("不用硬扛"))
    }

    func testBodyOSProfileCarriesProfileFields() {
        let bodyProfile = BodyOSProfile(
            mode: .advanced,
            sex: .male,
            age: 30,
            heightCentimeters: 180,
            weightKilograms: 82,
            targetWeightKilograms: 78,
            activityLevel: .moderate,
            trainingExperience: .intermediate,
            language: .simplifiedChinese,
            timezone: "America/Los_Angeles"
        )

        XCTAssertEqual(bodyProfile.targetWeightKilograms, 78)
        XCTAssertEqual(bodyProfile.activityLevel, .moderate)
        XCTAssertEqual(bodyProfile.trainingExperience, .intermediate)
        XCTAssertEqual(bodyProfile.language, .simplifiedChinese)
        XCTAssertEqual(bodyProfile.timezone, "America/Los_Angeles")
    }

    func testDerivedActivityLevelReflectsWorkoutFrequency() {
        var energyProfile = UserEnergyProfile(
            basalMetabolicRate: 1_600,
            activityCalories: 400,
            exerciseCalories: 0
        )
        energyProfile.workEnvironment = .office
        energyProfile.hasExerciseHabit = true
        energyProfile.weeklyWorkoutCount = 5

        XCTAssertEqual(energyProfile.derivedActivityLevel, .active)

        energyProfile.weeklyWorkoutCount = 2
        XCTAssertEqual(energyProfile.derivedActivityLevel, .light)

        energyProfile.hasExerciseHabit = false
        energyProfile.weeklyWorkoutCount = 0
        energyProfile.workEnvironment = .driver
        XCTAssertEqual(energyProfile.derivedActivityLevel, .low)
    }
}
