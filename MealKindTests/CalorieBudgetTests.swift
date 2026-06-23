import XCTest
@testable import MealKind

final class CalorieBudgetTests: XCTestCase {
    func testDailyGoalUsesBurnMinusPlanDeficit() {
        let budget = CalorieBudget(
            profile: UserEnergyProfile(basalMetabolicRate: 1_520, activityCalories: 420, exerciseCalories: 180),
            plan: .lifestyleCut,
            eatenCalories: 920
        )

        XCTAssertEqual(budget.burnBeforeDeficit, 2_120)
        XCTAssertEqual(budget.dailyGoal, 1_670)
        XCTAssertEqual(budget.remaining, 750)
    }

    func testDailyGoalDoesNotDropBelowSafetyFloor() {
        let budget = CalorieBudget(
            profile: UserEnergyProfile(basalMetabolicRate: 1_200, activityCalories: 100, exerciseCalories: 0),
            plan: .carbStepDown,
            eatenCalories: 0
        )

        XCTAssertEqual(budget.dailyGoal, 1_200)
    }

    func testOverBudgetStatusUsesAbsoluteAmount() {
        let budget = CalorieBudget(
            profile: UserEnergyProfile(basalMetabolicRate: 1_520, activityCalories: 420, exerciseCalories: 180),
            plan: .lifestyleCut,
            eatenCalories: 1_900
        )

        XCTAssertTrue(budget.isOverBudget)
        XCTAssertEqual(budget.statusTitle, "Over by")
        XCTAssertEqual(budget.statusAmount, 230)
    }

    func testCurrentDeficitUsesBurnMinusIntake() {
        let budget = CalorieBudget(
            profile: UserEnergyProfile(basalMetabolicRate: 1_520, activityCalories: 420, exerciseCalories: 180),
            plan: .lifestyleCut,
            eatenCalories: 1_520
        )

        XCTAssertEqual(budget.currentDeficit, 600)
        XCTAssertEqual(budget.targetDeficitRange, 330...570)
    }
}
