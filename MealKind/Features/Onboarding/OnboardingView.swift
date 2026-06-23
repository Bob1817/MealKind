import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var storedSettings: [StoredUserSettings]
    @Query(sort: \StoredHabit.createdAt) private var storedHabits: [StoredHabit]
    @Query(sort: \StoredDailyTask.createdAt) private var storedTasks: [StoredDailyTask]
    @Environment(AppState.self) private var appState

    @State private var step: BodyProfileStep = .body
    @State private var height = 170.0
    @State private var weight = 68.0
    @State private var age = 32
    @State private var sex: BiologicalSex = .female
    @State private var workEnvironment: WorkEnvironment = .office
    @State private var activityLevel: ActivityLevel = .light
    @State private var trainingExperience: TrainingExperience = .none
    @State private var failureScene = FailureScene.lateSnack
    @State private var dietScene = DietScene.takeaway

    private var isChinese: Bool { appState.language == .simplifiedChinese }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                hero
                stepRail

                Group {
                    switch step {
                    case .body:
                        bodyProfileStep
                    case .lifestyle:
                        lifestyleStep
                    case .aiProfile:
                        aiProfileStep
                    case .firstWeek:
                        firstWeekStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                primaryAction
            }
            .padding(.horizontal, MKTheme.pageMargin)
            .padding(.top, 28)
            .padding(.bottom, 34)
        }
        .background(MKThemeBackground())
        .safeAreaInset(edge: .top, spacing: 0) {
            MKTopNavigationBar(
                title: isChinese ? "AI 身体档案" : "AI Body Profile",
                subtitle: step.shortStatus(language: appState.language)
            ) {
                languageMenu
            }
            .padding(.horizontal, MKTheme.pageMargin)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .mkBarGlass(edges: .top)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text(isChinese ? "AI Body Profile Creation Flow" : "AI Body Profile Creation Flow")
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(MKTheme.primary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(MKTheme.primary.opacity(0.10), in: Capsule())

            Text(isChinese ? "我会先认识你，再给出第一周的小计划。" : "I will get to know you, then create your first gentle week.")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(MKTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(isChinese ? "不用填写复杂资料。只提供几个身体线索和生活场景，AI 会自动生成基础画像与最多 3 个微习惯。" : "No long questionnaire. Share a few body cues and daily scenes, then AI creates a simple profile and up to three tiny habits.")
                .font(.caption2.weight(.medium))
                .foregroundStyle(MKTheme.secondaryText)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stepRail: some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
                ForEach(BodyProfileStep.allCases) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? MKTheme.primary : MKTheme.track)
                        .frame(height: 5)
                        .animation(.smooth(duration: 0.28), value: step)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: step.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MKTheme.primary)
                    .frame(width: 30, height: 30)
                    .background(MKTheme.primary.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title(language: appState.language))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                    Text(step.subtitle(language: appState.language))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MKTheme.secondaryText)
                }

                Spacer(minLength: 0)

                Text("\(step.rawValue + 1)/\(BodyProfileStep.allCases.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
                    .monospacedDigit()
            }
        }
        .padding(13)
        .mkThemeCard(cornerRadius: 20)
    }

    private var bodyProfileStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            MKThemeSectionTitle(
                title: isChinese ? "身体档案" : "Body profile",
                subtitle: isChinese ? "AI 只需要几个基础线索，不需要你解释自己。" : "AI only needs a few basic signals."
            )

            HStack(spacing: 12) {
                ForEach(BiologicalSex.allCases, id: \.self) { item in
                    SexChoiceButton(
                        title: item.localizedName(language: appState.language),
                        symbol: item == .female ? "figure.stand.dress" : "figure.stand",
                        isSelected: sex == item
                    ) {
                        sex = item
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                BodyMetricDial(
                    title: isChinese ? "年龄" : "Age",
                    value: "\(age)",
                    unit: isChinese ? "岁" : "y",
                    symbol: "calendar",
                    decrement: { age = max(16, age - 1) },
                    increment: { age = min(75, age + 1) }
                )

                BodyMetricDial(
                    title: isChinese ? "身高" : "Height",
                    value: "\(Int(height))",
                    unit: "cm",
                    symbol: "ruler",
                    decrement: { height = max(140, height - 1) },
                    increment: { height = min(210, height + 1) }
                )

                BodyMetricDial(
                    title: isChinese ? "体重" : "Weight",
                    value: String(format: "%.1f", weight),
                    unit: "kg",
                    symbol: "scalemass",
                    decrement: { weight = max(40, weight - 0.5) },
                    increment: { weight = min(160, weight + 0.5) }
                )

                AISensingTile(
                    title: isChinese ? "正在理解" : "Learning",
                    value: bodyTone,
                    symbol: "waveform.path.ecg",
                    tint: MKColor.sky
                )
            }
        }
        .padding(16)
        .mkThemeCard(cornerRadius: 22)
    }

    private var lifestyleStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            MKThemeSectionTitle(
                title: isChinese ? "生活方式" : "Lifestyle",
                subtitle: isChinese ? "选择最像你的日常场景。越贴近日常，计划越容易坚持。" : "Choose the scenes that feel most like your day."
            )

            SceneChoiceGroup(
                title: isChinese ? "常见饮食场景" : "Common meal scene",
                symbol: "fork.knife",
                options: DietScene.allCases,
                selection: $dietScene,
                titleProvider: sceneTitle
            )

            SceneChoiceGroup(
                title: isChinese ? "最容易失控的时刻" : "Most fragile moment",
                symbol: "moon.zzz",
                options: FailureScene.allCases,
                selection: $failureScene,
                titleProvider: failureTitle
            )

            SceneChoiceGroup(
                title: isChinese ? "日常活动场景" : "Daily movement scene",
                symbol: "figure.walk",
                options: WorkEnvironment.onboardingCases,
                selection: $workEnvironment,
                titleProvider: { $0.localizedName(language: appState.language) }
            )
            .onChange(of: workEnvironment) { _, newValue in
                activityLevel = inferredActivityLevel(for: newValue)
            }
        }
        .padding(MKTheme.cardPadding)
        .mkThemeCard()
    }

    private var aiProfileStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            MKThemeSectionTitle(
                title: isChinese ? "AI 身体画像" : "AI body portrait",
                subtitle: isChinese ? "基础身体信息已生成。这里展示结论，不展示复杂计算。" : "Your base profile is ready. No complex math shown."
            )

            VStack(spacing: 12) {
                GeneratedProfileRow(
                    symbol: "person.crop.circle.badge.checkmark",
                    title: isChinese ? "身体基础" : "Body baseline",
                    value: "\(sex.localizedName(language: appState.language)) · \(age)\(isChinese ? "岁" : "y") · \(Int(height))cm · \(String(format: "%.1f", weight))kg",
                    tint: MKTheme.primary
                )

                GeneratedProfileRow(
                    symbol: "flame",
                    title: isChinese ? "日常消耗" : "Daily burn",
                    value: isChinese ? "\(activityLevelPlainName) · 已估算基础消耗" : "\(activityLevelPlainName) · baseline estimated",
                    tint: MKColor.citrus
                )

                GeneratedProfileRow(
                    symbol: "arrow.triangle.2.circlepath",
                    title: isChinese ? "热量差方向" : "Calorie-gap direction",
                    value: isChinese ? "饮食摄入与活动消耗保持温和差值" : "A gentle gap between intake and movement",
                    tint: MKColor.sky
                )
            }

            AIInsightBand(
                text: isChinese ? "第一周会优先稳定饮食记录、合理饮水、充足睡眠和适量活动。目标不是突然变严格，而是让身体慢慢进入节奏。" : "Week one focuses on steady meals, reasonable water, enough sleep, and light movement. The goal is rhythm, not pressure."
            )
        }
        .padding(MKTheme.cardPadding)
        .mkThemeCard()
    }

    private var firstWeekStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            MKThemeSectionTitle(
                title: isChinese ? "AI 第一周计划" : "AI first-week plan",
                subtitle: isChinese ? "最多 3 个微习惯。小到不会打断生活，才更容易开始。" : "Up to three tiny habits, small enough to fit real life."
            )

            ForEach(Array(firstWeekHabits.enumerated()), id: \.element.id) { index, habit in
                MicroHabitCard(index: index + 1, habit: habit)
            }

            AIInsightBand(
                text: isChinese ? "计划会围绕健康饮食、合理饮水、充足睡眠与适量活动，帮助摄入和消耗形成合理热量差。" : "The plan balances healthy eating, water, sleep, and movement so intake and burn can form a reasonable calorie gap."
            )
        }
        .padding(MKTheme.cardPadding)
        .mkThemeCard()
    }

    private var primaryAction: some View {
        HStack(spacing: 12) {
            if step != .body {
                Button {
                    withAnimation(.smooth(duration: 0.28)) {
                        step = step.previous
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MKTheme.primary)
                        .frame(width: 52, height: 52)
                        .background(MKTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityLabel(isChinese ? "上一步" : "Back")
            }

            Button {
                if step == .firstWeek {
                    finishSetup()
                } else {
                    withAnimation(.smooth(duration: 0.28)) {
                        step = step.next
                    }
                }
            } label: {
                MKThemePrimaryButtonLabel(
                    symbol: step == .firstWeek ? "sparkles" : "arrow.right",
                    title: primaryTitle
                )
            }
        }
    }

    private var languageMenu: some View {
        Picker("Language", selection: Binding(
            get: { appState.language },
            set: { appState.setLanguage($0, settings: currentSettings) }
        )) {
            ForEach(AppLanguage.allCases) { language in
                Text(language.displayName).tag(language)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .mkGlassSurface(cornerRadius: 22, tint: .white.opacity(0.18), isInteractive: true)
    }

    private var primaryTitle: String {
        switch step {
        case .body:
            return isChinese ? "继续认识我" : "Keep learning me"
        case .lifestyle:
            return isChinese ? "生成身体画像" : "Create body portrait"
        case .aiProfile:
            return isChinese ? "生成第一周计划" : "Create first week"
        case .firstWeek:
            return isChinese ? "开始第一周" : "Start week one"
        }
    }

    private var bodyTone: String {
        if isChinese {
            if age < 26 { return "年轻节奏" }
            if age < 45 { return "稳定节奏" }
            return "温和节奏"
        }
        if age < 26 { return "young rhythm" }
        if age < 45 { return "steady rhythm" }
        return "gentle rhythm"
    }

    private var activityLevelPlainName: String {
        switch (activityLevel, appState.language) {
        case (.low, .simplifiedChinese): return "低活动"
        case (.light, .simplifiedChinese): return "轻活动"
        case (.moderate, .simplifiedChinese): return "中等活动"
        case (.active, .simplifiedChinese): return "较高活动"
        case (.low, _): return "Low movement"
        case (.light, _): return "Light movement"
        case (.moderate, _): return "Moderate movement"
        case (.active, _): return "Active movement"
        }
    }

    private var inferredTargetWeight: Double {
        max(40, weight * 0.94)
    }

    private var computedProfile: UserEnergyProfile {
        let bmr = EnergyCalculator.basalMetabolicRate(
            sex: sex,
            weightKilograms: weight,
            heightCentimeters: height,
            age: age
        )
        let activity = EnergyCalculator.activityCalories(
            basalMetabolicRate: bmr,
            workEnvironment: workEnvironment,
            hasExerciseHabit: false,
            weeklyWorkoutCount: 0
        )
        return UserEnergyProfile(
            basalMetabolicRate: bmr,
            activityCalories: activity,
            exerciseCalories: 0,
            heightCentimeters: height,
            age: age,
            biologicalSex: sex,
            targetWeightKilograms: inferredTargetWeight,
            workEnvironment: workEnvironment,
            hasExerciseHabit: false,
            weeklyWorkoutCount: 0,
            fatLossWeeks: 12,
            activityLevel: activityLevel,
            trainingExperience: trainingExperience
        )
    }

    private var firstWeekHabits: [Habit] {
        Array(Habit.defaults(language: appState.language).prefix(3))
    }

    private var currentSettings: StoredUserSettings {
        LocalRecordRepository.settings(from: storedSettings, modelContext: modelContext)
    }

    private func finishSetup() {
        let settings = currentSettings
        appState.applyOnboardingProfile(
            profile: computedProfile,
            weightKilograms: weight,
            plan: .lifestyleCut,
            mode: .lifestyle,
            intent: .fatLoss,
            settings: settings
        )

        let reset = LocalRecordRepository.resetHabitSystem(
            language: appState.language,
            storedHabits: storedHabits,
            storedTasks: storedTasks,
            modelContext: modelContext
        )
        appState.habits = reset.habits
        appState.dailyTasks = reset.tasks
    }

    private func inferredActivityLevel(for environment: WorkEnvironment) -> ActivityLevel {
        switch environment {
        case .office, .driver:
            return .light
        case .retail, .kitchen:
            return .moderate
        case .construction, .fieldWork:
            return .active
        }
    }

    private func sceneTitle(_ scene: DietScene) -> String {
        switch (scene, appState.language) {
        case (.home, .simplifiedChinese): return "在家吃"
        case (.takeaway, .simplifiedChinese): return "外卖"
        case (.diningOut, .simplifiedChinese): return "聚餐/餐厅"
        case (.office, .simplifiedChinese): return "办公室"
        case (.home, _): return "Home meals"
        case (.takeaway, _): return "Takeout"
        case (.diningOut, _): return "Dining out"
        case (.office, _): return "Office meals"
        }
    }

    private func failureTitle(_ scene: FailureScene) -> String {
        switch (scene, appState.language) {
        case (.lateSnack, .simplifiedChinese): return "晚上想吃零食"
        case (.socialDinner, .simplifiedChinese): return "聚餐容易吃多"
        case (.stressEating, .simplifiedChinese): return "压力大就想吃"
        case (.skippedMeals, .simplifiedChinese): return "白天不吃，晚上补偿"
        case (.lateSnack, _): return "Late snacks"
        case (.socialDinner, _): return "Social dinners"
        case (.stressEating, _): return "Stress eating"
        case (.skippedMeals, _): return "Skipping meals, then overeating"
        }
    }
}

private enum BodyProfileStep: Int, CaseIterable, Identifiable {
    case body
    case lifestyle
    case aiProfile
    case firstWeek

    var id: Int { rawValue }

    var symbol: String {
        switch self {
        case .body: return "person.text.rectangle"
        case .lifestyle: return "sparkle.magnifyingglass"
        case .aiProfile: return "brain.head.profile"
        case .firstWeek: return "checklist"
        }
    }

    var next: BodyProfileStep {
        BodyProfileStep(rawValue: min(rawValue + 1, BodyProfileStep.allCases.count - 1)) ?? .firstWeek
    }

    var previous: BodyProfileStep {
        BodyProfileStep(rawValue: max(rawValue - 1, 0)) ?? .body
    }

    func title(language: AppLanguage) -> String {
        switch (self, language) {
        case (.body, .simplifiedChinese): return "Step 1 · 身体档案"
        case (.lifestyle, .simplifiedChinese): return "Step 2 · 生活方式"
        case (.aiProfile, .simplifiedChinese): return "Step 3 · AI 身体画像"
        case (.firstWeek, .simplifiedChinese): return "Step 4 · AI 第一周计划"
        case (.body, _): return "Step 1 · Body profile"
        case (.lifestyle, _): return "Step 2 · Lifestyle"
        case (.aiProfile, _): return "Step 3 · AI body portrait"
        case (.firstWeek, _): return "Step 4 · AI first-week plan"
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch (self, language) {
        case (.body, .simplifiedChinese): return "几个身体线索就够了"
        case (.lifestyle, .simplifiedChinese): return "选择常见场景"
        case (.aiProfile, .simplifiedChinese): return "自动生成基础身体信息"
        case (.firstWeek, .simplifiedChinese): return "自动生成最多 3 个微习惯"
        case (.body, _): return "A few body cues are enough"
        case (.lifestyle, _): return "Pick common scenes"
        case (.aiProfile, _): return "Base body info generated"
        case (.firstWeek, _): return "Up to three tiny habits"
        }
    }

    func shortStatus(language: AppLanguage) -> String {
        switch (self, language) {
        case (.body, .simplifiedChinese): return "正在认识你的身体基础"
        case (.lifestyle, .simplifiedChinese): return "正在理解你的日常"
        case (.aiProfile, .simplifiedChinese): return "身体画像已生成"
        case (.firstWeek, .simplifiedChinese): return "第一周计划已生成"
        case (.body, _): return "Learning your baseline"
        case (.lifestyle, _): return "Understanding your day"
        case (.aiProfile, _): return "Body portrait generated"
        case (.firstWeek, _): return "First week generated"
        }
    }
}

private struct BodyMetricDial: View {
    let title: String
    let value: String
    let unit: String
    let symbol: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(MKTheme.ink)
                    .monospacedDigit()
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                Text(unit)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
            }

            HStack(spacing: 8) {
                DialButton(symbol: "minus", action: decrement)
                DialButton(symbol: "plus", action: increment)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .mkThemeInsetTile(cornerRadius: 18)
    }
}

private struct SexChoiceButton: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : MKTheme.primary)
                    .frame(width: 34, height: 34)
                    .background(isSelected ? Color.white.opacity(0.18) : MKTheme.primary.opacity(0.10), in: Circle())

                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isSelected ? .white : MKTheme.ink)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(isSelected ? MKTheme.primary : MKTheme.fill, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct DialButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.primary)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct AISensingTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: Circle())

            Spacer(minLength: 0)

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(MKTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .mkThemeInsetTile(cornerRadius: 18)
    }
}

