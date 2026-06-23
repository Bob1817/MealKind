import Foundation

protocol StateEngineProtocol {
    func resolve(input: BodyOSStateInput) -> BodyState
}

protocol CycleEngineProtocol {
    func resolve(input: CycleInput) -> BodyOSCycle
}

protocol NutritionEngineProtocol {
    func calculateTarget(input: NutritionInput) -> NutritionTarget
}

protocol RecoveryEngineProtocol {
    func calculate(input: RecoveryInput) -> RecoveryScore
}

protocol StrategyEngineProtocol {
    func generate(input: StrategyInput, localDate: Date) -> TodayStrategy
}

struct CycleEngine: CycleEngineProtocol {
    func resolve(input: CycleInput) -> BodyOSCycle {
        let daysSinceStart = max(
            input.calendar.dateComponents([.day], from: input.startDate, to: input.currentDate).day ?? 0,
            0
        )
        let focus = focus(for: input.template, dayOffset: daysSinceStart, customPattern: input.customTrainingPattern)
        return BodyOSCycle(
            type: input.type,
            template: input.template,
            dayIndex: daysSinceStart + 1,
            focus: focus,
            isPlannedTrainingDay: focus != .rest
        )
    }

    private func focus(
        for template: BodyOSTrainingTemplate,
        dayOffset: Int,
        customPattern: [BodyOSWorkoutFocus]
    ) -> BodyOSWorkoutFocus {
        switch template {
        case .threeOnOneOff:
            return dayOffset % 4 == 3 ? .rest : .fullBody
        case .pushPullLegs:
            let pattern: [BodyOSWorkoutFocus] = [.push, .pull, .legs, .rest]
            return pattern[dayOffset % pattern.count]
        case .upperLower:
            let pattern: [BodyOSWorkoutFocus] = [.upper, .lower, .rest]
            return pattern[dayOffset % pattern.count]
        case .custom:
            guard !customPattern.isEmpty else { return .custom }
            return customPattern[dayOffset % customPattern.count]
        }
    }
}

struct StateEngine: StateEngineProtocol {
    func resolve(input: BodyOSStateInput) -> BodyState {
        let eventTypes = Set(input.events.map(\.type))
        let recoveryState = input.recoveryScore?.state ?? .moderate
        var trainingState = input.cycle.isPlannedTrainingDay ? input.plannedTrainingState : .restDay
        var lifeState: BodyOSLifeState = .normal
        var priority = input.cycle.isPlannedTrainingDay ? 30 : 20
        var reasons: [String] = []

        if eventTypes.contains(.injury) {
            trainingState = .injured
            priority = 100
            reasons.append("injury")
        } else if recoveryState == .critical {
            trainingState = .deload
            priority = 95
            reasons.append("critical_recovery")
        } else if eventTypes.contains(.illness) || input.goalState == .recovery {
            trainingState = .stopped
            lifeState = .illness
            priority = 90
            reasons.append("illness_or_recovery")
        } else if eventTypes.contains(.businessTrip) {
            trainingState = .stopped
            lifeState = .businessTrip
            priority = 80
            reasons.append("business_trip")
        } else if eventTypes.contains(.travel) {
            trainingState = .stopped
            lifeState = .travel
            priority = 78
            reasons.append("travel")
        } else if eventTypes.contains(.party) {
            lifeState = .party
            priority = 70
            reasons.append("party")
        } else if eventTypes.contains(.holiday) {
            lifeState = .holiday
            priority = 65
            reasons.append("holiday")
        } else if eventTypes.contains(.highExpenditure) {
            priority = 60
            reasons.append("high_expenditure")
        } else if eventTypes.contains(.trainingStopped) {
            trainingState = .stopped
            priority = 75
            reasons.append("training_stopped")
        } else if eventTypes.contains(.highStress) {
            lifeState = .highStress
            priority = 55
            reasons.append("high_stress")
        }

        if eventTypes.contains(.lowRecovery), recoveryState != .critical {
            reasons.append("low_recovery")
        }

        return BodyState(
            goalState: input.goalState,
            trainingState: trainingState,
            lifeState: lifeState,
            recoveryState: recoveryState,
            priority: priority,
            reasons: reasons
        )
    }
}

