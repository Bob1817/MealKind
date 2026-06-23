import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredDailyTask.createdAt) private var storedTasks: [StoredDailyTask]
    @Environment(AppState.self) private var appState
    @State private var celebration: String?
    @State private var sleepSheetPresented = false
    @State private var activitySheetPresented = false
    // 饮食拍照流程：菜单 → 相机 / 相册 → AI 分析弹层。
    @State private var mealMenuPresented = false
    @State private var showsCamera = false
    @State private var showsLibrary = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var mealImageData: Data?
    @State private var mealSource: MealSource = .photoLibrary
    @State private var mealReviewPresented = false
    @State private var cycleCreationPresented = false
    @State private var showDetailLog = false

    private var hasCamera: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    private var isChinese: Bool { appState.language == .simplifiedChinese }

    private var isProfessional: Bool { appState.bodyOSProfile.mode == .advanced }

    var body: some View {
        ScrollView {
            if isProfessional {
                professionalHomeClean
            } else {
                lifestyleHomeClean
            }
        }
        .mkGlassNavigation(title: isChinese ? "今日" : "Today", subtitle: todayDateText) {
            todayToolbarActions
        }
        .onChange(of: appState.latestCelebration) { _, newValue in
            celebration = newValue
        }
        .sheet(isPresented: $sleepSheetPresented) {
            TodaySleepSheet(isChinese: isChinese) { log in
                appState.saveSleep(log, modelContext: modelContext)
            }
        }
        .sheet(isPresented: $activitySheetPresented) {
            TodayActivitySheet(
                isChinese: isChinese,
                currentGoal: appState.activityBurnGoal,
                weightKilograms: appState.weightKilograms,
                age: appState.profile.age,
                onSetGoal: { goal in
                    appState.setActivityBurnGoal(goal, modelContext: modelContext)
                },
                onLog: { workout in
                    appState.saveWorkout(workout, modelContext: modelContext)
                }
            )
        }
        .confirmationDialog(
            isChinese ? "记录这顿" : "Log this meal",
            isPresented: $mealMenuPresented,
            titleVisibility: .visible
        ) {
            if hasCamera {
                Button(isChinese ? "拍照" : "Take photo") {
                    showsCamera = true
                }
            }
            Button(isChinese ? "从相册选择" : "Choose from library") {
                showsLibrary = true
            }
            Button(isChinese ? "取消" : "Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showsCamera) {
            CameraPicker { data in
                mealImageData = data
                mealSource = .camera
                showsCamera = false
                mealReviewPresented = true
            } onCancel: {
                showsCamera = false
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showsLibrary, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                mealImageData = try? await newValue.loadTransferable(type: Data.self)
                mealSource = .photoLibrary
                selectedPhoto = nil
                if mealImageData != nil { mealReviewPresented = true }
            }
        }
        .sheet(isPresented: $mealReviewPresented) {
            SmartScanReviewSheet(
                imageData: mealImageData,
                plan: appState.selectedPlan,
                remainingBeforeSave: appState.budget.remaining,
                weightKilograms: appState.weightKilograms,
                profile: appState.profile,
                language: appState.language,
                source: mealSource,
                bodyOSContext: appState.foodAnalysisContext()
            ) { result, source in
                appState.saveScannedMeal(
                    result: result,
                    source: source,
                    imageData: mealImageData,
                    modelContext: modelContext
                )
                mealReviewPresented = false
            } onSaveWorkout: { workout in
                appState.saveWorkout(workout, modelContext: modelContext)
                mealReviewPresented = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $cycleCreationPresented) {
            TrainingCycleCreationSheet(
                language: appState.language,
                weightKilograms: appState.weightKilograms
            ) { cycle in
                appState.saveTrainingCycle(cycle, modelContext: modelContext)
                cycleCreationPresented = false
            } onArchive: { newCycle in
                appState.archiveOverlappingCycles(for: newCycle, modelContext: modelContext)
            } onCheckOverlap: { cycle in
                appState.hasOverlappingCycle(for: cycle)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDetailLog) {
            TodayDetailLogSheet(
                appState: appState,
                isChinese: isChinese
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var todayToolbarActions: some View {
        HStack(spacing: 8) {
            Button { cycleCreationPresented = true } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MKColor.green)
                    .frame(width: 38, height: 38)
            }
            .accessibilityLabel(isProfessional ? (isChinese ? "创建周期" : "Create cycle") : (isChinese ? "新建" : "New"))
        }
    }

    private var topNavigationSubtitle: String {
        if appState.bodyOSProfile.mode == .advanced {
            return isChinese ? "训练、营养和恢复，今天看清楚。" : "Training, nutrition, and recovery for today."
        }
        return isChinese ? "先做一件很小的事。" : "Start with one tiny thing."
    }

    // 专业版首页：信息密度高，强调恢复分数、周期、训练状态与精确营养（含 TDEE/缺口、宏量明细）。
    private var professionalHomeClean: some View {
        VStack(alignment: .leading, spacing: MKTheme.cardSpacing) {
            primaryRecommendationCard
            todayStatusOverviewCard
            nutritionTargetOverviewCard
            professionalCompletionOverviewCard
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 28)
    }

    // 生活版首页：福格模型极简结构——头部 + 今天只做一件事 + 小步骤 + 今日建议 + AI 鼓励。
    // 首屏不出现大量热量数字、图表或多任务清单，只回答「今天该做什么」。
    private var lifestyleHomeClean: some View {
        let focus = todayFocusDecision

        return VStack(alignment: .leading, spacing: MKTheme.cardSpacing) {
            todayFocusHeroCard(focus)
            lifestyleEncouragementCard(focus)
            todaySuggestionCard(focus)
            recentGrowthCard
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 28)
    }

    // 今日重点：普通版首页只给一个明确 Prompt，让用户无需选择先做什么。
    private func todayFocusHeroCard(_ focus: TodayFocusDecision) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: focus.symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(focus.tint, in: Circle())

                VStack(alignment: .leading, spacing: 7) {
                    Text(focus.contextLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(focus.tint)
                    Text(focus.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(TodayStyle.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Text(focus.reason)
                .font(.subheadline)
                .foregroundStyle(TodayStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            focusActionButton(focus)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(focus.tint)
                Text(focus.timeHint)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(TodayStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .todayCard()
    }

    @ViewBuilder
    private func focusActionButton(_ focus: TodayFocusDecision) -> some View {
        switch focus.kind {
        case .meal:
            Button {
                mealMenuPresented = true
            } label: {
                TodayPrimaryButtonLabel(symbol: focus.actionSymbol, title: focus.actionTitle)
            }
            .buttonStyle(.plain)
        case .water:
            Button {
                appState.saveWaterChange(1, modelContext: modelContext)
            } label: {
                TodayPrimaryButtonLabel(symbol: focus.actionSymbol, title: focus.actionTitle)
            }
            .buttonStyle(.plain)
        case .activity:
            Button {
                activitySheetPresented = true
            } label: {
                TodayPrimaryButtonLabel(symbol: focus.actionSymbol, title: focus.actionTitle)
            }
            .buttonStyle(.plain)
        case .sleep:
            Button {
                sleepSheetPresented = true
            } label: {
                TodayPrimaryButtonLabel(symbol: focus.actionSymbol, title: focus.actionTitle)
            }
            .buttonStyle(.plain)
        case .review, .done:
            Button {
                showDetailLog = true
            } label: {
                TodaySecondaryButtonLabel(symbol: focus.actionSymbol, title: focus.actionTitle)
            }
            .buttonStyle(.plain)
        }
    }

    private var rowDivider: some View {
        Divider().overlay(TodayStyle.divider).padding(.leading, 46)
    }

    // —— 四元素步骤行 ——

    private var mealRow: some View {
        Button {
            mealMenuPresented = true
        } label: {
            elementRowLabel(
                symbol: "fork.knife",
                tint: mealStatus == .over ? MKColor.coral : TodayStyle.primary,
                title: isChinese ? "饮食" : "Meals",
                statusText: mealStatusText,
                status: mealStatus
            ) {
                Image(systemName: "camera.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(mealStatus == .over ? MKColor.coral : TodayStyle.primary)
            }
        }
        .buttonStyle(.plain)
    }

    private var waterRow: some View {
        elementRowLabel(
            symbol: "drop.fill",
            tint: MKColor.sky,
            title: isChinese ? "饮水" : "Water",
            statusText: waterStatusText,
            status: waterStatus
        ) {
            Button {
                appState.saveWaterChange(1, modelContext: modelContext)
            } label: {
                Label(isChinese ? "加一杯" : "+1", systemImage: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKColor.sky)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(MKColor.sky.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var sleepRow: some View {
        Button {
            sleepSheetPresented = true
        } label: {
            elementRowLabel(
                symbol: "moon.stars.fill",
                tint: sleepTint,
                title: isChinese ? "睡眠" : "Sleep",
                statusText: sleepStatusText,
                status: sleepStatus
            ) {
                Image(systemName: "square.and.pencil")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(sleepTint)
            }
        }
        .buttonStyle(.plain)
    }

    private var activityRow: some View {
        Button {
            activitySheetPresented = true
        } label: {
            elementRowLabel(
                symbol: "figure.walk",
                tint: MKColor.citrus,
                title: isChinese ? "活动" : "Move",
                statusText: activityStatusText,
                status: activityStatus
            ) {
                ActivityProgressRing(progress: activityProgress, tint: MKColor.citrus)
                    .frame(width: 30, height: 30)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func elementRowLabel<Trailing: View>(
        symbol: String,
        tint: Color,
        title: String,
        statusText: String,
        status: HomeElementStatus,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: status == .done ? "checkmark" : symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(status == .done ? .white : tint)
                .frame(width: 34, height: 34)
                .background(status == .done ? tint : tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TodayStyle.ink)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusTint(status))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    // MARK: - 四元素判定（内置引擎 / AI 引擎结果，普通版只输出状态提示）

    private enum HomeElementStatus { case pending, done, over }
    private enum TodayFocusKind { case meal(MealSlot), water, activity, sleep, review, done }
    private enum MealSlot { case breakfast, lunch, dinner }
    private struct TodayFocusDecision {
        let kind: TodayFocusKind
        let contextLabel: String
        let title: String
        let reason: String
        let actionTitle: String
        let actionSymbol: String
        let symbol: String
        let tint: Color
        let timeHint: String
        let encouragement: String
        let suggestions: [String]
    }

    private let waterGoalCups = 8
    private let sleepGoalHours = 7.0
    private var sleepTint: Color { Color(red: 0.47, green: 0.43, blue: 0.66) }

    private var todaySleepHours: Double { appState.latestSleepLog?.hoursSlept ?? 0 }

    // 饮食：摄入 ≤ 目标 = 完成；> 目标 = 超标（失败）；未记录 = 待完成。
    private var mealStatus: HomeElementStatus {
        let intake = appState.eatenCalories
        guard intake > 0 else { return .pending }
        let target = appState.bodyOSNutritionTarget.calories
        return (target > 0 && intake > target) ? .over : .done
    }
    // 饮水 / 睡眠：达标 = 完成；未达标 = 待完成（超过不算失败）。
    private var waterStatus: HomeElementStatus { appState.waterCups >= waterGoalCups ? .done : .pending }
    private var sleepStatus: HomeElementStatus { todaySleepHours >= sleepGoalHours ? .done : .pending }
    // 活动：达到自设消耗目标 = 完成。
    private var activityStatus: HomeElementStatus { appState.loggedExerciseCalories >= appState.activityBurnGoal ? .done : .pending }
    private var activityProgress: Double {
        guard appState.activityBurnGoal > 0 else { return 0 }
        return min(max(Double(appState.loggedExerciseCalories) / Double(appState.activityBurnGoal), 0), 1)
    }

    private var mealStatusText: String {
        switch mealStatus {
        case .done: return isChinese ? "已记录，今天吃得刚好" : "Logged, right on track"
        case .over: return isChinese ? "今天多了点，下一餐清淡些" : "A bit much — keep the next meal light"
        case .pending: return isChinese ? "拍一下这顿就好" : "Just snap this meal"
        }
    }
    private var waterStatusText: String {
        if waterStatus == .done { return isChinese ? "今天喝够了" : "Hydrated for today" }
        let left = max(waterGoalCups - appState.waterCups, 0)
        return isChinese ? "还差 \(left) 杯" : "\(left) cups to go"
    }
    private var sleepStatusText: String {
        if sleepStatus == .done { return isChinese ? "睡得不错" : "Well rested" }
        if todaySleepHours > 0 { return isChinese ? "再多睡一点会更好" : "A little more would help" }
        return isChinese ? "记一下昨晚睡了多久" : "Log last night's sleep"
    }
    private var activityStatusText: String {
        if activityStatus == .done { return isChinese ? "今天动够了" : "Move goal reached" }
        if appState.loggedExerciseCalories > 0 { return isChinese ? "已经动起来了，继续" : "Off to a good start" }
        return isChinese ? "记一次活动就好" : "Log one activity"
    }

    private func statusTint(_ status: HomeElementStatus) -> Color {
        switch status {
        case .done: return TodayStyle.primary
        case .over: return MKColor.coral
        case .pending: return TodayStyle.secondaryText
        }
    }

    private var doneCount: Int {
        [mealStatus, waterStatus, sleepStatus, activityStatus].filter { $0 == .done }.count
    }
    private var allDone: Bool { doneCount == 4 }

    // MARK: - 个性化提示语（阶段 × 时段 × 温和口吻）

    private enum HomeHeroState { case notStarted, inProgress, done }
    private struct HomeHeroPrompt { let eyebrow: String; let headline: String; let sub: String }

    private var heroState: HomeHeroState {
        if allDone { return .done }
        return doneCount >= 1 ? .inProgress : .notStarted
    }

    private enum DayPeriod { case morning, noon, afternoon, evening, night }
    private var dayPeriod: DayPeriod {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11: return .morning
        case 11..<14: return .noon
        case 14..<18: return .afternoon
        case 18..<22: return .evening
        default: return .night
        }
    }

    private var heroPrompt: HomeHeroPrompt {
        switch heroState {
        case .notStarted:
            return HomeHeroPrompt(
                eyebrow: isChinese ? "今天的记录" : "Today",
                headline: notStartedHeadline,
                sub: isChinese ? "不用完美，完成一点就算前进。" : "No need to be perfect — one small step counts."
            )
        case .inProgress:
            return HomeHeroPrompt(
                eyebrow: isChinese ? "继续加油" : "Keep going",
                headline: inProgressHeadline,
                sub: isChinese ? "已经做到 \(doneCount) / 4 件，剩下的很轻松。" : "\(doneCount) of 4 done — the rest is easy."
            )
        case .done:
            return HomeHeroPrompt(
                eyebrow: isChinese ? "今日已完成" : "All done",
                headline: doneHeadline,
                sub: isChinese ? "你值得为自己骄傲。" : "You should be proud of yourself."
            )
        }
    }

    private var notStartedHeadline: String {
        switch dayPeriod {
        case .morning: return isChinese ? "早安，先从一张早餐开始。" : "Good morning — start with breakfast."
        case .noon: return isChinese ? "中午好，拍一下这顿就行。" : "Hi — just snap this meal."
        case .afternoon: return isChinese ? "下午好，记一件小事就好。" : "Afternoon — log one small thing."
        case .evening: return isChinese ? "傍晚了，留一条今天的记录吧。" : "Evening — leave one record for today."
        case .night: return isChinese ? "睡前 30 秒，记一笔今天。" : "30 seconds before bed — log today."
        }
    }
    private var inProgressHeadline: String {
        switch dayPeriod {
        case .morning, .noon: return isChinese ? "开了个好头，继续保持。" : "Great start — keep it up."
        case .afternoon: return isChinese ? "做得不错，再完成一件。" : "Nicely done — one more to go."
        case .evening: return isChinese ? "今天已经有进展了，收个尾。" : "Good progress — let's finish up."
        case .night: return isChinese ? "睡前把剩下的轻轻补上。" : "Wrap up the rest before bed."
        }
    }
    private var doneHeadline: String {
        switch dayPeriod {
        case .morning, .noon, .afternoon: return isChinese ? "四件小事都做到了，太棒了。" : "All four done — amazing."
        case .evening: return isChinese ? "今天稳稳地完成了。" : "A solid day, fully done."
        case .night: return isChinese ? "今天画上了温柔的句号。" : "A gentle close to your day."
        }
    }

    // MARK: - 录入后超标/改进汇总（需求 5）

    private var todaySummaryLine: String {
        if allDone {
            return isChinese ? "今天四件小事都完成了，保持节奏就好。" : "All four done today — keep the rhythm."
        }
        if mealStatus == .over {
            return isChinese ? "今天热量多了一点，下一餐清淡些就好，不用补偿。" : "Calories ran a little high — keep the next meal light, no need to compensate."
        }
        let pendingNames = [
            waterStatus != .done ? (isChinese ? "饮水" : "water") : nil,
            sleepStatus != .done ? (isChinese ? "睡眠" : "sleep") : nil,
            activityStatus != .done ? (isChinese ? "活动" : "move") : nil,
            mealStatus == .pending ? (isChinese ? "饮食" : "meals") : nil
        ].compactMap { $0 }
        guard !pendingNames.isEmpty else {
            return isChinese ? "保持下去，今天很稳。" : "Steady day — keep going."
        }
        let joined = pendingNames.joined(separator: isChinese ? "、" : ", ")
        return isChinese ? "还差：\(joined)，完成一件就更近一步。" : "Still open: \(joined). One more gets you closer."
    }

    // 今日建议：最多两条，跟随当前时段和下一步行动变化。
    private func todaySuggestionCard(_ focus: TodayFocusDecision) -> some View {
        let tips = Array(focus.suggestions.prefix(2))

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: isChinese ? "今日建议" : "Today's suggestion")

            VStack(spacing: 0) {
                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(TodayStyle.primary)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(TodayStyle.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 11)

                    if index < tips.count - 1 {
                        Divider()
                            .overlay(TodayStyle.divider)
                            .padding(.leading, 28)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .todayCard()
    }

    // AI 鼓励：一句正向、无焦虑的反馈。
    private func lifestyleEncouragementCard(_ focus: TodayFocusDecision) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(TodayStyle.primary)
                .frame(width: 38, height: 38)
                .background(TodayStyle.primary.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(isChinese ? "AI 鼓励" : "AI encouragement")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TodayStyle.primary)
                Text(celebration ?? focus.encouragement)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TodayStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .todayCard()
        .accessibilityElement(children: .combine)
    }

    private var recentGrowthCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(TodayStyle.primary)
                .frame(width: 32, height: 32)
                .background(TodayStyle.primary.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(isChinese ? "最近变化" : "Recent growth")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TodayStyle.primary)
                Text(recentGrowthText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(TodayStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .todayCard()
        .accessibilityElement(children: .combine)
    }

    private var primaryRecommendationCard: some View {
        let task = nextActionTask

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: primaryRecommendationSymbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(TodayStyle.primary, in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(isChinese ? "今天该怎么做" : "What to do today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TodayStyle.primary)
                    Text(primaryRecommendationText)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(TodayStyle.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Text(celebration ?? appState.bodyOSStrategyExplanation.primaryAction)
                .font(.subheadline)
                .foregroundStyle(TodayStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    mealMenuPresented = true
                } label: {
                    TodayPrimaryButtonLabel(
                        symbol: "camera.fill",
                        title: isChinese ? "拍照记录" : "Photo log"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    BodyLogView()
                } label: {
                    TodaySecondaryButtonLabel(
                        symbol: "square.and.pencil",
                        title: isChinese ? "快速记录" : "Quick log"
                    )
                }
                .buttonStyle(.plain)
            }

            if let task {
                Button {
                    complete(task)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(task.status == .completed ? TodayStyle.primary : TodayStyle.secondaryText)
                        Text(task.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(TodayStyle.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Spacer(minLength: 8)
                        Text(taskIntentLabel(for: task))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TodayStyle.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(TodayStyle.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(task.status == .completed)
                .opacity(task.status == .completed ? 0.72 : 1)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .todayCard()
    }

    private var todayStatusOverviewCard: some View {
        let state = appState.bodyOSBodyState
        let cycle = appState.bodyOSCycle
        let recovery = appState.bodyOSRecoveryScore

        return VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: isChinese ? "今日状态" : "Today's status")

            HStack(spacing: 10) {
                StatusMetricBlock(
                    title: isChinese ? "恢复" : "Recovery",
                    value: "\(recovery.value)",
                    subtitle: recoveryShortLabel(state.recoveryState),
                    symbol: "heart.fill",
                    tint: recoveryTint(state.recoveryState),
                    ringProgress: Double(recovery.value) / 100
                )
                StatusMetricBlock(
                    title: isChinese ? "训练" : "Training",
                    value: trainingStateLabel(state.trainingState, cycle: cycle),
                    subtitle: cycle.isPlannedTrainingDay ? (isChinese ? "计划日" : "Planned") : (isChinese ? "休息" : "Rest"),
                    symbol: trainingSymbol(state.trainingState),
                    tint: state.shouldOverridePlannedTraining ? MKColor.coral : TodayStyle.primary,
                    ringProgress: cycle.isPlannedTrainingDay ? 0.72 : 0.38
                )
                StatusMetricBlock(
                    title: isChinese ? "周期" : "Cycle",
                    value: cycleTypeLabel(cycle.type),
                    subtitle: isChinese ? "第 \(cycle.dayIndex) 天" : "Day \(cycle.dayIndex)",
                    symbol: "calendar",
                    tint: TodayStyle.primary,
                    ringProgress: min(Double(cycle.dayIndex % 30) / 30, 1)
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .todayCard()
    }

    private var nutritionTargetOverviewCard: some View {
        let target = appState.bodyOSNutritionTarget
        let eaten = appState.eatenCalories
        let progress = target.calories > 0 ? Double(eaten) / Double(target.calories) : 0

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                SectionTitle(title: isChinese ? "营养目标" : "Nutrition target")
                Text(isChinese
                     ? "TDEE \(target.tdee) · 缺口 \(target.deficit) kcal"
                     : "TDEE \(target.tdee) · Deficit \(target.deficit) kcal")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(TodayStyle.secondaryText)
            }

            HStack(alignment: .center, spacing: 16) {
                CalorieRing(
                    current: eaten,
                    target: target.calories,
                    progress: progress,
                    isChinese: isChinese
                )
                .frame(width: 126)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(eaten) / \(target.calories)")
                        .font(.system(size: 25, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(TodayStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("kcal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TodayStyle.secondaryText)
                    Text(calorieRemainingText(current: eaten, target: target.calories))
                        .font(.subheadline)
                        .foregroundStyle(TodayStyle.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !target.shouldHideMacroDetails {
                HStack(spacing: 10) {
                    MacroSummaryBlock(
                        title: MacroKind.protein.title(language: appState.language),
                        current: appState.eatenMacros.protein,
                        target: target.protein,
                        tint: TodayStyle.primary,
                        isChinese: isChinese
                    )
                    MacroSummaryBlock(
                        title: MacroKind.carbs.title(language: appState.language),
                        current: appState.eatenMacros.carbs,
                        target: target.carbs,
                        tint: MKColor.sky,
                        isChinese: isChinese
                    )
                    MacroSummaryBlock(
                        title: MacroKind.fat.title(language: appState.language),
                        current: appState.eatenMacros.fat,
                        target: target.fat,
                        tint: MKColor.citrus,
                        isChinese: isChinese
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .todayCard()
    }

    // 专业版完成情况：覆盖饮食 / 训练 / 睡眠 / 饮水 / 补剂的清单样式。
    private var professionalCompletionOverviewCard: some View {
        let items = professionalCompletionItems
        let completed = items.filter(\.isCompleted).count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle(title: isChinese ? "今日完成情况" : "Today's completion")
                Spacer()
                Text("\(completed)/\(items.count)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(TodayStyle.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(TodayStyle.primary.opacity(0.10), in: Capsule())
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    CleanChecklistRow(item: item)
                    if index < items.count - 1 {
                        Divider()
                            .overlay(TodayStyle.divider)
                            .padding(.leading, 50)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .todayCard()
    }

    private var lifestyleHome: some View {
        VStack(alignment: .leading, spacing: 12) {
            microActionCard
            recordHubCard
            dailyCompassCard
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 28)
    }

    private var professionalDashboard: some View {
        VStack(alignment: .leading, spacing: 10) {
            professionalStatusCard
            professionalNutritionCard
            professionalCompletionCard
            professionalAdviceCard
            professionalRecordActions
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 28)
    }

    private var professionalStatusCard: some View {
        let state = appState.bodyOSBodyState
        let cycle = appState.bodyOSCycle
        let recovery = appState.bodyOSRecoveryScore

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: cycle.isPlannedTrainingDay ? trainingSymbol(state.trainingState) : "moon.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(state.shouldOverridePlannedTraining ? MKColor.coral : MKColor.green)
                    .frame(width: 34, height: 34)
                    .background((state.shouldOverridePlannedTraining ? MKColor.coral : MKColor.green).opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(professionalDayTitle(state: state, cycle: cycle))
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(professionalDaySubtitle(state: state, cycle: cycle))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Divider().overlay(Color.white.opacity(0.08))

            HStack(alignment: .center, spacing: 14) {
                RecoveryGauge(
                    score: recovery.value,
                    title: isChinese ? "恢复" : "Recovery",
                    subtitle: recoveryStateLabel(state.recoveryState, score: recovery),
                    tint: recoveryTint(state.recoveryState)
                )
                .frame(width: 112)

                VStack(spacing: 10) {
                    ProfessionalMetricTile(
                        title: isChinese ? "周期" : "Cycle",
                        value: cycleTypeLabel(cycle.type),
                        subtitle: isChinese ? "第 \(cycle.dayIndex) 天" : "Day \(cycle.dayIndex)",
                        tint: MKColor.green
                    )
                    ProfessionalMetricTile(
                        title: isChinese ? "训练" : "Training",
                        value: trainingStateLabel(state.trainingState, cycle: cycle),
                        subtitle: appState.todayWorkouts.isEmpty
                            ? (isChinese ? "未记录" : "not logged")
                            : (isChinese ? "\(appState.todayWorkouts.count) 条记录" : "\(appState.todayWorkouts.count) logs"),
                        tint: state.shouldOverridePlannedTraining ? MKColor.coral : MKColor.deepGreen
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkProfessionalPanel()
    }

    private var professionalNutritionCard: some View {
        let target = appState.bodyOSNutritionTarget
        let eaten = appState.eatenCalories
        let remaining = target.calories - eaten
        let calorieProgress = target.calories > 0 ? Double(eaten) / Double(target.calories) : 0

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isChinese ? "今日营养目标" : "Today's nutrition targets")
                        .font(.headline)
                    Text(isChinese
                         ? "根据状态、周期和恢复动态调整"
                         : "Adjusted by state, cycle, and recovery")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(remaining >= 0
                     ? (isChinese ? "剩 \(remaining)" : "\(remaining) left")
                     : (isChinese ? "多 \(abs(remaining))" : "\(abs(remaining)) over"))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(remaining < 0 ? MKColor.coral : MKColor.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((remaining < 0 ? MKColor.coral : MKColor.green).opacity(0.14), in: Capsule())
            }

            ProfessionalProgressRow(
                title: isChinese ? "热量" : "Calories",
                current: eaten,
                target: target.calories,
                unit: isChinese ? "千卡" : "kcal",
                progress: calorieProgress,
                tint: remaining < 0 ? MKColor.coral : MKColor.green
            )

            if !target.shouldHideMacroDetails {
                MacroBalanceRibbon(
                    proteinProgress: macroProgress(appState.eatenMacros.protein, target.protein),
                    carbsProgress: macroProgress(appState.eatenMacros.carbs, target.carbs),
                    fatProgress: macroProgress(appState.eatenMacros.fat, target.fat),
                    isChinese: isChinese
                )

                VStack(spacing: 12) {
                    ForEach(MacroKind.allCases) { macro in
                        let current = macro.value(in: appState.eatenMacros)
                        let goal = macro.value(in: appState.macroTarget)
                        ProfessionalProgressRow(
                            title: macro.title(language: appState.language),
                            current: current,
                            target: goal,
                            unit: "g",
                            progress: goal > 0 ? Double(current) / Double(goal) : 0,
                            tint: macroProgressTint(current: current, target: goal, base: macro.color)
                        )
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkProfessionalPanel()
    }

    private var professionalCompletionCard: some View {
        let items = professionalCompletionItems
        let completed = items.filter(\.isCompleted).count
        let progress = items.isEmpty ? 0 : Double(completed) / Double(items.count)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isChinese ? "今日记录完成情况" : "Today's log completion")
                        .font(.headline)
                    Text(isChinese
                         ? "专业版靠记录驱动动态调整"
                         : "Professional mode adjusts from logged data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(completed) / \(items.count)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(MKColor.green)
            }

            CalorieProgressBar(progress: progress, isOver: false)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ProfessionalChecklistRow(item: item)
                    if index < items.count - 1 {
                        Divider()
                            .overlay(Color.white.opacity(0.07))
                            .padding(.leading, 34)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkProfessionalPanel()
    }

    private var professionalAdviceCard: some View {
        let target = appState.bodyOSNutritionTarget
        let eaten = appState.eatenCalories
        let remaining = target.calories - eaten

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: professionalAdviceSymbol(remaining: remaining))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(professionalAdviceTint(remaining: remaining))
                    .frame(width: 30, height: 30)
                    .background(professionalAdviceTint(remaining: remaining).opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(appState.bodyOSStrategyExplanation.headline)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(professionalAdjustmentText(remaining: remaining))
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(appState.bodyOSStrategyExplanation.primaryAction)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkProfessionalPanel(cornerRadius: 22)
    }

    private var professionalRecordActions: some View {
        HStack(spacing: 10) {
            NavigationLink {
                ScanView()
            } label: {
                ProfessionalActionButton(
                    symbol: "camera.fill",
                    title: isChinese ? "记饮食 / 训练" : "Food / training",
                    tint: MKColor.green
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                BodyLogView()
            } label: {
                ProfessionalActionButton(
                    symbol: "list.bullet.rectangle.portrait.fill",
                    title: isChinese ? "身体记录" : "Body log",
                    tint: MKColor.sky
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }

    private var professionalCompletionItems: [ProfessionalChecklistItem] {
        let state = appState.bodyOSBodyState
        let hasWorkout = !appState.todayWorkouts.isEmpty
        let workoutCompleted = state.trainingState == .restDay || state.shouldOverridePlannedTraining || hasWorkout
        return [
            ProfessionalChecklistItem(
                title: isChinese ? "饮食记录" : "Meal log",
                detail: appState.todayMeals.isEmpty
                    ? (isChinese ? "还没有记录餐食" : "No meals logged")
                    : (isChinese ? "\(appState.todayMeals.count) 餐 · \(appState.eatenCalories) 千卡" : "\(appState.todayMeals.count) meals · \(appState.eatenCalories) kcal"),
                symbol: "fork.knife",
                tint: MKColor.green,
                isCompleted: !appState.todayMeals.isEmpty
            ),
            ProfessionalChecklistItem(
                title: isChinese ? "训练记录" : "Training log",
                detail: professionalWorkoutDetail(state: state),
                symbol: "figure.strengthtraining.traditional",
                tint: state.shouldOverridePlannedTraining ? MKColor.coral : MKColor.deepGreen,
                isCompleted: workoutCompleted
            ),
            ProfessionalChecklistItem(
                title: isChinese ? "睡眠记录" : "Sleep log",
                detail: appState.latestSleepLog.map {
                    isChinese ? String(format: "%.1f 小时", $0.hoursSlept) : String(format: "%.1f hr", $0.hoursSlept)
                } ?? (isChinese ? "还没有记录睡眠" : "No sleep logged"),
                symbol: "moon.stars.fill",
                tint: MKColor.sky,
                isCompleted: appState.latestSleepLog != nil
            ),
            ProfessionalChecklistItem(
                title: isChinese ? "饮水" : "Water",
                detail: isChinese ? "\(appState.waterCups) / 8 杯" : "\(appState.waterCups) / 8 cups",
                symbol: "drop.fill",
                tint: MKColor.sky,
                isCompleted: appState.waterCups >= 6
            ),
            ProfessionalChecklistItem(
                title: isChinese ? "补剂" : "Supplements",
                detail: appState.todaySupplementLogs.isEmpty
                    ? (isChinese ? "还没有补剂记录" : "No supplement logs")
                    : (isChinese ? "\(appState.todaySupplementLogs.count) 条记录" : "\(appState.todaySupplementLogs.count) logs"),
                symbol: "pills.fill",
                tint: MKColor.citrus,
                isCompleted: !appState.todaySupplementLogs.isEmpty
            )
        ]
    }

    private func professionalWorkoutDetail(state: BodyState) -> String {
        if state.shouldOverridePlannedTraining {
            return isChinese ? "今天由身体状态接管" : "Adjusted by body state"
        }
        if state.trainingState == .restDay {
            return isChinese ? "休息日，无需训练记录" : "Rest day, no workout needed"
        }
        if appState.todayWorkouts.isEmpty {
            return isChinese ? "计划训练日，未记录" : "Training day, not logged"
        }
        let calories = appState.loggedExerciseCalories
        return isChinese ? "\(appState.todayWorkouts.count) 次 · \(calories) 千卡" : "\(appState.todayWorkouts.count) sessions · \(calories) kcal"
    }

    private var microActionCard: some View {
        let task = nextActionTask
        let isComplete = appState.todayCompletionRate >= 1

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                MKIconBadge(
                    symbol: isComplete ? "checkmark.circle.fill" : taskSymbol(for: task),
                    tint: isComplete ? MKColor.green : MKColor.deepGreen,
                    fill: MKColor.subtleGreen.opacity(0.50),
                    size: 44
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(greeting)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(celebration ?? microActionPrompt(for: task, isComplete: isComplete))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Text(appState.todayCompletionText)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(MKColor.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(MKColor.green.opacity(0.14), in: Capsule())
            }

            if let task {
                Button {
                    complete(task)
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(task.status == .completed ? MKColor.green : MKColor.sky)
                            .frame(width: 30, height: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(taskIntentLabel(for: task))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MKColor.green)
                            Text(task.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(task.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)

                        if task.status != .completed {
                            Image(systemName: "arrow.right")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(task.status == .completed)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 28, tint: MKColor.subtleGreen.opacity(0.24), isInteractive: true)
    }

    private var dailyCompassCard: some View {
        let state = appState.bodyOSBodyState
        let target = appState.bodyOSNutritionTarget
        let cycle = appState.bodyOSCycle
        let eaten = appState.eatenCalories
        let remaining = target.calories - eaten
        let progress = target.calories > 0
            ? min(max(Double(eaten) / Double(target.calories), 0), 1.2)
            : 0
        let isAdvanced = appState.bodyOSProfile.mode == .advanced

        return VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isChinese ? "今天怎么吃" : "How to eat today")
                        .font(.headline)
                    Text(stateFocusText(state: state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text(modeBadgeText(isAdvanced: isAdvanced))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MKColor.green.opacity(0.15), in: Capsule())
                    .foregroundStyle(MKColor.green)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(remainingValueText(remaining))
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(remaining < 0 ? MKColor.coral : MKColor.green)
                    Text(remainingUnitText(remaining))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(eaten) / \(target.calories)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                CalorieProgressBar(progress: progress, isOver: remaining < 0)

                Text(energyBoundaryHint(remaining: remaining))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            FlowingChipRow(chips: currentStateChips(state: state, cycle: cycle, isAdvanced: isAdvanced))

            Divider()
                .overlay(Color.white.opacity(0.10))

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKColor.green)
                    .frame(width: 28, height: 28)
                    .background(MKColor.green.opacity(0.13), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryStrategyTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(primaryStrategyAction)
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(appState.bodyOSStrategyExplanation.supportingText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 28, tint: MKColor.subtleSky.opacity(0.24))
    }

    private var advancedDetailsCard: some View {
        let target = appState.bodyOSNutritionTarget
        let macros = appState.eatenMacros
        let remainingTasks = appState.todayTasks.filter { $0.status != .completed && $0.id != nextActionTask?.id }

        return VStack(alignment: .leading, spacing: 14) {
            Text(isChinese ? "想多看一点" : "A little more detail")
                .font(.headline)

            if !target.shouldHideMacroDetails {
                HStack(spacing: 10) {
                    MacroTile(
                        title: isChinese ? "蛋白" : "Protein",
                        eaten: macros.protein,
                        target: target.protein,
                        tint: MKColor.green
                    )
                    MacroTile(
                        title: isChinese ? "碳水" : "Carbs",
                        eaten: macros.carbs,
                        target: target.carbs,
                        tint: MKColor.citrus
                    )
                    MacroTile(
                        title: isChinese ? "脂肪" : "Fat",
                        eaten: macros.fat,
                        target: target.fat,
                        tint: MKColor.sky
                    )
                }
            }

            if !remainingTasks.isEmpty {
                VStack(spacing: 8) {
                    ForEach(remainingTasks) { task in
                        CompactTaskRow(task: task) {
                            complete(task)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 26, tint: .white.opacity(0.12))
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(greeting)
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(isChinese ? "不用完美，完成一点就算前进。" : "No need to be perfect. One small action counts.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .mkGlassSurface(cornerRadius: 28, tint: .white.opacity(0.16))
    }

    private var completionCard: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label(isChinese ? "今日完成度" : "Today's progress", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MKColor.green)
                Text(appState.todayCompletionText)
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }

            Spacer()

            ProgressRing(progress: appState.todayCompletionRate)
                .frame(width: 82, height: 82)
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 28, tint: MKColor.subtleGreen.opacity(0.22))
    }

    private var taskListCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isChinese ? "今日任务" : "Today's tasks")
                .font(.headline)

            VStack(spacing: 9) {
                ForEach(appState.todayTasks) { task in
                    TodayTaskRow(task: task) {
                        complete(task)
                    }
                }
            }
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 28, tint: .white.opacity(0.15))
    }

    private var currentStateCard: some View {
        let state = appState.bodyOSBodyState
        let isAdvanced = appState.bodyOSProfile.mode == .advanced
        let cycle = appState.bodyOSCycle

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isChinese ? "当前状态" : "Current State")
                        .font(.headline)
                    Text(currentStateSubtitle(state: state, cycle: cycle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text(modeBadgeText(isAdvanced: isAdvanced))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MKColor.green.opacity(0.18), in: Capsule())
                    .foregroundStyle(MKColor.green)
            }

            FlowingChipRow(chips: currentStateChips(state: state, cycle: cycle, isAdvanced: isAdvanced))

            if !state.reasons.isEmpty {
                Text(state.reasons.prefix(2).joined(separator: isChinese ? "，" : " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 28, tint: MKColor.subtleSky.opacity(0.30))
    }

    private var energySummaryCard: some View {
        let target = appState.bodyOSNutritionTarget
        let isAdvanced = appState.bodyOSProfile.mode == .advanced
        let eaten = appState.eatenCalories
        let remaining = target.calories - eaten
        let progress = target.calories > 0
            ? min(max(Double(eaten) / Double(target.calories), 0), 1.2)
            : 0
        let macros = appState.eatenMacros

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isAdvanced
                         ? (isChinese ? "能量与营养" : "Energy & Nutrition")
                         : (isChinese ? "今日剩余能量" : "Energy left today"))
                        .font(isAdvanced ? .headline : .subheadline.weight(.semibold))
                    Text(energySummarySubtitle(target: target, isAdvanced: isAdvanced))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if isAdvanced {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(max(remaining, 0))")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(remaining < 0 ? MKColor.coral : MKColor.green)
                    Text(remaining >= 0
                         ? (isChinese ? "千卡可用" : "kcal left")
                         : (isChinese ? "千卡超出" : "kcal over"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(isChinese ? "已吃 / 目标" : "Eaten / Target")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(eaten) / \(target.calories)")
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                    }
                }
                CalorieProgressBar(progress: progress, isOver: remaining < 0)
            } else {
                CalorieProgressBar(progress: progress, isOver: remaining < 0)
                Text(lifestyleEnergyHint(remaining: remaining))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isAdvanced && !target.shouldHideMacroDetails {
                HStack(spacing: 10) {
                    MacroTile(
                        title: isChinese ? "蛋白" : "Protein",
                        eaten: macros.protein,
                        target: target.protein,
                        tint: MKColor.green
                    )
                    MacroTile(
                        title: isChinese ? "碳水" : "Carbs",
                        eaten: macros.carbs,
                        target: target.carbs,
                        tint: MKColor.citrus
                    )
                    MacroTile(
                        title: isChinese ? "脂肪" : "Fat",
                        eaten: macros.fat,
                        target: target.fat,
                        tint: MKColor.sky
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 28, tint: MKColor.subtleCitrus.opacity(0.28))
    }

    // MARK: - 生活版首页数据 / 文案

    private func heroSymbol(task: DailyTask?, allDone: Bool) -> String {
        allDone ? "checkmark.seal.fill" : taskSymbol(for: task)
    }

    private func heroTitle(task: DailyTask?, allDone: Bool) -> String {
        guard let task, !allDone else {
            return isChinese ? "今天的事已完成" : "Today's thing is done"
        }
        return task.title
    }

    // 连续坚持天数：从今天往回数，连续有 ≥1 条饮食记录的天数。
    // 今天还没记录时，从昨天起算，避免把进行中的连续记录显示成 0。
    private var lifestyleStreakDays: Int {
        let calendar = Calendar.current
        let loggedDays = Set(appState.meals.map { calendar.startOfDay(for: $0.createdAt) })
        guard !loggedDays.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: Date())
        if !loggedDays.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }

        var count = 0
        while loggedDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    private var didLogYesterday: Bool {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())) else {
            return false
        }
        return appState.meals.contains { calendar.isDate($0.createdAt, inSameDayAs: yesterday) }
    }

    private func streakTitleText(days: Int) -> String {
        if days <= 0 {
            return isChinese ? "今天开始第一天" : "Day one starts today"
        }
        return isChinese ? "已坚持 \(days) 天" : "\(days)-day streak"
    }

    private var streakSubtitleText: String {
        if didLogYesterday {
            return isChinese ? "昨天完成了任务" : "You logged yesterday"
        }
        if lifestyleStreakDays == 0 {
            return isChinese ? "完成今天，就开始连续记录" : "Finish today to start your streak"
        }
        return isChinese ? "保持下去，今天也算上" : "Keep it going — today counts too"
    }

    private var todayFocusDecision: TodayFocusDecision {
        let hour = Calendar.current.component(.hour, from: Date())
        let breakfastLogged = hasMeal(in: 5..<11)
        let lunchLogged = hasMeal(in: 11..<16)
        let dinnerLogged = hasMeal(in: 16..<24)

        if lifestyleHabitsDone {
            return focusDecision(for: .done)
        }

        switch hour {
        case 0..<6:
            return sleepStatus == .done ? focusDecision(for: fallbackFocusKind) : focusDecision(for: .sleep)
        case 6..<11:
            if !breakfastLogged { return focusDecision(for: .meal(.breakfast)) }
            if waterStatus != .done { return focusDecision(for: .water) }
            return focusDecision(for: fallbackFocusKind)
        case 11..<14:
            if !lunchLogged { return focusDecision(for: .meal(.lunch)) }
            if waterStatus != .done { return focusDecision(for: .water) }
            if activityStatus != .done { return focusDecision(for: .activity) }
            return focusDecision(for: fallbackFocusKind)
        case 14..<18:
            if waterStatus != .done { return focusDecision(for: .water) }
            if activityStatus != .done { return focusDecision(for: .activity) }
            if !lunchLogged { return focusDecision(for: .meal(.lunch)) }
            return focusDecision(for: fallbackFocusKind)
        case 18..<21:
            if !dinnerLogged { return focusDecision(for: .meal(.dinner)) }
            if activityStatus != .done { return focusDecision(for: .activity) }
            if waterStatus != .done { return focusDecision(for: .water) }
            return focusDecision(for: fallbackFocusKind)
        case 21..<23:
            return sleepStatus == .done ? focusDecision(for: fallbackFocusKind) : focusDecision(for: .sleep)
        default:
            return sleepStatus == .done ? focusDecision(for: .review) : focusDecision(for: .sleep)
        }
    }

    private var lifestyleHabitsDone: Bool {
        hasMeal(in: 0..<24) && waterStatus == .done && sleepStatus == .done && activityStatus == .done
    }

    private var fallbackFocusKind: TodayFocusKind {
        if !hasMeal(in: 0..<24) { return .meal(defaultMealSlot) }
        if waterStatus != .done { return .water }
        if activityStatus != .done { return .activity }
        if sleepStatus != .done { return .sleep }
        return .done
    }

    private var defaultMealSlot: MealSlot {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11: return .breakfast
        case 11..<16: return .lunch
        default: return .dinner
        }
    }

    private func hasMeal(in hours: Range<Int>) -> Bool {
        let calendar = Calendar.current
        return appState.meals.contains { meal in
            calendar.isDateInToday(meal.createdAt) && hours.contains(calendar.component(.hour, from: meal.createdAt))
        }
    }

    private func focusDecision(for kind: TodayFocusKind) -> TodayFocusDecision {
        switch kind {
        case .meal(let slot):
            return mealFocusDecision(slot)
        case .water:
            return TodayFocusDecision(
                kind: kind,
                contextLabel: isChinese ? "现在最适合" : "Best next step",
                title: isChinese ? "先喝一杯水" : "Drink one glass of water",
                reason: isChinese ? "这个时间不用做很多，补一杯水就能让今天往前走。" : "Keep it small right now. One glass moves the day forward.",
                actionTitle: isChinese ? "加一杯水" : "Add one glass",
                actionSymbol: "plus",
                symbol: "drop.fill",
                tint: MKColor.sky,
                timeHint: isChinese ? "上午和下午更适合把饮水慢慢补上。" : "Morning and afternoon are good moments to keep water steady.",
                encouragement: isChinese ? "先完成一杯就很好，不需要一下子喝很多。" : "One glass is enough for now. No need to overdo it.",
                suggestions: waterSuggestions
            )
        case .activity:
            return TodayFocusDecision(
                kind: kind,
                contextLabel: isChinese ? "现在最适合" : "Best next step",
                title: isChinese ? "站起来走一小会儿" : "Stand and move for a few minutes",
                reason: isChinese ? "久坐之后，轻轻动一下比用力运动更容易坚持。" : "After sitting, a tiny movement break is easier to keep.",
                actionTitle: isChinese ? "记录活动" : "Log activity",
                actionSymbol: "figure.walk",
                symbol: "figure.walk",
                tint: MKColor.citrus,
                timeHint: isChinese ? "上午、下午或饭后，都是轻活动的好时间。" : "Late morning, afternoon, and after meals are good for light movement.",
                encouragement: isChinese ? "走几分钟也算数，今天只需要让身体动起来。" : "A few minutes counts. Just help your body start moving.",
                suggestions: activitySuggestions
            )
        case .sleep:
            return TodayFocusDecision(
                kind: kind,
                contextLabel: isChinese ? "现在最适合" : "Best next step",
                title: isChinese ? "准备休息" : "Prepare to rest",
                reason: isChinese ? "今晚先把节奏放慢，睡好也是在坚持。" : "Slow the pace tonight. Rest is part of staying consistent.",
                actionTitle: isChinese ? "记录睡眠" : "Log sleep",
                actionSymbol: "moon.stars.fill",
                symbol: "moon.stars.fill",
                tint: sleepTint,
                timeHint: isChinese ? "晚上 9 点后，首页会优先提醒休息。" : "After 9 PM, Today gives rest the highest priority.",
                encouragement: isChinese ? "今天做到这里已经可以了，早点休息就是下一步。" : "You have done enough for today. Rest is the next step.",
                suggestions: sleepSuggestions
            )
        case .review:
            return TodayFocusDecision(
                kind: kind,
                contextLabel: isChinese ? "睡前收尾" : "Wind down",
                title: isChinese ? "轻轻回顾今天" : "Gently review today",
                reason: isChinese ? "不用补很多内容，看一眼今天已经做过的事就好。" : "No need to add much. Just glance at what you already did.",
                actionTitle: isChinese ? "快速记录" : "Quick log",
                actionSymbol: "square.and.pencil",
                symbol: "sparkles",
                tint: TodayStyle.primary,
                timeHint: isChinese ? "太晚时不再追加压力，只保留温和收尾。" : "Late at night, Today keeps things gentle.",
                encouragement: isChinese ? "今天已经留下了痕迹，这就很有价值。" : "You left a trace today. That already matters.",
                suggestions: reviewSuggestions
            )
        case .done:
            return TodayFocusDecision(
                kind: kind,
                contextLabel: isChinese ? "今日已完成" : "Done for today",
                title: isChinese ? "今天已经足够好了" : "Today is enough",
                reason: isChinese ? "重要的小事都完成了，接下来保持轻松就好。" : "The important small actions are done. Keep the rest easy.",
                actionTitle: isChinese ? "查看记录" : "View log",
                actionSymbol: "checkmark.circle.fill",
                symbol: "checkmark.circle.fill",
                tint: TodayStyle.primary,
                timeHint: isChinese ? "完成后不继续加码，保持节奏比追求更多更重要。" : "After finishing, keeping rhythm matters more than adding more.",
                encouragement: isChinese ? "你今天已经完成了该做的事，继续这样就很好。" : "You did what mattered today. Keep going like this.",
                suggestions: doneSuggestions
            )
        }
    }

    private func mealFocusDecision(_ slot: MealSlot) -> TodayFocusDecision {
        TodayFocusDecision(
            kind: .meal(slot),
            contextLabel: isChinese ? mealContextLabel(slot) : "Meal time",
            title: mealFocusTitle(slot),
            reason: mealFocusReason(slot),
            actionTitle: isChinese ? "拍照记录" : "Take a photo",
            actionSymbol: "camera.fill",
            symbol: "fork.knife",
            tint: TodayStyle.primary,
            timeHint: mealTimeHint(slot),
            encouragement: mealEncouragement(slot),
            suggestions: mealSuggestions(slot)
        )
    }

    private func mealContextLabel(_ slot: MealSlot) -> String {
        switch slot {
        case .breakfast: return "早餐时间"
        case .lunch: return "午餐时间"
        case .dinner: return "晚餐时间"
        }
    }

    private func mealFocusTitle(_ slot: MealSlot) -> String {
        if isChinese {
            switch slot {
            case .breakfast: return "拍一下早餐"
            case .lunch: return "完成午餐记录"
            case .dinner: return "记录今天这顿晚餐"
            }
        }
        switch slot {
        case .breakfast: return "Snap breakfast"
        case .lunch: return "Log lunch"
        case .dinner: return "Log dinner"
        }
    }

    private func mealFocusReason(_ slot: MealSlot) -> String {
        let prefix: String
        if isChinese {
            switch slot {
            case .breakfast: prefix = "早上先完成一次记录，今天就开了个好头。"
            case .lunch: prefix = "午餐是今天最值得记录的一餐，拍一下就够。"
            case .dinner: prefix = "晚餐记录下来，今天就更完整了。"
            }
        } else {
            switch slot {
            case .breakfast: prefix = "One breakfast photo gives the day an easy start."
            case .lunch: prefix = "Lunch is the best meal to capture right now. One photo is enough."
            case .dinner: prefix = "Logging dinner gives today a clearer finish."
            }
        }
        return "\(prefix) \(gentleMealEnergyHint)"
    }

    private func mealTimeHint(_ slot: MealSlot) -> String {
        if isChinese {
            switch slot {
            case .breakfast: return "饭前或刚吃完拍照，都算完成。"
            case .lunch: return "饭点优先记录饮食，之后再考虑喝水或活动。"
            case .dinner: return "晚餐后不用补偿，保持温和就好。"
            }
        }
        switch slot {
        case .breakfast: return "Before or right after eating both count."
        case .lunch: return "At meal time, food logging comes before water or movement."
        case .dinner: return "After dinner, no compensation. Keep it gentle."
        }
    }

    private func mealEncouragement(_ slot: MealSlot) -> String {
        if isChinese {
            switch slot {
            case .breakfast: return "今天完成一次拍照，就已经开始坚持了。"
            case .lunch: return "先拍照，不用判断吃得好不好。记录本身就是进步。"
            case .dinner: return "把晚餐记下来就好，今天不需要完美。"
            }
        }
        switch slot {
        case .breakfast: return "One photo means you have already started."
        case .lunch: return "Take the photo first. No judging the meal."
        case .dinner: return "Just log dinner. Today does not need to be perfect."
        }
    }

    private func mealSuggestions(_ slot: MealSlot) -> [String] {
        let second: String
        if isChinese {
            switch slot {
            case .breakfast: second = "如果不饿，先喝水也可以。"
            case .lunch: second = "吃到七八分饱，下午会更轻松。"
            case .dinner: second = "晚餐慢一点，饭后散步几分钟就很好。"
            }
        } else {
            switch slot {
            case .breakfast: second = "If you are not hungry, water first is fine."
            case .lunch: second = "Stop comfortably full so the afternoon feels easier."
            case .dinner: second = "Eat slowly, then take a short walk if it feels good."
            }
        }
        return [gentleMealEnergyHint, second]
    }

    private var gentleMealEnergyHint: String {
        let remaining = appState.budget.remaining
        if remaining < 0 {
            return isChinese
                ? "这一餐轻一点就好，不用补偿。"
                : "Keep this meal lighter. No need to compensate."
        }
        if remaining < 350 {
            return isChinese
                ? "这一餐简单一点，主食少一点会更舒服。"
                : "Keep this meal simple; a little less starch may feel better."
        }
        return isChinese
            ? "正常吃，先拍照记录就好。"
            : "Eat normally. Just take the photo first."
    }

    private func lifestyleEnergyHint(remaining: Int) -> String {
        if remaining >= 0 {
            return isChinese
                ? "今天还有空间，正常吃就好。"
                : "There is still room today. Eat normally."
        }
        return isChinese
            ? "已经吃满了，不补偿，下一餐保持温和。"
            : "Already at the limit. No compensation, keep the next meal gentle."
    }

    private var waterSuggestions: [String] {
        if appState.waterCups == 0 {
            return isChinese
                ? ["先喝一杯水，今天就开始了。", "不需要一次喝很多，分几次更容易。"]
                : ["Drink one glass to start the day.", "No need to drink a lot at once. Spread it out."]
        }
        return isChinese
            ? ["把水杯放在手边，下一小时更容易想起来。", "如果刚吃完饭，先小口喝一点就好。"]
            : ["Keep your cup nearby so the next hour is easier.", "If you just ate, small sips are enough."]
    }

    private var activitySuggestions: [String] {
        isChinese
            ? ["站起来走 3 分钟就算完成一次行动。", "饭后或久坐后，轻轻动一下比用力更重要。"]
            : ["Stand and walk for 3 minutes. That counts.", "After a meal or long sitting, gentle movement matters most."]
    }

    private var sleepSuggestions: [String] {
        isChinese
            ? ["先把屏幕放远一点，让身体慢慢进入休息。", "明天继续记录就好，今晚不用补更多。"]
            : ["Put the screen farther away and let your body slow down.", "Continue tomorrow. No need to add more tonight."]
    }

    private var reviewSuggestions: [String] {
        isChinese
            ? ["只补最容易的一项，不用把今天填满。", "睡前保持轻松，比追求完整更重要。"]
            : ["Only add the easiest item. No need to fill everything.", "A calm bedtime matters more than a perfect log."]
    }

    private var doneSuggestions: [String] {
        isChinese
            ? ["今天已经完成，接下来保持轻松。", "继续保持这个节奏就很好。"]
            : ["Today is complete. Keep the rest easy.", "This rhythm is worth keeping."]
    }

    private var recentGrowthText: String {
        if lifestyleStreakDays >= 7 {
            return isChinese ? "你已经连续坚持 \(lifestyleStreakDays) 天，习惯正在变得稳定。" : "You have kept going for \(lifestyleStreakDays) days. The habit is getting steadier."
        }
        if appState.meals.count >= 3 {
            return isChinese ? "最近的饮食记录越来越自然，先拍一下正在变成习惯。" : "Food logging is starting to feel more natural."
        }
        if waterStatus == .done {
            return isChinese ? "今天的饮水已经稳定完成，这是很好的小进步。" : "Water is steady today. That is a real small win."
        }
        return isChinese ? "完成今天这一小步，就会给明天留下一点惯性。" : "Finish this tiny step today, and tomorrow gets a little easier."
    }

    private var nextActionTask: DailyTask? {
        appState.todayTasks.first { $0.status != .completed } ?? appState.todayTasks.first
    }

    private var primaryStrategyTitle: String {
        appState.bodyOSStrategyExplanation.headline
    }

    private var primaryStrategyAction: String {
        appState.bodyOSStrategyExplanation.primaryAction
    }

    private func microActionPrompt(for task: DailyTask?, isComplete: Bool) -> String {
        if isComplete {
            return isChinese ? "今天已经做到了，剩下不用太用力。" : "You did enough for today. Keep the rest easy."
        }

        guard let task else {
            return appState.gentleTodayMessage
        }

        switch task.taskType {
        case .mealPhoto:
            return isChinese ? "吃之前拍一下就行，不用拍得多好。" : "Take a quick photo before eating. It does not need to be perfect."
        case .portionAdjustment:
            return isChinese ? "只少一口，或者少一小勺就行。" : "Leave one bite, or one small spoonful."
        case .review:
            return isChinese ? "睡前看一眼，30 秒就够。" : "Take a 30-second look before bed."
        case .weight:
            return isChinese ? "记一下就好，不用评价数字。" : "Log it once without judging the number."
        }
    }

    private func taskIntentLabel(for task: DailyTask) -> String {
        switch task.taskType {
        case .mealPhoto:
            return isChinese ? "先拍一下" : "Just snap"
        case .portionAdjustment:
            return isChinese ? "少一点点" : "A little less"
        case .review:
            return isChinese ? "看一眼" : "One quick look"
        case .weight:
            return isChinese ? "记一下" : "Log once"
        }
    }

    private func taskSymbol(for task: DailyTask?) -> String {
        switch task?.taskType {
        case .mealPhoto:
            return "camera.fill"
        case .portionAdjustment:
            return "fork.knife"
        case .review:
            return "text.magnifyingglass"
        case .weight:
            return "scalemass.fill"
        case nil:
            return "leaf.fill"
        }
    }

    private func remainingValueText(_ remaining: Int) -> String {
        "\(abs(remaining))"
    }

    private func remainingUnitText(_ remaining: Int) -> String {
        if remaining >= 0 {
            return isChinese ? "千卡还能吃" : "kcal left"
        }
        return isChinese ? "千卡多了点" : "kcal over"
    }

    private func energyBoundaryHint(remaining: Int) -> String {
        if remaining >= 220 {
            return isChinese ? "下一餐正常吃，多放点肉蛋豆和蔬菜。" : "Eat normally next. Add protein and vegetables."
        }
        if remaining >= 0 {
            return isChinese ? "剩得不多了，下一餐清爽一点就好。" : "There is not much room left. Keep the next meal lighter."
        }
        return isChinese ? "不用饿回来，下一餐吃清淡一点就好。" : "No need to make up for it. Keep the next meal simple."
    }

    private func stateFocusText(state: BodyState) -> String {
        if state.shouldOverridePlannedTraining {
            return isChinese ? "今天身体更重要，别把自己逼太紧。" : "Your body comes first today. Keep it easier."
        }

        if state.lifeState != .normal {
            return isChinese ? "今天事情有点多，记录简单一点。" : "There is more going on today. Keep tracking simple."
        }

        if state.recoveryState == .low || state.recoveryState == .critical {
            return isChinese ? "今天有点累，做一件小事就好。" : "You seem tired today. One small thing is enough."
        }

        return isChinese ? "今天正常过，记得抓住一件小事。" : "A normal day. Hold onto one small thing."
    }

    private func professionalDayTitle(state: BodyState, cycle: BodyOSCycle) -> String {
        if state.shouldOverridePlannedTraining {
            return isChinese ? "今天按身体状态调整" : "Adjusted by body state today"
        }
        if cycle.isPlannedTrainingDay {
            return isChinese ? "\(cycleFocusZh(cycle.focus))训练日" : "\(cycleFocusEn(cycle.focus)) training day"
        }
        return isChinese ? "休息日" : "Rest day"
    }

    private func professionalDaySubtitle(state: BodyState, cycle: BodyOSCycle) -> String {
        if state.trainingState == .injured {
            return isChinese ? "受伤期间，训练强度和碳水会自动下调。" : "Injury period: training load and carbs are adjusted down."
        }
        if state.recoveryState == .critical || state.recoveryState == .low {
            return isChinese ? "恢复偏低，今天重点看睡眠、饮水和训练强度。" : "Recovery is low. Watch sleep, water, and training load."
        }
        if cycle.isPlannedTrainingDay {
            return isChinese ? "记录训练与营养完成度，系统会据此调整后续建议。" : "Log training and nutrition so the system can adjust next steps."
        }
        return isChinese ? "休息日也需要记录饮食、睡眠和恢复。" : "Rest days still need food, sleep, and recovery logs."
    }

    private func cycleTypeLabel(_ type: BodyOSCycleType) -> String {
        if isChinese {
            switch type {
            case .fatLoss: return "减脂期"
            case .maintenance: return "维持期"
            case .muscleGain: return "增肌期"
            case .recovery: return "恢复期"
            }
        }
        switch type {
        case .fatLoss: return "Fat loss"
        case .maintenance: return "Maintain"
        case .muscleGain: return "Muscle gain"
        case .recovery: return "Recovery"
        }
    }

    private func macroProgressTint(current: Int, target: Int, base: Color) -> Color {
        guard target > 0 else { return base }
        let ratio = Double(current) / Double(target)
        if ratio > 1.15 {
            return MKColor.coral
        }
        if ratio < 0.72 {
            return MKColor.citrus
        }
        return base
    }

    private func macroProgress(_ current: Int, _ target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(max(Double(current) / Double(target), 0), 1.15)
    }

    private func professionalAdviceSymbol(remaining: Int) -> String {
        if appState.bodyOSBodyState.shouldOverridePlannedTraining {
            return "cross.case.fill"
        }
        if remaining < 0 {
            return "exclamationmark.triangle.fill"
        }
        if appState.bodyOSRecoveryScore.state == .low || appState.bodyOSRecoveryScore.state == .critical {
            return "moon.zzz.fill"
        }
        return "sparkles"
    }

    private func professionalAdviceTint(remaining: Int) -> Color {
        if appState.bodyOSBodyState.shouldOverridePlannedTraining || remaining < 0 {
            return MKColor.coral
        }
        if appState.bodyOSRecoveryScore.state == .low || appState.bodyOSRecoveryScore.state == .critical {
            return MKColor.citrus
        }
        return MKColor.green
    }

    private func professionalAdjustmentText(remaining: Int) -> String {
        let state = appState.bodyOSBodyState
        let macros = appState.eatenMacros
        let target = appState.bodyOSNutritionTarget

        if state.shouldOverridePlannedTraining {
            return isChinese
                ? "今天不要硬追原训练计划，优先记录疼痛、睡眠和饮食完成度。"
                : "Do not chase the original training plan. Track pain, sleep, and nutrition completion."
        }
        if remaining < 0 {
            return isChinese
                ? "热量已经多了一点，后续不要补偿性加练，下一餐降低油脂和主食。"
                : "Calories are over. Avoid compensatory training; keep the next meal lower in fat and carbs."
        }
        if target.protein > 0, macros.protein < Int(Double(target.protein) * 0.75) {
            return isChinese
                ? "蛋白还没到位，下一餐先补肉蛋豆奶，再看主食。"
                : "Protein is behind. Add protein first at the next meal, then adjust carbs."
        }
        if appState.bodyOSRecoveryScore.state == .low || appState.bodyOSRecoveryScore.state == .critical {
            return isChinese
                ? "恢复偏低，训练完成不如睡眠和饮水重要。"
                : "Recovery is low. Sleep and water matter more than finishing training."
        }
        return isChinese
            ? "当前完成情况正常，继续按目标记录即可。"
            : "Completion is on track. Keep logging against the targets."
    }


    private func modeBadgeText(isAdvanced: Bool) -> String {
        if isChinese {
            return isAdvanced ? "多看一点" : "简单看"
        }
        return isAdvanced ? "More detail" : "Simple"
    }

    private func currentStateSubtitle(state: BodyState, cycle: BodyOSCycle) -> String {
        if state.shouldOverridePlannedTraining {
            return isChinese ? "今天听身体的，训练先放轻" : "Listen to your body today; keep training lighter"
        }
        if cycle.isPlannedTrainingDay {
            return isChinese ? "今天可以照常动一动" : "Move as planned today"
        }
        return isChinese ? "休息日，轻轻过就好" : "Rest day, keep it gentle"
    }

    private func energySummarySubtitle(target: NutritionTarget, isAdvanced: Bool) -> String {
        if isAdvanced {
            if isChinese {
                return "TDEE \(target.tdee) · 缺口 \(target.deficit) 千卡"
            }
            return "TDEE \(target.tdee) · Deficit \(target.deficit) kcal"
        }
        return isChinese ? "今日剩余热量与状态" : "Today's remaining energy"
    }

    private func currentStateChips(state: BodyState, cycle: BodyOSCycle, isAdvanced: Bool) -> [StateChipData] {
        var chips: [StateChipData] = []

        chips.append(StateChipData(
            symbol: goalSymbol(state.goalState),
            label: goalStateLabel(state.goalState),
            tint: MKColor.green
        ))

        chips.append(StateChipData(
            symbol: trainingSymbol(state.trainingState),
            label: trainingStateLabel(state.trainingState, cycle: cycle),
            tint: state.shouldOverridePlannedTraining ? MKColor.coral : MKColor.deepGreen
        ))

        if state.lifeState != .normal {
            chips.append(StateChipData(
                symbol: lifeSymbol(state.lifeState),
                label: lifeStateLabel(state.lifeState),
                tint: MKColor.citrus
            ))
        }

        if isAdvanced {
            chips.append(StateChipData(
                symbol: "heart.text.square.fill",
                label: recoveryStateLabel(state.recoveryState, score: appState.bodyOSRecoveryScore),
                tint: recoveryTint(state.recoveryState)
            ))
        }

        return chips
    }

    private func goalSymbol(_ goal: BodyOSGoalState) -> String {
        switch goal {
        case .fatLoss: return "flame.fill"
        case .maintenance: return "scalemass.fill"
        case .muscleGain: return "figure.strengthtraining.traditional"
        case .recovery: return "leaf.fill"
        }
    }

    private func goalStateLabel(_ goal: BodyOSGoalState) -> String {
        if isChinese {
            switch goal {
            case .fatLoss: return "减脂"
            case .maintenance: return "维持"
            case .muscleGain: return "增肌"
            case .recovery: return "恢复"
            }
        }
        switch goal {
        case .fatLoss: return "Fat loss"
        case .maintenance: return "Maintain"
        case .muscleGain: return "Muscle"
        case .recovery: return "Recovery"
        }
    }

    private func trainingSymbol(_ state: BodyOSTrainingState) -> String {
        switch state {
        case .normalTraining: return "dumbbell.fill"
        case .restDay: return "moon.fill"
        case .deload: return "tortoise.fill"
        case .stopped: return "pause.circle.fill"
        case .injured: return "cross.case.fill"
        case .returning: return "arrow.uturn.forward.circle.fill"
        }
    }

    private func trainingStateLabel(_ state: BodyOSTrainingState, cycle: BodyOSCycle) -> String {
        if isChinese {
            switch state {
            case .normalTraining: return cycleFocusZh(cycle.focus) + "日"
            case .restDay: return "休息日"
            case .deload: return "减载周"
            case .stopped: return "停训"
            case .injured: return "受伤"
            case .returning: return "复训中"
            }
        }
        switch state {
        case .normalTraining: return cycleFocusEn(cycle.focus) + " day"
        case .restDay: return "Rest"
        case .deload: return "Deload"
        case .stopped: return "Stopped"
        case .injured: return "Injured"
        case .returning: return "Returning"
        }
    }

    private func cycleFocusZh(_ focus: BodyOSWorkoutFocus) -> String {
        switch focus {
        case .fullBody: return "全身"
        case .push: return "推"
        case .pull: return "拉"
        case .legs: return "腿"
        case .upper: return "上肢"
        case .lower: return "下肢"
        case .rest: return "休息"
        case .custom: return "自定义"
        }
    }

    private func cycleFocusEn(_ focus: BodyOSWorkoutFocus) -> String {
        switch focus {
        case .fullBody: return "Full body"
        case .push: return "Push"
        case .pull: return "Pull"
        case .legs: return "Legs"
        case .upper: return "Upper"
        case .lower: return "Lower"
        case .rest: return "Rest"
        case .custom: return "Custom"
        }
    }

    private func lifeSymbol(_ life: BodyOSLifeState) -> String {
        switch life {
        case .normal: return "sun.max.fill"
        case .travel: return "airplane"
        case .businessTrip: return "briefcase.fill"
        case .party: return "fork.knife.circle.fill"
        case .holiday: return "gift.fill"
        case .highStress: return "bolt.heart.fill"
        case .illness: return "bandage.fill"
        }
    }

    private func lifeStateLabel(_ life: BodyOSLifeState) -> String {
        if isChinese {
            switch life {
            case .normal: return "日常"
            case .travel: return "旅行"
            case .businessTrip: return "出差"
            case .party: return "聚餐"
            case .holiday: return "假期"
            case .highStress: return "高压力"
            case .illness: return "生病"
            }
        }
        switch life {
        case .normal: return "Normal"
        case .travel: return "Travel"
        case .businessTrip: return "Business trip"
        case .party: return "Social meal"
        case .holiday: return "Holiday"
        case .highStress: return "High stress"
        case .illness: return "Illness"
        }
    }

    private func recoveryStateLabel(_ state: BodyOSRecoveryState, score: RecoveryScore) -> String {
        if isChinese {
            switch state {
            case .good: return "恢复良好 \(score.value)"
            case .moderate: return "中等恢复 \(score.value)"
            case .low: return "恢复偏低 \(score.value)"
            case .critical: return "恢复严重不足 \(score.value)"
            }
        }
        switch state {
        case .good: return "Recovery good \(score.value)"
        case .moderate: return "Recovery fair \(score.value)"
        case .low: return "Recovery low \(score.value)"
        case .critical: return "Recovery critical \(score.value)"
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

    private var bodyOSStrategyCard: some View {
        let state = appState.bodyOSBodyState
        let target = appState.bodyOSNutritionTarget
        let strategy = appState.bodyOSTodayStrategy

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isChinese ? "Body OS 今日策略" : "Body OS Strategy")
                        .font(.headline)
                    Text(stateSummary(state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if appState.bodyOSProfile.mode == .advanced {
                    Text("\(target.calories) kcal")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(MKColor.green)
                }
            }

            VStack(spacing: 10) {
                ForEach(Array(strategy.items.prefix(2))) { item in
                    StrategyItemRow(item: item)
                }
            }
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 28, tint: MKColor.subtleGreen.opacity(0.18))
    }

    private var recordHubCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(MKColor.green)
                    .frame(width: 32, height: 32)
                    .background(MKColor.subtleGreen.opacity(0.40), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(isChinese ? "记一下今天" : "Log today")
                        .font(.headline)
                    Text(isChinese
                         ? "饮食、运动、睡眠、饮水、补剂，都可以简单记一笔。"
                         : "Food, movement, sleep, water, and supplements can all be logged lightly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                NavigationLink {
                    ScanView()
                } label: {
                    RecordShortcutLabel(
                        symbol: "camera.fill",
                        title: isChinese ? "拍照或记运动" : "Photo or workout",
                        subtitle: isChinese ? "吃的、练的" : "Food, training",
                        tint: MKColor.green
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    BodyLogView()
                } label: {
                    RecordShortcutLabel(
                        symbol: "list.bullet.rectangle.portrait.fill",
                        title: isChinese ? "补充身体记录" : "Body notes",
                        subtitle: isChinese ? "睡眠、饮水、补剂" : "Sleep, water, supplements",
                        tint: MKColor.sky
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .mkGlassSurface(cornerRadius: 26, tint: .white.opacity(0.14), isInteractive: true)
    }

    private var feedbackCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(MKColor.green)
                .frame(width: 34, height: 34)
                .background(MKColor.subtleGreen.opacity(0.38), in: Circle())

            Text(celebration ?? appState.gentleTodayMessage)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(16)
        .mkGlassSurface(cornerRadius: 24, tint: .white.opacity(0.12))
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if isChinese {
            if hour < 11 { return "早上好，今天先完成一个小动作。" }
            if hour < 18 { return "下午好，今天还有很轻的一步。" }
            return "晚上好，收个温和的尾就好。"
        }

        if hour < 11 { return "Good morning. Start with one small action." }
        if hour < 18 { return "Good afternoon. Keep the next step light." }
        return "Good evening. Close the day gently."
    }

    private var todayDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans" : "en_US")
        formatter.dateFormat = isChinese ? "M月d日 EEEE" : "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    private var headerStatusTag: String {
        let state = appState.bodyOSBodyState
        if state.shouldOverridePlannedTraining {
            return isChinese ? "恢复中" : "Recovering"
        }
        return cycleTypeLabel(appState.bodyOSCycle.type)
    }

    private var primaryRecommendationSymbol: String {
        let state = appState.bodyOSBodyState
        if state.shouldOverridePlannedTraining {
            return "heart.fill"
        }
        if appState.bodyOSCycle.isPlannedTrainingDay {
            return trainingSymbol(state.trainingState)
        }
        return "leaf.fill"
    }

    private var primaryRecommendationText: String {
        let state = appState.bodyOSBodyState
        let cycle = appState.bodyOSCycle
        let target = appState.bodyOSNutritionTarget

        if isChinese {
            if state.shouldOverridePlannedTraining {
                return "今天按身体状态调整，先把训练放轻，记录睡眠、饮水和饮食。"
            }
            if cycle.isPlannedTrainingDay {
                return "今天是\(cycleFocusZh(cycle.focus))训练日，建议完成力量训练，并保证蛋白质摄入。"
            }
            if target.shouldHideMacroDetails {
                return "今天先保持轻松记录，吃饭正常一点，不用追求完美。"
            }
            return "今天是休息日，保持饮食记录，蛋白质别落下。"
        }

        if state.shouldOverridePlannedTraining {
            return "Adjust by body state today. Keep training lighter, then log sleep, water, and food."
        }
        if cycle.isPlannedTrainingDay {
            return "Today is a \(cycleFocusEn(cycle.focus)) training day. Finish strength work and keep protein on track."
        }
        if target.shouldHideMacroDetails {
            return "Keep logging light today. Eat normally; no need to be perfect."
        }
        return "Today is a rest day. Keep food logged and do not let protein drop."
    }

    private func calorieRemainingText(current: Int, target: Int) -> String {
        let remaining = target - current
        if isChinese {
            return remaining >= 0 ? "还剩 \(remaining) kcal" : "已超出 \(abs(remaining)) kcal"
        }
        return remaining >= 0 ? "\(remaining) kcal left" : "\(abs(remaining)) kcal over"
    }

    private func recoveryShortLabel(_ state: BodyOSRecoveryState) -> String {
        if isChinese {
            switch state {
            case .good: return "良好"
            case .moderate: return "中等"
            case .low: return "偏低"
            case .critical: return "过低"
            }
        }
        switch state {
        case .good: return "Good"
        case .moderate: return "Fair"
        case .low: return "Low"
        case .critical: return "Critical"
        }
    }

    private func stateSummary(_ state: BodyState) -> String {
        if isChinese {
            switch (state.trainingState, state.recoveryState, state.lifeState) {
            case (.injured, _, _):
                return "受伤优先，今天覆盖原训练计划"
            case (_, .critical, _):
                return "恢复不足，今天先降强度"
            case (_, _, .businessTrip), (_, _, .travel):
                return "行程模式，降低记录压力"
            case (_, _, .party):
                return "聚餐模式，保持温和边界"
            default:
                return "正常日，保持轻量推进"
            }
        }

        switch (state.trainingState, state.recoveryState, state.lifeState) {
        case (.injured, _, _):
            return "Injury first; original training is overridden"
        case (_, .critical, _):
            return "Recovery is low; reduce intensity today"
        case (_, _, .businessTrip), (_, _, .travel):
            return "Travel mode; keep logging lighter"
        case (_, _, .party):
            return "Social meal mode; keep gentle boundaries"
        default:
            return "Normal day; keep progress light"
        }
    }

    private func complete(_ task: DailyTask) {
        appState.completeTask(id: task.id)
        LocalRecordRepository.completeTask(id: task.id, in: storedTasks, modelContext: modelContext)
        celebration = appState.latestCelebration
    }
}

private typealias TodayStyle = MKTheme

private struct TodayBackground: View {
    var body: some View {
        TodayStyle.background
            .ignoresSafeArea()
    }
}

private struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(TodayStyle.ink)
    }
}

private struct TodayPrimaryButtonLabel: View {
    let symbol: String
    let title: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(TodayStyle.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TodaySecondaryButtonLabel: View {
    let symbol: String
    let title: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(TodayStyle.primary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(TodayStyle.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// 活动消耗进度环（Apple Fitness Move 环式）。
private struct ActivityProgressRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.18), lineWidth: 4)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}

// 普通版睡眠快速录入：仅小时数 + 保存。
private struct TodaySleepSheet: View {
    let isChinese: Bool
    let onSave: (SleepLog) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hours: Double = 7

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(isChinese ? "昨晚睡了多久？" : "How long did you sleep?")
                    .font(.headline)
                    .foregroundStyle(MKTheme.ink)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", hours))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(MKTheme.ink)
                    Text(isChinese ? "小时" : "hr")
                        .font(.headline)
                        .foregroundStyle(MKTheme.secondaryText)
                }

                Stepper(value: $hours, in: 0...14, step: 0.5) {
                    Text(isChinese ? "调整时长" : "Adjust")
                        .font(.subheadline)
                }
                .padding(.horizontal, 40)

                Button {
                    onSave(SleepLog(hoursSlept: hours, quality: .fair, note: ""))
                    dismiss()
                } label: {
                    Text(isChinese ? "保存" : "Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(MKPrimaryActionStyle(tint: MKColor.green))
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 28)
            .frame(maxWidth: .infinity)
            .background(MKBackdrop())
            .navigationTitle(isChinese ? "记录睡眠" : "Log sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "取消" : "Cancel") { dismiss() }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// 普通版活动录入：自设消耗目标 + 快速记录一次活动（类型 + 时长 → 估算消耗）。
private struct TodayActivitySheet: View {
    let isChinese: Bool
    let currentGoal: Int
    let weightKilograms: Double
    let age: Int
    let onSetGoal: (Int) -> Void
    let onLog: (WorkoutLog) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var goal: Int
    @State private var type: WorkoutType = .walking
    @State private var minutes: Int = 30

    private let typeOptions: [WorkoutType] = [.walking, .running, .cycling, .yoga, .other]
    private let durationOptions: [Int] = [15, 30, 60, 90]

    init(isChinese: Bool, currentGoal: Int, weightKilograms: Double, age: Int, onSetGoal: @escaping (Int) -> Void, onLog: @escaping (WorkoutLog) -> Void) {
        self.isChinese = isChinese
        self.currentGoal = currentGoal
        self.weightKilograms = weightKilograms
        self.age = age
        self.onSetGoal = onSetGoal
        self.onLog = onLog
        _goal = State(initialValue: currentGoal)
    }

    private var estimatedCalories: Int {
        EnergyCalculator.workoutCalories(
            type: type,
            weightKilograms: weightKilograms,
            durationMinutes: minutes,
            averageHeartRate: nil,
            age: age
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(isChinese ? "今日消耗目标" : "Daily move goal")
                            .font(.headline)
                            .foregroundStyle(MKTheme.ink)
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text("\(goal)")
                                .font(.system(size: 36, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(MKColor.citrus)
                            Text(isChinese ? "千卡" : "kcal")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(MKTheme.secondaryText)
                        }
                        Stepper(value: $goal, in: 100...1500, step: 50) {
                            Text(isChinese ? "调整目标" : "Adjust goal").font(.subheadline)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text(isChinese ? "记录一次活动" : "Log an activity")
                            .font(.headline)
                            .foregroundStyle(MKTheme.ink)

                        VStack(spacing: 0) {
                            ForEach(Array(typeOptions.enumerated()), id: \.offset) { index, option in
                                Button { type = option } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: type == option ? "largecircle.fill.circle" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(type == option ? MKColor.citrus : MKTheme.secondaryText.opacity(0.5))
                                        Text(option.localizedName(language: isChinese ? .simplifiedChinese : .english))
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(MKTheme.ink)
                                        Spacer()
                                    }
                                    .padding(.vertical, 11)
                                }
                                .buttonStyle(.plain)
                                if index < typeOptions.count - 1 {
                                    Divider().overlay(MKTheme.divider).padding(.leading, 32)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                        HStack(spacing: 10) {
                            ForEach(durationOptions, id: \.self) { value in
                                Button { minutes = value } label: {
                                    Text(value >= 90 ? (isChinese ? "90+ 分" : "90+m") : (isChinese ? "\(value) 分" : "\(value)m"))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(minutes == value ? .white : MKTheme.ink)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(minutes == value ? MKColor.citrus : MKTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        onSetGoal(goal)
                        onLog(WorkoutLog(type: type, durationMinutes: minutes, averageHeartRate: nil, calories: estimatedCalories, note: "", source: .manual))
                        dismiss()
                    } label: {
                        Text(isChinese ? "完成" : "Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(MKPrimaryActionStyle(tint: MKColor.citrus))
                }
                .padding(20)
            }
            .background(MKBackdrop())
            .navigationTitle(isChinese ? "记录活动" : "Log activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "取消" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isChinese ? "仅存目标" : "Goal only") {
                        onSetGoal(goal)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct StatusMetricBlock: View {
    let title: String
    let value: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let ringProgress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(tint.opacity(0.11), in: Circle())
                Spacer()
                MiniStaticRing(progress: ringProgress, tint: tint)
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(TodayStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(TodayStyle.secondaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(TodayStyle.secondaryText.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(12)
        .background(TodayStyle.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MiniStaticRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.07), lineWidth: 4)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}

private struct CalorieRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let current: Int
    let target: Int
    let progress: Double
    let isChinese: Bool

    @State private var animatedProgress = 0.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(TodayStyle.background, lineWidth: 14)
            Circle()
                .trim(from: 0, to: min(max(animatedProgress, 0), 1))
                .stroke(
                    current > target ? MKColor.coral : TodayStyle.primary,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(min(max(progress, 0), 1) * 100))%")
                    .font(.system(size: 23, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(TodayStyle.ink)
                Text(isChinese ? "热量" : "Energy")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(TodayStyle.secondaryText)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isChinese ? "热量进度" : "Energy progress")
        .accessibilityValue("\(current) / \(target) kcal")
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

private struct MacroSummaryBlock: View {
    let title: String
    let current: Int
    let target: Int
    let tint: Color
    let isChinese: Bool

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(max(Double(current) / Double(target), 0), 1)
    }

    private var remaining: Int {
        max(target - current, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TodayStyle.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text("\(current)/\(target)g")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(TodayStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            MKCapsuleProgressBar(progress: progress, tint: tint, height: 7)

            Text(isChinese ? "剩 \(remaining)g" : "\(remaining)g left")
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(TodayStyle.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(TodayStyle.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct CleanChecklistRow: View {
    let item: ProfessionalChecklistItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.isCompleted ? .white : item.tint)
                .frame(width: 36, height: 36)
                .background(
                    item.isCompleted ? item.tint : item.tint.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TodayStyle.ink)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(TodayStyle.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 8)

            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(item.isCompleted ? TodayStyle.primary : TodayStyle.secondaryText.opacity(0.4))
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.detail)
    }
}

private extension View {
    func todayCard() -> some View {
        self
            .background(TodayStyle.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: TodayStyle.shadow, radius: 18, x: 0, y: 8)
    }
}

private struct StrategyItemRow: View {
    let item: StrategyItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKColor.green)
                .frame(width: 30, height: 30)
                .background(MKColor.green.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(item.actions.prefix(2))) { action in
                    Text(action.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var symbol: String {
        switch item.type {
        case .nutrition:
            return "fork.knife"
        case .training:
            return "figure.strengthtraining.traditional"
        case .recovery:
            return "moon.zzz.fill"
        case .supplement:
            return "pills.fill"
        case .habit:
            return "checkmark.circle.fill"
        }
    }
}

private struct TodayTaskRow: View {
    let task: DailyTask
    let onComplete: () -> Void

    private var isCompleted: Bool {
        task.status == .completed
    }

    var body: some View {
        Button(action: onComplete) {
            HStack(spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? MKColor.green : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(task.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(13)
            .background(Color.white.opacity(isCompleted ? 0.035 : 0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isCompleted)
    }
}

private struct CompactTaskRow: View {
    let task: DailyTask
    let onComplete: () -> Void

    var body: some View {
        Button(action: onComplete) {
            HStack(spacing: 10) {
                Image(systemName: "circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MKColor.sky)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(task.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct RecordShortcutLabel: View {
    let symbol: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .padding(13)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct ProfessionalMetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
    }
}

private struct RecoveryGauge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let score: Int
    let title: String
    let subtitle: String
    let tint: Color

    @State private var animatedProgress = 0.0

    private var progress: Double {
        min(max(Double(score) / 100, 0), 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(width: 88, height: 88)

            Text(subtitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(score)")
        .accessibilityValue(subtitle)
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
            withAnimation(.smooth(duration: 0.65)) {
                animatedProgress = value
            }
        }
    }
}

private struct MacroBalanceRibbon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let proteinProgress: Double
    let carbsProgress: Double
    let fatProgress: Double
    let isChinese: Bool

    @State private var revealed = false

    private var segments: [(title: String, progress: Double, tint: Color)] {
        [
            (isChinese ? "蛋白" : "Protein", proteinProgress, MKColor.green),
            (isChinese ? "碳水" : "Carbs", carbsProgress, MKColor.citrus),
            (isChinese ? "脂肪" : "Fat", fatProgress, MKColor.sky)
        ]
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                VStack(alignment: .leading, spacing: 6) {
                    MKCapsuleProgressColumn(
                        progress: min(segment.progress, 1) * (revealed ? 1 : 0),
                        tint: segment.tint,
                        minFillHeight: 5
                    )
                    .frame(height: 56)

                    Text(segment.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isChinese ? "宏量营养完成图" : "Macro completion chart")
        .onAppear {
            if reduceMotion {
                revealed = true
            } else {
                withAnimation(.smooth(duration: 0.55)) {
                    revealed = true
                }
            }
        }
    }
}

private struct ProfessionalProgressRow: View {
    let title: String
    let current: Int
    let target: Int
    let unit: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(current) / \(target) \(unit)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            CalorieProgressBar(progress: min(max(progress, 0), 1), isOver: progress > 1.08, tint: tint)
        }
    }
}

private struct ProfessionalChecklistItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let isCompleted: Bool
}

private struct ProfessionalChecklistRow: View {
    let item: ProfessionalChecklistItem

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(item.isCompleted ? item.tint : .secondary)
                .frame(width: 24, height: 24)

            Image(systemName: item.symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(item.tint)
                .frame(width: 24, height: 24)
                .background(item.tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

private struct ProfessionalActionButton: View {
    let symbol: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.075), lineWidth: 1)
        )
    }
}

private struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.09), lineWidth: 10)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(MKColor.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }
}

struct StateChipData: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let label: String
    let tint: Color
}

private struct FlowingChipRow: View {
    let chips: [StateChipData]

    var body: some View {
        WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(chips) { chip in
                HStack(spacing: 6) {
                    Image(systemName: chip.symbol)
                        .font(.caption2.weight(.bold))
                    Text(chip.label)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(chip.tint)
                .background(chip.tint.opacity(0.16), in: Capsule())
            }
        }
    }
}

private struct WrappingHStack: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(in: maxWidth, subviews: subviews)
        let height = rows.reduce(0) { partial, row in partial + row.height } +
            CGFloat(max(rows.count - 1, 0)) * verticalSpacing
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(in: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct RowInfo {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(in totalWidth: CGFloat, subviews: Subviews) -> [RowInfo] {
        var rows: [RowInfo] = [RowInfo()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            var current = rows[rows.count - 1]
            let projected = current.width + (current.indices.isEmpty ? 0 : horizontalSpacing) + size.width
            if projected > totalWidth && !current.indices.isEmpty {
                rows.append(RowInfo())
                current = rows[rows.count - 1]
            }
            current.indices.append(index)
            current.width += (current.indices.count == 1 ? 0 : horizontalSpacing) + size.width
            current.height = max(current.height, size.height)
            rows[rows.count - 1] = current
        }
        return rows
    }
}

private struct CalorieProgressBar: View {
    let progress: Double
    let isOver: Bool
    var tint: Color? = nil

    var body: some View {
        MKCapsuleProgressBar(
            progress: progress,
            tint: tint ?? MKColor.green,
            isOver: isOver,
            height: 8
        )
    }
}

private extension View {
    func mkProfessionalPanel(cornerRadius: CGFloat = 24) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return self
            .background(
                ZStack {
                    shape
                        .fill(.ultraThinMaterial)
                    shape
                        .fill(MKColor.elevatedSurface.opacity(0.58))
                }
            )
            .overlay(
                shape
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 5)
    }
}

private struct MacroTile: View {
    let title: String
    let eaten: Int
    let target: Int
    let tint: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(max(Double(eaten) / Double(target), 0), 1.2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(eaten)g")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            MKCapsuleProgressBar(progress: progress, tint: tint, height: 6)
            Text("/ \(target)g")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
