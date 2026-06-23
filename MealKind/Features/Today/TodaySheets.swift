import SwiftUI
import UIKit

struct ScanResultSheet: View {
    let plan: DietPlan
    let remainingBeforeSave: Int
    let imageData: Data?
    let onSave: (FoodAnalysisResult?) -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.services) private var services
    @State private var showsDetails = false
    @State private var result: FoodAnalysisResult?

    private let estimatedMealCalories = 540
    private var l10n: L10n { L10n(language: appState.language) }

    private var fitsToday: Bool {
        (result?.decision ?? .adjust) == .fits
    }

    private var remainingAfterSave: Int {
        remainingBeforeSave - (result?.estimatedCalories ?? estimatedMealCalories)
    }

    private var comparisonText: String {
        let calories = Double(result?.estimatedCalories ?? estimatedMealCalories)
        if appState.language == .simplifiedChinese {
            return String(format: l10n.t(.riceComparison), calories / 230.0)
        }
        return String(format: l10n.t(.burgerComparison), calories / 540.0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                resultHeader
                mealPreview
                decisionCard
                actionCard
                detailDisclosure
                saveButton
            }
            .padding(22)
        }
        .background(MKBackdrop())
        .task {
            result = await services.analyzeMealImage(
                imageData,
                plan,
                remainingBeforeSave,
                appState.language,
                appState.foodAnalysisContext()
            )
        }
    }

    @ViewBuilder
    private var mealPreview: some View {
        if
            let imageData,
            let image = UIImage(data: imageData)
        {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    Text(l10n.t(.mealPhoto))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MKColor.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.46), in: Capsule())
                        .padding(12)
                }
        }
    }

    private var resultHeader: some View {
        HStack(spacing: 12) {
            MKIconBadge(symbol: "camera.fill", tint: MKColor.green, fill: MKColor.subtleGreen.opacity(0.55), size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t(.mealScanned))
                    .font(.title3.bold())
                Text(plan.localizedName(language: appState.language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var decisionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: fitsToday ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath.circle.fill")
                Text(result?.decision.localizedTitle(language: appState.language) ?? l10n.t(.checkingMeal))
            }
            .font(.title2.bold())
            .foregroundStyle(fitsToday ? MKColor.green : .orange)

            Text(result?.summary ?? (fitsToday ? l10n.t(.eatNormallySummary) : l10n.t(.adjustSummary)))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                ResultPill(title: l10n.t(.estimate), value: "\((result?.estimatedCalories ?? estimatedMealCalories)) \(l10n.t(.kcalUnit))")
                ResultPill(title: l10n.t(.foodImpact), value: remainingAfterSave >= 0 ? "\(remainingAfterSave) \(l10n.t(.left))" : "\(abs(remainingAfterSave)) \(l10n.t(.over))")
            }

            Text(comparisonText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MKColor.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(MKTheme.track, in: Capsule())

            MacroStrip(
                protein: result?.protein ?? 0,
                carbs: result?.carbs ?? 0,
                fat: result?.fat ?? 0,
                language: appState.language
            )
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 30, tint: .white.opacity(0.30))
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(l10n.t(.howToEatIt), systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MKColor.sky)

            VStack(spacing: 0) {
                ScanActionRow(symbol: "fork.knife", title: result?.actions.first ?? plan.localizedGuardrails(language: appState.language)[0])
                Divider().padding(.leading, 34)
                ScanActionRow(symbol: "takeoutbag.and.cup.and.straw", title: result?.actions.dropFirst().first ?? l10n.t(.savePartForLater))
            }
        }
        .padding(16)
        .mkGlassSurface(cornerRadius: 26, tint: .white.opacity(0.24))
    }

    private var detailDisclosure: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy) {
                    showsDetails.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.headline)
                        .foregroundStyle(MKColor.sky)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t(.detailsTitle))
                            .font(.subheadline.weight(.semibold))
                        Text(l10n.t(.detailsSubtitle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.subheadline.bold())
                        .rotationEffect(.degrees(showsDetails ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsDetails {
                VStack(spacing: 10) {
                    DetailRow(title: l10n.t(.recognized), value: result?.mealName ?? l10n.t(.analyzing))
                    DetailRow(title: l10n.t(.confidence), value: result?.confidence.localizedName(language: appState.language) ?? "...")
                    DetailRow(title: l10n.t(.protein), value: "\(result?.protein ?? 0)g")
                    DetailRow(title: l10n.t(.carbs), value: "\(result?.carbs ?? 0)g")
                    DetailRow(title: l10n.t(.fat), value: "\(result?.fat ?? 0)g")
                }
                .padding(.top, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .mkGlassSurface(cornerRadius: 24, tint: .white.opacity(0.18), isInteractive: true)
    }

    private var saveButton: some View {
        Button {
            onSave(result)
        } label: {
            HStack {
                Text(l10n.t(.saveToToday))
                    .font(.headline)
                Spacer()
                Image(systemName: "checkmark")
                    .font(.headline.bold())
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .buttonStyle(MKPrimaryActionStyle(tint: MKColor.green))
    }
}

struct QuickLogSheet: View {
    let onSave: (MealLog) -> Void
    @Environment(AppState.self) private var appState
    private var l10n: L10n { L10n(language: appState.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(l10n.t(.quickLog), systemImage: "note.text.badge.plus")
                .font(.title2.bold())
                .foregroundStyle(MKColor.green)

            Text(l10n.t(.quickLogSubtitle))
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Button("\(l10n.t(.lightMeal)) · 350 \(l10n.t(.kcalUnit))") {
                    onSave(MealLog(name: l10n.t(.lightMeal), calories: 350, protein: 24, carbs: 38, fat: 10))
                }
                Button("\(l10n.t(.regularMeal)) · 550 \(l10n.t(.kcalUnit))") {
                    onSave(MealLog(name: l10n.t(.regularMeal), calories: 550, protein: 34, carbs: 62, fat: 18))
                }
                Button("\(l10n.t(.largeMeal)) · 750 \(l10n.t(.kcalUnit))") {
                    onSave(MealLog(name: l10n.t(.largeMeal), calories: 750, protein: 42, carbs: 88, fat: 26))
                }
            }
            .buttonStyle(LogButtonStyle())

            Spacer()
        }
        .padding(24)
        .background(MKBackdrop())
    }
}

struct SimpleSheet: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(MKColor.green)
            Text(title)
                .font(.title.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ResultPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .mkGlassSurface(cornerRadius: 18, tint: .white.opacity(0.18))
    }
}

private struct MacroStrip: View {
    let protein: Int
    let carbs: Int
    let fat: Int
    let language: AppLanguage

    private var total: Int {
        max(protein + carbs + fat, 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Capsule()
                    .fill(MKColor.green)
                    .frame(maxWidth: CGFloat(protein) / CGFloat(total) * 220)
                Capsule()
                    .fill(MKColor.mint.opacity(0.72))
                    .frame(maxWidth: CGFloat(carbs) / CGFloat(total) * 220)
                Capsule()
                    .fill(MKColor.citrus.opacity(0.72))
                    .frame(maxWidth: CGFloat(fat) / CGFloat(total) * 220)
            }
            .frame(height: 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                MacroLegend(title: L10n(language: language).t(.protein), value: protein, color: MKColor.green)
                MacroLegend(title: L10n(language: language).t(.carbs), value: carbs, color: MKColor.mint.opacity(0.72))
                MacroLegend(title: L10n(language: language).t(.fat), value: fat, color: MKColor.citrus.opacity(0.72))
            }
        }
        .padding(12)
        .mkGlassSurface(cornerRadius: 18, tint: .white.opacity(0.16))
    }
}

private struct MacroLegend: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(value)g")
                .font(.caption2.weight(.bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScanActionRow: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MKColor.green)
                .frame(width: 22)
            Text(title)
                .font(.body.weight(.semibold))
            Spacer()
        }
        .padding(.vertical, 11)
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

private struct LogButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(MKColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct TodayDetailLogSheet: View {
    let appState: AppState
    let isChinese: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var today: Date { Date() }
    private var calendar: Calendar { Calendar.current }

    private var detailRingTitles: [String] {
        isChinese ? ["饮食", "饮水", "睡眠", "活动"] : ["Meals", "Water", "Sleep", "Move"]
    }

    private let detailRingSymbols = ["fork.knife", "drop.fill", "moon.stars.fill", "figure.walk"]

    private var detailRingTints: [Color] {
        [MKColor.green, MKColor.sky, Color(red: 0.47, green: 0.43, blue: 0.66), MKColor.citrus]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    detailRecordsCard
                    taskHistoryCard
                }
                .padding(20)
            }
            .background(MKBackdrop())
            .navigationTitle(isChinese ? "今日记录" : "Today's log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "关闭" : "Close") { dismiss() }
                }
            }
        }
    }

    private var detailRecordsCard: some View {
        let dims = dayDimensions(for: today)
        let values = detailRecordValues(for: today)
        let mealRatio = mealCalorieRatio(for: today)
        let triggerKey = "\(Int(today.timeIntervalSince1970))"

        return VStack(alignment: .leading, spacing: 16) {
            Label(isChinese ? "详细记录" : "Detailed records", systemImage: "chart.pie")
                .font(.headline)
                .foregroundStyle(MKColor.green)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    TodayDetailRingTile(
                        title: detailRingTitles[i],
                        value: values.indices.contains(i) ? values[i] : "",
                        symbol: detailRingSymbols[i],
                        progress: dims.indices.contains(i) ? dims[i] : 0,
                        tint: i == 0 ? MKColor.mealLoad(ratio: mealRatio) : detailRingTints[i],
                        badge: i == 0 ? mealBadge(ratio: mealRatio) : nil,
                        triggerKey: triggerKey
                    )
                }
            }
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 26)
    }

    private var taskHistoryCard: some View {
        let todayTasks = appState.dailyTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return calendar.isDate(completedAt, inSameDayAs: today)
        }

        return VStack(alignment: .leading, spacing: 16) {
            Label(isChinese ? "今日操作记录" : "Today's actions", systemImage: "clock.arrow.circlepath")
                .font(.headline)
                .foregroundStyle(MKColor.green)

            if todayTasks.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(isChinese ? "今天还没有操作记录" : "No actions recorded today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(todayTasks.enumerated()), id: \.element.id) { index, task in
                        TaskHistoryRow(task: task, isChinese: isChinese)
                        if index < todayTasks.count - 1 {
                            Divider().overlay(MKTheme.divider).padding(.leading, 44)
                        }
                    }
                }
                .padding(14)
                .mkGlassSurface(cornerRadius: 22, tint: .white.opacity(0.12))
            }
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 26)
    }

    private func dayDimensions(for date: Date) -> [Double] {
        let mealTarget = Double(appState.bodyOSNutritionTarget.calories)
        let mealIntake = Double(appState.meals
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .map(\.calories)
            .reduce(0, +))
        let mealProgress = mealTarget > 0 ? min(mealIntake / mealTarget, 1.5) : 0

        let cups = Double(waterCups(on: date))
        let waterProgress = min(cups / 8.0, 1.0)

        let sleepHours = appState.sleepLogs
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .map(\.hoursSlept)
            .max() ?? 0
        let sleepProgress = min(sleepHours / 7.0, 1.0)

        let burned = Double(appState.workouts
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .map(\.calories)
            .reduce(0, +))
        let goal = Double(appState.activityBurnGoal)
        let moveProgress = goal > 0 ? min(burned / goal, 1.0) : 0

        return [mealProgress, waterProgress, sleepProgress, moveProgress]
    }

    private func detailRecordValues(for date: Date) -> [String] {
        let mealTarget = appState.bodyOSNutritionTarget.calories
        let mealIntake = appState.meals
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .map(\.calories)
            .reduce(0, +)
        let cups = waterCups(on: date)
        let sleepHours = appState.sleepLogs
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .map(\.hoursSlept)
            .max() ?? 0
        let burned = appState.workouts
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .map(\.calories)
            .reduce(0, +)
        let goal = appState.activityBurnGoal

        if isChinese {
            return [
                "建议\(mealTarget)/摄入\(mealIntake) 千卡",
                "建议8/已喝\(cups) 杯",
                String(format: "建议7.0/实睡%.1f 小时", sleepHours),
                "目标\(goal)/已耗\(burned) 千卡"
            ]
        }
        return [
            "rec \(mealTarget)/in \(mealIntake) kcal",
            "goal 8/got \(cups) cups",
            String(format: "goal 7.0/slept %.1f hr", sleepHours),
            "goal \(goal)/burned \(burned) kcal"
        ]
    }

    private func waterCups(on date: Date) -> Int {
        if calendar.isDateInToday(date) {
            return appState.waterCups
        }
        return 0
    }

    private func mealCalorieRatio(for date: Date) -> Double {
        let target = Double(appState.bodyOSNutritionTarget.calories)
        let intake = Double(appState.meals
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .map(\.calories)
            .reduce(0, +))
        guard target > 0 else { return 0 }
        return intake / target
    }

    private func mealBadge(ratio: Double) -> String? {
        guard ratio > 1.0 else { return nil }
        if ratio <= 1.1 { return isChinese ? "热量警告" : "Watch" }
        if ratio <= 1.3 { return isChinese ? "热量超标" : "Over" }
        return isChinese ? "吃太多啦" : "Too much"
    }
}

