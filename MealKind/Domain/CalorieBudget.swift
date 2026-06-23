import Foundation

struct CalorieBudget: Equatable {
    var profile: UserEnergyProfile
    var plan: DietPlan
    var eatenCalories: Int

    var burnBeforeDeficit: Int {
        profile.basalMetabolicRate + profile.activityCalories + profile.exerciseCalories
    }

    var dailyGoal: Int {
        max(1_200, burnBeforeDeficit - plan.dailyDeficit)
    }

    var remaining: Int {
        dailyGoal - eatenCalories
    }

    var currentDeficit: Int {
        burnBeforeDeficit - eatenCalories
    }

    var targetDeficitRange: ClosedRange<Int> {
        max(250, plan.dailyDeficit - 120)...(plan.dailyDeficit + 120)
    }

    var deficitRangePosition: Double {
        let displayMin = 0
        let displayMax = max(1_000, targetDeficitRange.upperBound + 220)
        return min(max(Double(currentDeficit - displayMin) / Double(displayMax - displayMin), 0), 1)
    }

    var targetRangeStartPosition: Double {
        let displayMax = max(1_000, targetDeficitRange.upperBound + 220)
        return Double(targetDeficitRange.lowerBound) / Double(displayMax)
    }

    var targetRangeEndPosition: Double {
        let displayMax = max(1_000, targetDeficitRange.upperBound + 220)
        return Double(targetDeficitRange.upperBound) / Double(displayMax)
    }

    var gaugeMinimumDeficit: Int {
        min(0, targetDeficitRange.lowerBound - 520)
    }

    var gaugeMaximumDeficit: Int {
        targetDeficitRange.upperBound + 520
    }

    var deficitGaugePosition: Double {
        let span = max(gaugeMaximumDeficit - gaugeMinimumDeficit, 1)
        let normalizedDeficit = Double(currentDeficit - gaugeMinimumDeficit) / Double(span)
        return min(max(1 - normalizedDeficit, 0), 1)
    }

    var targetGaugeStartPosition: Double {
        let span = max(gaugeMaximumDeficit - gaugeMinimumDeficit, 1)
        return min(max(1 - Double(targetDeficitRange.upperBound - gaugeMinimumDeficit) / Double(span), 0), 1)
    }

    var targetGaugeEndPosition: Double {
        let span = max(gaugeMaximumDeficit - gaugeMinimumDeficit, 1)
        return min(max(1 - Double(targetDeficitRange.lowerBound - gaugeMinimumDeficit) / Double(span), 0), 1)
    }

    var isOverBudget: Bool {
        remaining < 0
    }

    var statusTitle: String {
        if isOverBudget {
            return "Over by"
        }
        return "You can still eat"
    }

    var statusAmount: Int {
        abs(remaining)
    }

    var statusCaption: String {
        if isOverBudget {
            return "Keep the next meal simple"
        }
        return "You're on track today"
    }
}