struct RecoveryEngine: RecoveryEngineProtocol {
    func calculate(input: RecoveryInput) -> RecoveryScore {
        var score = 70
        var factors: [String] = []

        if let sleepHours = input.sleepHours {
            if sleepHours >= 7 {
                score += 12
                factors.append("sleep_good")
            } else if sleepHours < 5.5 {
                score -= 22
                factors.append("sleep_debt")
            }
        }

        if let hrv = input.hrv {
            if hrv >= 55 {
                score += 8
                factors.append("hrv_good")
            } else if hrv < 35 {
                score -= 14
                factors.append("hrv_low")
            }
        }

        if let restingHeartRate = input.restingHeartRate {
            if restingHeartRate <= 62 {
                score += 5
                factors.append("resting_hr_good")
            } else if restingHeartRate >= 78 {
                score -= 12
                factors.append("resting_hr_high")
            }
        }

        if input.waterCups >= 6 {
            score += 5
            factors.append("hydration_good")
        } else if input.waterCups <= 2 {
            score -= 8
            factors.append("hydration_low")
        }

        if let fatigueRating = input.fatigueRating {
            if fatigueRating >= 8 {
                score -= 25
                factors.append("fatigue_high")
            } else if fatigueRating <= 3 {
                score += 5
                factors.append("fatigue_low")
            }
        }

        let clamped = min(max(score, 0), 100)
        let state: BodyOSRecoveryState
        switch clamped {
        case 80...100:
            state = .good
        case 60..<80:
            state = .moderate
        case 40..<60:
            state = .low
        default:
            state = .critical
        }

        return RecoveryScore(value: clamped, state: state, factors: factors)
    }
}

struct NutritionEngine: NutritionEngineProtocol {
    func calculateTarget(input: NutritionInput) -> NutritionTarget {
        let tdee = max(input.basalMetabolicRate + input.activityCalories + input.exerciseCalories, 1_200)
        let deficit = targetDeficit(input: input)
        let calories = max(1_200, tdee - deficit)
        let proteinPerKg = proteinPerKilogram(input: input)
        let protein = Int((input.profile.weightKilograms * proteinPerKg).rounded())
        let fat = fatTarget(input: input, calories: calories)
        let usedCalories = protein * 4 + fat * 9
        let carbs = max(50, Int((Double(calories - usedCalories) / 4.0).rounded()))

        return NutritionTarget(
            calories: calories,
            protein: protein,
            carbs: adjustedCarbs(carbs, input: input),
            fat: fat,
            deficit: deficit,
            tdee: tdee,
            shouldHideMacroDetails: input.profile.mode == .lifestyle
        )
    }

    private func targetDeficit(input: NutritionInput) -> Int {
        if input.goalState == .maintenance || input.goalState == .recovery {
            return 0
        }

        let state = input.bodyState
        if input.profile.mode == .lifestyle {
            if state.recoveryState == .low || state.recoveryState == .critical || state.lifeState == .businessTrip || state.lifeState == .travel || state.lifeState == .highStress {
                return 250
            }
            return 450
        }

        if state.recoveryState == .low || state.recoveryState == .critical {
            return 300
        }
        if state.trainingState == .normalTraining || state.trainingState == .returning {
            return 400
        }
        if state.reasons.contains("high_expenditure") {
            return 500
        }
        return 500
    }

    private func proteinPerKilogram(input: NutritionInput) -> Double {
        if input.profile.mode == .lifestyle {
            return 1.4
        }

        switch input.bodyState.trainingState {
        case .injured, .stopped, .returning:
            return 2.0
        default:
            return input.goalState == .fatLoss ? 2.0 : 1.8
        }
    }

    private func fatTarget(input: NutritionInput, calories: Int) -> Int {
        if input.profile.mode == .advanced {
            return Int((input.profile.weightKilograms * 0.7).rounded())
        }
        return Int((Double(calories) * 0.28 / 9.0).rounded())
    }

    private func adjustedCarbs(_ carbs: Int, input: NutritionInput) -> Int {
        switch input.bodyState.trainingState {
        case .injured, .stopped:
            return max(50, carbs - 25)
        case .normalTraining:
            return carbs + (input.profile.mode == .advanced ? 20 : 0)
        default:
            return carbs
        }
    }
}

struct StrategyEngine: StrategyEngineProtocol {
    func generate(input: StrategyInput, localDate: Date = Date()) -> TodayStrategy {
        var items: [StrategyItem] = []
        items.append(nutritionStrategy(input: input))

        if let training = trainingStrategy(input: input) {
            items.append(training)
        }

        if let recovery = recoveryStrategy(input: input) {
            items.append(recovery)
        }

        if input.profile.mode == .advanced {
            items.append(supplementStrategy())
        }

        return TodayStrategy(
            localDate: localDate,
            items: items.sorted { $0.priority > $1.priority }
        )
    }

