import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ProgressView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \StoredWaterRecord.loggedAt) private var storedWater: [StoredWaterRecord]
    @Query(sort: \StoredWeightRecord.loggedAt) private var storedWeights: [StoredWeightRecord]

    private var review: WeeklyReview { appState.weeklyReview }
    private var summary: InsightsSummary { appState.insightsSummary }
    private var isChinese: Bool { appState.language == .simplifiedChinese }
    private var isAdvanced: Bool { appState.experienceMode == .professional }

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
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .mkGlassNavigation(
            title: isChinese ? (isAdvanced ? "进展" : "成长") : (isAdvanced ? "Progress" : "Growth"),
            subtitle: isChinese
                ? (isAdvanced ? "看行为是不是在变好。" : "看见坚持之后获得了什么。")
                : (isAdvanced ? "See whether behavior is improving." : "See what consistency has given you.")
        )
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
                     : (isChinese ? "简单回看" : "Simple review"))
                    .font(.subheadline.weight(.semibold))
                Text(isAdvanced
                     ? (isChinese ? "吃饭、训练、睡眠和体重的变化" : "Food, training, sleep, and weight changes")
                     : (isChinese ? "本周做到了什么，下周先做哪一件" : "What worked this week, one focus next week"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 22, tint: .white.opacity(0.16))
    }

    // Lifestyle 成长页：情绪价值中心，而不是数据报表。
    // 结构：成长作品卡 → 体重趋势 → 成就馆 → AI 成长洞察 → Before/Now → 分享成长。
    @ViewBuilder
    private var lifestyleSections: some View {
        GrowthMasterpieceCard(appState: appState, isChinese: isChinese)
        weightTrendSection
        achievementGallerySection
        aiGrowthInsightsSection
        beforeNowSection
        shareGrowthSection
    }

    // MARK: - Lifestyle Growth V2

    private var aiGrowthHeroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(isChinese ? "AI 成长摘要" : "AI growth summary")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                    Text(isChinese ? "看见最近真正变稳定的地方" : "What has quietly become steadier")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MKTheme.secondaryText)
                }

                Spacer(minLength: 0)

                Text(growthHeroPeriodText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MKTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(MKTheme.primary.opacity(0.10), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(isChinese ? "你最大的变化是：" : "Your biggest change:")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)
                Text(growthHeroHeadline)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(MKTheme.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(MKTheme.primary.opacity(0.45))
                    .frame(width: 3)

                Text(growthHeroSupportText)
                    .font(.subheadline)
                    .foregroundStyle(MKTheme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mkThemeInsetTile(cornerRadius: 18)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkThemeCard(cornerRadius: 26)
    }

    private var weightTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: isChinese ? "体重趋势" : "Weight trend",
                subtitle: isChinese ? "基于你的体重记录生成" : "Based on your weight logs"
            )

            WeightTrendCard(
                points: weightTrendPoints,
                isChinese: isChinese
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkThemeCard(cornerRadius: 22)
    }

    private var achievementGallerySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: isChinese ? "成就馆" : "Awards",
                subtitle: isChinese ? "像健身奖章一样，记录每次完成" : "Badges for the moments you repeat"
            )

            let achievements = achievementItems
            if achievements.isEmpty {
                emptyGrowthState(
                    symbol: "trophy.fill",
                    title: isChinese ? "第一个成就快到了" : "Your first achievement is close",
                    text: isChinese ? "先完成一次记录，就会点亮这里。" : "One log is enough to start lighting this up."
                )
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(achievements) { item in
                        NavigationLink {
                            GrowthAchievementDetailView(item: item, isChinese: isChinese)
                        } label: {
                            GrowthAchievementBadge(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkThemeCard(cornerRadius: 22)
    }

    private var aiGrowthInsightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: isChinese ? "AI 成长洞察" : "AI growth insights",
                subtitle: isChinese ? "只看行为怎么变稳定" : "Only behavior growth, kept human"
            )

            VStack(spacing: 10) {
                ForEach(growthInsightItems) { item in
                    GrowthInsightRow(item: item)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkThemeCard(cornerRadius: 24)
    }

    private var beforeNowSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: isChinese ? "成长变化" : "Before → Now",
                subtitle: isChinese ? "看见已经发生的变化" : "See what has already changed"
            )

            VStack(spacing: 10) {
                ForEach(beforeNowItems) { item in
                    GrowthBeforeNowCard(item: item)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkThemeCard(cornerRadius: 24)
    }

    private var shareGrowthSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.headline)
                    .foregroundStyle(MKColor.citrus)
                    .frame(width: 36, height: 36)
                    .background(MKColor.citrus.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(isChinese ? "分享我的成长" : "Share my growth")
                        .font(.headline)
                        .foregroundStyle(MKTheme.ink)
                    Text(isChinese ? "把这一段坚持生成一张温暖的成长纪念卡。" : "Turn this stretch of consistency into a warm memory card.")
                        .font(.subheadline)
                        .foregroundStyle(MKTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(shareOptions, id: \.self) { option in
                    Text(option)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MKTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .mkThemeInsetTile(cornerRadius: 12)
                }
            }

            Button {
            } label: {
                MKThemeSecondaryButtonLabel(symbol: "square.and.arrow.up", title: isChinese ? "生成成长卡片" : "Create growth card")
            }
            .buttonStyle(.plain)
            .accessibilityHint(isChinese ? "分享生成功能将在后续版本接入" : "Share generation will be connected in a later version")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkThemeCard(cornerRadius: 24)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(MKColor.ink)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func emptyGrowthState(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKColor.green)
                .frame(width: 34, height: 34)
                .background(MKColor.green.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MKColor.ink)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - ③ 本周回顾（AI）

    private var weeklyReflectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(isChinese ? "本周回顾" : "Weekly reflection", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MKColor.green)

            Text(review.aiSummary.isEmpty
                 ? (isChinese ? "这周你开始留下记录，已经是很好的开始。" : "You started leaving records this week — a strong start.")
                 : review.aiSummary)
                .font(.subheadline)
                .foregroundStyle(MKColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 24)
    }

    // MARK: - ④ 本周小成就

    private var smallWinsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isChinese ? "本周小成就" : "Small wins")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(MKColor.ink)

            let wins = smallWins
            if wins.isEmpty {
                Text(isChinese
                     ? "第一个成长节点会在持续记录后出现。"
                     : "Your first growth moment will appear after a little consistency.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(wins.enumerated()), id: \.element.id) { index, win in
                        HStack(spacing: 12) {
                            Image(systemName: "party.popper.fill")
                                .font(.subheadline)
                                .foregroundStyle(MKColor.citrus)
                            Text(win.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(MKColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 11)

                        if index < wins.count - 1 {
                            Divider().overlay(MKTheme.divider).padding(.leading, 28)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 24)
    }

    // MARK: - ⑤ 身体趋势（弱化、垫底）

    private var lifestyleBodyTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isChinese ? "温和变化" : "Gentle changes")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(bodyTrendRows.enumerated()), id: \.offset) { index, row in
                    HStack {
                        Text(row.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(row.value)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(MKColor.ink)
                    }
                    .padding(.vertical, 10)

                    if index < bodyTrendRows.count - 1 {
                        Divider().overlay(MKTheme.divider)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 24)
    }

    // MARK: - Lifestyle 成长数据推导

    private var growthCalendar: Calendar { .current }

    private var weekWindowStart: Date {
        let startOfToday = growthCalendar.startOfDay(for: Date())
        return growthCalendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
    }

    private func mealDayCount(from start: Date, to end: Date) -> Int {
        var days = Set<Date>()
        for meal in appState.meals where meal.createdAt >= start && meal.createdAt < end {
            days.insert(growthCalendar.startOfDay(for: meal.createdAt))
        }
        return days.count
    }

    private var thisWeekActionCount: Int {
        let end = growthCalendar.date(byAdding: .day, value: 1, to: growthCalendar.startOfDay(for: Date())) ?? Date()
        return mealDayCount(from: weekWindowStart, to: end)
    }

    private var lastWeekActionCount: Int {
        let end = weekWindowStart
        let start = growthCalendar.date(byAdding: .day, value: -7, to: end) ?? end
        return mealDayCount(from: start, to: end)
    }

    private var growthDeltaText: String {
        let delta = thisWeekActionCount - lastWeekActionCount
        if delta > 0 {
            return isChinese ? "相比上周多完成 \(delta) 次" : "\(delta) more than last week"
        }
        if delta == 0 {
            return isChinese ? "和上周保持一样稳" : "As steady as last week"
        }
        return isChinese ? "继续保持节奏，慢慢来就好" : "Keep your rhythm — easy does it"
    }

    private var allMealDays: Set<Date> {
        Set(appState.meals.map { growthCalendar.startOfDay(for: $0.createdAt) })
    }

    private var waterCupsByDay: [Date: Int] {
        var dict: [Date: Int] = [:]
        for record in storedWater {
            let day = growthCalendar.startOfDay(for: record.loggedAt)
            dict[day, default: 0] += record.cupDelta
        }
        return dict
    }

    private static let waterGoalCups = 8

    // 首次达成某行为的日期（全历史）。
    private var firstMealDate: Date? { appState.meals.map(\.createdAt).min() }
    private var firstPhotoMealDate: Date? { appState.meals.filter { $0.source != .manual }.map(\.createdAt).min() }
    private var firstBreakfastDate: Date? {
        appState.meals
            .filter { growthCalendar.component(.hour, from: $0.createdAt) < 11 }
            .map(\.createdAt).min()
    }
    private var firstSleepDate: Date? { appState.sleepLogs.map(\.createdAt).min() }
    private var firstWaterGoalDate: Date? {
        waterCupsByDay.filter { $0.value >= Self.waterGoalCups }.keys.min()
    }
    private var firstMealStreak3Date: Date? {
        firstStreakCompletionDate(days: allMealDays, length: 3)
    }

    // 连续 length 天首次达成的"完成日"。
    private func firstStreakCompletionDate(days: Set<Date>, length: Int) -> Date? {
        for day in days.sorted() {
            var ok = true
            for offset in 0..<length {
                let prev = growthCalendar.date(byAdding: .day, value: -offset, to: day)
                if let prev, days.contains(prev) { continue }
                ok = false
                break
            }
            if ok { return day }
        }
        return nil
    }

    private func isInThisWeek(_ date: Date) -> Bool {
        date >= weekWindowStart
    }

    private func weekdayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans" : "en_US")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    // 本周内的成长事件，按时间排序，最多 4 条。
    private var growthEvents: [GrowthEvent] {
        var events: [GrowthEvent] = []
        func add(_ date: Date?, _ title: String) {
            guard let date, isInThisWeek(date) else { return }
            events.append(GrowthEvent(date: date, weekday: weekdayLabel(date), title: title))
        }
        add(firstMealDate, isChinese ? "第一次记录餐食" : "First meal logged")
        add(firstPhotoMealDate, isChinese ? "第一次拍照记录" : "First photo log")
        add(firstBreakfastDate, isChinese ? "第一次记录早餐" : "First breakfast logged")
        add(firstWaterGoalDate, isChinese ? "第一次喝够水" : "First full water day")
        add(firstSleepDate, isChinese ? "开始记录睡眠" : "Started logging sleep")
        add(firstMealStreak3Date, isChinese ? "连续记录满 3 天" : "Reached a 3-day streak")
        return Array(events.sorted { $0.date < $1.date }.prefix(4))
    }

    // 已达成的"第一次"小成就（全历史）。
    private var smallWins: [GrowthEvent] {
        var wins: [GrowthEvent] = []
        if firstMealStreak3Date != nil {
            wins.append(GrowthEvent(date: .distantPast, weekday: "", title: isChinese ? "第一次连续记录 3 天" : "First 3-day streak"))
        }
        if firstWaterGoalDate != nil {
            wins.append(GrowthEvent(date: .distantPast, weekday: "", title: isChinese ? "第一次完成每日饮水目标" : "First daily water goal"))
        }
        if firstBreakfastDate != nil {
            wins.append(GrowthEvent(date: .distantPast, weekday: "", title: isChinese ? "第一次完成早餐记录" : "First breakfast logged"))
        }
        if firstPhotoMealDate != nil {
            wins.append(GrowthEvent(date: .distantPast, weekday: "", title: isChinese ? "第一次拍照记录" : "First photo log"))
        }
        return wins
    }

    private struct BodyTrendRowData {
        let title: String
        let value: String
    }

    private var bodyTrendRows: [BodyTrendRowData] {
        var rows: [BodyTrendRowData] = []

        rows.append(BodyTrendRowData(
            title: isChinese ? "行为变化" : "Behavior change",
            value: isChinese ? "本周 \(thisWeekActionCount) 次小行动" : "\(thisWeekActionCount) small actions"
        ))

        if let waist = appState.measurementLogs.filter({ $0.kind == .waist }).max(by: { $0.takenAt < $1.takenAt }) {
            rows.append(BodyTrendRowData(
                title: isChinese ? "身体参考" : "Body reference",
                value: String(format: "%.0f %@", waist.value, waist.unit)
            ))
        }

        rows.append(BodyTrendRowData(
            title: isChinese ? "当前资料" : "Current profile",
            value: String(format: "%.1f kg", appState.weightKilograms)
        ))

        return rows
    }

    private var growthHeroPeriodText: String {
        isChinese ? "最近 30 天" : "Last 30 days"
    }

    private var growthHeroHeadline: String {
        if firstMealStreak30Date != nil {
            return isChinese ? "记录已经成为你生活里的稳定习惯。" : "Logging has become a steady part of your life."
        }
        if firstMealStreak7Date != nil {
            return isChinese ? "你已经完成过连续一周记录。" : "You have already logged for a full week."
        }
        if thisWeekActionCount > lastWeekActionCount {
            return isChinese ? "记录频率正在变得更稳定。" : "Your logging rhythm is getting steadier."
        }
        if firstWaterGoalDate != nil {
            return isChinese ? "饮水习惯已经开始稳定出现。" : "Your water habit has started to show up more steadily."
        }
        if firstPhotoMealDate != nil {
            return isChinese ? "拍照记录已经迈出了第一步。" : "Photo logging has already started."
        }
        return isChinese ? "你的成长故事正在开始。" : "Your growth story is just beginning."
    }

    // AI 写给你的信（先用模板）。
    private var growthHeroSupportText: String {
        GrowthLetter.make(
            language: appState.language,
            streakDays: summary.currentLoggingStreak,
            recordCount: appState.meals.count + appState.workouts.count + appState.sleepLogs.count,
            topHabit: growthLetterTopHabit
        )
    }

    private var growthLetterTopHabit: String? {
        if firstPhotoMealDate != nil { return isChinese ? "拍照记录" : "photo logging" }
        if firstWaterGoalDate != nil { return isChinese ? "喝水" : "water" }
        if firstWorkoutDate != nil { return isChinese ? "活动" : "movement" }
        return nil
    }

    private var firstCompletedTaskDate: Date? {
        appState.dailyTasks.compactMap(\.completedAt).min()
    }

    private var firstAllTasksDate: Date? {
        let completed = appState.dailyTasks.filter { $0.status == .completed }
        guard !completed.isEmpty, completed.count == appState.dailyTasks.count else { return nil }
        return completed.compactMap(\.completedAt).max()
    }

    private var firstWorkoutDate: Date? {
        appState.workouts.map(\.createdAt).min()
    }

    private var firstMealStreak7Date: Date? {
        firstStreakCompletionDate(days: allMealDays, length: 7)
    }

    private var firstMealStreak30Date: Date? {
        firstStreakCompletionDate(days: allMealDays, length: 30)
    }

    private var weightTrendPoints: [WeightTrendPoint] {
        storedWeights
            .sorted { $0.loggedAt < $1.loggedAt }
            .map { WeightTrendPoint(date: $0.loggedAt, weightKilograms: $0.weightKilograms) }
    }

    private var firstBodyFatDropDate: Date? {
        firstLowerMeasurementDate(kind: .bodyFatPercentage)
    }

    // 时间线起点：优先使用注册日期；若有更早的记录则取更早者。
    private var firstKnownJourneyDate: Date? {
        let mealDates = appState.meals.map(\.createdAt)
        let workoutDates = appState.workouts.map(\.createdAt)
        let sleepDates = appState.sleepLogs.map(\.createdAt)
        let measurementDates = appState.measurementLogs.map(\.takenAt)
        let earliestRecord = (mealDates + workoutDates + sleepDates + measurementDates).min()
        return [appState.registeredAt, earliestRecord].compactMap { $0 }.min()
    }

    // 首次减重 1kg：相对首条体重记录下降 ≥ 1kg 的那条记录时间。
    private var firstWeightDropDate: Date? {
        let logs = storedWeights.sorted { $0.loggedAt < $1.loggedAt }
        guard let first = logs.first else { return nil }
        return logs.dropFirst().first { $0.weightKilograms <= first.weightKilograms - 1.0 }?.loggedAt
    }

    private func firstLowerMeasurementDate(kind: MeasurementKind) -> Date? {
        let logs = appState.measurementLogs
            .filter { $0.kind == kind }
            .sorted { $0.takenAt < $1.takenAt }
        guard let first = logs.first else { return nil }
        return logs.dropFirst().first { $0.value < first.value }?.takenAt
    }

    private var growthTimelineEvents: [GrowthEvent] {
        var events: [GrowthEvent] = []
        func add(_ date: Date?, title: String, detail: String, symbol: String) {
            guard let date else { return }
            events.append(GrowthEvent(
                date: date,
                weekday: shortDateLabel(date),
                title: title,
                detail: detail,
                symbol: symbol
            ))
        }

        add(
            firstKnownJourneyDate,
            title: isChinese ? "第一次来到轻减AI" : "Started QingJian AI",
            detail: isChinese ? "你的微习惯旅程从这里开始。" : "Your micro-habit journey started here.",
            symbol: "leaf.fill"
        )
        add(
            firstMealDate,
            title: isChinese ? "第一次记录" : "First log",
            detail: isChinese ? "你留下了第一条饮食记录。" : "You left your first food log.",
            symbol: "fork.knife"
        )
        add(
            firstPhotoMealDate,
            title: isChinese ? "第一次拍照记录" : "First photo log",
            detail: isChinese ? "拍一下就好，记录开始变得更轻。" : "One photo was enough. Logging became lighter.",
            symbol: "camera.fill"
        )
        add(
            firstCompletedTaskDate,
            title: isChinese ? "第一次完成任务" : "First task completed",
            detail: isChinese ? "你完成了一个真正可执行的小动作。" : "You completed one truly doable action.",
            symbol: "checkmark.circle.fill"
        )
        add(
            firstAllTasksDate,
            title: isChinese ? "第一次完成全部任务" : "First full-task day",
            detail: isChinese ? "那一天，你把该做的小事都完成了。" : "That day, you completed the small actions that mattered.",
            symbol: "checkmark.seal.fill"
        )
        add(
            firstMealStreak3Date,
            title: isChinese ? "第一次连续坚持 3 天" : "First 3-day streak",
            detail: isChinese ? "连续出现三天，习惯已经开始发芽。" : "Three days in a row means the habit started to take root.",
            symbol: "flame.fill"
        )
        add(
            firstMealStreak7Date,
            title: isChinese ? "第一次连续坚持 7 天" : "First 7-day streak",
            detail: isChinese ? "你完成过一整周记录，这很值得记住。" : "You completed a full week of logging. That is worth remembering.",
            symbol: "calendar.badge.checkmark"
        )
        add(
            firstMealStreak30Date,
            title: isChinese ? "第一次连续坚持 30 天" : "First 30-day streak",
            detail: isChinese ? "这已经不是偶然，而是稳定的生活节奏。" : "That is no longer random. It is a steady rhythm.",
            symbol: "sparkles"
        )
        add(
            firstWorkoutDate,
            title: isChinese ? "第一次活动记录" : "First activity log",
            detail: isChinese ? "你开始把轻活动也放进日常。" : "You started bringing light movement into daily life.",
            symbol: "figure.walk"
        )
        add(
            firstWaterGoalDate,
            title: isChinese ? "第一次喝满饮水目标" : "First full water day",
            detail: isChinese ? "饮水这件小事，第一次稳定完成。" : "Water, one small habit, was completed for the first time.",
            symbol: "drop.fill"
        )
        add(
            firstWeightDropDate,
            title: isChinese ? "第一次减重 1kg" : "First 1kg lost",
            detail: isChinese ? "坚持开始在身体上留下温和的回应。" : "Consistency started showing up on the scale, gently.",
            symbol: "scalemass.fill"
        )
        add(
            firstBodyFatDropDate,
            title: isChinese ? "第一次体脂下降" : "First body-fat drop",
            detail: isChinese ? "身体变化开始有了可回看的痕迹。" : "Body change started leaving a visible trace.",
            symbol: "chart.line.downtrend.xyaxis"
        )

        return events.sorted { $0.date < $1.date }
    }

    private var achievementItems: [GrowthAchievementItem] {
        [
            GrowthAchievementItem(
                title: isChinese ? "餐食记录" : "Meal logs",
                firstEarnedDate: firstMealDate,
                totalCount: appState.meals.count,
                explanation: isChinese ? "每完成一次饮食记录，都会点亮这枚徽标一次。" : "Each food log adds one completion to this badge.",
                symbol: "fork.knife",
                tint: MKColor.green,
                isChinese: isChinese
            ),
            GrowthAchievementItem(
                title: isChinese ? "拍照记录" : "Photo logs",
                firstEarnedDate: firstPhotoMealDate,
                totalCount: appState.meals.filter { $0.source != .manual }.count,
                explanation: isChinese ? "用照片完成记录时获得。它代表记录正在变轻。" : "Earned when you log with a photo. It means tracking is getting lighter.",
                symbol: "camera.fill",
                tint: MKColor.deepGreen,
                isChinese: isChinese
            ),
            GrowthAchievementItem(
                title: isChinese ? "连续 3 天" : "3-day streak",
                firstEarnedDate: firstMealStreak3Date,
                totalCount: mealStreakCompletionCount(length: 3),
                explanation: isChinese ? "连续 3 天有饮食记录时获得。重复出现，就是习惯开始形成。" : "Earned for logging meals three days in a row. Repetition is the start of a habit.",
                symbol: "flame.fill",
                tint: MKColor.citrus,
                isChinese: isChinese
            ),
            GrowthAchievementItem(
                title: isChinese ? "连续 7 天" : "7-day streak",
                firstEarnedDate: firstMealStreak7Date,
                totalCount: mealStreakCompletionCount(length: 7),
                explanation: isChinese ? "连续 7 天有饮食记录时获得。它代表你完成过一整周的节奏。" : "Earned for a full week of meal logging. It marks a real weekly rhythm.",
                symbol: "calendar.badge.checkmark",
                tint: MKColor.green,
                isChinese: isChinese
            ),
            GrowthAchievementItem(
                title: isChinese ? "喝够水" : "Water goal",
                firstEarnedDate: firstWaterGoalDate,
                totalCount: totalWaterGoalDays,
                explanation: isChinese ? "当天饮水达到目标时获得。小事稳定，也会被记住。" : "Earned on days you reach your water goal. Small steady things count.",
                symbol: "drop.fill",
                tint: MKColor.sky,
                isChinese: isChinese
            ),
            GrowthAchievementItem(
                title: isChinese ? "活动记录" : "Activity logs",
                firstEarnedDate: firstWorkoutDate,
                totalCount: appState.workouts.count,
                explanation: isChinese ? "每完成一次活动记录时获得。它代表消耗也被看见。" : "Earned for each activity log. It makes movement visible too.",
                symbol: "figure.walk",
                tint: MKColor.citrus,
                isChinese: isChinese
            ),
            GrowthAchievementItem(
                title: isChinese ? "体重记录" : "Weight logs",
                firstEarnedDate: weightTrendPoints.first?.date,
                totalCount: weightTrendPoints.count,
                explanation: isChinese ? "每记录一次体重时获得。趋势比单次数字更重要。" : "Earned for each weight log. The trend matters more than one number.",
                symbol: "scalemass.fill",
                tint: MKColor.green,
                isChinese: isChinese
            ),
            GrowthAchievementItem(
                title: isChinese ? "减重 1kg" : "1kg change",
                firstEarnedDate: firstWeightDropDate,
                totalCount: firstWeightDropDate == nil ? 0 : 1,
                explanation: isChinese ? "相对第一条体重记录下降 1kg 时获得。只作为温和反馈，不制造压力。" : "Earned when weight is 1kg below the first log. Gentle feedback, not pressure.",
                symbol: "chart.line.downtrend.xyaxis",
                tint: MKColor.deepGreen,
                isChinese: isChinese
            )
        ]
    }

    private func mealStreakCompletionCount(length: Int) -> Int {
        let days = allMealDays.sorted()
        guard days.count >= length else { return 0 }
        return days.reduce(0) { count, day in
            for offset in 0..<length {
                guard let prev = growthCalendar.date(byAdding: .day, value: -offset, to: day),
                      allMealDays.contains(prev) else {
                    return count
                }
            }
            return count + 1
        }
    }

    private var totalWaterGoalDays: Int {
        waterCupsByDay.values.filter { $0 >= Self.waterGoalCups }.count
    }

    private func achievementReason(for event: GrowthEvent) -> String {
        if event.symbol == "flame.fill" || event.symbol == "calendar.badge.checkmark" || event.symbol == "sparkles" {
            return isChinese ? "来自连续坚持" : "From consistency"
        }
        if event.symbol == "drop.fill" {
            return isChinese ? "来自饮水习惯" : "From water habit"
        }
        if event.symbol == "figure.walk" {
            return isChinese ? "来自活动记录" : "From activity logging"
        }
        return isChinese ? "来自第一次行动" : "From first action"
    }

    private func achievementTint(for symbol: String) -> Color {
        switch symbol {
        case "drop.fill": return MKColor.sky
        case "figure.walk": return MKColor.citrus
        case "scalemass.fill": return MKColor.green
        case "flame.fill", "calendar.badge.checkmark", "sparkles": return MKColor.green
        default: return MKColor.deepGreen
        }
    }

    private var growthInsightItems: [GrowthInsightItem] {
        [
            GrowthInsightItem(
                period: isChinese ? "最近 7 天" : "Last 7 days",
                title: isChinese ? "最稳定的习惯" : "Most stable habit",
                text: strongestLifestyleHabitText,
                symbol: "checkmark.seal.fill",
                tint: MKColor.green
            ),
            GrowthInsightItem(
                period: isChinese ? "最近 30 天" : "Last 30 days",
                title: isChinese ? "成长观察" : "Growth observation",
                text: thirtyDayGrowthObservation,
                symbol: "sparkles",
                tint: MKColor.deepGreen
            ),
            GrowthInsightItem(
                period: isChinese ? "最近 90 天" : "Last 90 days",
                title: isChinese ? "下一个小建议" : "Next tiny suggestion",
                text: nextTinySuggestionText,
                symbol: "arrow.forward.circle.fill",
                tint: MKColor.citrus
            )
        ]
    }

    private var strongestLifestyleHabitText: String {
        if thisWeekActionCount >= max(waterGoalDays(inLast: 7), appState.workouts.filter { daysAgo($0.createdAt) < 7 }.count) {
            return isChinese ? "饮食记录最容易出现，尤其是拍照这一步。" : "Food logging shows up most easily, especially the photo step."
        }
        if waterGoalDays(inLast: 7) > 0 {
            return isChinese ? "饮水习惯正在变得更稳定。" : "Your water habit is getting steadier."
        }
        if !appState.workouts.filter({ daysAgo($0.createdAt) < 7 }).isEmpty {
            return isChinese ? "轻活动已经开始进入你的日常。" : "Light movement has started entering your routine."
        }
        return isChinese ? "还在观察，先让一次记录稳定出现。" : "Still learning. Start by making one log show up."
    }

    private var thirtyDayGrowthObservation: String {
        let current = mealLoggedDays(inLast: 30)
        let previous = mealLoggedDays(fromDaysAgo: 60, toDaysAgo: 30)
        if current > previous {
            return isChinese ? "过去一个月，记录出现得比之前更频繁。" : "Over the past month, logging showed up more often than before."
        }
        if current >= 7 {
            return isChinese ? "过去一个月，你已经多次回到记录这件事上。" : "Over the past month, you returned to logging many times."
        }
        return isChinese ? "先把记录变得更容易，成长会慢慢累积。" : "Make logging easier first. Growth will accumulate slowly."
    }

    private var nextTinySuggestionText: String {
        if firstPhotoMealDate == nil {
            return isChinese ? "下一步只需要完成一次拍照记录。" : "Next, complete just one photo log."
        }
        if firstWaterGoalDate == nil {
            return isChinese ? "下周可以试试把水杯放在更顺手的位置。" : "Next week, try keeping your cup easier to reach."
        }
        if firstMealStreak7Date == nil {
            return isChinese ? "下一步不是做更多，而是让记录连续出现几天。" : "The next step is not doing more. Let logging show up for a few days."
        }
        return isChinese ? "继续保持最稳的小动作，不需要加码。" : "Keep the steadiest tiny action. No need to add more."
    }

    private var beforeNowItems: [GrowthBeforeNowItem] {
        var items: [GrowthBeforeNowItem] = [
            GrowthBeforeNowItem(
                title: isChinese ? "记录频率" : "Logging rhythm",
                before: isChinese ? "\(lastWeekActionCount) 次/周" : "\(lastWeekActionCount)/week",
                now: isChinese ? "\(thisWeekActionCount) 次/周" : "\(thisWeekActionCount)/week",
                caption: isChinese ? "记录正在更容易出现。" : "Logging is getting easier to show up.",
                symbol: "square.and.pencil",
                tint: MKColor.green
            ),
            GrowthBeforeNowItem(
                title: isChinese ? "饮水习惯" : "Water habit",
                before: isChinese ? "\(waterGoalDays(fromDaysAgo: 14, toDaysAgo: 7)) 天" : "\(waterGoalDays(fromDaysAgo: 14, toDaysAgo: 7)) days",
                now: isChinese ? "\(waterGoalDays(inLast: 7)) 天" : "\(waterGoalDays(inLast: 7)) days",
                caption: isChinese ? "小习惯越稳定，执行压力越低。" : "The steadier the tiny habit, the lower the effort feels.",
                symbol: "drop.fill",
                tint: MKColor.sky
            )
        ]

        if let weightChange = weightBeforeNowItem {
            items.append(weightChange)
        }
        if let bodyChange = bodyChangeBeforeNowItem {
            items.append(bodyChange)
        }
        return items
    }

    // 体重 Before→Now：取最早与最新的体重记录（需 ≥2 条且不同）。
    private var weightBeforeNowItem: GrowthBeforeNowItem? {
        let logs = storedWeights.sorted { $0.loggedAt < $1.loggedAt }
        guard let first = logs.first, let last = logs.last, first.id != last.id else { return nil }
        return GrowthBeforeNowItem(
            title: isChinese ? "体重变化" : "Weight change",
            before: String(format: "%.1f kg", first.weightKilograms),
            now: String(format: "%.1f kg", last.weightKilograms),
            caption: isChinese ? "只看变化本身，不强调还差多少。" : "Only the change itself — never how far is left.",
            symbol: "scalemass.fill",
            tint: MKColor.green
        )
    }

    private var bodyChangeBeforeNowItem: GrowthBeforeNowItem? {
        let bodyFat = measurementBeforeNow(kind: .bodyFatPercentage)
        if let bodyFat {
            return GrowthBeforeNowItem(
                title: isChinese ? "体脂变化" : "Body-fat change",
                before: String(format: "%.1f%%", bodyFat.before),
                now: String(format: "%.1f%%", bodyFat.now),
                caption: isChinese ? "这是坚持留下的身体参考，不是压力。" : "This is a body reference from consistency, not pressure.",
                symbol: "chart.line.downtrend.xyaxis",
                tint: MKColor.deepGreen
            )
        }
        let waist = measurementBeforeNow(kind: .waist)
        if let waist {
            return GrowthBeforeNowItem(
                title: isChinese ? "腰围变化" : "Waist change",
                before: String(format: "%.0f cm", waist.before),
                now: String(format: "%.0f cm", waist.now),
                caption: isChinese ? "身体变化只作为温和参考。" : "Body change stays a gentle reference.",
                symbol: "ruler.fill",
                tint: MKColor.deepGreen
            )
        }
        return nil
    }

    private func measurementBeforeNow(kind: MeasurementKind) -> (before: Double, now: Double)? {
        let logs = appState.measurementLogs
            .filter { $0.kind == kind }
            .sorted { $0.takenAt < $1.takenAt }
        guard let first = logs.first, let last = logs.last, first.id != last.id else { return nil }
        return (first.value, last.value)
    }

    private var shareOptions: [String] {
        isChinese
            ? ["AI 海报", "朋友圈卡片", "小红书图文", "成长纪念卡"]
            : ["AI poster", "Social card", "Story post", "Memory card"]
    }

    private func mealLoggedDays(inLast days: Int) -> Int {
        let start = growthCalendar.date(byAdding: .day, value: -days + 1, to: growthCalendar.startOfDay(for: Date())) ?? Date()
        let end = growthCalendar.date(byAdding: .day, value: 1, to: growthCalendar.startOfDay(for: Date())) ?? Date()
        return mealDayCount(from: start, to: end)
    }

    private func mealLoggedDays(fromDaysAgo startAgo: Int, toDaysAgo endAgo: Int) -> Int {
        let today = growthCalendar.startOfDay(for: Date())
        let start = growthCalendar.date(byAdding: .day, value: -startAgo, to: today) ?? today
        let end = growthCalendar.date(byAdding: .day, value: -endAgo, to: today) ?? today
        return mealDayCount(from: start, to: end)
    }

    private func waterGoalDays(inLast days: Int) -> Int {
        waterGoalDays(fromDaysAgo: days - 1, toDaysAgo: -1)
    }

    private func waterGoalDays(fromDaysAgo startAgo: Int, toDaysAgo endAgo: Int) -> Int {
        let today = growthCalendar.startOfDay(for: Date())
        let start = growthCalendar.date(byAdding: .day, value: -startAgo, to: today) ?? today
        let end = growthCalendar.date(byAdding: .day, value: -endAgo, to: today) ?? today
        return waterCupsByDay.filter { $0.key >= start && $0.key < end && $0.value >= Self.waterGoalCups }.count
    }

    private func daysAgo(_ date: Date) -> Int {
        growthCalendar.dateComponents([.day], from: growthCalendar.startOfDay(for: date), to: growthCalendar.startOfDay(for: Date())).day ?? Int.max
    }

    private func shortDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans" : "en_US")
        formatter.dateFormat = isChinese ? "M月d日" : "MMM d"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private var advancedSections: some View {
        professionalReviewDashboardCard
        bodyOSAdherenceCard
        weeklyCalorieTrendCard
        macroHitRateCard
        trainingCompletionCard
        recoveryTrendCard
        sleepTrendCard
        weightTrendCard
        weeklySummaryCard
        nextWeekFocusCard
    }

    private var bodyOSAdherenceCard: some View {
        let adherence = summary.adherence
        let rate = Int((adherence.overallRate * 100).rounded())
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isChinese ? "本周记录情况" : "This week's rhythm")
                        .font(.headline)
                    Text(isChinese
                         ? "把小任务、吃饭、运动和睡眠放在一起看"
                         : "Looks at tasks, meals, movement, and sleep together")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(rate)%")
                    .font(.title3.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(MKColor.green)
            }

            HStack(spacing: 10) {
                AdherenceTile(
                    title: isChinese ? "任务" : "Tasks",
                    value: "\(Int((adherence.taskCompletionRate * 100).rounded()))%"
                )
                AdherenceTile(
                    title: isChinese ? "餐食" : "Meals",
                    value: "\(adherence.mealLoggedDayCount)/7"
                )
                AdherenceTile(
                    title: isChinese ? "训练" : "Workout",
                    value: "\(adherence.workoutDayCount)/7"
                )
                AdherenceTile(
                    title: isChinese ? "睡眠" : "Sleep",
                    value: "\(adherence.sleepLoggedDayCount)/7"
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 28, tint: MKColor.subtleGreen.opacity(0.20))
    }

    private var lifestyleReviewFocusCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "leaf.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKColor.green)
                    .frame(width: 30, height: 30)
                    .background(MKColor.green.opacity(0.13), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(isChinese ? "本周先看一件事" : "Look at one thing this week")
                        .font(.headline)
                    Text(lifestyleReviewSentence)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            WeeklyRhythmMap(days: summary.days, isChinese: isChinese)

            Text(review.nextWeekFocus)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 26, tint: MKColor.subtleGreen.opacity(0.18))
    }

    private var professionalReviewDashboardCard: some View {
        let target = appState.macroTarget
        let proteinHits = proteinHitDays(target: target)
        let weeklyTarget = max(appState.profile.weeklyWorkoutCount, 1)
        let workoutCount = appState.workouts.filter {
            Calendar.current.dateComponents([.day], from: $0.createdAt, to: Date()).day.map { $0 < 7 } ?? false
        }.count
        let recovery = appState.bodyOSRecoveryScore

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isChinese ? "本周数据总览" : "Weekly data overview")
                        .font(.headline)
                    Text(isChinese
                         ? "用于判断下周热量、训练和恢复是否需要调整"
                         : "Used to decide next week's calorie, training, and recovery adjustments")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            ProfessionalOverviewRings(
                calorieProgress: professionalCalorieBalanceProgress,
                proteinProgress: Double(proteinHits) / Double(max(summary.days.count, 1)),
                trainingProgress: Double(workoutCount) / Double(max(weeklyTarget, 1)),
                recoveryProgress: Double(recovery.value) / 100,
                isChinese: isChinese,
                recoveryTint: recoveryTint(recovery.state)
            )

            VStack(spacing: 0) {
                ProfessionalReviewRow(
                    title: isChinese ? "热量净差" : "Calorie balance",
                    value: "\(summary.weeklyBalance)",
                    detail: isChinese ? "千卡" : "kcal",
                    tint: summary.isWithinGentleRange ? MKColor.green : MKColor.citrus
                )
                Divider().overlay(MKTheme.divider)
                ProfessionalReviewRow(
                    title: isChinese ? "蛋白达标" : "Protein hits",
                    value: "\(proteinHits)/\(summary.days.count)",
                    detail: isChinese ? "天" : "days",
                    tint: MKColor.green
                )
                Divider().overlay(MKTheme.divider)
                ProfessionalReviewRow(
                    title: isChinese ? "训练完成" : "Training",
                    value: "\(workoutCount)/\(weeklyTarget)",
                    detail: isChinese ? "次" : "sessions",
                    tint: workoutCount >= weeklyTarget ? MKColor.green : MKColor.citrus
                )
                Divider().overlay(MKTheme.divider)
                ProfessionalReviewRow(
                    title: isChinese ? "恢复评分" : "Recovery",
                    value: "\(recovery.value)",
                    detail: recoveryStateLabel(recovery.state),
                    tint: recoveryTint(recovery.state)
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 26, tint: .white.opacity(0.12))
    }

    private var lifestyleReviewSentence: String {
        if review.taskCompletionRate < 0.34 {
            return isChinese ? "不是做得不够好，是任务还可以再变小。" : "This is not failure. The task can be made smaller."
        }
        if summary.loggedDayCount < 3 {
            return isChinese ? "先让记录更容易出现，不追求每天完整。" : "Make logging easier to show up; no need for complete days."
        }
        return isChinese ? "已经有节奏了，下周只保留一个最稳的小动作。" : "There is a rhythm now. Keep one stable small action next week."
    }

    private var weeklySummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(isChinese ? "本周复盘" : "Weekly review", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(MKColor.green)
            Text(review.aiSummary)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .mkGlassSurface(cornerRadius: 28, tint: .white.opacity(0.16))
    }

    private var progressHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                MKIconBadge(
                    symbol: progressHeroSymbol,
                    tint: progressHeroTint,
                    fill: progressHeroTint.opacity(0.16),
                    size: 48
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(progressHeroTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(progressHeroSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            ProgressTrack(progress: review.taskCompletionRate, tint: progressHeroTint)

            HStack {
                Text(isChinese ? "本周行为完成率" : "Weekly behavior rate")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(review.taskCompletionRate * 100))%")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(progressHeroTint)
            }
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 28, tint: MKColor.subtleGreen.opacity(0.20))
    }

    private var behaviorStatsCard: some View {
        HStack(spacing: 10) {
            ProgressMetric(
                title: isChinese ? "小任务" : "Tasks",
                value: "\(review.completedTaskCount)",
                subtitle: isChinese ? "已完成" : "completed"
            )
            ProgressMetric(
                title: isChinese ? "连续" : "Streak",
                value: "\(summary.currentLoggingStreak)",
                subtitle: isChinese ? "记录天数" : "logged days"
            )
            ProgressMetric(
                title: isChinese ? "记录日" : "Log days",
                value: "\(summary.loggedDayCount)/7",
                subtitle: isChinese ? "本周有记录" : "days this week"
            )
        }
        .padding(14)
        .mkGlassSurface(cornerRadius: 28, tint: MKColor.subtleGreen.opacity(0.16))
    }

    private var loggingRhythmCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(isChinese ? "本周记录节奏" : "Weekly logging rhythm")
                    .font(.headline)
                Spacer()
                Text(isChinese ? "\(summary.loggedDayCount)/7 天" : "\(summary.loggedDayCount)/7 days")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(MKColor.green)
            }

            HStack(spacing: 8) {
                ForEach(summary.days) { day in
                    LoggingDayPill(day: day, isChinese: isChinese)
                }
            }

            Text(isChinese
                 ? "目标不是每天写很多，只是让记录这件事更容易出现。"
                 : "The goal is not detailed logging every day. It is making the behavior easier to show up.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 28, tint: .white.opacity(0.14))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isChinese ? "本周记录节奏" : "Weekly logging rhythm")
        .accessibilityValue(isChinese ? "\(summary.loggedDayCount) 天有记录" : "\(summary.loggedDayCount) days logged")
    }

    private var habitCompletionChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(isChinese ? "行为完成图" : "Habit completion")
                    .font(.headline)
                Spacer()
                Text(isChinese ? "轻量观察" : "Light check")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MKColor.green)
            }

            VStack(spacing: 10) {
                ForEach(habitProgressRows) { row in
                    HabitProgressRow(row: row)
                }
            }
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 28, tint: .white.opacity(0.14))
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReviewLine(
                title: isChinese ? "最稳定的习惯" : "Most stable habit",
                value: review.strongestHabit ?? (isChinese ? "还在观察" : "Still learning"),
                symbol: "checkmark.seal.fill"
            )
            ReviewLine(
                title: isChinese ? "最大阻碍" : "Biggest obstacle",
                value: review.biggestObstacle ?? (isChinese ? "还在观察" : "Still learning"),
                symbol: "moon.zzz.fill"
            )
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 28, tint: .white.opacity(0.14))
    }

    private var difficultyAdjustmentCard: some View {
        let adjustment = review.difficultyAdjustment
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: adjustment == .makeEasier ? "arrow.down.circle.fill" : "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(adjustment == .makeEasier ? MKColor.citrus : MKColor.green)
                .frame(width: 34, height: 34)
                .background((adjustment == .makeEasier ? MKColor.subtleCitrus : MKColor.subtleGreen).opacity(0.38), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(isChinese ? "下周难度建议" : "Next week difficulty")
                    .font(.headline)
                Text(difficultyAdjustmentText(adjustment))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .mkGlassSurface(cornerRadius: 24, tint: .white.opacity(0.12))
    }

    private var nextWeekFocusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(isChinese ? "下周只改一件事" : "One focus next week", systemImage: "target")
                .font(.headline)
                .foregroundStyle(MKColor.green)
            Text(review.nextWeekFocus)
                .font(.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .mkGlassSurface(cornerRadius: 28, tint: .white.opacity(0.16))
    }

    private var weightTrendCard: some View {
        let current = appState.weightKilograms
        let target = appState.profile.targetWeightKilograms
        let delta = current - target
        return ProgressCard(
            symbol: "scalemass.fill",
            tint: MKColor.green,
            title: isChinese ? "体重趋势" : "Weight trend"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(String(format: "%.1f", current))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text("kg")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(deltaLabel(delta: delta))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(delta > 0 ? MKColor.citrus : MKColor.green)
                }
                Text(isChinese
                     ? "目标 \(String(format: "%.1f", target)) kg · 完整体重曲线需要每日记录积累。"
                     : "Target \(String(format: "%.1f", target)) kg · A full curve needs daily logging.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var weeklyCalorieTrendCard: some View {
        let days = summary.days
        let maxValue = max(
            days.map(\.eatenCalories).max() ?? 0,
            days.first?.goalCalories ?? 0,
            1
        )
        return ProgressCard(
            symbol: "flame.fill",
            tint: MKColor.coral,
            title: isChinese ? "周热量趋势" : "Weekly calorie trend"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(days) { day in
                        WeeklyCalorieBar(
                            day: day,
                            maxValue: maxValue,
                            isChinese: isChinese
                        )
                    }
                }
                .frame(height: 110)

                HStack(spacing: 12) {
                    LegendDot(color: MKColor.green, label: isChinese ? "在范围内" : "In range")
                    LegendDot(color: MKColor.citrus, label: isChinese ? "高于目标" : "Above goal")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                Text(isChinese
                     ? "周净差 \(summary.weeklyBalance) 千卡 · \(summary.isWithinGentleRange ? "仍在温和范围内" : "偏离温和范围")"
                     : "Net weekly balance \(summary.weeklyBalance) kcal · \(summary.isWithinGentleRange ? "still gentle" : "outside gentle range")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var macroHitRateCard: some View {
        let target = appState.macroTarget
        let hits = proteinHitDays(target: target)
        let denominator = max(summary.days.count, 1)
        let rate = Double(hits) / Double(denominator)
        return ProgressCard(
            symbol: "fish.fill",
            tint: MKColor.green,
            title: isChinese ? "蛋白达标率" : "Protein hit rate"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(Int(rate * 100))%")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(MKColor.green)
                    Text(isChinese ? "本周达标 \(hits)/\(denominator) 天" : "\(hits)/\(denominator) days hit")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ProgressTrack(progress: rate, tint: MKColor.green)
                Text(isChinese
                     ? "目标蛋白 \(target.protein)g · 单日达 85% 视为达标。"
                     : "Protein target \(target.protein)g · 85% counts as a hit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var trainingCompletionCard: some View {
        let weeklyTarget = max(appState.profile.weeklyWorkoutCount, 1)
        let done = appState.workouts.filter { date in
            Calendar.current.dateComponents([.day], from: date.createdAt, to: Date()).day.map { $0 < 7 } ?? false
        }.count
        let rate = min(Double(done) / Double(weeklyTarget), 1.2)
        return ProgressCard(
            symbol: "figure.strengthtraining.traditional",
            tint: MKColor.deepGreen,
            title: isChinese ? "训练完成率" : "Training completion"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(done)/\(weeklyTarget)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text(isChinese ? "本周训练次数" : "weekly sessions")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(min(rate, 1) * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ProgressTrack(progress: rate, tint: MKColor.deepGreen)
                Text(isChinese
                     ? "周训练目标来自个人资料中的每周训练次数。"
                     : "Weekly target comes from your profile's weekly workout count.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var recoveryTrendCard: some View {
        let score = appState.bodyOSRecoveryScore
        let factors = score.factors.prefix(3)
        return ProgressCard(
            symbol: "heart.text.square.fill",
            tint: recoveryTint(score.state),
            title: isChinese ? "恢复趋势" : "Recovery trend"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(score.value)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(recoveryTint(score.state))
                    Text(recoveryStateLabel(score.state))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ProgressTrack(progress: Double(score.value) / 100, tint: recoveryTint(score.state))
                if factors.isEmpty {
                    Text(isChinese
                         ? "完整恢复趋势需要 HealthKit 睡眠 / HRV 数据。"
                         : "Full recovery trend needs HealthKit sleep / HRV inputs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 8) {
                        ForEach(Array(factors), id: \.self) { factor in
                            Text(factor.replacingOccurrences(of: "_", with: " "))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(recoveryTint(score.state).opacity(0.18), in: Capsule())
                                .foregroundStyle(recoveryTint(score.state))
                        }
                    }
                }
            }
        }
    }

    private var sleepTrendCard: some View {
        ProgressCard(
            symbol: "moon.stars.fill",
            tint: MKColor.sky,
            title: isChinese ? "睡眠趋势" : "Sleep trend"
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isChinese ? "等待 HealthKit 接入" : "Awaiting HealthKit data")
                    .font(.subheadline.weight(.semibold))
                Text(isChinese
                     ? "时长、深睡占比、入睡时间将由健康连接后驱动恢复评分趋势。"
                     : "Duration, deep sleep ratio, and onset will drive the recovery score trend once Health is connected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func deltaLabel(delta: Double) -> String {
        if abs(delta) < 0.05 {
            return isChinese ? "已到目标" : "On target"
        }
        let absoluteText = String(format: "%.1f kg", abs(delta))
        if delta > 0 {
            return isChinese ? "还差 \(absoluteText)" : "\(absoluteText) above"
        }
        return isChinese ? "低于目标 \(absoluteText)" : "\(absoluteText) below"
    }

    private var progressHeroSymbol: String {
        if review.taskCompletionRate >= 0.67 { return "checkmark.seal.fill" }
        if summary.loggedDayCount >= 3 { return "calendar.badge.checkmark" }
        return "leaf.fill"
    }

    private var progressHeroTint: Color {
        if review.taskCompletionRate >= 0.67 { return MKColor.green }
        if summary.loggedDayCount >= 3 { return MKColor.sky }
        return MKColor.citrus
    }

    private var progressHeroTitle: String {
        if isChinese {
            if review.completedTaskCount > 0 {
                return "本周你完成了 \(review.completedTaskCount) 次小动作。"
            }
            if summary.loggedDayCount > 0 {
                return "本周已经留下 \(summary.loggedDayCount) 天记录。"
            }
            return "这周先从一个很小的记录开始。"
        }

        if review.completedTaskCount > 0 {
            return "You completed \(review.completedTaskCount) small actions this week."
        }
        if summary.loggedDayCount > 0 {
            return "You logged on \(summary.loggedDayCount) days this week."
        }
        return "Start this week with one very small log."
    }

    private var progressHeroSubtitle: String {
        if isChinese {
            if summary.currentLoggingStreak >= 2 {
                return "已经连续记录 \(summary.currentLoggingStreak) 天，先保留这个节奏。"
            }
            if review.taskCompletionRate >= 0.67 {
                return "行为正在变稳定，不需要把每一天都做满。"
            }
            return "看行为有没有变容易，不用用体重评价一整周。"
        }

        if summary.currentLoggingStreak >= 2 {
            return "You have a \(summary.currentLoggingStreak)-day logging rhythm. Keep that first."
        }
        if review.taskCompletionRate >= 0.67 {
            return "The behavior is getting steadier. Every day does not need to be full."
        }
        return "Look for easier behavior, not a weekly verdict from weight."
    }

    private func difficultyAdjustmentText(_ adjustment: WeeklyReviewDifficultyAdjustment) -> String {
        switch (adjustment, isChinese) {
        case (.makeEasier, true):
            return "先把任务降到更容易开始的版本。能完成一点，比继续硬撑更重要。"
        case (.makeEasier, false):
            return "Make the task easier to start. Completing a little matters more than pushing harder."
        case (.keep, true):
            return "当前难度可以先保持。下周只增加一个很小的关注点。"
        case (.keep, false):
            return "Keep the current difficulty. Add only one very small focus next week."
        }
    }

    private var habitProgressRows: [HabitProgressData] {
        let progress = WeeklyReviewGenerator.habitProgress(
            habits: appState.activeHabits,
            tasks: appState.dailyTasks
        )
        if progress.isEmpty {
            return [
                HabitProgressData(
                    title: isChinese ? "午餐前拍一下" : "Snap lunch before eating",
                    detail: isChinese ? "等待第一个小任务" : "Waiting for the first tiny task",
                    progress: 0,
                    tint: MKColor.citrus
                )
            ]
        }

        return progress.map { item in
            let detail: String
            let tint: Color

            if item.hasSkippedTask {
                detail = isChinese ? "这项可能偏难，下周可以降低难度" : "This may be too hard. Lower it next week."
                tint = MKColor.citrus
            } else if item.completedCount > 0 {
                detail = isChinese ? "已完成，继续保持轻一点" : "Done. Keep it light."
                tint = MKColor.green
            } else {
                detail = isChinese ? "还没稳定出现，可以只做最小版本" : "Not stable yet. The smallest version counts."
                tint = MKColor.sky
            }

            return HabitProgressData(
                title: item.title,
                detail: detail,
                progress: item.completionRate,
                tint: tint
            )
        }
    }

    private func proteinHitDays(target: MacroTarget) -> Int {
        guard target.protein > 0 else { return 0 }
        let calendar = Calendar.current
        return summary.days.reduce(0) { partial, day in
            let dayMeals = appState.meals.filter { calendar.isDate($0.createdAt, inSameDayAs: day.date) }
            let total = dayMeals.map(\.protein).reduce(0, +)
            let threshold = Int(Double(target.protein) * 0.85)
            return partial + (total >= threshold && total > 0 ? 1 : 0)
        }
    }

    private var professionalCalorieBalanceProgress: Double {
        let weeklyTarget = max(appState.bodyOSNutritionTarget.deficit * 7, 1)
        let distance = abs(summary.weeklyBalance - weeklyTarget)
        return min(max(1 - Double(distance) / Double(max(weeklyTarget, 1)), 0), 1)
    }

    private func recoveryStateLabel(_ state: BodyOSRecoveryState) -> String {
        if isChinese {
            switch state {
            case .good: return "恢复良好"
            case .moderate: return "中等恢复"
            case .low: return "恢复偏低"
            case .critical: return "恢复严重不足"
            }
        }
        switch state {
        case .good: return "Recovery good"
        case .moderate: return "Recovery fair"
        case .low: return "Recovery low"
        case .critical: return "Recovery critical"
        }
    }

    private func recoveryTint(_ state: BodyOSRecoveryState) -> Color {
        switch state {
        case .good: return MKColor.green
        case .moderate: return MKColor.sky
        case .low: return MKColor.citrus
        case .critical: return MKColor.coral
        }
    }
}

private struct WeeklyRhythmMap: View {
    let days: [DailyEnergyBalance]
    let isChinese: Bool

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days) { day in
                VStack(spacing: 7) {
                    MKCapsuleProgressColumn(
                        progress: day.eatenCalories > 0 ? 1 : 0,
                        tint: rhythmTint(for: day),
                        minFillHeight: day.eatenCalories > 0 ? 2 : 0,
                        showsShadow: false
                    )
                        .frame(height: barHeight(for: day))
                        .frame(maxHeight: 44, alignment: .bottom)
                    Text(dayLabel(for: day))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .bottom)
            }
        }
        .padding(12)
        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isChinese ? "本周记录节奏图" : "Weekly rhythm chart")
    }

    private func rhythmTint(for day: DailyEnergyBalance) -> Color {
        guard day.eatenCalories > 0 else { return MKTheme.track }
        return day.balance > 200 ? MKColor.citrus : MKColor.green
    }

    private func barHeight(for day: DailyEnergyBalance) -> CGFloat {
        guard day.eatenCalories > 0 else { return 12 }
        return day.balance > 200 ? 44 : 34
    }

    private func dayLabel(for day: DailyEnergyBalance) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans" : "en_US")
        formatter.dateFormat = "EEE"
        return formatter.string(from: day.date)
    }
}

private struct ProfessionalOverviewRings: View {
    let calorieProgress: Double
    let proteinProgress: Double
    let trainingProgress: Double
    let recoveryProgress: Double
    let isChinese: Bool
    let recoveryTint: Color

    var body: some View {
        HStack(spacing: 10) {
            MiniProgressRing(
                title: isChinese ? "热量" : "Energy",
                progress: calorieProgress,
                tint: MKColor.coral
            )
            MiniProgressRing(
                title: isChinese ? "蛋白" : "Protein",
                progress: proteinProgress,
                tint: MKColor.green
            )
            MiniProgressRing(
                title: isChinese ? "训练" : "Training",
                progress: trainingProgress,
                tint: MKColor.deepGreen
            )
            MiniProgressRing(
                title: isChinese ? "恢复" : "Recovery",
                progress: recoveryProgress,
                tint: recoveryTint
            )
        }
        .accessibilityElement(children: .contain)
    }
}

private struct MiniProgressRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let progress: Double
    let tint: Color

    @State private var animatedProgress = 0.0

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .stroke(MKTheme.track, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(max(animatedProgress, 0), 1))
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(min(max(progress, 0), 1) * 100))")
                    .font(.caption.weight(.heavy))
                    .monospacedDigit()
            }
            .frame(width: 48, height: 48)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(min(max(progress, 0), 1) * 100))%")
        .onAppear {
            updateProgress(progress)
        }
        .onChange(of: progress) { _, newValue in
            updateProgress(newValue)
        }
    }

    private func updateProgress(_ value: Double) {
        if reduceMotion {
            animatedProgress = value
        } else {
            withAnimation(.smooth(duration: 0.55)) {
                animatedProgress = value
            }
        }
    }
}

