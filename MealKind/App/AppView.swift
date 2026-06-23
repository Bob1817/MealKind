import SwiftUI
import SwiftData
import UIKit

struct AppView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var storedSettings: [StoredUserSettings]
    @Query(sort: \StoredHabit.createdAt) private var storedHabits: [StoredHabit]
    @Query(sort: \StoredDailyTask.createdAt) private var storedTasks: [StoredDailyTask]
    @Query(sort: \StoredMealRecord.createdAt) private var storedMeals: [StoredMealRecord]
    @Query(sort: \StoredWorkoutRecord.createdAt) private var storedWorkouts: [StoredWorkoutRecord]
    @Query(sort: \StoredSleepRecord.createdAt) private var storedSleep: [StoredSleepRecord]
    @Query(sort: \StoredWaterRecord.loggedAt) private var storedWater: [StoredWaterRecord]
    @Query(sort: \StoredWeightRecord.loggedAt) private var storedWeight: [StoredWeightRecord]
    @Query(sort: \StoredSupplementRecord.takenAt) private var storedSupplements: [StoredSupplementRecord]
    @Query(sort: \StoredMeasurementRecord.takenAt) private var storedMeasurements: [StoredMeasurementRecord]
    @Query(sort: \StoredDailyStrategy.generatedAt) private var storedStrategies: [StoredDailyStrategy]
    @Query(sort: \StoredWeeklyReview.generatedAt) private var storedReviews: [StoredWeeklyReview]
    @Query(sort: \StoredTrainingCycle.createdAt) private var storedCycles: [StoredTrainingCycle]
    @State private var selectedTab: AppTab = .today
    @State private var appState = AppState.sample
    @State private var didHydrate = false
    @State private var remoteSyncTask: Task<Void, Never>?
    @State private var didAttemptRemoteRestore = false

    var body: some View {
        rootContent
        .environment(appState)
        .preferredColorScheme(appState.appearance.colorScheme)
        .onAppear {
            hydrateIfNeeded()
        }
        .onChange(of: persistenceChangeKey) { oldValue, newValue in
            handlePersistenceChange(from: oldValue, to: newValue)
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if !appState.hasSelectedLanguage {
            LanguageSelectionView(onSelectLanguage: selectLanguage)
        } else if shouldShowAuth {
            AuthView(
                language: appState.language,
                onAuthenticated: completeAuthentication
            )
        } else if appState.hasCompletedOnboarding {
            mainTabs
        } else {
            OnboardingView()
        }
    }

    private var shouldShowAuth: Bool {
        appState.accountMode != .signedIn
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    tab.content(experienceMode: appState.experienceMode, selectedTab: $selectedTab)
                }
                .tabItem {
                    tab.label(language: appState.language, experienceMode: appState.experienceMode)
                }
                .tag(tab)
            }
        }
        .tint(MKColor.green)
    }

    private func selectLanguage(_ language: AppLanguage) {
        appState.setLanguage(language, settings: settingsForMutation())
        resetStoredHabitSystem(for: language)
        saveSettings()
    }

    private func completeAuthentication(_ session: AccountSession) {
        appState.accountMode = .signedIn
        appState.persist(to: settingsForMutation())
        saveSettings()
        didAttemptRemoteRestore = false
        restoreRemoteIfNeeded()
    }

    private var persistenceChangeKey: PersistenceChangeKey {
        PersistenceChangeKey(
            meals: storedMeals.count,
            workouts: storedWorkouts.count,
            habits: storedHabits.count,
            tasks: storedTasks.count,
            sleep: storedSleep.count,
            water: storedWater.count,
            weight: storedWeight.count,
            supplements: storedSupplements.count,
            measurements: storedMeasurements.count,
            cycles: storedCycles.count,
            strategies: storedStrategies.count,
            reviews: storedReviews.count
        )
    }

    private func handlePersistenceChange(from oldValue: PersistenceChangeKey, to newValue: PersistenceChangeKey) {
        let shouldHydrate = oldValue.userRecordCounts != newValue.userRecordCounts
        if shouldHydrate {
            hydrateIfNeeded(force: true)
        }

        if oldValue.dailyStrategyInputs != newValue.dailyStrategyInputs {
            refreshDailyStrategy()
        }

        if oldValue.tasks != newValue.tasks {
            refreshWeeklyReview()
        }

        scheduleRemoteSync()
    }

    private func settingsForMutation() -> StoredUserSettings {
        LocalRecordRepository.settings(from: storedSettings, modelContext: modelContext)
    }

    private func saveSettings() {
        try? modelContext.save()
    }

    private func hydrateIfNeeded(force: Bool = false) {
        guard force || !didHydrate else { return }

        let settings = LocalRecordRepository.settings(from: storedSettings, modelContext: modelContext)

        seedHabitSystemIfNeeded()
        appState.apply(
            settings: settings,
            records: storedMeals,
            workoutRecords: storedWorkouts,
            storedHabits: storedHabits,
            storedTasks: storedTasks,
            sleepRecords: storedSleep,
            waterRecords: storedWater,
            supplementRecords: storedSupplements,
            measurementRecords: storedMeasurements,
            storedStrategies: storedStrategies,
            storedReviews: storedReviews,
            storedCycles: storedCycles
        )
        didHydrate = true
        ensurePersistedStrategy()
        ensurePersistedWeeklyReview()
        restoreRemoteIfNeeded()
    }

    private func refreshDailyStrategy() {
        guard appState.hasCompletedOnboarding else { return }
        appState.refreshPersistedStrategy(existing: storedStrategies, modelContext: modelContext)
    }

    private func refreshWeeklyReview() {
        guard appState.hasCompletedOnboarding else { return }
        appState.refreshPersistedWeeklyReview(existing: storedReviews, modelContext: modelContext)
    }

    private func ensurePersistedStrategy() {
        guard appState.hasCompletedOnboarding else { return }
        let todayLocal = LocalDateStamp.dateString(for: Date())
        if storedStrategies.contains(where: { $0.localDate == todayLocal }) == false {
            appState.refreshPersistedStrategy(existing: storedStrategies, modelContext: modelContext)
        }
    }

    private func ensurePersistedWeeklyReview() {
        guard appState.hasCompletedOnboarding else { return }
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekStartLocal = LocalDateStamp.dateString(for: weekStart)
        if storedReviews.contains(where: { $0.weekStartLocalDate == weekStartLocal }) == false {
            appState.refreshPersistedWeeklyReview(existing: storedReviews, modelContext: modelContext)
        }
    }

    private func seedHabitSystemIfNeeded() {
        LocalRecordRepository.seedHabitSystemIfNeeded(
            language: appState.language,
            storedHabits: storedHabits,
            storedTasks: storedTasks,
            modelContext: modelContext
        )
    }

    private func resetStoredHabitSystem(for language: AppLanguage) {
        let reset = LocalRecordRepository.resetHabitSystem(
            language: language,
            storedHabits: storedHabits,
            storedTasks: storedTasks,
            modelContext: modelContext
        )
        appState.habits = reset.habits
        appState.dailyTasks = reset.tasks
    }

    private func scheduleRemoteSync() {
        guard appState.hasSelectedLanguage else { return }
        let snapshot = RemotePersistenceSnapshot(
            settings: settingsForMutation(),
            habits: storedHabits,
            tasks: storedTasks,
            meals: storedMeals,
            workouts: storedWorkouts,
            sleep: storedSleep,
            water: storedWater,
            weight: storedWeight,
            supplements: storedSupplements,
            measurements: storedMeasurements,
            strategies: storedStrategies,
            reviews: storedReviews,
            cycles: storedCycles
        )
        let language = appState.language
        remoteSyncTask?.cancel()
        remoteSyncTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            await RemotePersistenceService().sync(snapshot: snapshot, language: language)
        }
    }

    private func restoreRemoteIfNeeded() {
        guard appState.hasSelectedLanguage else { return }
        guard didAttemptRemoteRestore == false else {
            scheduleRemoteSync()
            return
        }

        didAttemptRemoteRestore = true
        let localHasUserData = hasLocalUserRecords
        let language = appState.language
        Task {
            let remoteExport = await RemotePersistenceService().export(language: language)
            guard let remoteExport, remoteExport.hasUserRecords else {
                scheduleRemoteSync()
                return
            }
            guard localHasUserData == false else {
                scheduleRemoteSync()
                return
            }

            LocalRecordRepository.applyRemoteExport(
                remoteExport,
                settings: settingsForMutation(),
                storedHabits: storedHabits,
                storedTasks: storedTasks,
                storedMeals: storedMeals,
                storedWorkouts: storedWorkouts,
                storedSleep: storedSleep,
                storedWater: storedWater,
                storedWeight: storedWeight,
                storedSupplements: storedSupplements,
                storedMeasurements: storedMeasurements,
                storedStrategies: storedStrategies,
                storedReviews: storedReviews,
                storedCycles: storedCycles,
                modelContext: modelContext
            )
            hydrateIfNeeded(force: true)
        }
    }

    private var hasLocalUserRecords: Bool {
        storedMeals.isEmpty == false
            || storedWorkouts.isEmpty == false
            || storedSleep.isEmpty == false
            || storedWater.isEmpty == false
            || storedWeight.isEmpty == false
            || storedSupplements.isEmpty == false
            || storedMeasurements.isEmpty == false
            || storedCycles.isEmpty == false
    }
}