private struct SceneChoiceGroup<Option: Hashable & Identifiable>: View {
    let title: String
    let symbol: String
    let options: [Option]
    @Binding var selection: Option
    let titleProvider: (Option) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKTheme.ink)

            FlowLayout(spacing: 8) {
                ForEach(options) { option in
                    Button {
                        selection = option
                    } label: {
                        Text(titleProvider(option))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selection == option ? .white : MKTheme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(minHeight: 44)
                            .background(selection == option ? MKTheme.primary : MKTheme.fill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct GeneratedProfileRow: View {
    let symbol: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .mkThemeInsetTile(cornerRadius: 18)
    }
}

private struct AIInsightBand: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(MKTheme.primary)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MKTheme.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(MKTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MicroHabitCard: View {
    let index: Int
    let habit: Habit

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(MKTheme.primary, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(habit.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                Text(habit.tinyBehavior)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MKTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(MKTheme.primary)
        }
        .padding(14)
        .mkThemeInsetTile(cornerRadius: 18)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let height = rows.reduce(CGFloat.zero) { partial, row in
            partial + row.height
        } + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [FlowRow] {
        var rows: [FlowRow] = []
        var currentItems: [FlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            let proposedWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if proposedWidth > maxWidth, !currentItems.isEmpty {
                rows.append(FlowRow(items: currentItems, height: currentHeight))
                currentItems = [FlowItem(subview: subview, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(FlowItem(subview: subview, size: size))
                currentWidth = proposedWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(FlowRow(items: currentItems, height: currentHeight))
        }

        return rows
    }

    private struct FlowItem {
        let subview: LayoutSubview
        let size: CGSize
    }

    private struct FlowRow {
        let items: [FlowItem]
        let height: CGFloat
    }
}

private extension WorkEnvironment {
    static var onboardingCases: [WorkEnvironment] {
        [.office, .driver, .retail, .kitchen, .fieldWork]
    }
}