private struct ProfessionalReviewRow: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct ProgressCard<Content: View>: View {
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
        .mkGlassSurface(cornerRadius: 28, tint: .white.opacity(0.14))
    }
}

private struct ProgressMetric: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ReviewLine: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(MKColor.green)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct HabitProgressData: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let progress: Double
    let tint: Color
}

private struct HabitProgressRow: View {
    let row: HabitProgressData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 8)
                Text("\(Int(row.progress * 100))%")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(row.tint)
            }

            ProgressTrack(progress: row.progress, tint: row.tint)

            Text(row.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.title)
        .accessibilityValue("\(Int(row.progress * 100))%. \(row.detail)")
    }
}

private struct LoggingDayPill: View {
    let day: DailyEnergyBalance
    let isChinese: Bool

    private var didLog: Bool {
        day.eatenCalories > 0
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans" : "en_US")
        formatter.dateFormat = "EEE"
        return formatter.string(from: day.date)
    }

    private var accessibilityText: String {
        if isChinese {
            return didLog ? "\(dayLabel)，已记录 \(day.eatenCalories) 千卡" : "\(dayLabel)，未记录"
        }
        return didLog ? "\(dayLabel), logged \(day.eatenCalories) calories" : "\(dayLabel), not logged"
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: didLog ? "checkmark" : "minus")
                .font(.caption.weight(.bold))
                .foregroundStyle(didLog ? MKColor.green : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    didLog ? MKColor.subtleGreen.opacity(0.45) : MKTheme.track,
                    in: Circle()
                )