private struct PersistenceChangeKey: Equatable {
    let meals: Int
    let workouts: Int
    let habits: Int
    let tasks: Int
    let sleep: Int
    let water: Int
    let weight: Int
    let supplements: Int
    let measurements: Int
    let cycles: Int
    let strategies: Int
    let reviews: Int

    var userRecordCounts: [Int] {
        [
            meals,
            workouts,
            habits,
            tasks,
            sleep,
            water,
            weight,
            supplements,
            measurements,
            cycles
        ]
    }

    var dailyStrategyInputs: [Int] {
        [
            meals,
            workouts,
            sleep,
            water
        ]
    }
}

private struct LanguageSelectionView: View {
    let onSelectLanguage: (AppLanguage) -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            VStack(spacing: 18) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 82, height: 82)
                    .background(MKTheme.primary, in: Circle())
                    .shadow(color: MKTheme.primary.opacity(0.22), radius: 22, y: 12)

                VStack(spacing: 8) {
                    Text("MealKind")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(MKTheme.ink)
                    Text("AI creates your first body profile\nAI 将为你生成第一份身体档案")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MKTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }

            HStack(spacing: 8) {
                LanguagePreviewPill(symbol: "person.text.rectangle", title: "Profile")
                LanguagePreviewPill(symbol: "fork.knife", title: "Meals")
                LanguagePreviewPill(symbol: "moon.zzz", title: "Sleep")
            }

            VStack(spacing: 12) {
                LanguageButton(title: "简体中文", subtitle: "后续引导和 App 将使用中文") {
                    onSelectLanguage(.simplifiedChinese)
                }
                LanguageButton(title: "English", subtitle: "Use English for setup and app text") {
                    onSelectLanguage(.english)
                }
            }
            .padding(18)
            .mkThemeCard(cornerRadius: 28)

            Spacer()

            Text("No long form. Just a calm setup.\n无需复杂问卷，只需几个轻量选择。")
                .font(.caption.weight(.medium))
                .foregroundStyle(MKTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)
        }
        .padding(.horizontal, MKTheme.pageMargin)
        .background(MKThemeBackground())
    }
}

