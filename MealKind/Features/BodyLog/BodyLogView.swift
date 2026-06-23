import SwiftUI
import SwiftData

struct BodyLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredWaterRecord.loggedAt) private var storedWater: [StoredWaterRecord]
    @State private var sleepSheetPresented = false
    @State private var supplementSheetPresented = false
    @State private var measurementSheetPresented = false
    @State private var selectedReviewDate = Date()
    // 每次进入「坚持」页 +1，触发日历所有日期的柱状图重新升起。
    @State private var calendarPlayToken = 0
    // 连续天数 0→N 滚动动效的当前显示值。
    @State private var displayedStreak = 0
    // 顶栏右上角入口弹出的完整网格日历。
    @State private var showFullCalendar = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isChinese: Bool { appState.language == .simplifiedChinese }
    private var isAdvanced: Bool { appState.experienceMode == .professional }
    private var l10n: L10n { L10n(language: appState.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MKTheme.cardSpacing) {
                if isAdvanced {
                    modeBanner
                    advancedSections
                } else {
                    lifestyleSections
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .mkGlassNavigation(
            title: isAdvanced ? (isChinese ? "身体记录" : "BodyLog") : (isChinese ? "坚持中心" : "Check-in"),
            subtitle: isAdvanced
                ? (isChinese ? "看看今天身体的节奏。" : "See today's body rhythm.")
                : (isChinese ? "看看你最近坚持得怎么样。" : "See how your small habits are growing.")
        ) {
            if !isAdvanced {
                Button {
                    showFullCalendar = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MKColor.green)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isChinese ? "完整日历" : "Full calendar")
            }
        }
        .sheet(isPresented: $showFullCalendar) {
            fullCalendarSheet
        }
        .sheet(isPresented: $sleepSheetPresented) {
            SleepEntrySheet(isChinese: isChinese) { log in
                appState.saveSleep(log, modelContext: modelContext)
            }
        }
        .sheet(isPresented: $supplementSheetPresented) {
            SupplementEntrySheet(isChinese: isChinese) { log in
                appState.saveSupplement(log, modelContext: modelContext)
            }
        }
        .sheet(isPresented: $measurementSheetPresented) {
            MeasurementEntrySheet(isChinese: isChinese) { log in
                appState.saveMeasurement(log, modelContext: modelContext)
            }
        }
    }

    private var modeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: isAdvanced ? "chart.bar.doc.horizontal.fill" : "leaf.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKColor.green)
                .frame(width: 32, height: 32)
                .background(MKColor.subtleGreen.opacity(0.45), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(isAdvanced
                     ? (isChinese ? "多看一点" : "More detail")
                     : (isChinese ? "简单记录" : "Simple logging"))
                    .font(.subheadline.weight(.semibold))
                Text(isAdvanced
                     ? (isChinese ? "吃了什么、练了什么、睡得怎么样" : "Food, training, sleep, and recovery")
                     : (isChinese ? "体重、喝水、吃饭，先简单记" : "Weight, water, meals, kept simple"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 22, tint: .white.opacity(0.16))
    }

    @ViewBuilder
    private var lifestyleSections: some View {
        compactStreakHeader
        calendarDetailCard
        aiSummaryCard
    }

    @ViewBuilder
    private var advancedSections: some View {
        professionalCompletenessCard
        nutritionSummaryCard
        macroBreakdownCard
        workoutsCard(limit: 4)
        sleepCard
        waterCard
        supplementsCard
        measurementsCard
        mealsCard(limit: 4)
    }

    private var lifestyleNudgeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(isChinese ? "今天先记一件就好" : "Log just one thing first", systemImage: "leaf.fill")
                .font(.headline)
                .foregroundStyle(MKColor.green)

            Text(isChinese
                 ? "这里不是打卡清单。先把最容易的一件事留下来，比如喝水、睡眠，或者一餐。"
                 : "This is not a checklist. Start with the easiest thing: water, sleep, or one meal.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                LifestyleLogPill(symbol: "drop.fill", title: isChinese ? "喝水" : "Water", tint: MKColor.sky) {
                    updateWaterCups(by: 1)
                }
                LifestyleLogPill(symbol: "moon.stars.fill", title: isChinese ? "睡眠" : "Sleep", tint: MKColor.sky) {
                    sleepSheetPresented = true
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 24, tint: MKColor.subtleGreen.opacity(0.14))
    }

    // 精简连续天数：一行矮条，数字进入时从 0 快速滚到坚持天数。
    private var compactStreakHeader: some View {
        let streak = currentStreakDays
        return HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(MKColor.citrus)
                .frame(width: 40, height: 40)
                .background(MKColor.citrus.opacity(0.14), in: Circle())

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(displayedStreak)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(MKTheme.ink)
                Text(isChinese ? "天" : "days")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
            }

            Spacer(minLength: 8)

            Text(isChinese ? "连续坚持" : "Day streak")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MKColor.citrus)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(MKColor.citrus.opacity(0.12), in: Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 22)
        .task(id: calendarPlayToken) { await rollStreak(to: streak) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isChinese ? "连续坚持 \(streak) 天" : "\(streak) day streak")
    }

    // 0 → 目标天数的滚动：ease-out（先快后慢、逐渐变慢）。
    @MainActor
    private func rollStreak(to target: Int) async {
        guard !reduceMotion, target > 0 else {
            displayedStreak = target
            return
        }
        displayedStreak = 0
        let duration = 1.2
        let frames = 48
        for frame in 1...frames {
            try? await Task.sleep(for: .seconds(duration / Double(frames)))
            let t = Double(frame) / Double(frames)
            let eased = 1 - pow(1 - t, 3) // easeOutCubic：越接近终点越慢
            displayedStreak = Int((eased * Double(target)).rounded())
        }
        displayedStreak = target
    }

    private var detailRingTitles: [String] {
        isChinese ? ["饮食", "饮水", "睡眠", "活动"] : ["Meals", "Water", "Sleep", "Move"]
    }

    private let detailRingSymbols = ["fork.knife", "drop.fill", "moon.stars.fill", "figure.walk"]

    private var selectedDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans_CN" : "en_US")
        if calendar.isDateInToday(selectedReviewDate) {
            return isChinese ? "今天" : "Today"
        }
        formatter.setLocalizedDateFormatFromTemplate(isChinese ? "M月d日 EEEE" : "EEE, MMM d")
        return formatter.string(from: selectedReviewDate)
    }

    // 选中那天每个维度的「建议 / 录入」数据文案。
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

    // 饮食超标三阶段角标：热量警告 / 热量超标 / 吃太多啦。
    private func mealBadge(ratio: Double) -> String? {
        guard ratio > 1.0 else { return nil }
        if ratio <= 1.1 { return isChinese ? "热量警告" : "Watch" }
        if ratio <= 1.3 { return isChinese ? "热量超标" : "Over" }
        return isChinese ? "吃太多啦" : "Too much"
    }

    // 日历 + 详细记录合并为一张卡：上方单行横滑日历，下方展示「选中那天」的详细记录（从属关系）。
    private var calendarDetailCard: some View {
        let dims = dayDimensions(for: selectedReviewDate)
        let values = detailRecordValues(for: selectedReviewDate)
        let mealRatio = mealCalorieRatio(for: selectedReviewDate)
        let triggerKey = "\(calendarPlayToken)|\(Int(calendar.startOfDay(for: selectedReviewDate).timeIntervalSince1970))"

        return VStack(alignment: .leading, spacing: 16) {
            // —— 日历部分 ——
            MKThemeSectionTitle(
                title: isChinese ? "坚持日历" : "Check-in calendar",
                subtitle: isChinese ? "左右滑动，点开看那天的记录。" : "Swipe and tap a day to review it."
            )

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(calendarDays.enumerated()), id: \.element.id) { index, day in
                            VStack(spacing: 6) {
                                Text(weekdayLetter(day.date))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(MKTheme.secondaryText)
                                Button {
                                    selectedReviewDate = day.date
                                } label: {
                                    CheckInCalendarDayCell(
                                        day: day,
                                        isSelected: calendar.isDate(day.date, inSameDayAs: selectedReviewDate),
                                        isToday: calendar.isDateInToday(day.date),
                                        index: index,
                                        playToken: calendarPlayToken
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(day.accessibilityLabel(isChinese: isChinese))
                            }
                            .frame(width: 42)
                            .id(day.id)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
                .onAppear {
                    calendarPlayToken += 1
                    if let todayID = calendarDays.last?.id {
                        proxy.scrollTo(todayID, anchor: .trailing)
                    }
                }
            }

            CalendarLegend(isChinese: isChinese)

            Divider().overlay(MKTheme.divider)

            // —— 详细记录部分（从属于上方选中的日期）——
            HStack(alignment: .firstTextBaseline) {
                Text(isChinese ? "详细记录" : "Detailed records")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(MKTheme.ink)
                Spacer()
                Text(selectedDateTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MKColor.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MKColor.subtleGreen.opacity(0.5), in: Capsule())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    DetailRingTile(
                        title: detailRingTitles[i],
                        value: values.indices.contains(i) ? values[i] : "",
                        symbol: detailRingSymbols[i],
                        progress: dims.indices.contains(i) ? dims[i] : 0,
                        tint: i == 0 ? MKColor.mealLoad(ratio: mealRatio) : CheckInBarStyle.tints[i],
                        badge: i == 0 ? mealBadge(ratio: mealRatio) : nil,
                        triggerKey: triggerKey
                    )
                }
            }

            // —— 餐食记录明细 ——
            mealRecordsList(for: selectedReviewDate)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 26)
    }

    // 选定日期的餐食记录明细列表
    @ViewBuilder
    private func mealRecordsList(for date: Date) -> some View {
        let dayMeals = appState.meals
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt < $1.createdAt }

        if !dayMeals.isEmpty {
            Divider().overlay(MKTheme.divider)

            VStack(alignment: .leading, spacing: 10) {
                Text(isChinese ? "餐食记录" : "Meal records")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)

                ForEach(dayMeals) { meal in
                    mealRecordRow(meal)
                }
            }
        }
    }

    private func mealRecordRow(_ meal: MealLog) -> some View {
        HStack(spacing: 10) {
            Text(mealTimeText(meal.createdAt))
                .font(.caption.weight(.semibold))
                .foregroundStyle(MKColor.green)
                .monospacedDigit()

            Text(mealRecordContent(meal))
                .font(.subheadline)
                .foregroundStyle(MKTheme.ink)
                .lineLimit(1)

            Spacer()

            Text(mealSourceText(meal.source))
                .font(.caption2.weight(.medium))
                .foregroundStyle(MKTheme.secondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.vertical, 4)
    }

    private func mealTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func mealRecordContent(_ meal: MealLog) -> String {
        let name = meal.name
        let kcal = "\(meal.calories)\(isChinese ? "千卡" : "kcal")"
        return "\(name) \(kcal)"
    }

    private func mealSourceText(_ source: MealSource) -> String {
        switch source {
        case .camera:
            return isChinese ? "拍摄记录" : "Photo"
        case .photoLibrary:
            return isChinese ? "相册记录" : "Library"
        case .manual:
            return isChinese ? "手动记录" : "Manual"
        }
    }

    private func weekdayLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans_CN" : "en_US")
        formatter.dateFormat = isChinese ? "EEEEE" : "EEE"
        return formatter.string(from: date)
    }

    private var weekdaySymbols: [String] {
        isChinese ? ["一", "二", "三", "四", "五", "六", "日"] : ["M", "T", "W", "T", "F", "S", "S"]
    }

    private var calendarGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    }

    // 完整日历（从顶栏右上角进入）：仿 Apple Fitness 连续月份，纵向上下滑动查看过去月份。
    private var fullCalendarSheet: some View {
        let months = calendarMonths()
        return NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                        LazyVGrid(columns: calendarGridColumns, spacing: 0) {
                            ForEach(0..<7, id: \.self) { i in
                                Text(weekdaySymbols[i])
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(MKTheme.secondaryText)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        ForEach(months) { month in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(month.title)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(MKTheme.ink)

                                LazyVGrid(columns: calendarGridColumns, spacing: 10) {
                                    ForEach(0..<month.leadingBlanks, id: \.self) { _ in
                                        Color.clear.frame(height: 52)
                                    }
                                    ForEach(Array(month.days.enumerated()), id: \.element.id) { index, day in
                                        Button {
                                            selectedReviewDate = day.date
                                            showFullCalendar = false
                                        } label: {
                                            CheckInCalendarDayCell(
                                                day: day,
                                                isSelected: calendar.isDate(day.date, inSameDayAs: selectedReviewDate),
                                                isToday: calendar.isDateInToday(day.date),
                                                index: index,
                                                playToken: calendarPlayToken
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(day.accessibilityLabel(isChinese: isChinese))
                                    }
                                }
                            }
                            .id(month.id)
                        }

                        CalendarLegend(isChinese: isChinese)
                    }
                .padding(20)
            }
            .background(MKBackdrop())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showFullCalendar = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                    }
                    .accessibilityLabel(isChinese ? "关闭" : "Close")
                }
            }
        }
    }

    // 最近 6 个月（含当月，旧→新），每月含周对齐的前导空位与每天的记录。
    private func calendarMonths() -> [LifestyleMonth] {
        let today = calendar.startOfDay(for: Date())
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else {
            return []
        }

        var months: [LifestyleMonth] = []
        // 新→旧：当前月在最上方，向下滑动查看过去月份。
        for offset in stride(from: 0, through: -5, by: -1) {
            guard
                let monthStart = calendar.date(byAdding: .month, value: offset, to: currentMonthStart),
                let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
            else { continue }

            let days: [LifestyleCalendarDay] = dayRange.compactMap { dayNumber in
                guard let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthStart) else { return nil }
                return LifestyleCalendarDay(
                    date: date,
                    status: checkInStatus(for: date),
                    dimensions: dayDimensions(for: date),
                    mealRatio: mealCalorieRatio(for: date),
                    calendar: calendar
                )
            }

            // 周一为第一列：weekday 1=周日…7=周六 → Monday=0。
            let firstWeekday = calendar.component(.weekday, from: monthStart)
            let leadingBlanks = (firstWeekday + 5) % 7
            let showYear = offset == 0 || calendar.component(.month, from: monthStart) == 1

            months.append(
                LifestyleMonth(
                    id: monthStart,
                    title: monthTitle(monthStart, showYear: showYear),
                    leadingBlanks: leadingBlanks,
                    days: days
                )
            )
        }
        return months
    }

    private func monthTitle(_ date: Date, showYear: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans_CN" : "en_US")
        if isChinese {
            formatter.setLocalizedDateFormatFromTemplate(showYear ? "yyyy年M月" : "M月")
        } else {
            formatter.setLocalizedDateFormatFromTemplate(showYear ? "MMMM yyyy" : "MMMM")
        }
        return formatter.string(from: date)
    }

    // 底部仅保留 AI 总结：选中那天的温和建议 / 鼓励。
    private var aiSummaryCard: some View {
        let review = dailyReview(for: selectedReviewDate)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(MKColor.green)
                .frame(width: 38, height: 38)
                .background(MKColor.green.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(isChinese ? "AI 总结" : "AI summary")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MKColor.green)
                Text(review.summary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MKTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 24)
    }

    private var professionalCompletenessCard: some View {
        let items = professionalCompletenessItems
        let completed = items.filter(\.isCompleted).count
        let progress = items.isEmpty ? 0 : Double(completed) / Double(items.count)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isChinese ? "今日数据完整度" : "Today's data completeness")
                        .font(.headline)
                    Text(isChinese
                         ? "这些记录会影响热量、恢复和训练建议"
                         : "These inputs affect calories, recovery, and training guidance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(completed) / \(items.count)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(MKColor.green)
            }

            CapsuleProgressBar(progress: progress, tint: MKColor.green)

            CompletenessDotGrid(items: items)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    DataCompletenessRow(item: item)
                    if index < items.count - 1 {
                        Divider().overlay(MKTheme.divider)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 24, tint: .white.opacity(0.12))
    }

    private var professionalCompletenessItems: [DataCompletenessItem] {
        [
            DataCompletenessItem(
                title: isChinese ? "饮食" : "Meals",
                value: appState.todayMeals.isEmpty ? (isChinese ? "未记录" : "missing") : "\(appState.todayMeals.count)",
                symbol: "fork.knife",
                tint: MKColor.green,
                isCompleted: !appState.todayMeals.isEmpty
            ),
            DataCompletenessItem(
                title: isChinese ? "训练" : "Training",
                value: appState.todayWorkouts.isEmpty ? (isChinese ? "未记录" : "missing") : "\(appState.todayWorkouts.count)",
                symbol: "figure.strengthtraining.traditional",
                tint: MKColor.deepGreen,
                isCompleted: !appState.todayWorkouts.isEmpty || appState.bodyOSBodyState.trainingState == .restDay || appState.bodyOSBodyState.shouldOverridePlannedTraining
            ),
            DataCompletenessItem(
                title: isChinese ? "睡眠" : "Sleep",
                value: appState.latestSleepLog == nil ? (isChinese ? "未记录" : "missing") : (isChinese ? "已记录" : "logged"),
                symbol: "moon.stars.fill",
                tint: MKColor.sky,
                isCompleted: appState.latestSleepLog != nil
            ),
            DataCompletenessItem(
                title: isChinese ? "饮水" : "Water",
                value: "\(appState.waterCups)",
                symbol: "drop.fill",
                tint: MKColor.sky,
                isCompleted: appState.waterCups >= 6
            ),
            DataCompletenessItem(
                title: isChinese ? "补剂" : "Supplements",
                value: appState.todaySupplementLogs.isEmpty ? (isChinese ? "未记录" : "missing") : "\(appState.todaySupplementLogs.count)",
                symbol: "pills.fill",
                tint: MKColor.citrus,
                isCompleted: !appState.todaySupplementLogs.isEmpty
            )
        ]
    }

    private var weightCard: some View {
        BodyLogCard(
            symbol: "scalemass.fill",
            tint: MKColor.green,
            title: isChinese ? "体重" : "Weight"
        ) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", appState.weightKilograms))
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                Text("kg")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(isChinese ? "目标" : "Target")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f kg", appState.profile.targetWeightKilograms))
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
    }

    private var waterCard: some View {
        let target = 8
        let cups = appState.waterCups
        let progress = min(max(Double(cups) / Double(target), 0), 1)
        return BodyLogCard(
            symbol: "drop.fill",
            tint: MKColor.sky,
            title: isChinese ? "饮水" : "Water"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(cups)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text(isChinese ? "杯 / \(target) 杯" : "/ \(target) cups")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                CapsuleProgressBar(progress: progress, tint: MKColor.sky)
                WaterCupStrip(cups: cups, target: target)

                HStack(spacing: 8) {
                    Button {
                        updateWaterCups(by: 1)
                    } label: {
                        Label(isChinese ? "加一杯" : "Add cup", systemImage: "plus.circle.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(MKColor.subtleSky.opacity(0.35), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        updateWaterCups(by: -1)
                    } label: {
                        Label(isChinese ? "少一杯" : "Remove", systemImage: "minus.circle")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(MKTheme.track, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(cups == 0)
                    .opacity(cups == 0 ? 0.45 : 1)
                }
            }
        }
    }

    private var stepsCard: some View {
        BodyLogCard(
            symbol: "figure.walk",
            tint: MKColor.citrus,
            title: isChinese ? "步数" : "Steps"
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isChinese ? "暂未连接 Apple 健康" : "Apple Health not connected")
                    .font(.subheadline.weight(.semibold))
                Text(isChinese
                     ? "连接健康权限后会在这里显示今日步数与活动消耗。"
                     : "Once Health access is on, daily steps and active energy will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var nutritionSummaryCard: some View {
        let target = appState.bodyOSNutritionTarget
        let eaten = appState.eatenCalories
        let remaining = target.calories - eaten
        let progress = target.calories > 0
            ? min(max(Double(eaten) / Double(target.calories), 0), 1.2)
            : 0
        return BodyLogCard(
            symbol: "fork.knife",
            tint: MKColor.green,
            title: isChinese ? "今日能量" : "Today energy"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(max(remaining, 0))")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(remaining < 0 ? MKColor.coral : MKColor.green)
                    Text(remaining >= 0
                         ? (isChinese ? "千卡可用" : "kcal left")
                         : (isChinese ? "千卡超出" : "kcal over"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(eaten) / \(target.calories)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                CapsuleProgressBar(progress: progress, tint: remaining < 0 ? MKColor.coral : MKColor.green)
                Text(isChinese ? "今天参考 \(target.calories) 千卡"
                              : "Today around \(target.calories) kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var macroBreakdownCard: some View {
        let target = appState.bodyOSNutritionTarget
        let macros = appState.eatenMacros
        return BodyLogCard(
            symbol: "chart.pie.fill",
            tint: MKColor.sky,
            title: isChinese ? "蛋白、碳水、脂肪" : "Protein, carbs, fat"
        ) {
            VStack(spacing: 10) {
                MacroBar(title: isChinese ? "蛋白" : "Protein", eaten: macros.protein, target: target.protein, tint: MKColor.green)
                MacroBar(title: isChinese ? "碳水" : "Carbs", eaten: macros.carbs, target: target.carbs, tint: MKColor.citrus)
                MacroBar(title: isChinese ? "脂肪" : "Fat", eaten: macros.fat, target: target.fat, tint: MKColor.sky)
            }
        }
    }

    private func workoutsCard(limit: Int) -> some View {
        let workouts = Array(appState.todayWorkouts.suffix(limit).reversed())
        return BodyLogCard(
            symbol: "figure.strengthtraining.traditional",
            tint: MKColor.deepGreen,
            title: isChinese ? "训练" : "Workouts"
        ) {
            if workouts.isEmpty {
                Text(isChinese ? "今天还没有训练记录。" : "No workouts logged today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(workouts) { workout in
                        WorkoutRow(workout: workout, isChinese: isChinese)
                    }
                }
            }
        }
    }

    private var sleepCard: some View {
        let latest = appState.latestSleepLog
        return BodyLogCard(
            symbol: "moon.stars.fill",
            tint: MKColor.sky,
            title: isChinese ? "睡眠" : "Sleep"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if let latest {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(String(format: "%.1f", latest.hoursSlept))
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                        Text(isChinese ? "小时" : "hr")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(latest.quality.localizedName(language: appState.language))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(MKColor.subtleSky.opacity(0.35), in: Capsule())
                    }
                    Text(isChinese
                         ? "睡眠会进入 Recovery Engine 与今日策略。"
                         : "Sleep feeds Recovery Engine and today's strategy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(isChinese ? "今天还没有记录睡眠。" : "No sleep logged yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    sleepSheetPresented = true
                } label: {
                    Label(
                        isChinese ? "记录睡眠" : "Log sleep",
                        systemImage: "plus.circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(MKColor.subtleSky.opacity(0.35), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var supplementsCard: some View {
        let logs = appState.todaySupplementLogs
        return BodyLogCard(
            symbol: "pills.fill",
            tint: MKColor.citrus,
            title: isChinese ? "补剂" : "Supplements"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if logs.isEmpty {
                    Text(isChinese ? "今天还没有补剂打卡。" : "No supplements logged today.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 6) {
                        ForEach(logs) { log in
                            SupplementRow(log: log, language: appState.language)
                        }
                    }
                }

                Button {
                    supplementSheetPresented = true
                } label: {
                    Label(
                        isChinese ? "添加补剂" : "Add supplement",
                        systemImage: "plus.circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(MKColor.subtleCitrus.opacity(0.35), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var measurementsCard: some View {
        let measurements = appState.latestMeasurements
            .sorted { $0.takenAt > $1.takenAt }
        return BodyLogCard(
            symbol: "ruler.fill",
            tint: MKColor.coral,
            title: isChinese ? "围度与体脂" : "Measurements"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    BodyMetricChip(
                        title: isChinese ? "身高" : "Height",
                        value: String(format: "%.0f cm", appState.profile.heightCentimeters)
                    )
                    BodyMetricChip(
                        title: isChinese ? "体重" : "Weight",
                        value: String(format: "%.1f kg", appState.weightKilograms)
                    )
                    BodyMetricChip(
                        title: isChinese ? "目标" : "Target",
                        value: String(format: "%.1f kg", appState.profile.targetWeightKilograms)
                    )
                }

                if measurements.isEmpty {
                    Text(isChinese ? "还没有围度或体脂记录。" : "No waist, hip, or body fat entries yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 6) {
                        ForEach(Array(measurements.prefix(4))) { log in
                            MeasurementRow(log: log, language: appState.language)
                        }
                    }
                }

                Button {
                    measurementSheetPresented = true
                } label: {
                    Label(
                        isChinese ? "添加测量" : "Add measurement",
                        systemImage: "plus.circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(MKColor.coral.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func mealsCard(limit: Int) -> some View {
        let meals = Array(appState.todayMeals.suffix(limit).reversed())
        return BodyLogCard(
            symbol: "takeoutbag.and.cup.and.straw.fill",
            tint: MKColor.green,
            title: isChinese ? "今日餐食" : "Today's meals"
        ) {
            if meals.isEmpty {
                Text(isChinese ? "今天还没有记录餐食。" : "No meals recorded yet today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(meals) { meal in
                        MealRow(meal: meal, isChinese: isChinese)
                    }
                }
            }
        }
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: Date())
        }
    }

    private var currentStreakDays: Int {
        var streak = 0
        for offset in 0..<90 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            if checkInStatus(for: date) == .none {
                break
            }
            streak += 1
        }
        return streak
    }

    private var weeklyHabitProgressItems: [LifestyleHabitProgressItem] {
        [
            LifestyleHabitProgressItem(
                title: isChinese ? "饮食记录" : "Meal check-in",
                symbol: "fork.knife",
                completedDays: weekDays.filter(hasMeal(on:)).count,
                dayUnit: isChinese ? "天" : "days",
                tint: MKColor.green
            ),
            LifestyleHabitProgressItem(
                title: isChinese ? "饮水习惯" : "Water habit",
                symbol: "drop.fill",
                completedDays: weekDays.filter { waterCups(on: $0) >= 6 }.count,
                dayUnit: isChinese ? "天" : "days",
                tint: MKColor.sky
            ),
            LifestyleHabitProgressItem(
                title: isChinese ? "睡眠习惯" : "Sleep habit",
                symbol: "moon.stars.fill",
                completedDays: weekDays.filter(hasSleep(on:)).count,
                dayUnit: isChinese ? "天" : "days",
                tint: Color(red: 0.47, green: 0.43, blue: 0.66)
            ),
            LifestyleHabitProgressItem(
                title: isChinese ? "活动记录" : "Activity check-in",
                symbol: "figure.walk",
                completedDays: weekDays.filter(hasActivity(on:)).count,
                dayUnit: isChinese ? "天" : "days",
                tint: MKColor.citrus
            )
        ]
    }

    private var calendarDays: [LifestyleCalendarDay] {
        (0..<28).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(27 - offset), to: Date()) else { return nil }
            return LifestyleCalendarDay(
                date: date,
                status: checkInStatus(for: date),
                dimensions: dayDimensions(for: date),
                mealRatio: mealCalorieRatio(for: date),
                calendar: calendar
            )
        }
    }

    // 当天四个习惯维度的完成度（0...1），对应柱状图四根柱子的高度：饮食 / 饮水 / 睡眠 / 活动。
    private func dayDimensions(for date: Date) -> [Double] {
        let cups = waterCups(on: date)
        let sleepHours = appState.sleepLogs
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .map(\.hoursSlept)
            .max() ?? 0
        let activeMinutes = appState.workouts
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .map(\.durationMinutes)
            .reduce(0, +)

        func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
        return [
            clamp(mealCalorieRatio(for: date)), // 饮食按"摄入/建议"比值，超标时高度封顶、颜色转红
            clamp(Double(cups) / 8.0),
            clamp(sleepHours / 8.0),
            clamp(Double(activeMinutes) / 30.0)
        ]
    }

    // 当天摄入热量 / 建议热量 的比值（0 = 未记录；>1 = 超标）。
    private func mealCalorieRatio(for date: Date) -> Double {
        let intake = appState.meals
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .map(\.calories)
            .reduce(0, +)
        let target = appState.bodyOSNutritionTarget.calories
        guard target > 0, intake > 0 else { return 0 }
        return Double(intake) / Double(target)
    }

    private func dailyReview(for date: Date) -> LifestyleDailyReview {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans_CN" : "en_US")
        formatter.setLocalizedDateFormatFromTemplate(isChinese ? "M月d日" : "MMM d")

        var items: [LifestyleReviewItem] = []
        let mealCount = appState.meals.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }.count
        if mealCount > 0 {
            items.append(LifestyleReviewItem(title: isChinese ? "完成饮食记录 \(mealCount) 次" : "\(mealCount) meal check-in\(mealCount == 1 ? "" : "s")", tint: MKColor.green))
        }

        let cups = waterCups(on: date)
        if cups > 0 {
            items.append(LifestyleReviewItem(title: isChinese ? "喝水 \(cups) 杯" : "\(cups) cups of water", tint: MKColor.sky))
        }

        if hasSleep(on: date) {
            items.append(LifestyleReviewItem(title: isChinese ? "睡眠已记录" : "Sleep logged", tint: Color(red: 0.47, green: 0.43, blue: 0.66)))
        }

        let activityMinutes = appState.workouts
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .map(\.durationMinutes)
            .reduce(0, +)
        if activityMinutes > 0 {
            items.append(LifestyleReviewItem(title: isChinese ? "活动 \(activityMinutes) 分钟" : "\(activityMinutes) active minutes", tint: MKColor.citrus))
        }

        let taskTitles = appState.dailyTasks.filter { task in
            guard task.status == .completed, let completedAt = task.completedAt else { return false }
            return calendar.isDate(completedAt, inSameDayAs: date)
        }
        for task in taskTitles.prefix(2) {
            items.append(LifestyleReviewItem(title: task.title, tint: MKColor.green))
        }

        let completedItemCount = items.count

        if items.isEmpty {
            items.append(LifestyleReviewItem(title: isChinese ? "这一天还没有留下记录" : "No check-in recorded for this day", tint: MKTheme.secondaryText))
        }

        return LifestyleDailyReview(
            dateTitle: formatter.string(from: date),
            items: items,
            summary: dailySummary(for: date, itemCount: completedItemCount)
        )
    }

    private func dailySummary(for date: Date, itemCount: Int) -> String {
        let recentCounts = (1...3).compactMap { offset -> Int? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { return nil }
            return checkInSignalCount(on: day)
        }
        let recentAverage = recentCounts.isEmpty ? 0 : Double(recentCounts.reduce(0, +)) / Double(recentCounts.count)

        if itemCount == 0 {
            return isChinese
                ? "这一天暂时没有记录。没关系，习惯成长看的是能不能再次开始。今天做一个最小动作就很好。"
                : "This day has no check-in yet. That is okay. Habit growth is about starting again with one small action."
        }

        if Double(itemCount) >= recentAverage {
            return isChinese
                ? "今天保持得不错。几个小习惯都留下了痕迹，整体执行情况优于最近三天的平均水平。"
                : "A good steady day. Several small habits showed up, and the rhythm is above the recent three-day average."
        }

        return isChinese
            ? "今天已经有记录出现。还有一些习惯暂时没有出现，但这一天依然为连续性留下了痕迹。"
            : "A check-in showed up today. Some habits did not appear yet, but the day still adds to your consistency."
    }

    private func checkInStatus(for date: Date) -> LifestyleCheckInStatus {
        let count = checkInSignalCount(on: date)
        if count >= 2 { return .completed }
        if count == 1 { return .partial }
        return .none
    }

    private func checkInSignalCount(on date: Date) -> Int {
        [
            hasMeal(on: date),
            waterCups(on: date) > 0,
            hasSleep(on: date),
            hasActivity(on: date),
            hasCompletedTask(on: date)
        ].filter { $0 }.count
    }

    private func hasMeal(on date: Date) -> Bool {
        appState.meals.contains { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }

    private func hasSleep(on date: Date) -> Bool {
        appState.sleepLogs.contains { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }

    private func hasActivity(on date: Date) -> Bool {
        appState.workouts.contains { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }

    private func hasCompletedTask(on date: Date) -> Bool {
        appState.dailyTasks.contains { task in
            guard task.status == .completed, let completedAt = task.completedAt else { return false }
            return calendar.isDate(completedAt, inSameDayAs: date)
        }
    }

    private func waterCups(on date: Date) -> Int {
        if calendar.isDateInToday(date) {
            return appState.waterCups
        }
        let localDate = LocalDateStamp.dateString(for: date)
        return storedWater
            .filter { $0.localDate == localDate }
            .map(\.cupDelta)
            .reduce(0, +)
    }

    private func updateWaterCups(by delta: Int) {
        seedTodayWaterBaselineIfNeeded()
        appState.saveWaterChange(delta, modelContext: modelContext)
    }

    private func seedTodayWaterBaselineIfNeeded() {
        let today = LocalDateStamp.dateString(for: Date())
        guard storedWater.contains(where: { $0.localDate == today }) == false else { return }
        guard appState.waterCups > 0 else { return }

        LocalRecordRepository.saveWater(
            WaterLog(cupDelta: appState.waterCups, note: "daily baseline"),
            to: modelContext
        )
    }
}

private struct ProPlusGateBadge: View {
    let feature: ProPlusFeature
    let tier: SubscriptionTier
    let isChinese: Bool

    private var isUnlocked: Bool {
        feature.isUnlocked(for: tier)
    }

    var body: some View {
        Label(
            isUnlocked
                ? (isChinese ? "Pro Plus 已启用" : "Pro Plus enabled")
                : (isChinese ? "Pro Plus 功能" : "Pro Plus feature"),
            systemImage: isUnlocked ? "checkmark.seal.fill" : "lock.fill"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(isUnlocked ? MKColor.green : MKColor.citrus)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background((isUnlocked ? MKColor.subtleGreen : MKColor.subtleCitrus).opacity(0.30), in: Capsule())
        .accessibilityLabel(
            "\(feature.localizedName(language: isChinese ? .simplifiedChinese : .english)), \(isUnlocked ? (isChinese ? "已启用" : "enabled") : (isChinese ? "需要 Pro Plus" : "requires Pro Plus"))"
        )
    }
}

private struct LifestyleLogPill: View {
    let symbol: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(tint.opacity(0.13), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private enum LifestyleCheckInStatus {
    case completed
    case partial
    case none

    var fill: Color {
        switch self {
        case .completed:
            return MKColor.green
        case .partial:
            return MKColor.citrus.opacity(0.72)
        case .none:
            return MKTheme.track
        }
    }
}

private struct LifestyleHabitProgressItem: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let completedDays: Int
    let plannedDays = 7
    let dayUnit: String
    let tint: Color

    var progress: Double {
        Double(completedDays) / Double(plannedDays)
    }
}

private struct LifestyleHabitRingTile: View {
    let item: LifestyleHabitProgressItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(MKTheme.track, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: min(max(item.progress, 0), 1))
                    .stroke(item.tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: item.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(item.tint)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text("\(item.completedDays) / \(item.plannedDays) \(item.dayUnit)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(minHeight: 78)
        .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.completedDays) of \(item.plannedDays) days")
    }
}

private struct LifestyleMonth: Identifiable {
    let id: Date
    let title: String
    let leadingBlanks: Int
    let days: [LifestyleCalendarDay]
}

private struct LifestyleCalendarDay: Identifiable {
    // 用「当天零点」作为稳定标识：calendarDays 每次用 Date() 计算会带亚秒差异，
    // 若直接用 date 作 id 会导致每次渲染整排 cell 失去身份、动画被全体重触发。
    let id: Date
    let date: Date
    let status: LifestyleCheckInStatus
    let dimensions: [Double]
    let mealRatio: Double
    let dayNumber: Int

    init(date: Date, status: LifestyleCheckInStatus, dimensions: [Double], mealRatio: Double, calendar: Calendar) {
        self.id = calendar.startOfDay(for: date)
        self.date = date
        self.status = status
        self.dimensions = dimensions
        self.mealRatio = mealRatio
        self.dayNumber = calendar.component(.day, from: date)
    }

    func accessibilityLabel(isChinese: Bool) -> String {
        let state: String
        switch status {
        case .completed:
            state = isChinese ? "完成" : "completed"
        case .partial:
            state = isChinese ? "部分完成" : "partially completed"
        case .none:
            state = isChinese ? "未记录" : "not recorded"
        }
        return "\(dayNumber), \(state)"
    }
}

// 四维习惯柱状图的统一配色：饮食 / 饮水 / 睡眠 / 活动。
private enum CheckInBarStyle {
    static let tints: [Color] = [
        MKColor.green,
        MKColor.sky,
        Color(red: 0.47, green: 0.43, blue: 0.66),
        MKColor.citrus
    ]
}

// 详细记录的单个圆环：进入/切换日期时按 Apple Fitness 风格（先快后慢 + 轻微过冲）扫动填充。
private struct DetailRingTile: View {
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
        // ease-out：开始快、逐渐变慢地扫到终点。
        withAnimation(.easeOut(duration: 1.1)) {
            animated = progress
        }
    }
}

private struct CheckInCalendarDayCell: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let day: LifestyleCalendarDay
    let isSelected: Bool
    let isToday: Bool
    let index: Int
    let playToken: Int

    private let tileHeight: CGFloat = 34

    @State private var fraction: CGFloat = 1

    private var tileFill: Color {
        if isSelected { return MKColor.green.opacity(0.20) }
        if isToday { return MKColor.citrus.opacity(0.16) }
        return MKTheme.fill
    }

    private var dayNumberColor: Color {
        if isSelected { return MKColor.green }
        if isToday { return MKColor.citrus }
        return MKTheme.secondaryText
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tileFill)

                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<4, id: \.self) { i in
                        let value = day.dimensions.indices.contains(i) ? day.dimensions[i] : 0
                        MKCapsuleProgressColumn(
                            progress: value * fraction,
                            tint: i == 0 ? MKColor.mealLoad(ratio: day.mealRatio) : CheckInBarStyle.tints[i],
                            minFillHeight: value > 0 ? 2 : 0,
                            showsShadow: false
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: barTrackHeight)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .frame(height: tileHeight, alignment: .bottom)
            }
            .frame(height: tileHeight)
            .animation(.smooth(duration: 0.25), value: isSelected)

            Text("\(day.dayNumber)")
                .font(.system(size: 10, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundStyle(dayNumberColor)
                .monospacedDigit()
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .onChange(of: isSelected) { _, selected in
            guard selected else { return }
            Task { await rise(delay: 0) }
        }
    }

    private var barTrackHeight: CGFloat { tileHeight - 8 }

    @MainActor
    private func rise(delay: Double) async {
        guard !reduceMotion else {
            fraction = 1
            return
        }
        fraction = 0
        if delay > 0 {
            try? await Task.sleep(for: .seconds(delay))
        } else {
            try? await Task.sleep(for: .milliseconds(16))
        }
        withAnimation(.easeOut(duration: 0.8)) { fraction = 1 }
    }
}

// 日历下方的四维图例。
private struct CalendarLegend: View {
    let isChinese: Bool

    private var labels: [String] {
        isChinese
            ? ["饮食", "饮水", "睡眠", "活动"]
            : ["Meals", "Water", "Sleep", "Move"]
    }

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<4, id: \.self) { i in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(CheckInBarStyle.tints[i])
                        .frame(width: 8, height: 8)
                    Text(labels[i])
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(MKTheme.secondaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }
}

private struct LifestyleReviewItem: Identifiable {
    let id = UUID()
    let title: String
    let tint: Color
}

private struct LifestyleDailyReview {
    let dateTitle: String
    let items: [LifestyleReviewItem]
    let summary: String
}

private struct DataCompletenessItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let symbol: String
    let tint: Color
    let isCompleted: Bool
}

private struct DataCompletenessRow: View {
    let item: DataCompletenessItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.isCompleted ? item.tint : .secondary)
                .frame(width: 22)

            Image(systemName: item.symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(item.tint)
                .frame(width: 22)

            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            Text(item.value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
    }
}

private struct CompletenessDotGrid: View {
    let items: [DataCompletenessItem]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(item.isCompleted ? item.tint : MKTheme.track)
                        .frame(height: 34)
                        .overlay {
                            Image(systemName: item.symbol)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(item.isCompleted ? .white.opacity(0.92) : .secondary)
                        }

                    Text(item.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Data completeness")
    }
}

private struct BodyLogCard<Content: View>: View {
    let symbol: String
    let tint: Color
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.16), in: Circle())
                Text(title)
                    .font(.headline)
                Spacer()
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .mkGlassSurface(cornerRadius: 26, tint: .white.opacity(0.14))
    }
}

private struct CapsuleProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        MKCapsuleProgressBar(progress: progress, tint: tint, height: 8)
    }
}

private struct WaterCupStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let cups: Int
    let target: Int

    @State private var revealedCups = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<target, id: \.self) { index in
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(index < revealedCups ? MKColor.sky.opacity(0.86) : MKTheme.track)
                    .frame(height: 26)
                    .overlay(alignment: .bottom) {
                        if index < revealedCups {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(MKTheme.track)
                                .frame(height: 8)
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Water cups")
        .accessibilityValue("\(cups) of \(target)")
        .onAppear {
            updateCups(cups)
        }
        .onChange(of: cups) { _, newValue in
            updateCups(newValue)
        }
    }

    private func updateCups(_ value: Int) {
        let clamped = min(max(value, 0), target)
        if reduceMotion {
            revealedCups = clamped
        } else {
            withAnimation(.smooth(duration: 0.45)) {
                revealedCups = clamped
            }
        }
    }
}

private struct MacroBar: View {
    let title: String
    let eaten: Int
    let target: Int
    let tint: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(max(Double(eaten) / Double(target), 0), 1.2)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            CapsuleProgressBar(progress: progress, tint: tint)
            Text("\(eaten) / \(target)g")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 84, alignment: .trailing)
        }
    }
}