            Text(dayLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}

private struct GrowthEvent: Identifiable {
    let id = UUID()
    let date: Date
    let weekday: String
    let title: String
    var detail: String = ""
    var symbol: String = "sparkles"
}

private struct WeightTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weightKilograms: Double
}

private struct GrowthAchievementItem: Identifiable {
    let id = UUID()
    let title: String
    let firstEarnedDate: Date?
    let totalCount: Int
    let explanation: String
    let symbol: String
    let tint: Color
    let isChinese: Bool

    var isEarned: Bool { totalCount > 0 }

    var countText: String {
        isChinese ? "\(totalCount) 次" : "\(totalCount)x"
    }

    var firstEarnedText: String {
        guard let firstEarnedDate else {
            return isChinese ? "尚未获得" : "Not earned yet"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans" : "en_US")
        formatter.dateFormat = isChinese ? "yyyy年M月d日" : "MMM d, yyyy"
        return formatter.string(from: firstEarnedDate)
    }
}

private struct GrowthInsightItem: Identifiable {
    let id = UUID()
    let period: String
    let title: String
    let text: String
    let symbol: String
    let tint: Color
}

private struct GrowthBeforeNowItem: Identifiable {
    let id = UUID()
    let title: String
    let before: String
    let now: String
    let caption: String
    let symbol: String
    let tint: Color
}

private struct GrowthTimelineList: View {
    let events: [GrowthEvent]
    let isChinese: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: 14) {
                    Text(event.weekday)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MKTheme.secondaryText)
                        .frame(width: 54, alignment: .leading)
                        .padding(.top, 1)