private struct TaskHistoryRow: View {
    let task: DailyTask
    let isChinese: Bool

    private var taskSymbol: String {
        switch task.taskType {
        case .mealPhoto: return "camera.fill"
        case .portionAdjustment: return "fork.knife"
        case .review: return "moon.stars.fill"
        case .weight: return "scalemass.fill"
        }
    }

    private var taskColor: Color {
        switch task.taskType {
        case .mealPhoto: return MKColor.green
        case .portionAdjustment: return MKColor.mint
        case .review: return Color(red: 0.47, green: 0.43, blue: 0.66)
        case .weight: return MKColor.sky
        }
    }

    private var formattedTime: String {
        guard let completedAt = task.completedAt else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans_CN" : "en_US")
        formatter.dateFormat = isChinese ? "HH:mm" : "h:mm a"
        return formatter.string(from: completedAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(task.status == .completed ? taskColor : .secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MKTheme.ink)
                if task.completedAt != nil {
                    Text(formattedTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: taskSymbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(taskColor)
                .frame(width: 28, height: 28)
                .background(taskColor.opacity(0.12), in: Circle())
        }
        .padding(.vertical, 10)
    }
}

private struct TodayDetailRingTile: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let value: String
    let symbol: String
    let progress: Double
    let tint: Color
    var badge: String? = nil
    let triggerKey: String

    @State private var animated: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(MKTheme.track, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: min(max(animated, 0), 1))
                    .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                        .lineLimit(1)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(tint, in: Capsule())
                            .lineLimit(1)
                    }
                }
                Text(value)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)
                    .monospacedDigit()
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(minHeight: 78)
        .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .task(id: triggerKey) { await sweep() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }

    @MainActor
    private func sweep() async {
        guard !reduceMotion else {
            animated = progress
            return
        }
        animated = 0
        try? await Task.sleep(for: .milliseconds(16))
        withAnimation(.easeOut(duration: 1.1)) {
            animated = progress
        }
    }
}
