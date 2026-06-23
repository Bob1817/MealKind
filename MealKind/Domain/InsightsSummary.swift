import Foundation

struct DailyEnergyBalance: Identifiable, Equatable {
    var id: Date { date }
    var date: Date
    var eatenCalories: Int
    var goalCalories: Int

    var balance: Int {
        guard eatenCalories > 0 else { return 0 }
        return eatenCalories - goalCalories
    }
}

struct BodyOSAdherence: Equatable {
    var taskCompletionRate: Double
    var mealLoggedDayCount: Int
    var workoutDayCount: Int
    var sleepLoggedDayCount: Int
    var supplementDayCount: Int

    var overallRate: Double {
        let signals: [Double] = [
            taskCompletionRate,
            Double(mealLoggedDayCount) / 7.0,
            Double(max(workoutDayCount, sleepLoggedDayCount + supplementDayCount)) / 7.0
        ]
        let weighted = signals.reduce(0, +) / Double(signals.count)
        return min(max(weighted, 0), 1)
    }
}

struct InsightsSummary: Equatable {
    var days: [DailyEnergyBalance]
    var loggedMeals: Int
    var weeklyBalance: Int
    var adherence: BodyOSAdherence

    var isWithinGentleRange: Bool {
        abs(weeklyBalance) <= 500
    }

    var loggedDayCount: Int {
        days.filter { $0.eatenCalories > 0 }.count
    }

    var currentLoggingStreak: Int {
        days.reversed().prefix { $0.eatenCalories > 0 }.count
    }

    static func make(
        meals: [MealLog],
        profile: UserEnergyProfile,
        plan: DietPlan,
        workouts: [WorkoutLog] = [],
        sleepLogs: [SleepLog] = [],
        supplementLogs: [SupplementLog] = [],
        dailyTasks: [DailyTask] = [],
        calendar: Calendar = .current,
        today: Date = Date()
    ) -> InsightsSummary {
        let startOfToday = calendar.startOfDay(for: today)
        let dates = (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: startOfToday)
        }
        let goal = CalorieBudget(profile: profile, plan: plan, eatenCalories: 0).dailyGoal
        let days = dates.map { date in
            let calories = meals
                .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
                .map(\.calories)
                .reduce(0, +)

            return DailyEnergyBalance(
                date: date,
                eatenCalories: calories,
                goalCalories: goal
            )
        }

        let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? today
        let loggedMeals = meals.filter { meal in
            meal.createdAt >= sevenDaysAgo && meal.createdAt < tomorrow
        }.count

        let adherence = makeAdherence(
            dates: dates,
            workouts: workouts,
            sleepLogs: sleepLogs,
            supplementLogs: supplementLogs,
            dailyTasks: dailyTasks,
            meals: meals,
            calendar: calendar,
            weekStart: sevenDaysAgo,
            weekEnd: tomorrow
        )

        return InsightsSummary(
            days: days,
            loggedMeals: loggedMeals,
            weeklyBalance: days.map(\.balance).reduce(0, +),
            adherence: adherence
        )
    }

    private static func makeAdherence(
        dates: [Date],
        workouts: [WorkoutLog],
        sleepLogs: [SleepLog],
        supplementLogs: [SupplementLog],
        dailyTasks: [DailyTask],
        meals: [MealLog],
        calendar: Calendar,
        weekStart: Date,
        weekEnd: Date
    ) -> BodyOSAdherence {
        let weekTasks = dailyTasks.filter { task in
            if task.status == .skipped { return false }
            if let completed = task.completedAt {
                return completed >= weekStart && completed < weekEnd
            }
            return true
        }
        let completedTasks = weekTasks.filter { $0.status == .completed }
        let taskRate = weekTasks.isEmpty ? 0 : Double(completedTasks.count) / Double(weekTasks.count)

        let mealDays = countDays(in: dates, calendar: calendar) { day in
            meals.contains { calendar.isDate($0.createdAt, inSameDayAs: day) }
        }
        let workoutDays = countDays(in: dates, calendar: calendar) { day in
            workouts.contains { calendar.isDate($0.createdAt, inSameDayAs: day) }
        }
        let sleepDays = countDays(in: dates, calendar: calendar) { day in
            sleepLogs.contains { calendar.isDate($0.createdAt, inSameDayAs: day) }
        }
        let supplementDays = countDays(in: dates, calendar: calendar) { day in
            supplementLogs.contains { calendar.isDate($0.takenAt, inSameDayAs: day) }
        }

        return BodyOSAdherence(
            taskCompletionRate: min(max(taskRate, 0), 1),
            mealLoggedDayCount: mealDays,
            workoutDayCount: workoutDays,
            sleepLoggedDayCount: sleepDays,
            supplementDayCount: supplementDays
        )
    }

    private static func countDays(
        in dates: [Date],
        calendar: Calendar,
        predicate: (Date) -> Bool
    ) -> Int {
        dates.reduce(0) { acc, date in
            predicate(date) ? acc + 1 : acc
        }
    }
}

/// 成长页「AI 写给你的信」——先用模板生成（后续可替换为真实 AI 接口）。
/// 100~200 字，第二人称、温和、肯定进步、以鼓励收尾，避免数据解读。
enum GrowthLetter {
    static func make(
        language: AppLanguage,
        streakDays: Int,
        recordCount: Int,
        topHabit: String? = nil
    ) -> String {
        if language == .simplifiedChinese {
            let habitLine = topHabit.map { "尤其是\($0)，正在慢慢变成你的习惯。" } ?? ""
            return """
            给现在的你：
            这段时间，你已经坚持了 \(streakDays) 天，留下了 \(recordCount) 次记录。\(habitLine)刚开始也许会忘记、会想偷懒，但你一次次回来，这件事本身就很了不起。成长从来不会一夜发生，它就藏在这些小小的重复里。不用追求完美，继续保持就好，我会一直陪着你。
            —— 你的 AI 伙伴
            """
        }
        let habitLine = topHabit.map { "Especially \($0), which is slowly becoming a habit. " } ?? ""
        return """
        To you, right now:
        Over this stretch you've kept going for \(streakDays) days and left \(recordCount) records. \(habitLine)At the start it's easy to forget or skip, yet you kept coming back — that alone is something to be proud of. Growth never happens overnight; it hides in these small repeats. No need to be perfect, just keep going. I'll be here with you.
        — Your AI companion
        """
    }
}