    private func nutritionStrategy(input: StrategyInput) -> StrategyItem {
        let state = input.bodyState
        let summary = input.dailySummary
        let target = input.nutritionTarget

        if state.lifeState == .party {
            return StrategyItem(
                type: .nutrition,
                priority: 90,
                title: "聚餐也可以轻松一点",
                actions: [
                    StrategyAction(code: "protein_first", label: "先吃几口肉蛋豆和蔬菜", reason: "先垫一垫，再吃主食和喜欢的菜。"),
                    StrategyAction(code: "no_compensation", label: "聚餐后不用饿回来", reason: "第二天恢复平常吃法就好。")
                ]
            )
        }

        if summary.caloriesIn > target.calories + 300 {
            return StrategyItem(
                type: .nutrition,
                priority: 88,
                title: "今天慢慢收回来",
                actions: [
                    StrategyAction(code: "next_meal_simple", label: "下一餐正常吃，主食少一点", reason: "已经吃了就过去了，下一餐清爽一点就行。"),
                    StrategyAction(code: "resume_tomorrow", label: "明天照常继续", reason: "不用因为一餐打乱后面的日子。")
                ]
            )
        }

        if input.profile.mode == .advanced {
            return StrategyItem(
                type: .nutrition,
                priority: 82,
                title: "今天记得吃够蛋白质",
                actions: [
                    StrategyAction(code: "hit_protein", label: "每餐放一点肉蛋豆或奶", reason: "这样更容易吃饱，也更稳。"),
                    StrategyAction(code: "calorie_guardrail", label: "今天大概吃到 \(target.calories) 千卡附近", reason: "不用精确，心里有个大概就好。")
                ]
            )
        }

        return StrategyItem(
            type: .nutrition,
            priority: 78,
            title: "今天做两件小事就够",
            actions: [
                StrategyAction(code: "snap_one_meal", label: "吃饭前拍一餐", reason: "先养成顺手记录的感觉，不用每餐都拍。"),
                StrategyAction(code: "lighter_dinner_starch", label: "晚餐主食少一点点", reason: "小小调整就有用。")
            ]
        )
    }

    private func trainingStrategy(input: StrategyInput) -> StrategyItem? {
        let state = input.bodyState

        switch state.trainingState {
        case .injured:
            return StrategyItem(
                type: .training,
                priority: 95,
                title: "今天训练先放一放",
                actions: [
                    StrategyAction(code: "avoid_intensity", label: "受伤的地方今天别硬练", reason: "先让身体缓一缓。"),
                    StrategyAction(code: "mobility_only", label: "只散步或轻轻拉伸", reason: "能动一点就够了。")
                ]
            )
        case .deload:
            return StrategyItem(
                type: .training,
                priority: 90,
                title: "今天练轻一点",
                actions: [
                    StrategyAction(code: "deload", label: "做到平时一半多就可以", reason: "累的时候不用追求表现。")
                ]
            )
        case .stopped:
            return StrategyItem(
                type: .training,
                priority: 76,
                title: "今天不用补练",
                actions: [
                    StrategyAction(code: "no_makeup_workout", label: "不因为没练就加倍练", reason: "把吃饭和休息照顾好就行。")
                ]
            )
        case .returning:
            return StrategyItem(
                type: .training,
                priority: 80,
                title: "刚恢复，慢慢来",
                actions: [
                    StrategyAction(code: "returning_volume", label: "先做到平时一半多", reason: "先看看身体反应，再慢慢加。")
                ]
            )
        default:
            return nil
        }
    }

    private func recoveryStrategy(input: StrategyInput) -> StrategyItem? {
        guard input.bodyState.recoveryState == .low || input.bodyState.recoveryState == .critical else {
            return nil
        }

        return StrategyItem(
            type: .recovery,
            priority: 84,
            title: "今天早点休息更重要",
            actions: [
                StrategyAction(code: "sleep_focus", label: "今晚尽量早点睡", reason: "睡好了，明天会轻松很多。"),
                StrategyAction(code: "hydration", label: "今天多喝几口水", reason: "喝水是最容易做到的小事。")
            ]
        )
    }

    private func supplementStrategy() -> StrategyItem {
        StrategyItem(
            type: .supplement,
            priority: 45,
            title: "顺手记一下补剂",
            actions: [
                StrategyAction(code: "creatine_check", label: "今天吃了就点一下", reason: "顺手记录，比记得很精确更重要。")
            ]
        )
    }
}