private struct LanguageButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MKTheme.primary)
                    .frame(width: 40, height: 40)
                    .background(MKTheme.primary.opacity(0.10), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MKTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(MKTheme.secondaryText)
            }
            .padding(14)
            .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct LanguagePreviewPill: View {
    let symbol: String
    let title: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(MKTheme.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(MKTheme.primary.opacity(0.10), in: Capsule())
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case today
    case scan
    case bodyLog
    case progress
    case me

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .today:
            "house"
        case .scan:
            "square.and.pencil"
        case .bodyLog:
            "flame"
        case .progress:
            "sparkles"
        case .me:
            "person"
        }
    }

    func title(language: AppLanguage, experienceMode: AppExperienceMode = .professional) -> String {
        let l10n = L10n(language: language)
        switch self {
        case .today:
            if experienceMode == .professional {
                return language == .simplifiedChinese ? "今日" : "Today"
            }
            return l10n.t(.today)
        case .scan:
            if experienceMode == .lifestyle {
                return language == .simplifiedChinese ? "记录" : "Log"
            }
            return language == .simplifiedChinese ? "状态" : "Status"
        case .bodyLog:
            if experienceMode == .professional {
                return language == .simplifiedChinese ? "档案" : "History"
            }
            return language == .simplifiedChinese ? "坚持" : "Check-in"
        case .progress:
            if experienceMode == .lifestyle {
                return language == .simplifiedChinese ? "成长" : "Growth"
            }
            return language == .simplifiedChinese ? "成就" : "Achievements"
        case .me:
            return l10n.t(.me)
        }
    }

    @ViewBuilder
    @MainActor
    func content(experienceMode: AppExperienceMode, selectedTab: Binding<AppTab>? = nil) -> some View {
        switch self {
        case .today:
            if experienceMode == .professional {
                AdvancedPlanView()
            } else {
                TodayView()
            }
        case .scan:
            if experienceMode == .professional {
                AdvancedStatusView()
            } else {
                ScanView()
            }
        case .bodyLog:
            if experienceMode == .professional {
                AdvancedCycleLogView()
            } else {
                BodyLogView()
            }
        case .progress:
            if experienceMode == .professional {
                AdvancedAchievementsView()
            } else {
                ProgressView()
            }
        case .me:
            if let selectedTab {
                MeView(selectedTab: selectedTab)
            } else {
                MeView(selectedTab: .constant(.me))
            }
        }
    }

    @ViewBuilder
    @MainActor
    func label(language: AppLanguage, experienceMode: AppExperienceMode = .professional) -> some View {
        Label {
            Text(title(language: language, experienceMode: experienceMode))
        } icon: {
            Image(systemName: tabSymbol(experienceMode: experienceMode))
                .font(.system(size: 15, weight: .regular))
                .symbolRenderingMode(.monochrome)
        }
    }

    func tabSymbol(experienceMode: AppExperienceMode) -> String {
        guard experienceMode == .professional else { return symbol }
        switch self {
        case .today:
            return "list.clipboard"
        case .scan:
            return "waveform.path.ecg"
        case .bodyLog:
            return "square.and.pencil.circle"
        case .progress:
            return "seal"
        case .me:
            return "person.crop.circle"
        }
    }

}