                    VStack(spacing: 0) {
                        Circle()
                            .fill(MKTheme.primary.opacity(0.45))
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        if index < events.count - 1 {
                            Rectangle()
                                .fill(MKTheme.primary.opacity(0.14))
                                .frame(width: 1, height: 34)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MKTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if event.detail.isEmpty == false {
                            Text(event.detail)
                                .font(.caption)
                                .foregroundStyle(MKTheme.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, index < events.count - 1 ? 18 : 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(event.weekday), \(event.title)")
            }
        }
    }
}

private struct WeightTrendCard: View {
    let points: [WeightTrendPoint]
    let isChinese: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WeightTrendChart(points: points)
                .frame(height: points.count >= 2 ? 112 : 98)

            if points.count < 2 {
                HStack(spacing: 10) {
                    Image(systemName: "scalemass")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MKTheme.primary)
                        .frame(width: 24, height: 24)
                        .background(MKTheme.primary.opacity(0.10), in: Circle())

                    Text(isChinese ? "记录 2 次体重后，这里会显示趋势。" : "Log weight twice to show your trend.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MKTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct WeightTrendChart: View {
    let points: [WeightTrendPoint]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(MKTheme.divider.opacity(0.62))
                            .frame(height: 1)
                        Spacer(minLength: 0)
                    }
                    Rectangle()
                        .fill(MKTheme.divider.opacity(0.62))
                        .frame(height: 1)
                }