private struct WorkoutRow: View {
    let workout: WorkoutLog
    let isChinese: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKColor.deepGreen)
                .frame(width: 28, height: 28)
                .background(MKColor.deepGreen.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(workoutTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(workout.durationMinutes) \(isChinese ? "分钟" : "min") · \(workout.calories) \(isChinese ? "千卡" : "kcal")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()
        }
        .padding(10)
        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var workoutTitle: String {
        let raw = workout.type.localizedName(language: isChinese ? .simplifiedChinese : .english)
        return workout.note.isEmpty ? raw : "\(raw) · \(workout.note)"
    }
}

private struct MealRow: View {
    let meal: MealLog
    let isChinese: Bool

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: meal.createdAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKColor.green)
                .frame(width: 28, height: 28)
                .background(MKColor.green.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(meal.calories) \(isChinese ? "千卡" : "kcal") · \(timeText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()
        }
        .padding(10)
        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BodyMetricChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SupplementRow: View {
    let log: SupplementLog
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: log.takenAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pills.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKColor.citrus)
                .frame(width: 28, height: 28)
                .background(MKColor.citrus.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(log.name.isEmpty ? log.category.localizedName(language: language) : log.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if !log.dosage.isEmpty {
                    Text("\(log.dosage) · \(timeText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(timeText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MeasurementRow: View {
    let log: MeasurementLog
    let language: AppLanguage

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: log.takenAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "ruler.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKColor.coral)
                .frame(width: 28, height: 28)
                .background(MKColor.coral.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(log.kind.localizedName(language: language))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(dateText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(String(format: log.kind == .bodyFatPercentage ? "%.1f" : "%.0f", log.value)) \(log.unit)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
        .padding(10)
        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SleepEntrySheet: View {
    let isChinese: Bool
    let onSave: (SleepLog) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hoursSlept: Double = 7
    @State private var quality: SleepQuality = .fair
    @State private var note: String = ""

    private var language: AppLanguage { isChinese ? .simplifiedChinese : .english }

    var body: some View {
        NavigationStack {
            Form {
                Section(isChinese ? "时长" : "Duration") {
                    HStack {
                        Text("\(String(format: "%.1f", hoursSlept)) \(isChinese ? "小时" : "hr")")
                            .monospacedDigit()
                            .font(.headline)
                        Spacer()
                        Stepper("", value: $hoursSlept, in: 0...14, step: 0.5)
                            .labelsHidden()
                    }
                }
                Section(isChinese ? "质量" : "Quality") {
                    Picker(isChinese ? "睡眠质量" : "Sleep quality", selection: $quality) {
                        ForEach(SleepQuality.allCases) { item in
                            Text(item.localizedName(language: language)).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section(isChinese ? "备注" : "Note") {
                    TextField(isChinese ? "可选" : "Optional", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle(isChinese ? "记录睡眠" : "Log sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "取消" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isChinese ? "保存" : "Save") {
                        onSave(
                            SleepLog(
                                hoursSlept: hoursSlept,
                                quality: quality,
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SupplementEntrySheet: View {
    let isChinese: Bool
    let onSave: (SupplementLog) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category: SupplementCategory = .creatine
    @State private var customName: String = ""
    @State private var dosage: String = ""

    private var language: AppLanguage { isChinese ? .simplifiedChinese : .english }

    private var resolvedName: String {
        if category == .custom {
            return customName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return category.localizedName(language: language)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(isChinese ? "类别" : "Type") {
                    Picker(isChinese ? "类别" : "Category", selection: $category) {
                        ForEach(SupplementCategory.allCases) { item in
                            Text(item.localizedName(language: language)).tag(item)
                        }
                    }
                }
                if category == .custom {
                    Section(isChinese ? "名称" : "Name") {
                        TextField(isChinese ? "补剂名称" : "Supplement name", text: $customName)
                    }
                }
                Section(isChinese ? "剂量" : "Dosage") {
                    TextField(isChinese ? "例如 5g" : "e.g. 5g", text: $dosage)
                }
            }
            .navigationTitle(isChinese ? "记录补剂" : "Log supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "取消" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isChinese ? "保存" : "Save") {
                        onSave(
                            SupplementLog(
                                category: category,
                                name: resolvedName,
                                dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(category == .custom && resolvedName.isEmpty)
                }
            }
        }
    }
}

private struct MeasurementEntrySheet: View {
    let isChinese: Bool
    let onSave: (MeasurementLog) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: MeasurementKind = .waist
    @State private var valueText: String = ""

    private var language: AppLanguage { isChinese ? .simplifiedChinese : .english }

    private var parsedValue: Double? {
        Double(valueText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(isChinese ? "项目" : "Type") {
                    Picker(isChinese ? "项目" : "Measurement", selection: $kind) {
                        ForEach(MeasurementKind.allCases) { item in
                            Text(item.localizedName(language: language)).tag(item)
                        }
                    }
                }
                Section(isChinese ? "数值" : "Value") {
                    HStack {
                        TextField(isChinese ? "数值" : "Value", text: $valueText)
                            .keyboardType(.decimalPad)
                        Text(kind.defaultUnit)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isChinese ? "记录测量" : "Log measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "取消" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isChinese ? "保存" : "Save") {
                        if let value = parsedValue {
                            onSave(MeasurementLog(kind: kind, value: value))
                            dismiss()
                        }
                    }
                    .disabled(parsedValue == nil)
                }
            }
        }
    }
}
