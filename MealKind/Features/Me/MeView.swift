import SwiftUI
import SwiftData

struct MeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var storedSettings: [StoredUserSettings]
    @Query(sort: \StoredHabit.createdAt) private var storedHabits: [StoredHabit]
    @Query(sort: \StoredDailyTask.createdAt) private var storedTasks: [StoredDailyTask]
    @Query(sort: \StoredMealRecord.createdAt) private var storedMeals: [StoredMealRecord]
    @Query(sort: \StoredWorkoutRecord.createdAt) private var storedWorkouts: [StoredWorkoutRecord]
    @Query(sort: \StoredSleepRecord.createdAt) private var storedSleep: [StoredSleepRecord]
    @Query(sort: \StoredSupplementRecord.takenAt) private var storedSupplements: [StoredSupplementRecord]
    @Query(sort: \StoredMeasurementRecord.takenAt) private var storedMeasurements: [StoredMeasurementRecord]
    @Query(sort: \StoredDailyStrategy.generatedAt) private var storedStrategies: [StoredDailyStrategy]
    @Query(sort: \StoredWeeklyReview.generatedAt) private var storedReviews: [StoredWeeklyReview]
    @Environment(AppState.self) private var appState
    @Binding var selectedTab: AppTab
    @State private var activeSheet: MeSheet?
    @State private var pendingMode: AppExperienceMode?
    @State private var showsDeleteConfirmation = false
    @State private var showsSignOutConfirmation = false
    private var l10n: L10n { L10n(language: appState.language) }
    private var isChinese: Bool { appState.language == .simplifiedChinese }
    private var accountEmail: String? { UserDefaults.standard.string(forKey: "mealkind.account.email") }
    private var hasAccountSession: Bool {
        appState.accountMode == .signedIn
            || UserDefaults.standard.string(forKey: "mealkind.persistence.token")?.isEmpty == false
            || accountEmail?.isEmpty == false
    }
    private var accountStatusText: String {
        if let accountEmail, accountEmail.isEmpty == false { return accountEmail }
        return hasAccountSession ? (isChinese ? "已登录" : "Signed in") : appState.accountMode.localizedName(language: appState.language)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MKTheme.cardSpacing) {
                lifestyleSections
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(MKBackdrop())
        .sheet(item: $activeSheet) { sheet in
            sheetView(for: sheet)
                .presentationDetents(sheet.detents)
                .presentationDragIndicator(.visible)
        }
        .alert(
            appState.language == .simplifiedChinese ? "切换版本模式" : "Switch mode",
            isPresented: Binding(
                get: { pendingMode != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingMode = nil
                    }
                }
            ),
            presenting: pendingMode
        ) { mode in
            Button(appState.language == .simplifiedChinese ? "取消" : "Cancel", role: .cancel) {
                pendingMode = nil
            }
            Button(appState.language == .simplifiedChinese ? "确认切换" : "Switch") {
                applyMode(mode)
            }
        } message: { mode in
            Text(modeSwitchMessage(for: mode))
        }
        .confirmationDialog(
            appState.language == .simplifiedChinese ? "删除本机数据？" : "Delete local data?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(appState.language == .simplifiedChinese ? "删除本机记录并重新开始" : "Delete local records and start over", role: .destructive) {
                deleteLocalData()
            }
            Button(appState.language == .simplifiedChinese ? "取消" : "Cancel", role: .cancel) { }
        } message: {
            Text(appState.language == .simplifiedChinese ? "这会清除本机记录和设置，然后回到建档流程。" : "This clears local records and settings, then returns to setup.")
        }
        .confirmationDialog(
            appState.language == .simplifiedChinese ? "退出登录？" : "Sign out?",
            isPresented: $showsSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button(appState.language == .simplifiedChinese ? "退出登录" : "Sign out", role: .destructive) {
                signOut()
            }
            Button(appState.language == .simplifiedChinese ? "取消" : "Cancel", role: .cancel) { }
        } message: {
            Text(appState.language == .simplifiedChinese ? "这只会退出当前账号，本机记录会继续保留。" : "This only signs out of the current account. Local records stay on this device.")
        }
        .mkGlassNavigation(
            title: l10n.t(.me),
            subtitle: isChinese ? "资料、模式、隐私与设置。" : "Profile, mode, privacy, and settings."
        )
    }

    @ViewBuilder
    private func sheetView(for sheet: MeSheet) -> some View {
        switch sheet {
        case .profile:
            ProfileEditorSheet(
                initialProfile: appState.profile,
                initialWeight: appState.weightKilograms,
                initialIntent: appState.fitnessIntent,
                initialMode: appState.experienceMode,
                language: appState.language
            ) { profile, weight, intent, mode in
                appState.profile = profile
                appState.fitnessIntent = intent
                appState.experienceMode = mode
                appState.persist(to: currentSettings)
                // 体重单独走 saveWeight：更新当前值并记录带时间戳的历史。
                appState.saveWeight(weight, modelContext: modelContext)
                activeSheet = nil
            }
        case .plan:
            PlanEditorSheet(
                selectedPlan: appState.selectedPlan,
                profile: appState.profile,
                currentWeight: appState.weightKilograms,
                intent: appState.fitnessIntent,
                mode: appState.experienceMode,
                language: appState.language
            ) { plan, intent, mode in
                appState.selectedPlan = plan
                appState.fitnessIntent = intent
                appState.experienceMode = mode
                appState.persist(to: currentSettings)
                activeSheet = nil
            }
        case .preferences:
            InformationalSheet(
                symbol: "fork.knife.circle.fill",
                title: appState.language == .simplifiedChinese ? "饮食偏好" : "Diet preferences",
                message: appState.language == .simplifiedChinese
                    ? "V1 会优先使用低压力默认偏好：少喝含糖饮料、外卖先拍照、晚餐主食少一点。后续会开放更细的食物偏好。"
                    : "V1 uses low-pressure defaults: fewer sugary drinks, snap takeout first, and leave a little dinner starch. More detailed preferences can come later."
            )
        case .reminders:
            ReminderSettingsSheet(language: appState.language)
        case .subscription:
            SubscriptionSheet(
                language: appState.language,
                tier: appState.subscriptionTier
            ) { tier in
                appState.subscriptionTier = tier
                appState.persist(to: currentSettings)
            }
        case .coach:
            AnalysisView()
        case .export:
            DataExportSheet(
                language: appState.language,
                exportText: exportSnapshot.jsonString()
            )
        case .account:
            AccountSheet(
                language: appState.language,
                accountMode: appState.accountMode,
                email: UserDefaults.standard.string(forKey: "mealkind.account.email")
            ) { _ in
                appState.accountMode = .signedIn
                appState.persist(to: currentSettings)
            } onSignOut: {
                signOut()
                activeSheet = nil
            }
        case .health:
            InformationalSheet(
                symbol: "heart.text.square.fill",
                title: appState.language == .simplifiedChinese ? "健康权限" : "Health permissions",
                message: appState.language == .simplifiedChinese
                    ? "当前版本暂未连接 Apple 健康。你记录的餐食、体重、习惯和任务只保存在本机，用于生成温和复盘。"
                    : "Apple Health is not connected in this version. Meals, weight, habits, and tasks stay local and are used for gentle reviews."
            )
        case .privacy:
            InformationalSheet(
                symbol: "lock.shield.fill",
                title: appState.language == .simplifiedChinese ? "隐私和 AI 记忆" : "Privacy and AI memory",
                message: appState.language == .simplifiedChinese
                    ? "MealKind 会把个人资料、习惯和记录保存在本机。食物图片仅在你主动分析时用于生成建议；你可以随时重新建档或删除本机数据。"
                    : "MealKind keeps your profile, habits, and logs on this device. Food photos are used only when you analyze a meal; you can retake setup or delete local data anytime."
            )
        case .terms:
            InformationalSheet(
                symbol: "doc.text.fill",
                title: appState.language == .simplifiedChinese ? "条款和免责声明" : "Terms and disclaimer",
                message: appState.language == .simplifiedChinese
                    ? "MealKind 只提供饮食习惯建议和基础估算，不构成医疗建议。若你有疾病、孕期、进食障碍史或特殊饮食需求，请先咨询专业人士。"
                    : "MealKind provides habit guidance and basic estimates only. It is not medical advice. Consult a qualified professional for illness, pregnancy, eating disorder history, or special dietary needs."
            )
        case .watch:
            InformationalSheet(
                symbol: "applewatch",
                title: "Apple Watch",
                message: appState.language == .simplifiedChinese
                    ? "当前版本暂未连接 Apple Watch。后续可用于同步活动、站立和基础健康信号。"
                    : "Apple Watch is not connected in this version. A future version can sync activity, standing, and basic health signals."
            )
        case .wechat:
            InformationalSheet(
                symbol: "figure.walk.circle.fill",
                title: appState.language == .simplifiedChinese ? "微信运动" : "WeChat Steps",
                message: appState.language == .simplifiedChinese
                    ? "当前版本暂未连接微信运动。连接后可作为活动参考，不会改变生活版的低压力体验。"
                    : "WeChat Steps is not connected in this version. Once connected, it can provide light activity context without changing the low-pressure experience."
            )
        case .aiAdvisor:
            InformationalSheet(
                symbol: "sparkles",
                title: appState.language == .simplifiedChinese ? "AI 顾问" : "AI Advisor",
                message: appState.language == .simplifiedChinese
                    ? "AI 顾问会基于你的资料和记录提供温和建议。你可以随时关闭个性化建议。"
                    : "The AI Advisor uses your profile and logs for gentle suggestions. Personalized guidance can be turned off anytime."
            )
        case .aiStyle:
            InformationalSheet(
                symbol: "text.bubble.fill",
                title: appState.language == .simplifiedChinese ? "AI 风格" : "AI Style",
                message: appState.language == .simplifiedChinese
                    ? "默认使用鼓励式表达。后续可切换为简洁式或陪伴式。"
                    : "The default style is encouraging. Concise and companion styles can be added later."
            )
        case .aiMemory:
            InformationalSheet(
                symbol: "brain.head.profile",
                title: appState.language == .simplifiedChinese ? "AI 记忆管理" : "AI Memory",
                message: appState.language == .simplifiedChinese
                    ? "你可以查看、清除或关闭个性化记忆。当前本机数据只用于生成温和建议。"
                    : "You can review, clear, or turn off personalized memory. Current local data is used only for gentle suggestions."
            )
        case .help:
            InformationalSheet(
                symbol: "questionmark.circle.fill",
                title: appState.language == .simplifiedChinese ? "帮助中心" : "Help Center",
                message: appState.language == .simplifiedChinese
                    ? "帮助中心会提供拍照记录、模式选择、隐私和账号相关说明。"
                    : "The help center will cover capture, mode selection, privacy, and account questions."
            )
        case .feedback:
            InformationalSheet(
                symbol: "bubble.left.and.bubble.right.fill",
                title: appState.language == .simplifiedChinese ? "意见反馈" : "Feedback",
                message: appState.language == .simplifiedChinese
                    ? "感谢你帮助轻减AI变得更好。后续版本会开放反馈入口。"
                    : "Thanks for helping QingJian AI improve. A feedback channel can be added in a future version."
            )
        }
    }

    private var profileCard: some View {
        Button {
            activeSheet = .profile
        } label: {
            HStack(spacing: 14) {
                MKIconBadge(symbol: "person.crop.circle.fill", tint: MKColor.green, fill: MKColor.subtleGreen.opacity(0.56), size: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.language == .simplifiedChinese ? "个人资料" : "Profile")
                        .font(.title3.bold())
                    Text("\(String(format: "%.1f", appState.weightKilograms)) kg → \(String(format: "%.1f", appState.profile.targetWeightKilograms)) kg · \(appState.experienceMode.localizedName(language: appState.language))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(16)
        .mkGlassSurface(cornerRadius: 24, tint: .white.opacity(0.18), isInteractive: true)
    }

    // Profile & Settings：克制的身份 Hero + 三张分组卡，所有设置二级进入。
    @ViewBuilder
    private var lifestyleSections: some View {
        identityHero
        preferencesCard
        dataPrivacyCard
        accountAboutCard
        
        if hasAccountSession {
            signOutSection
        }
    }

    // 外观：跟随系统 / 浅色 / 深色。
    private var appearanceSection: some View {
        SettingsSectionCard(title: isChinese ? "外观" : "Appearance") {
            ForEach(Array(AppAppearance.allCases.enumerated()), id: \.element.id) { index, option in
                SettingsRow(
                    symbol: option.symbol,
                    title: option.localizedName(language: appState.language),
                    value: appState.appearance == option ? (isChinese ? "已选择" : "Selected") : ""
                ) {
                    if appState.appearance != option {
                        appState.appearance = option
                        appState.persist(to: currentSettings)
                        try? modelContext.save()
                    }
                }
                if index < AppAppearance.allCases.count - 1 {
                    Divider().padding(.leading, 44)
                }
            }
        }
    }

    // 克制的身份 Hero：头像 + 名称 + 一行「模式 · 目标」，点按进入资料编辑。
    private var identityHero: some View {
        Button {
            activeSheet = .profile
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 50, weight: .regular))
                    .foregroundStyle(MKColor.green)
                    .frame(width: 68, height: 68)
                    .background(MKColor.subtleGreen.opacity(0.45), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(isChinese ? "轻减AI 用户" : "QingJian User")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                    Text("\(appState.experienceMode.localizedName(language: appState.language)) · \(appState.fitnessIntent.localizedName(language: appState.language))")
                        .font(.subheadline)
                        .foregroundStyle(MKTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .mkGlassSurface(cornerRadius: 26)
    }

    // ① 偏好：目标 / 版本模式（收敛单行）/ 外观（收敛单行）/ 提醒。
    private var preferencesCard: some View {
        SettingsSectionCard(title: isChinese ? "偏好" : "Preferences") {
            SettingsRow(symbol: "target", title: isChinese ? "目标设置" : "Goal", value: appState.fitnessIntent.localizedName(language: appState.language)) {
                activeSheet = .plan
            }
            Divider().padding(.leading, 44)
            modeSettingRow
            Divider().padding(.leading, 44)
            appearanceSettingRow
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "bell", title: isChinese ? "提醒" : "Reminders", value: isChinese ? "温和" : "Gentle") {
                activeSheet = .reminders
            }
        }
    }

    // ② 数据与隐私。
    private var dataPrivacyCard: some View {
        SettingsSectionCard(title: isChinese ? "数据与隐私" : "Data & Privacy") {
            SettingsRow(symbol: "heart.text.square", title: "Apple Health", value: l10n.t(.notConnected)) { activeSheet = .health }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "applewatch", title: "Apple Watch", value: l10n.t(.notConnected)) { activeSheet = .watch }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "figure.walk", title: isChinese ? "微信运动" : "WeChat Steps", value: l10n.t(.notConnected)) { activeSheet = .wechat }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "square.and.arrow.up", title: isChinese ? "导出数据" : "Export data", value: "") { activeSheet = .export }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "brain.head.profile", title: isChinese ? "AI 记忆管理" : "AI Memory", value: "") { activeSheet = .aiMemory }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "lock.shield", title: isChinese ? "隐私政策" : "Privacy policy", value: "") { activeSheet = .privacy }
            Divider().padding(.leading, 44)
            deleteDataRow
        }
    }

    // ③ 账号与关于。
    private var accountAboutCard: some View {
        SettingsSectionCard(title: isChinese ? "账号与关于" : "Account & About") {
            SettingsRow(symbol: "person.crop.circle", title: isChinese ? "账号" : "Account", value: accountStatusText) {
                activeSheet = .account
            }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "sparkles", title: isChinese ? "轻减AI Pro" : "QingJian AI Pro", value: appState.subscriptionTier.localizedName(language: appState.language)) {
                activeSheet = .subscription
            }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "sparkle", title: isChinese ? "AI 顾问" : "AI Advisor", value: isChinese ? "已开启" : "On") { activeSheet = .aiAdvisor }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "text.bubble", title: isChinese ? "AI 风格" : "AI Style", value: isChinese ? "鼓励式" : "Encouraging") { activeSheet = .aiStyle }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "questionmark.circle", title: isChinese ? "帮助中心" : "Help Center", value: "") { activeSheet = .help }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "bubble.left.and.bubble.right", title: isChinese ? "意见反馈" : "Feedback", value: "") { activeSheet = .feedback }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "doc.text", title: isChinese ? "条款与免责声明" : "Terms & disclaimer", value: "") { activeSheet = .terms }
            Divider().padding(.leading, 44)
            languagePickerRow
            Divider().padding(.leading, 44)
            SettingsStaticRow(symbol: "number", title: isChinese ? "版本号" : "Version", value: appVersionText)
        }
    }

    // 版本模式：只展示当前模式，点按弹出选择（切换沿用确认流程）。
    private var modeSettingRow: some View {
        Menu {
            ForEach(AppExperienceMode.allCases) { mode in
                Button {
                    if mode != appState.experienceMode { pendingMode = mode }
                } label: {
                    Label(mode.localizedName(language: appState.language), systemImage: appState.experienceMode == mode ? "checkmark" : mode.symbol)
                }
            }
        } label: {
            settingsMenuRowLabel(
                symbol: "square.grid.2x2",
                title: isChinese ? "版本模式" : "Mode",
                value: appState.experienceMode.localizedName(language: appState.language)
            )
        }
    }

    // 外观：只展示当前项，点按弹出选择。
    private var appearanceSettingRow: some View {
        Menu {
            ForEach(AppAppearance.allCases) { option in
                Button {
                    if appState.appearance != option {
                        appState.appearance = option
                        appState.persist(to: currentSettings)
                        try? modelContext.save()
                    }
                } label: {
                    Label(option.localizedName(language: appState.language), systemImage: appState.appearance == option ? "checkmark" : option.symbol)
                }
            }
        } label: {
            settingsMenuRowLabel(
                symbol: "circle.lefthalf.filled",
                title: isChinese ? "外观" : "Appearance",
                value: appState.appearance.localizedName(language: appState.language)
            )
        }
    }

    private func settingsMenuRowLabel(symbol: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(MKColor.green)
                .frame(width: 28)
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(MKTheme.ink)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(l10n.t(.proTitle), systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MKColor.sky)
                    Text(l10n.t(.proDescription))
                        .font(.subheadline)
                        .lineSpacing(2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)
            }

            Text(appState.subscriptionTier.localizedName(language: appState.language))
                .font(.caption.weight(.semibold))
                .foregroundStyle(MKColor.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(MKColor.subtleGreen.opacity(0.35), in: Capsule())

            Button {
                activeSheet = .subscription
            } label: {
                Text(appState.language == .simplifiedChinese ? "查看 Pro 能力" : "View Pro features")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .foregroundStyle(MKColor.background)
                    .background(MKColor.green, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .mkGlassSurface(cornerRadius: 28, tint: .white.opacity(0.22), isInteractive: true)
    }

    private var modePositioningCard: some View {
        let isProfessional = appState.experienceMode == .professional
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: appState.experienceMode.symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKColor.green)
                    .frame(width: 32, height: 32)
                    .background(MKColor.green.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.experienceMode.localizedName(language: appState.language))
                        .font(.headline)
                    Text(modePositioningText(isProfessional: isProfessional))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            modeToggleRow
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 24, tint: isProfessional ? .white.opacity(0.12) : MKColor.subtleGreen.opacity(0.14), isInteractive: true)
    }

    private func modePositioningText(isProfessional: Bool) -> String {
        if appState.language == .simplifiedChinese {
            return isProfessional
                ? "专业版是一套记录工具。训练、营养、睡眠、饮水和补剂记录越完整，系统调整越准确。"
                : "生活版是微习惯助手。目标是让你每天做一点点调整，而不是学习复杂数据。"
        }
        return isProfessional
            ? "Professional mode is a logging tool. More complete training, nutrition, sleep, water, and supplement data leads to better adjustments."
            : "Lifestyle mode is a tiny-habit assistant. The goal is one small adjustment a day, not learning complex data."
    }

    private var goalSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                activeSheet = .plan
            } label: {
                HStack {
                    Label(appState.language == .simplifiedChinese ? "目标设置" : "Goal settings", systemImage: "target")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MKColor.green)
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Text(appState.language == .simplifiedChinese ? "第一周先稳定记录" : "First week: stabilize tracking")
                .font(.title3.bold())

            HStack(spacing: 8) {
                PlanInfoPill(title: appState.language == .simplifiedChinese ? "当前" : "Current", value: String(format: "%.1fkg", appState.weightKilograms))
                PlanInfoPill(title: appState.language == .simplifiedChinese ? "目标" : "Target", value: String(format: "%.1fkg", appState.profile.targetWeightKilograms))
                PlanInfoPill(title: appState.language == .simplifiedChinese ? "习惯" : "Habits", value: "\(appState.activeHabits.count)")
            }

            Text(appState.language == .simplifiedChinese ? "目标设置保留基础资料能力，便于后续调整模式和方案。" : "Goal settings keep the basic profile layer available for future mode and plan changes.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .mkGlassSurface(cornerRadius: 24, tint: .white.opacity(0.08), isInteractive: true)
    }

    private var modeToggleRow: some View {
        Menu {
            ForEach(AppExperienceMode.allCases) { mode in
                Button {
                    guard mode != appState.experienceMode else { return }
                    pendingMode = mode
                } label: {
                    Label(
                        mode.localizedName(language: appState.language),
                        systemImage: appState.experienceMode == mode ? "checkmark.circle.fill" : mode.symbol
                    )
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: appState.experienceMode.symbol)
                    .foregroundStyle(MKColor.green)
                    .frame(width: 28)
                Text(appState.language == .simplifiedChinese ? "版本模式" : "Experience mode")
                    .font(.body.weight(.semibold))
                Spacer()
                Text(appState.experienceMode.localizedName(language: appState.language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private func modeSwitchMessage(for mode: AppExperienceMode) -> String {
        let targetName = mode.localizedName(language: appState.language)
        if appState.language == .simplifiedChinese {
            return "确认切换到\(targetName)？\(mode.localizedSubtitle(language: appState.language))。切换后首页、记录和建议会按当前版本重新呈现。"
        }
        return "Switch to \(targetName)? \(mode.localizedSubtitle(language: appState.language)). Today, Record, and guidance will adapt to this mode."
    }

    private func applyMode(_ mode: AppExperienceMode) {
        appState.experienceMode = mode
        appState.fitnessIntent = mode == .professional ? .fitness : .fatLoss
        appState.persist(to: currentSettings)
        pendingMode = nil
        selectedTab = .today
    }

    private var settingsList: some View {
        VStack(spacing: 0) {
            SettingsRow(symbol: "person.crop.circle", title: appState.language == .simplifiedChinese ? "账号" : "Account", value: appState.accountMode.localizedName(language: appState.language)) {
                activeSheet = .account
            }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "sparkles", title: appState.language == .simplifiedChinese ? "AI 教练" : "AI Coach", value: appState.language == .simplifiedChinese ? "温和支持" : "Gentle") {
                activeSheet = .coach
            }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "fork.knife", title: appState.language == .simplifiedChinese ? "饮食偏好" : "Diet preferences", value: "") {
                activeSheet = .preferences
            }
            Divider().padding(.leading, 44)
            languagePickerRow
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "bell", title: appState.language == .simplifiedChinese ? "提醒设置" : "Reminder settings", value: appState.language == .simplifiedChinese ? "温和" : "Gentle") {
                activeSheet = .reminders
            }
            Divider().padding(.leading, 44)
            resetAssessmentRow
            Divider().padding(.leading, 44)
            resetHabitRow
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "heart.text.square", title: l10n.t(.healthPermissions), value: l10n.t(.notConnected)) {
                activeSheet = .health
            }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "lock.shield", title: l10n.t(.privacyAIMemory), value: "") {
                activeSheet = .privacy
            }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "doc.text", title: l10n.t(.termsDisclaimer), value: "") {
                activeSheet = .terms
            }
            Divider().padding(.leading, 44)
            SettingsRow(symbol: "square.and.arrow.up", title: appState.language == .simplifiedChinese ? "数据导出" : "Data export", value: "") {
                activeSheet = .export
            }
            Divider().padding(.leading, 44)
            if hasAccountSession {
                signOutRow
                Divider().padding(.leading, 44)
            }
            deleteDataRow
        }
        .padding(14)
        .mkGlassSurface(cornerRadius: 24, tint: .white.opacity(0.14))
    }

    private var languagePickerRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .foregroundStyle(MKColor.green)
                .frame(width: 28)
            Text(l10n.t(.languageAndRegion))
                .font(.body.weight(.semibold))
            Spacer()
            Picker(l10n.t(.languageAndRegion), selection: Binding(
                get: { appState.language },
                set: { newLanguage in
                    appState.setLanguage(newLanguage, settings: currentSettings)
                }
            )) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        .padding(.vertical, 13)
    }

    private var resetAssessmentRow: some View {
        Button {
            appState.hasCompletedOnboarding = false
            appState.persist(to: currentSettings)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .foregroundStyle(MKColor.green)
                    .frame(width: 28)
                Text(appState.language == .simplifiedChinese ? "重新测试目标和方案" : "Retake goal assessment")
                    .font(.body.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private var resetHabitRow: some View {
        Button {
            resetHabitSystem()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(MKColor.green)
                    .frame(width: 28)
                Text(appState.language == .simplifiedChinese ? "重置第一周习惯" : "Reset first-week habits")
                    .font(.body.weight(.semibold))
                Spacer()
                Text(appState.language == .simplifiedChinese ? "3 个" : "3")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private var deleteDataRow: some View {
        Button(role: .destructive) {
            showsDeleteConfirmation = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "trash")
                    .foregroundStyle(.orange)
                    .frame(width: 28)
                Text(appState.language == .simplifiedChinese ? "删除本机数据" : "Delete local data")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private var signOutRow: some View {
        Button(role: .destructive) {
            showsSignOutConfirmation = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.red)
                    .frame(width: 28)
                Text(appState.language == .simplifiedChinese ? "退出登录" : "Sign out")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var signOutSection: some View {
        Button(role: .destructive) {
            showsSignOutConfirmation = true
        } label: {
            HStack {
                Spacer()
                Label(
                    appState.language == .simplifiedChinese ? "退出登录" : "Sign out",
                    systemImage: "rectangle.portrait.and.arrow.right"
                )
                .font(.body.weight(.semibold))
                .foregroundStyle(.red)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func signOut() {
        AccountAuthService().signOut()
        appState.accountMode = .guest
        appState.hasCompletedOnboarding = false
        appState.persist(to: currentSettings)
        try? modelContext.save()
    }

    private func resetHabitSystem() {
        let reset = LocalRecordRepository.resetHabitSystem(
            language: appState.language,
            storedHabits: storedHabits,
            storedTasks: storedTasks,
            modelContext: modelContext
        )
        appState.habits = reset.habits
        appState.dailyTasks = reset.tasks
        appState.latestCelebration = appState.language == .simplifiedChinese ? "第一周习惯已重置。" : "First-week habits have been reset."
    }

    private func deleteLocalData() {
        LocalRecordRepository.deleteLocalRecords(
            storedMeals: storedMeals,
            storedWorkouts: storedWorkouts,
            storedHabits: storedHabits,
            storedTasks: storedTasks,
            storedSleep: storedSleep,
            storedSupplements: storedSupplements,
            storedMeasurements: storedMeasurements,
            storedStrategies: storedStrategies,
            storedReviews: storedReviews,
            modelContext: modelContext
        )

        let settings = currentSettings
        settings.hasCompletedOnboarding = false
        settings.waterCups = 0
        appState.meals = []
        appState.workouts = []
        appState.waterCups = 0
        appState.hasCompletedOnboarding = false
        appState.resetDefaultHabitSystem()
        appState.persist(to: settings)
    }

    private var currentSettings: StoredUserSettings {
        LocalRecordRepository.settings(from: storedSettings, modelContext: modelContext)
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        switch (version, build) {
        case let (version?, build?):
            return "\(version) (\(build))"
        case let (version?, nil):
            return version
        default:
            return "1.0"
        }
    }

    private var exportSnapshot: DataExportSnapshot {
        DataExportSnapshot.make(
            currentWeightKg: appState.weightKilograms,
            targetWeightKg: appState.profile.targetWeightKilograms,
            habits: appState.habits,
            tasks: appState.dailyTasks,
            meals: appState.meals,
            weeklyReview: appState.weeklyReview
        )
    }
}

private enum MeSheet: String, Identifiable {
    case profile
    case plan
    case preferences
    case reminders
    case subscription
    case coach
    case export
    case account
    case health
    case privacy
    case terms
    case watch
    case wechat
    case aiAdvisor
    case aiStyle
    case aiMemory
    case help
    case feedback

    var id: String { rawValue }

    var detents: Set<PresentationDetent> {
        switch self {
        case .profile, .plan, .coach, .export:
            return [.large]
        case .preferences, .reminders, .subscription, .account, .health, .privacy, .terms, .watch, .wechat, .aiAdvisor, .aiStyle, .aiMemory, .help, .feedback:
            return [.medium]
        }
    }
}

private struct SettingsRow: View {
    let symbol: String
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(MKColor.green)
                    .frame(width: 28)
                Text(title)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.leading)
                Spacer()
                if !value.isEmpty {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MKTheme.secondaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .mkGlassSurface(cornerRadius: 18)
        }
    }
}

private struct SettingsStaticRow: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(MKColor.green)
                .frame(width: 28)
            Text(title)
                .font(.body.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 13)
    }
}

private struct PlanInfoPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ProfileEditorSheet: View {
    let language: AppLanguage
    let onSave: (UserEnergyProfile, Double, FitnessIntent, AppExperienceMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sex: BiologicalSex
    @State private var intent: FitnessIntent
    @State private var mode: AppExperienceMode
    @State private var age: Int
    @State private var height: Double
    @State private var weight: Double
    @State private var targetWeight: Double
    @State private var currentBodyFat: String
    @State private var targetBodyFat: String
    @State private var workEnvironment: WorkEnvironment
    @State private var activityLevel: ActivityLevel
    @State private var trainingExperience: TrainingExperience
    @State private var hasExerciseHabit: Bool
    @State private var weeklyWorkoutCount: Int
    @State private var restDay: Int
    @State private var fatLossWeeks: Int

    private var isChinese: Bool { language == .simplifiedChinese }

    init(
        initialProfile: UserEnergyProfile,
        initialWeight: Double,
        initialIntent: FitnessIntent,
        initialMode: AppExperienceMode,
        language: AppLanguage,
        onSave: @escaping (UserEnergyProfile, Double, FitnessIntent, AppExperienceMode) -> Void
    ) {
        self.language = language
        self.onSave = onSave
        _sex = State(initialValue: initialProfile.biologicalSex)
        _intent = State(initialValue: initialIntent)
        _mode = State(initialValue: initialMode)
        _age = State(initialValue: initialProfile.age)
        _height = State(initialValue: initialProfile.heightCentimeters)
        _weight = State(initialValue: initialWeight)
        _targetWeight = State(initialValue: initialProfile.targetWeightKilograms)
        _currentBodyFat = State(initialValue: initialProfile.currentBodyFatPercentage.map { String(format: "%.1f", $0) } ?? "")
        _targetBodyFat = State(initialValue: initialProfile.targetBodyFatPercentage.map { String(format: "%.1f", $0) } ?? "")
        _workEnvironment = State(initialValue: initialProfile.workEnvironment)
        _activityLevel = State(initialValue: initialProfile.activityLevel)
        _trainingExperience = State(initialValue: initialProfile.trainingExperience)
        _hasExerciseHabit = State(initialValue: initialProfile.hasExerciseHabit)
        _weeklyWorkoutCount = State(initialValue: initialProfile.weeklyWorkoutCount)
        _restDay = State(initialValue: initialProfile.restDayRawValue)
        _fatLossWeeks = State(initialValue: initialProfile.fatLossWeeks)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MeSectionTitle(title: isChinese ? "目标模式" : "Goal mode", symbol: "target")

                    Picker(isChinese ? "目标" : "Goal", selection: $intent) {
                        ForEach(FitnessIntent.allCases) { item in
                            Text(item.localizedName(language: language)).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(isChinese ? "版本" : "Mode", selection: $mode) {
                        ForEach(AppExperienceMode.allCases) { item in
                            Text(item.localizedName(language: language)).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    MeSectionTitle(title: isChinese ? "个人基本信息" : "Basics", symbol: "person.text.rectangle")

                    Picker(isChinese ? "性别" : "Sex", selection: $sex) {
                        ForEach(BiologicalSex.allCases, id: \.self) { item in
                            Text(item.localizedName(language: language)).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    MeMetricStepper(title: isChinese ? "年龄" : "Age", value: $age, range: 16...75, unit: isChinese ? "岁" : "y")
                    MeMetricDoubleStepper(title: isChinese ? "身高" : "Height", value: $height, range: 140...210, step: 1, unit: "cm")
                    MeMetricDoubleStepper(title: isChinese ? "当前体重" : "Current weight", value: $weight, range: 40...160, step: 0.5, unit: "kg")
                    MeMetricDoubleStepper(title: isChinese ? "目标体重" : "Target weight", value: $targetWeight, range: 40...160, step: 0.5, unit: "kg")

                    HStack(spacing: 10) {
                        MeNumberField(title: isChinese ? "当前体脂" : "Body fat", text: $currentBodyFat, placeholder: isChinese ? "选填" : "Optional")
                        MeNumberField(title: isChinese ? "目标体脂" : "Target fat", text: $targetBodyFat, placeholder: isChinese ? "选填" : "Optional")
                    }

                    MeSectionTitle(title: isChinese ? "生活和运动" : "Lifestyle", symbol: "figure.walk.motion")

                    Picker(isChinese ? "工作环境" : "Work", selection: $workEnvironment) {
                        ForEach(WorkEnvironment.allCases) { environment in
                            Text(environment.localizedName(language: language)).tag(environment)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Picker(isChinese ? "日常活动水平" : "Activity level", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases) { level in
                            Text(level.localizedName(language: language)).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Picker(isChinese ? "训练经验" : "Training experience", selection: $trainingExperience) {
                        ForEach(TrainingExperience.allCases) { experience in
                            Text(experience.localizedName(language: language)).tag(experience)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Toggle(isChinese ? "有规律运动习惯" : "Regular exercise habit", isOn: $hasExerciseHabit)
                        .tint(MKColor.green)

                    MeMetricStepper(title: isChinese ? "每周运动" : "Weekly workouts", value: $weeklyWorkoutCount, range: 0...7, unit: isChinese ? "次" : "x")
                        .opacity(hasExerciseHabit ? 1 : 0.45)
                        .disabled(!hasExerciseHabit)

                    MeMetricStepper(title: isChinese ? "休息日" : "Rest day", value: $restDay, range: 1...7, unit: isChinese ? "周\(restDay)" : "day")
                    MeMetricStepper(title: isChinese ? "目标周期" : "Timeline", value: $fatLossWeeks, range: 4...52, unit: isChinese ? "周" : "weeks")

                    calculationPreview
                }
                .padding(22)
            }
            .background(MKBackdrop())
            .navigationTitle(isChinese ? "编辑个人资料" : "Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "取消" : "Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isChinese ? "保存" : "Save") {
                        onSave(computedProfile, weight, intent, mode)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var calculationPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            MeSectionTitle(title: isChinese ? "计算预览" : "Calculation preview", symbol: "gauge.with.dots.needle.50percent")
            HStack(spacing: 8) {
                PlanInfoPill(title: "BMR", value: "\(computedProfile.basalMetabolicRate)")
                PlanInfoPill(title: isChinese ? "活动" : "Activity", value: "\(computedProfile.activityCalories)")
                PlanInfoPill(title: isChinese ? "运动" : "Exercise", value: "\(computedProfile.exerciseCalories)")
            }
        }
        .padding(16)
        .mkGlassSurface(cornerRadius: 24, tint: .white.opacity(0.18))
    }

    private var computedProfile: UserEnergyProfile {
        let effectiveWorkoutCount = hasExerciseHabit ? weeklyWorkoutCount : 0
        let bmr = EnergyCalculator.basalMetabolicRate(
            sex: sex,
            weightKilograms: weight,
            heightCentimeters: height,
            age: age
        )
        let activity = EnergyCalculator.activityCalories(
            basalMetabolicRate: bmr,
            workEnvironment: workEnvironment,
            hasExerciseHabit: hasExerciseHabit,
            weeklyWorkoutCount: effectiveWorkoutCount
        )
        let exercise = EnergyCalculator.plannedExerciseCalories(
            weightKilograms: weight,
            weeklyWorkoutCount: effectiveWorkoutCount,
            hasExerciseHabit: hasExerciseHabit
        )

        return UserEnergyProfile(
            basalMetabolicRate: bmr,
            activityCalories: activity,
            exerciseCalories: exercise,
            heightCentimeters: height,
            age: age,
            biologicalSex: sex,
            targetWeightKilograms: targetWeight,
            currentBodyFatPercentage: Double(currentBodyFat),
            targetBodyFatPercentage: Double(targetBodyFat),
            workEnvironment: workEnvironment,
            hasExerciseHabit: hasExerciseHabit,
            weeklyWorkoutCount: effectiveWorkoutCount,
            restDayRawValue: restDay,
            fatLossWeeks: fatLossWeeks,
            activityLevel: activityLevel,
            trainingExperience: trainingExperience
        )
    }
}

private struct PlanEditorSheet: View {
    let profile: UserEnergyProfile
    let currentWeight: Double
    let language: AppLanguage
    let onSave: (DietPlan, FitnessIntent, AppExperienceMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: DietPlan
    @State private var intent: FitnessIntent
    @State private var mode: AppExperienceMode

    private var isChinese: Bool { language == .simplifiedChinese }
    private var recommendations: [PlanRecommendation] {
        PlanEngine.recommendations(
            profile: profile,
            currentWeight: currentWeight,
            intent: intent,
            language: language
        )
    }

    init(
        selectedPlan: DietPlan,
        profile: UserEnergyProfile,
        currentWeight: Double,
        intent: FitnessIntent,
        mode: AppExperienceMode,
        language: AppLanguage,
        onSave: @escaping (DietPlan, FitnessIntent, AppExperienceMode) -> Void
    ) {
        self.profile = profile
        self.currentWeight = currentWeight
        self.language = language
        self.onSave = onSave
        _selectedPlan = State(initialValue: selectedPlan)
        _intent = State(initialValue: intent)
        _mode = State(initialValue: mode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MeSectionTitle(title: isChinese ? "目标和版本" : "Goal and mode", symbol: "target")

                    Picker(isChinese ? "目标" : "Goal", selection: $intent) {
                        ForEach(FitnessIntent.allCases) { item in
                            Text(item.localizedName(language: language)).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(isChinese ? "版本" : "Mode", selection: $mode) {
                        ForEach(AppExperienceMode.allCases) { item in
                            Text(item.localizedName(language: language)).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    MeSectionTitle(title: isChinese ? "推荐方案" : "Recommended plans", symbol: "sparkles")

                    ForEach(recommendations) { recommendation in
                        Button {
                            selectedPlan = recommendation.plan
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(recommendation.plan.localizedName(language: language))
                                        .font(.headline)
                                    Spacer()
                                    DifficultyDotsView(value: recommendation.difficulty)
                                }
                                Text(recommendation.note)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    PlanInfoPill(title: isChinese ? "热量差" : "Deficit", value: "\(recommendation.dailyDeficit)")
                                    PlanInfoPill(title: isChinese ? "预计/周" : "Weekly", value: String(format: "%.1fkg", recommendation.weeklyLossKilograms))
                                }
                            }
                            .padding(14)
                            .mkGlassSurface(
                                cornerRadius: 20,
                                tint: selectedPlan == recommendation.plan ? MKColor.subtleGreen.opacity(0.42) : .white.opacity(0.10),
                                isInteractive: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(22)
            }
            .background(MKBackdrop())
            .navigationTitle(isChinese ? "调整方案" : "Adjust plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "取消" : "Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isChinese ? "保存" : "Save") {
                        onSave(selectedPlan, intent, mode)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct InformationalSheet: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(MKColor.green)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MKBackdrop())
    }
}

private struct AccountSheet: View {
    let language: AppLanguage
    let accountMode: AccountMode
    let email: String?
    let onAuthenticated: (AccountSession) -> Void
    let onSignOut: () -> Void

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        Group {
            if accountMode == .signedIn {
                signedInContent
            } else {
                AuthView(language: language, onAuthenticated: onAuthenticated)
            }
        }
    }

    private var signedInContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(isChinese ? "账号" : "Account", systemImage: "person.crop.circle.fill")
                .font(.title2.bold())
                .foregroundStyle(MKColor.green)

            VStack(alignment: .leading, spacing: 10) {
                Text(isChinese ? "已登录" : "Signed in")
                    .font(.headline)
                Text(email ?? (isChinese ? "当前账号已连接线上同步。" : "This account is connected to cloud sync."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button(role: .destructive) {
                onSignOut()
            } label: {
                Label(isChinese ? "退出登录" : "Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Text(isChinese ? "退出后，本机数据仍保留；再次登录同一账号可继续同步线上数据。" : "Signing out keeps local data on this device. Sign in again to continue cloud sync.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MKBackdrop())
    }
}

private struct SubscriptionSheet: View {
    let language: AppLanguage
    let tier: SubscriptionTier
    let onChange: (SubscriptionTier) -> Void

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(isChinese ? "轻减AI Pro" : "MealKind Pro", systemImage: "sparkles")
                .font(.title2.bold())
                .foregroundStyle(MKColor.green)

            Text(isChinese ? "当前版本提供本地订阅状态，用于验证 Pro 入口和后续付费触发点。" : "This build keeps a local subscription state for validating Pro entry points and future paywall triggers.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                FeatureLine(text: isChinese ? "无限拍照分析" : "Unlimited scans")
                FeatureLine(text: isChinese ? "AI 教练深度调整" : "Deeper AI coach adjustment")
                FeatureLine(text: isChinese ? "AI 周复盘" : "AI weekly reviews")
                FeatureLine(text: isChinese ? "个性化习惯调整" : "Personalized habit adjustment")
                FeatureLine(text: isChinese ? "Pro Plus：睡眠、恢复、周期和训练建议" : "Pro Plus: sleep, recovery, cycle, and training suggestions")
            }
            .padding(14)
            .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(spacing: 10) {
                ForEach(SubscriptionTier.allCases) { option in
                    Button {
                        onChange(option)
                    } label: {
                        HStack {
                            Image(systemName: tier == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(tier == option ? MKColor.green : .secondary)
                            Text(option.localizedName(language: language))
                                .font(.headline)
                            Spacer()
                        }
                        .padding(14)
                        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(isChinese ? "这是本地状态，不会发起真实扣费。" : "This is a local state and does not start a real purchase.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MKBackdrop())
    }
}

private struct FeatureLine: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(MKColor.green)
            Text(text)
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
    }
}

private struct DataExportSheet: View {
    let language: AppLanguage
    let exportText: String

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(isChinese ? "数据导出" : "Data export", systemImage: "square.and.arrow.up.fill")
                            .font(.title2.bold())
                            .foregroundStyle(MKColor.green)
                        Text(isChinese ? "导出内容包含本机资料、偏好和记录快照。" : "The export includes local profile, preferences, and record snapshots.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .mkGlassSurface(cornerRadius: 26, tint: .white.opacity(0.16))

                    Text(exportText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(20)
            }
            .background(MKBackdrop())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(
                        item: exportText,
                        subject: Text(isChinese ? "轻减AI 数据导出" : "MealKind data export"),
                        message: Text(isChinese ? "本机导出的轻减AI数据。" : "Local MealKind data export.")
                    ) {
                        Label(isChinese ? "分享" : "Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

private struct ReminderSettingsSheet: View {
    let language: AppLanguage
    @State private var scheduleState: ScheduleState = .idle

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundStyle(MKColor.green)
                    .frame(width: 44, height: 44)
                    .background(MKColor.subtleGreen.opacity(0.35), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(isChinese ? "提醒设置" : "Reminder settings")
                        .font(.title2.bold())
                    Text(isChinese ? "提醒是行为提示，不是催促。" : "Reminders are prompts, not pressure.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(ReminderPlanner.defaults(language: language)) { reminder in
                VStack(alignment: .leading, spacing: 5) {
                    Text(reminder.title)
                        .font(.headline)
                    Text(reminder.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Text(isChinese ? "开启后会安排午餐前、睡前和周复盘提醒。所有文案保持温和，不催促。" : "When enabled, lunch-before, bedtime, and weekly review reminders are scheduled with gentle wording.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    scheduleState = .requesting
                    let granted = await ReminderNotificationScheduler.requestPermissionAndSchedule(language: language)
                    scheduleState = granted ? .enabled : .denied
                }
            } label: {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(MKPrimaryActionStyle(tint: MKColor.green))
            .disabled(scheduleState == .requesting)

            if let statusText {
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(scheduleState == .denied ? MKColor.citrus : MKColor.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MKBackdrop())
    }

    private var buttonTitle: String {
        switch scheduleState {
        case .idle:
            return isChinese ? "启用温和提醒" : "Enable gentle reminders"
        case .requesting:
            return isChinese ? "正在请求权限..." : "Requesting permission..."
        case .enabled:
            return isChinese ? "已启用提醒" : "Reminders enabled"
        case .denied:
            return isChinese ? "重新请求权限" : "Request permission again"
        }
    }

    private var statusText: String? {
        switch scheduleState {
        case .idle, .requesting:
            return nil
        case .enabled:
            return isChinese ? "已安排午餐前、睡前和周复盘提醒。" : "Lunch-before, bedtime, and weekly review reminders are scheduled."
        case .denied:
            return isChinese ? "未获得通知权限。你可以稍后在系统设置里开启。" : "Notification permission was not granted. You can enable it later in Settings."
        }
    }

    private enum ScheduleState {
        case idle
        case requesting
        case enabled
        case denied
    }
}

private struct MeSectionTitle: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(MKColor.green)
    }
}

private struct MeMetricStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        Stepper(value: $value, in: range) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(value) \(unit)")
                    .font(.subheadline.bold())
                    .monospacedDigit()
            }
        }
    }
}

private struct MeMetricDoubleStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(String(format: "%.1f", value)) \(unit)")
                    .font(.subheadline.bold())
                    .monospacedDigit()
            }
        }
    }
}

private struct MeNumberField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .font(.subheadline.bold())
                .padding(12)
                .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct DifficultyDotsView: View {
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                Circle()
                    .fill(index <= value ? (value > 3 ? MKColor.citrus : MKColor.green) : MKTheme.track)
                    .frame(width: 7, height: 7)
            }
        }
    }
}