                if points.count >= 2 {
                    let chartPoints = mappedPoints(in: geo.size)
                    Path { path in
                        guard let first = chartPoints.first else { return }
                        path.move(to: first)
                        for point in chartPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(MKTheme.primary, style: StrokeStyle(lineWidth: 2.25, lineCap: .round, lineJoin: .round))
                } else {
                    VStack(spacing: 10) {
                        Path { path in
                            let width = geo.size.width * 0.52
                            let startX = (geo.size.width - width) / 2
                            let midY = geo.size.height * 0.52
                            path.move(to: CGPoint(x: startX, y: midY + 10))
                            path.addLine(to: CGPoint(x: startX + width * 0.32, y: midY + 4))
                            path.addLine(to: CGPoint(x: startX + width * 0.66, y: midY + 8))
                            path.addLine(to: CGPoint(x: startX + width, y: midY - 8))
                        }
                        .stroke(MKTheme.primary.opacity(0.26), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func mappedPoints(in size: CGSize) -> [CGPoint] {
        let sorted = points.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return [] }

        let weights = sorted.map(\.weightKilograms)
        let minWeight = weights.min() ?? 0
        let maxWeight = weights.max() ?? 1
        let span = max(maxWeight - minWeight, 0.4)
        let horizontalStep = size.width / CGFloat(max(sorted.count - 1, 1))
        let verticalPadding: CGFloat = 10
        let chartHeight = max(size.height - verticalPadding * 2, 1)

        return sorted.enumerated().map { index, point in
            let x = CGFloat(index) * horizontalStep
            let normalized = (point.weightKilograms - minWeight) / span
            let y = verticalPadding + chartHeight * CGFloat(1 - normalized)
            return CGPoint(x: x, y: y)
        }
    }
}

private struct GrowthAchievementBadge: View {
    let item: GrowthAchievementItem

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(item.isEarned ? item.tint.opacity(0.08) : Color.clear)
                    .frame(width: 64, height: 64)
                Circle()
                    .strokeBorder(item.isEarned ? item.tint.opacity(0.26) : MKTheme.divider.opacity(0.82), lineWidth: 1)
                    .frame(width: 64, height: 64)
                Circle()
                    .strokeBorder(item.isEarned ? item.tint.opacity(0.08) : .clear, lineWidth: 5)
                    .frame(width: 52, height: 52)
                Image(systemName: item.symbol)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(item.isEarned ? item.tint : MKTheme.secondaryText.opacity(0.46))
            }

            Text(item.countText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(item.isEarned ? MKTheme.ink : MKTheme.secondaryText.opacity(0.82))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.countText)")
    }
}

private struct GrowthAchievementDetailView: View {
    let item: GrowthAchievementItem
    let isChinese: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 18) {
                ZStack {
                    Circle()
                        .fill(item.isEarned ? item.tint.opacity(0.12) : MKTheme.track)
                        .frame(width: 96, height: 96)
                    Circle()
                        .stroke(item.isEarned ? item.tint.opacity(0.26) : MKTheme.divider, lineWidth: 1)
                        .frame(width: 96, height: 96)
                    Image(systemName: item.symbol)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(item.isEarned ? item.tint : MKTheme.secondaryText.opacity(0.55))
                }

                VStack(spacing: 8) {
                    Text(item.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                        .multilineTextAlignment(.center)
                    Text(item.countText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.tint)
                }

                VStack(alignment: .leading, spacing: 10) {
                    DetailLine(
                        title: isChinese ? "徽标解释" : "Meaning",
                        value: item.explanation
                    )
                    DetailLine(
                        title: isChinese ? "第一次获得" : "First earned",
                        value: item.firstEarnedText
                    )
                    DetailLine(
                        title: isChinese ? "总获得次数" : "Total earned",
                        value: item.countText
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .mkThemeCard(cornerRadius: 22)
            }
            .padding(24)
        }
        .background(MKThemeBackground())
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DetailLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MKTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

private struct GrowthInsightRow: View {
    let item: GrowthInsightItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(item.tint)
                .frame(width: 32, height: 32)
                .background(item.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MKTheme.ink)
                    Spacer(minLength: 8)
                    Text(item.period)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(item.tint)
                }

                Text(item.text)
                    .font(.subheadline)
                    .foregroundStyle(MKTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct GrowthBeforeNowCard: View {
    let item: GrowthBeforeNowItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(item.tint)
                .frame(width: 32, height: 32)
                .background(item.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MKTheme.ink)
                    Spacer(minLength: 10)
                    Text("\(item.before)  →  \(item.now)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(item.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Text(item.caption)
                    .font(.caption)
                    .foregroundStyle(MKTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct JourneyTimeline: View {
    let events: [GrowthEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(MKColor.green)
                            .frame(width: 10, height: 10)
                        if index < events.count - 1 {
                            Rectangle()
                                .fill(MKTheme.track)
                                .frame(width: 2, height: 28)
                        }
                    }
                    .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MKColor.ink)
                        if !event.weekday.isEmpty {
                            Text(event.weekday)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, index < events.count - 1 ? 12 : 0)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(12)
        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ProgressTrack: View {
    let progress: Double
    let tint: Color

    var body: some View {
        MKCapsuleProgressBar(progress: progress, tint: tint, height: 8)
    }
}

private struct WeeklyCalorieBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let day: DailyEnergyBalance
    let maxValue: Int
    let isChinese: Bool

    @State private var animatedRatio = 0.0

    private var ratio: Double {
        Double(day.eatenCalories) / Double(max(maxValue, 1))
    }

    private var goalRatio: Double {
        Double(day.goalCalories) / Double(max(maxValue, 1))
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans" : "en_US")
        formatter.dateFormat = "EEE"
        return formatter.string(from: day.date)
    }

    private var tint: Color {
        guard day.eatenCalories > 0 else { return MKTheme.track }
        return day.balance > 200 ? MKColor.citrus : MKColor.green
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    MKCapsuleProgressColumn(
                        progress: animatedRatio,
                        tint: tint,
                        minFillHeight: 4,
                        showsShadow: false
                    )
                    Rectangle()
                        .fill(MKTheme.track)
                        .frame(height: 1)
                        .offset(y: -geo.size.height * goalRatio)
                }
            }
            Text(dayLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            updateRatio(ratio)
        }
        .onChange(of: ratio) { _, newValue in
            updateRatio(newValue)
        }
    }

    private func updateRatio(_ value: Double) {
        if reduceMotion {
            animatedRatio = value
        } else {
            withAnimation(.smooth(duration: 0.55)) {
                animatedRatio = value
            }
        }
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
        }
    }
}
private struct AdherenceTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Lifestyle 成长作品卡（照抄 Advanced 设计）

private struct GrowthMasterpieceCard: View {
    let appState: AppState
    let isChinese: Bool

    @State private var showsEditSheet = false
    @State private var customization: GrowthAlbumCustomization = .default
    @State private var showsShareSheet = false
    @State private var shareImage: UIImage?

    private var calendar: Calendar { Calendar.current }

    // 坚持天数：从第一次使用到今天的天数
    private var totalDays: Int {
        guard let firstDate = firstRecordDate else { return 0 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: firstDate), to: calendar.startOfDay(for: Date())).day ?? 0
        return max(days + 1, 1)
    }

    // 记录次数：所有记录的累计次数
    private var totalRecords: Int {
        appState.meals.count + appState.workouts.count + appState.sleepLogs.count
    }

    // 体重变化
    private var weightChangeText: String {
        let current = appState.weightKilograms
        let target = appState.profile.targetWeightKilograms
        let delta = current - target
        if abs(delta) < 0.1 { return isChinese ? "稳定" : "Stable" }
        return delta < 0
            ? "-\(String(format: "%.1f", abs(delta)))kg"
            : "+\(String(format: "%.1f", delta))kg"
    }

    // 连续天数：最长连续记录天数
    private var longestStreak: Int {
        let mealDays = Set(appState.meals.map { calendar.startOfDay(for: $0.createdAt) })
        let workoutDays = Set(appState.workouts.map { calendar.startOfDay(for: $0.createdAt) })
        let allDays = mealDays.union(workoutDays)

        guard !allDays.isEmpty else { return 0 }

        let sortedDays = allDays.sorted()
        var maxStreak = 1
        var currentStreak = 1

        for i in 1..<sortedDays.count {
            let prevDay = calendar.date(byAdding: .day, value: -1, to: sortedDays[i])
            if let prevDay, calendar.isDate(prevDay, inSameDayAs: sortedDays[i - 1]) {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 1
            }
        }

        return maxStreak
    }

    private var firstRecordDate: Date? {
        let dates = [appState.meals.map(\.createdAt).min(),
                     appState.workouts.map(\.createdAt).min(),
                     appState.sleepLogs.map(\.createdAt).min()].compactMap { $0 }
        return dates.min()
    }

    // 系统每日鼓励语
    private var dailyTitle: String {
        if !customization.summaryTitle.isEmpty { return customization.summaryTitle }
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let encouragements = isChinese ? [
            "坚持就是胜利", "每天进步一点点", "你比想象中更强大",
            "健康是一种习惯", "小小的改变，大大的不同", "你值得更好的自己",
            "记录让改变可见", "每一步都算数"
        ] : [
            "Consistency is key", "Small steps, big changes", "You are stronger than you think",
            "Health is a habit", "Small changes, big differences", "You deserve better",
            "Records make change visible", "Every step counts"
        ]
        return encouragements[dayOfYear % encouragements.count]
    }

    // 近期表现最佳方面的赞美语
    private var praiseText: String {
        let mealDays = Set(appState.meals.suffix(7).map { calendar.startOfDay(for: $0.createdAt) }).count
        let workoutDays = Set(appState.workouts.suffix(7).map { calendar.startOfDay(for: $0.createdAt) }).count

        if mealDays >= 5 {
            return isChinese ? "最近一周记录了\(mealDays)天餐食，你已经把记录变成了习惯。" : "You logged meals \(mealDays) days this week. Recording has become your habit."
        }
        if workoutDays >= 3 {
            return isChinese ? "最近一周运动了\(workoutDays)天，你的身体正在变得更强。" : "You exercised \(workoutDays) days this week. Your body is getting stronger."
        }
        if totalDays >= 30 {
            return isChinese ? "已经坚持\(totalDays)天了，这份持续本身就值得被看见。" : "You've persisted for \(totalDays) days. This consistency itself deserves to be seen."
        }
        return isChinese ? "你的每一步都在让未来的自己感谢现在的你。" : "Every step you take is building a future self that thanks you."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 封面区域
            GrowthAlbumCover(
                title: customization.albumName,
                coverIndex: customization.coverIndex,
                imageData: customization.coverImageData
            )
            .frame(maxWidth: .infinity)
            .frame(height: 340)
            .overlay(alignment: .topTrailing) {
                Button {
                    showsEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.24), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(14)
                .accessibilityLabel(isChinese ? "编辑专辑" : "Edit album")
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(dailyTitle)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(praiseText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MKTheme.secondaryText)
                    .lineLimit(3)

                GrowthAlbumMetricsRow(
                    days: "\(totalDays)",
                    records: "\(totalRecords)",
                    weight: weightChangeText,
                    streak: "\(longestStreak)",
                    isChinese: isChinese
                )
                .padding(.top, 2)

                HStack(spacing: 10) {
                    GrowthReviewBadge(text: isChinese ? "持续成长中" : "Growing", isChinese: isChinese)

                    Spacer(minLength: 8)

                    Button {
                        generateShareImage()
                    } label: {
                        Label(isChinese ? "分享" : "Share", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MKTheme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(MKTheme.fill.opacity(0.72), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .growthGlassCard(cornerRadius: 32, shadowOpacity: 0.14)
        .sheet(isPresented: $showsEditSheet) {
            GrowthMasterpieceEditSheet(
                customization: $customization,
                isChinese: isChinese
            )
        }
        .sheet(isPresented: $showsShareSheet) {
            if let shareImage {
                ShareSheet(items: [shareImage])
            }
        }
    }

    private func generateShareImage() {
        let renderer = ImageRenderer(content:
            GrowthSharePoster(
                customization: customization,
                dailyTitle: dailyTitle,
                praiseText: praiseText,
                totalDays: totalDays,
                totalRecords: totalRecords,
                weightChangeText: weightChangeText,
                longestStreak: longestStreak,
                isChinese: isChinese
            )
        )
        renderer.scale = 3.0
        if let image = renderer.uiImage {
            shareImage = image
            showsShareSheet = true
        }
    }
}

// MARK: - 分享海报

private struct GrowthSharePoster: View {
    let customization: GrowthAlbumCustomization
    let dailyTitle: String
    let praiseText: String
    let totalDays: Int
    let totalRecords: Int
    let weightChangeText: String
    let longestStreak: Int
    let isChinese: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GrowthAlbumCover(
                title: customization.albumName,
                coverIndex: customization.coverIndex,
                imageData: customization.coverImageData
            )
            .frame(height: 280)

            VStack(alignment: .leading, spacing: 12) {
                Text(dailyTitle)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(MKTheme.ink)

                Text(praiseText)
                    .font(.subheadline)
                    .foregroundStyle(MKTheme.secondaryText)

                GrowthAlbumMetricsRow(
                    days: "\(totalDays)",
                    records: "\(totalRecords)",
                    weight: weightChangeText,
                    streak: "\(longestStreak)",
                    isChinese: isChinese
                )
            }
            .padding(16)
        }
        .frame(width: 360)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

// MARK: - 编辑弹窗

private struct GrowthMasterpieceEditSheet: View {
    @Binding var customization: GrowthAlbumCustomization
    let isChinese: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var showsCamera = false
    @State private var showsLibrary = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var albumName: String = ""
    @State private var summaryTitle: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 封面选择
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isChinese ? "封面风格" : "Cover Style")
                            .font(.headline)

                        HStack(spacing: 12) {
                            ForEach(0..<3, id: \.self) { index in
                                GrowthCoverThumbnail(
                                    coverIndex: index,
                                    isSelected: customization.coverIndex == index
                                )
                                .onTapGesture {
                                    customization.coverIndex = index
                                    customization.coverImageData = nil
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            Button {
                                showsCamera = true
                            } label: {
                                Label(isChinese ? "拍照" : "Camera", systemImage: "camera.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                showsLibrary = true
                            } label: {
                                Label(isChinese ? "相册" : "Library", systemImage: "photo")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Divider()

                    // 专辑名称
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isChinese ? "专辑名称" : "Album Name")
                            .font(.headline)

                        TextField(isChinese ? "我的成长故事" : "My Growth Story", text: $albumName)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    // 摘要标题
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isChinese ? "摘要标题" : "Summary Title")
                            .font(.headline)

                        TextField(isChinese ? "输入标题" : "Enter title", text: $summaryTitle)
                            .textFieldStyle(.roundedBorder)

                        Text(isChinese ? "留空将使用系统每日鼓励语" : "Leave empty for daily encouragement")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .background(MKBackdrop())
            .navigationTitle(isChinese ? "编辑专辑" : "Edit Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "取消" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isChinese ? "保存" : "Save") {
                        customization.albumName = albumName.isEmpty ? (isChinese ? "我的成长故事" : "My Growth Story") : albumName
                        customization.summaryTitle = summaryTitle
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            albumName = customization.albumName
            summaryTitle = customization.summaryTitle
        }
        .sheet(isPresented: $showsCamera) {
            CameraPicker { data in
                customization.coverImageData = data
                showsCamera = false
            } onCancel: {
                showsCamera = false
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showsLibrary, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                customization.coverImageData = try? await newValue.loadTransferable(type: Data.self)
                selectedPhoto = nil
            }
        }
    }
}

// MARK: - 数据模型

private struct GrowthAlbumCustomization {
    var albumName: String
    var summaryTitle: String
    var coverIndex: Int
    var coverImageData: Data?

    static var `default`: GrowthAlbumCustomization {
        GrowthAlbumCustomization(
            albumName: "",
            summaryTitle: "",
            coverIndex: 0,
            coverImageData: nil
        )
    }
}

// MARK: - 封面组件

private struct GrowthAlbumCover: View {
    let title: String
    let coverIndex: Int
    var imageData: Data? = nil

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let cornerRadius = min(max(size.width * 0.08, 18), 28)
            ZStack {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                } else {
                    GrowthAlbumCoverArtwork(coverIndex: coverIndex)
                        .frame(width: size.width, height: size.height)
                }

                LinearGradient(
                    colors: [
                        .black.opacity(0.48),
                        .black.opacity(0.10),
                        .clear,
                        .black.opacity(0.34)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                GrowthAlbumBrandMark()
                    .padding(min(max(size.width * 0.055, 12), 20))
            }
            .overlay(alignment: .bottomLeading) {
                Text(title)
                    .font(.system(size: min(max(size.width * 0.075, 17), 24), weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .shadow(color: .black.opacity(0.36), radius: 10, x: 0, y: 4)
                    .padding(min(max(size.width * 0.07, 14), 24))
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.8)
        )
    }

    private var uiImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }
}

private struct GrowthAlbumBrandMark: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [MKColor.green.opacity(0.92), MKColor.mint.opacity(0.92)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            Text(isChinese ? "轻减AI" : "MealKind")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.black.opacity(0.20), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.20), lineWidth: 0.7)
        }
    }

    private var isChinese: Bool { true } // 默认中文，实际使用时从环境获取
}

private struct GrowthAlbumCoverArtwork: View {
    let coverIndex: Int

    private var palette: [Color] {
        let options: [[Color]] = [
            [Color(red: 0.08, green: 0.30, blue: 0.22), Color(red: 0.58, green: 0.82, blue: 0.56), Color(red: 0.05, green: 0.07, blue: 0.08)],
            [Color(red: 0.10, green: 0.18, blue: 0.33), Color(red: 0.20, green: 0.55, blue: 0.85), Color(red: 0.05, green: 0.06, blue: 0.09)],
            [Color(red: 0.23, green: 0.16, blue: 0.10), Color(red: 0.86, green: 0.57, blue: 0.28), Color(red: 0.06, green: 0.05, blue: 0.04)]
        ]
        return options[min(max(coverIndex, 0), options.count - 1)]
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let diameter = min(width, height) * 0.78

            ZStack {
                LinearGradient(
                    colors: palette,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: diameter * 0.86, height: diameter * 0.86)
                    .blur(radius: max(diameter * 0.06, 4))
                    .offset(x: width * 0.28, y: -height * 0.34)

                Circle()
                    .stroke(.white.opacity(0.18), lineWidth: max(diameter * 0.13, 8))
                    .frame(width: diameter, height: diameter)
                    .offset(x: -width * 0.25, y: -height * 0.22)
            }
        }
        .clipped()
    }
}

private struct GrowthCoverThumbnail: View {
    let coverIndex: Int
    let isSelected: Bool

    var body: some View {
        GrowthAlbumCoverArtwork(coverIndex: coverIndex)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? MKColor.green : MKTheme.divider.opacity(0.16), lineWidth: isSelected ? 2 : 0.7)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(height: 80)
    }
}

// MARK: - 指标行

private struct GrowthAlbumMetricsRow: View {
    let days: String
    let records: String
    let weight: String
    let streak: String
    let isChinese: Bool

    var body: some View {
        HStack(spacing: 0) {
            GrowthAlbumMetricItem(
                value: days,
                unit: days == "-" ? "" : (isChinese ? "天" : "d"),
                label: isChinese ? "坚持" : "Days"
            )
            GrowthAlbumMetricItem(
                value: records,
                unit: records == "-" ? "" : (isChinese ? "次" : "x"),
                label: isChinese ? "记录" : "Records"
            )
            GrowthAlbumMetricItem(
                value: numericPart(weight, unit: "kg"),
                unit: weight == "-" ? "" : "kg",
                label: isChinese ? "体重" : "Weight"
            )
            GrowthAlbumMetricItem(
                value: streak,
                unit: streak == "-" ? "" : (isChinese ? "天" : "d"),
                label: isChinese ? "连续" : "Streak"
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(MKTheme.fill.opacity(0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MKTheme.divider.opacity(0.9), lineWidth: 0.7)
        }
    }

    private func numericPart(_ value: String, unit: String) -> String {
        value.replacingOccurrences(of: unit, with: "")
            .replacingOccurrences(of: "+", with: "")
    }
}

private struct GrowthAlbumMetricItem: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(MKTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 24)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MKTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 评价徽章

private struct GrowthReviewBadge: View {
    let text: String
    let isChinese: Bool

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(MKColor.green)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(MKColor.green.opacity(0.12), in: Capsule())
    }
}

// MARK: - Glass Card 效果

private struct GrowthGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let shadowOpacity: Double

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(cardBase)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(materialOpacity))
                    )
                    .overlay(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(strokeColor, lineWidth: 0.8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? shadowOpacity * 1.45 : shadowOpacity), radius: 13, x: 0, y: 7)
    }

    private var cardBase: Color {
        colorScheme == .dark ? MKTheme.card.opacity(0.96) : .white.opacity(0.94)
    }

    private var materialOpacity: Double {
        colorScheme == .dark ? 0.08 : 0.22
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                .white.opacity(0.06),
                MKColor.green.opacity(0.07),
                .black.opacity(0.06)
            ]
        }
        return [
            .white.opacity(0.34),
            MKColor.green.opacity(0.035),
            .black.opacity(0.045)
        ]
    }

    private var strokeColor: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .white.opacity(0.78)
    }

    private var borderColor: Color {
        colorScheme == .dark ? .black.opacity(0.32) : .black.opacity(0.105)
    }
}

private extension View {
    func growthGlassCard(cornerRadius: CGFloat, shadowOpacity: Double = 0.20) -> some View {
        modifier(GrowthGlassCardModifier(cornerRadius: cornerRadius, shadowOpacity: shadowOpacity))
    }
}

// MARK: - ShareSheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
