import SwiftUI
import SwiftData
import UIKit
import PhotosUI

private extension AppState {
    var advancedSnapshotCacheKey: String {
        [
            language.rawValue,
            experienceMode.rawValue,
            selectedPlan.rawValue,
            "\(meals.count):\(meals.last?.id.uuidString ?? "-"):\(eatenCalories):\(eatenMacros.protein):\(eatenMacros.carbs):\(eatenMacros.fat)",
            "\(workouts.count):\(workouts.last?.id.uuidString ?? "-"):\(todayWorkouts.count):\(loggedExerciseCalories)",
            "\(sleepLogs.count):\(sleepLogs.last?.id.uuidString ?? "-"):\(latestSleepLog?.hoursSlept ?? 0)",
            "\(supplementLogs.count):\(supplementLogs.last?.id.uuidString ?? "-")",
            "\(measurementLogs.count):\(measurementLogs.last?.id.uuidString ?? "-")",
            "\(trainingCycles.count):\(trainingCycles.last?.id.uuidString ?? "-"):\(trainingCycles.last?.status.rawValue ?? "-")",
            "\(waterLogs.count):\(waterLogs.last?.id.uuidString ?? "-"):\(waterCups):\(weightKilograms):\(profile.basalMetabolicRate):\(profile.activityCalories):\(profile.exerciseCalories)"
        ].joined(separator: "|")
    }
}

struct AdvancedPlanView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var isCycleArchived = false
    @State private var isShowingCycleDetail = false
    @State private var isShowingEditPlan = false
    @State private var isShowingArchiveConfirmation = false
    @State private var editConfirmationMessage: String?
    @State private var cycleCreationPresented = false

    @State private var todayTrainingLogs: [AdvancedTrainingLog] = []
    @State private var trainingTargetCalories = 250
    @State private var trainingTargetMinutes = 70
    @State private var todaySleepLog = AdvancedSleepLog()
    @State private var todaySupplementIntakes: [AdvancedSupplementIntake] = []
    @State private var otherSupplementSettings: [AdvancedSupplementIntake] = [
        AdvancedSupplementIntake(name: "肌酸", dosage: "5g", isTaken: false),
        AdvancedSupplementIntake(name: "鱼油", dosage: "2g", isTaken: false),
        AdvancedSupplementIntake(name: "电解质", dosage: "1 serving", isTaken: false)
    ]
    @State private var waterTargetCups = 8
    @State private var sleepTargetHours = 7.5
    @State private var isShowingNutritionInput = false
    @State private var isShowingTrainingInput = false
    @State private var isShowingSleepInput = false
    @State private var cachedSnapshot: AdvancedModeSnapshot?
    @State private var selectedRecordDetail: AdvancedRecordDetailKind?
    @State private var trainingConfirmationMessage: String?

    private var snapshot: AdvancedModeSnapshot { cachedSnapshot ?? .make(from: appState) }
    private var isChinese: Bool { appState.language == .simplifiedChinese }
    private var activeCreatedCycle: TrainingCycle? {
        appState.trainingCycles.first { $0.isActive || $0.isScheduled }
    }
    private var todayTrainingLog: AdvancedTrainingLog {
        AdvancedTrainingLog(
            durationMinutes: todayTrainingLogs.map(\.durationMinutes).reduce(0, +),
            caloriesBurned: todayTrainingLogs.map(\.caloriesBurned).reduce(0, +)
        )
    }
    private var displayedSleepLog: AdvancedSleepLog {
        if let latestSleepLog = appState.latestSleepLog {
            return AdvancedSleepLog(hours: latestSleepLog.hoursSlept)
        }
        return todaySleepLog
    }

    var body: some View {
        AdvancedScreen(
            title: isChinese ? "今日" : "Today",
            subtitle: isChinese ? "今日周期执行计划" : "Daily cycle execution plan",
            trailing: .createCycle(appState.language) { cycleCreationPresented = true }
        ) {
            let data = snapshot
            let today = data.trainingPlan.today

            if isCycleArchived {
                AdvancedNoActiveCycleState(language: appState.language) {
                    isCycleArchived = false
                    isShowingEditPlan = true
                } onCustomPlan: {
                    isCycleArchived = false
                    isShowingEditPlan = true
                }
            } else {
                AdvancedCyclePlanHeader(
                    cycle: data.cycle,
                    language: appState.language
                ) {
                    isShowingCycleDetail = true
                }

                AdvancedDailyExecutionSummaryCard(
                    plan: data.nutritionPlan,
                    eatenCalories: appState.eatenCalories,
                    eatenMacros: appState.eatenMacros,
                    basalMetabolicRate: appState.activeProfile.basalMetabolicRate,
                    activityCalories: appState.activeProfile.activityCalories,
                    exerciseCalories: appState.activeProfile.exerciseCalories,
                    waterCups: appState.waterCups,
                    adherenceDays: data.currentCycleCompletions.consecutiveCompletionDays,
                    trainingDay: today,
                    trainingTargetCalories: trainingTargetCalories,
                    trainingTargetMinutes: trainingTargetMinutes,
                    recovery: data.recovery,
                    supplements: data.supplements,
                    language: appState.language,
                    trainingLog: todayTrainingLog,
                    sleepLog: displayedSleepLog,
                    supplementIntakes: todaySupplementIntakes,
                    supplementSettings: otherSupplementSettings,
                    waterTarget: waterTargetCups,
                    sleepTarget: sleepTargetHours,
                    nutritionAction: { isShowingNutritionInput = true },
                    nutritionInfoAction: { selectedRecordDetail = .nutrition },
                    trainingAction: { isShowingTrainingInput = true },
                    trainingInfoAction: { selectedRecordDetail = .training },
                    otherInfoAction: { selectedRecordDetail = .other },
                    sleepAction: { isShowingSleepInput = true }
                )
                AdvancedRemainingActionsCard(
                    plan: data.nutritionPlan,
                    eatenCalories: appState.eatenCalories,
                    eatenMacros: appState.eatenMacros,
                    trainingDay: today,
                    trainingLog: todayTrainingLog,
                    sleepLog: displayedSleepLog,
                    supplements: data.supplements,
                    supplementIntakes: todaySupplementIntakes,
                    language: appState.language,
                    nutritionAction: { isShowingNutritionInput = true },
                    trainingAction: { isShowingTrainingInput = true },
                    otherAction: { isShowingSleepInput = true }
                )
                AdvancedAISuggestionCard(
                    insight: data.insights[0],
                    plan: data.nutritionPlan,
                    eatenCalories: appState.eatenCalories,
                    eatenMacros: appState.eatenMacros,
                    basalMetabolicRate: appState.activeProfile.basalMetabolicRate,
                    activityCalories: appState.activeProfile.activityCalories,
                    exerciseCalories: appState.activeProfile.exerciseCalories,
                    language: appState.language
                )
            }
        }
        .sheet(isPresented: $isShowingCycleDetail) {
            AdvancedCycleDetailSheet(
                snapshot: snapshot,
                createdCycle: activeCreatedCycle,
                language: appState.language,
                onEdit: {
                    isShowingCycleDetail = false
                    isShowingEditPlan = true
                },
                onArchive: {
                    isShowingCycleDetail = false
                    isShowingArchiveConfirmation = true
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingEditPlan) {
            TrainingCycleCreationSheet(
                language: appState.language,
                weightKilograms: appState.weightKilograms,
                editingCycle: activeCreatedCycle
            ) { cycle in
                appState.updateTrainingCycle(cycle, modelContext: modelContext)
                isShowingEditPlan = false
                editConfirmationMessage = isChinese
                    ? "新计划将从明天或下一个计划日开始生效。"
                    : "The updated plan will apply from tomorrow or the next planned day."
            } onArchive: { _ in
            } onCheckOverlap: { _ in
                nil
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingNutritionInput) {
            AdvancedNutritionInputSheet(
                macros: appState.eatenMacros,
                plan: snapshot.nutritionPlan,
                language: appState.language,
                mealHistory: appState.meals
            ) { meal in
                appState.saveManualMeal(meal, modelContext: modelContext)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingTrainingInput) {
            AdvancedTrainingInputSheet(
                logs: $todayTrainingLogs,
                targetCalories: $trainingTargetCalories,
                targetMinutes: $trainingTargetMinutes,
                language: appState.language
            ) {
                isShowingTrainingInput = false
                trainingConfirmationMessage = isChinese ? "录入成功" : "Logged"
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedRecordDetail) { kind in
            AdvancedRecordDetailSheet(
                kind: kind,
                meals: appState.todayMeals,
                trainingLogs: todayTrainingLogs,
                sleepLogs: appState.sleepLogs,
                waterLogs: appState.waterLogs,
                supplementIntakes: todaySupplementIntakes,
                language: appState.language,
                onDeleteMeal: { meal in
                    appState.deleteMeal(id: meal.id, modelContext: modelContext)
                },
                onDeleteTraining: { deleted in
                    deleteTrainingLog(deleted)
                },
                onDeleteSleep: { deleted in
                    appState.deleteSleep(id: deleted.id, modelContext: modelContext)
                    if abs(todaySleepLog.totalHours - deleted.hoursSlept) < 0.01 {
                        todaySleepLog = AdvancedSleepLog()
                    }
                },
                onDeleteWater: { deleted in
                    appState.deleteWater(id: deleted.id, modelContext: modelContext)
                },
                onDeleteSupplement: { deleted in
                    deleteSupplementIntake(deleted)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingSleepInput) {
            AdvancedSleepInputSheet(
                log: $todaySleepLog,
                supplementIntakes: $todaySupplementIntakes,
                supplementSettings: $otherSupplementSettings,
                waterCups: appState.waterCups,
                waterTarget: $waterTargetCups,
                sleepTarget: $sleepTargetHours,
                language: appState.language
            ) { delta in
                appState.saveWaterChange(delta, modelContext: modelContext)
            } onSleepSave: { log in
                todaySleepLog = AdvancedSleepLog(hours: log.hoursSlept)
                appState.saveSleep(log, modelContext: modelContext)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            isChinese ? "结束当前周期？" : "End current cycle?",
            isPresented: $isShowingArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button(isChinese ? "继续执行" : "Keep executing", role: .cancel) { }
            Button(isChinese ? "结束并归档" : "End and archive", role: .destructive) {
                isCycleArchived = true
            }
        } message: {
            Text(isChinese ? "结束后，该周期会被归档，并保留已有记录。你可以随时创建新的周期计划。" : "After ending, this cycle will be archived and existing records will be kept. You can create a new cycle plan anytime.")
        }
        .alert(
            isChinese ? "计划已更新" : "Plan updated",
            isPresented: Binding(
                get: { editConfirmationMessage != nil },
                set: { if !$0 { editConfirmationMessage = nil } }
            )
        ) {
            Button("OK") { editConfirmationMessage = nil }
        } message: {
            Text(editConfirmationMessage ?? "")
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
        .task(id: appState.advancedSnapshotCacheKey) {
            cachedSnapshot = .make(from: appState)
            syncTodaySleepLogFromAppStateIfNeeded()
        }
        .overlay(alignment: .top) {
            if let trainingConfirmationMessage {
                AdvancedToastMessage(text: trainingConfirmationMessage)
                    .padding(.top, 58)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .onChange(of: trainingConfirmationMessage) { _, newValue in
            guard newValue != nil else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(1600))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        trainingConfirmationMessage = nil
                    }
                }
            }
        }
    }

    private func deleteTrainingLog(_ deleted: AdvancedTrainingLog) {
        todayTrainingLogs.removeAll { $0.id == deleted.id }
    }

    private func deleteSupplementIntake(_ deleted: AdvancedSupplementIntake) {
        if let index = todaySupplementIntakes.firstIndex(where: { $0.id == deleted.id || $0.name == deleted.name }) {
            todaySupplementIntakes[index].isTaken = false
        }
    }

    private func syncTodaySleepLogFromAppStateIfNeeded() {
        guard todaySleepLog.totalHours == 0, let latestSleepLog = appState.latestSleepLog else { return }
        todaySleepLog = AdvancedSleepLog(hours: latestSleepLog.hoursSlept)
    }
}

struct AdvancedStatusView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \StoredWeightRecord.loggedAt) private var storedWeights: [StoredWeightRecord]
    @State private var cachedSnapshot: AdvancedModeSnapshot?

    private var snapshot: AdvancedModeSnapshot { cachedSnapshot ?? .make(from: appState) }
    private var isChinese: Bool { appState.language == .simplifiedChinese }
    private var bodyScore: AdvancedBodyScoreSummary {
        AdvancedBodyScoreSummary.make(snapshot: snapshot, appState: appState, language: appState.language)
    }

    var body: some View {
        let data = snapshot
        let projection = cycleProjection(data)
        let rates = executionRates(data)
        let limiter = limitingFactor(data, rates: rates)
        let match = cycleMatch(data, projection: projection, limiter: limiter)

        AdvancedScreen(
            title: isChinese ? "状态" : "Status",
            subtitle: isChinese ? "周期状态与趋势变化" : "Cycle status and trend changes"
        ) {
            AdvancedCycleControlHero(
                cycle: data.cycle,
                match: match,
                language: appState.language
            )

            AdvancedCoreTrendsCard(
                trends: coreTrends(data, projection: projection, rates: rates),
                language: appState.language
            )

            AdvancedPlanAdherenceCard(rates: rates, limiterName: limiter.title, language: appState.language)

            AdvancedCycleEndPredictionCard(
                scenarios: cycleEndScenarios(projection, limiter: limiter),
                language: appState.language
            )
        }
        .task(id: appState.advancedSnapshotCacheKey) {
            cachedSnapshot = .make(from: appState)
        }
    }

    private var calorieDelta: Int {
        appState.activeProfile.basalMetabolicRate + appState.activeProfile.activityCalories + appState.activeProfile.exerciseCalories - appState.eatenCalories
    }

    private func cycleProjection(_ data: AdvancedModeSnapshot) -> AdvancedCycleProjection {
        let cycle = data.cycle
        let elapsedDays = max(cycle.elapsedDays, 1)
        let dailyChange = (cycle.currentWeightKg - cycle.startWeightKg) / Double(elapsedDays)
        let predictedWeight = cycle.currentWeightKg + dailyChange * Double(cycle.remainingDays)
        let missKg: Double
        if cycle.kind == .muscleGain {
            missKg = max(cycle.targetWeightKg - predictedWeight, 0)
        } else {
            missKg = max(predictedWeight - cycle.targetWeightKg, 0)
        }
        let canHitTarget = missKg <= 0.5
        let judgment: String
        if canHitTarget {
            judgment = isChinese ? "按当前执行情况，可以接近周期目标。" : "At the current pace, this cycle can land near target."
        } else {
            judgment = isChinese ? "按当前执行情况，无法按计划完成目标。" : "At the current pace, this cycle is unlikely to hit target."
        }
        return AdvancedCycleProjection(
            startWeight: cycle.startWeightKg,
            targetWeight: cycle.targetWeightKg,
            currentWeight: cycle.currentWeightKg,
            predictedWeight: predictedWeight,
            targetMissKg: missKg,
            canHitTarget: canHitTarget,
            judgment: judgment,
            tint: canHitTarget ? MKColor.green : MKColor.citrus
        )
    }

    private func bodyFatProjection(_ data: AdvancedModeSnapshot, projection: AdvancedCycleProjection) -> AdvancedBodyFatProjection {
        let target = data.cycle.targetBodyFatPercent ?? (data.cycle.kind == .fatLoss ? 15 : 18)
        let current = target + max(projection.targetMissKg * 0.8, 1.2)
        let predicted = max(target, current - max(data.cycle.progress, 0.25) * 1.4)
        return .init(target: target, current: current, predicted: predicted)
    }

    private func cycleMatch(_ data: AdvancedModeSnapshot, projection: AdvancedCycleProjection, limiter: AdvancedLimitingFactor) -> AdvancedCycleMatch {
        let plannedProgress = data.cycle.progress
        let actualProgress = data.cycle.weightProgress
        let gap = actualProgress - plannedProgress
        let score = max(0, min(100, Int((1 - abs(gap)) * 100)))
        let status: String
        let message: String
        let tint: Color

        if gap < -0.16 {
            status = isChinese ? "未跟上计划" : "Behind plan"
            message = isChinese ? "\(limiter.title)是核心偏离原因。\(limiter.impact)" : "\(limiter.title) is the main drift. \(limiter.impact)"
            tint = MKColor.citrus
        } else if gap > 0.18 {
            status = isChinese ? "进度过快" : "Too fast"
            message = isChinese ? "当前进度快于计划，建议观察恢复与训练质量，避免过度执行。" : "Progress is faster than planned. Watch recovery and training quality."
            tint = MKColor.coral
        } else if score >= 85 {
            status = isChinese ? "状态优秀" : "Excellent"
            message = isChinese ? "当前状态与计划匹配良好，继续保持当前策略。" : "Current status matches the plan well. Keep the strategy."
            tint = MKColor.green
        } else {
            status = isChinese ? "状态可提升" : "Can improve"
            message = isChinese ? "当前状态接近计划，优先提升\(limiter.title)即可提高达成概率。" : "Status is near plan. Improving \(limiter.title) should raise target probability."
            tint = Color.blue
        }

        return .init(
            score: score,
            status: status,
            message: message,
            plannedProgress: plannedProgress,
            actualProgress: actualProgress,
            tint: tint
        )
    }

    private func coreTrends(_ data: AdvancedModeSnapshot, projection: AdvancedCycleProjection, rates: AdvancedExecutionRates) -> [AdvancedCoreTrend] {
        let weightRecords = dailyTrendRecords(
            for: data.cycle,
            entries: storedWeights.map { ($0.loggedAt, $0.weightKilograms) },
            reducer: latestValue
        )
        let bodyFatRecords = dailyTrendRecords(
            for: data.cycle,
            entries: appState.measurementLogs
                .filter { $0.kind == .bodyFatPercentage }
                .map { ($0.takenAt, $0.value) },
            reducer: latestValue
        )
        let trainingRecords = dailyTrendRecords(
            for: data.cycle,
            entries: appState.workouts.map { ($0.createdAt, Double($0.calories)) },
            reducer: sumValues
        )
        let nutritionRecords = dailyTrendRecords(
            for: data.cycle,
            entries: appState.meals.map { ($0.createdAt, Double($0.calories)) },
            reducer: sumValues
        )
        let sleepRecords = dailyTrendRecords(
            for: data.cycle,
            entries: appState.sleepLogs.map { ($0.createdAt, $0.hoursSlept) },
            reducer: latestValue
        )

        let hasWeightData = hasTrendData(weightRecords)
        let hasTrainingData = hasTrendData(trainingRecords)
        let hasNutritionData = hasTrendData(nutritionRecords)
        let hasSleepData = hasTrendData(sleepRecords)
        let weightAnchored = hasWeightData
            ? anchoredRecords(
                weightRecords,
                cycle: data.cycle,
                startValue: data.cycle.startWeightKg,
                currentValue: data.cycle.currentWeightKg
            )
            : weightRecords
        let bodyFatValues = bodyFatRecords.compactMap(\.value)
        let hasBodyFatData = !bodyFatValues.isEmpty
        let bodyFatStart = bodyFatValues.first ?? (data.cycle.startBodyFatPercentage > 0 ? data.cycle.startBodyFatPercentage : nil)
        let bodyFatCurrent = bodyFatValues.last ?? (data.cycle.currentBodyFatPercentage > 0 ? data.cycle.currentBodyFatPercentage : nil)
        let bodyFatAnchored: [AdvancedTrendRecord]
        if hasBodyFatData, let bodyFatStart, let bodyFatCurrent {
            bodyFatAnchored = anchoredRecords(
                bodyFatRecords,
                cycle: data.cycle,
                startValue: bodyFatStart,
                currentValue: bodyFatCurrent
            )
        } else {
            bodyFatAnchored = bodyFatRecords
        }
        let weightDelta = trendDelta(weightAnchored)
        let bodyFatDelta = bodyFatAnchored.compactMap(\.value).isEmpty ? nil : trendDelta(bodyFatAnchored)
        let todayIndex = todayTrendIndex(for: data.cycle)

        return [
            .init(
                title: isChinese ? "体重" : "Weight",
                value: hasWeightData ? signedValue(weightDelta, unit: "kg") : "-",
                direction: hasWeightData ? direction(for: weightAnchored) : .flat,
                tint: hasWeightData ? (weightDelta <= 0 ? MKColor.green : Color.blue) : MKTheme.secondaryText,
                records: weightAnchored,
                unit: "kg",
                todayIndex: todayIndex
            ),
            .init(
                title: isChinese ? "体脂" : "Body Fat",
                value: bodyFatDelta.map { signedValue($0, unit: "%") } ?? "-",
                direction: hasBodyFatData ? direction(for: bodyFatAnchored) : .flat,
                tint: hasBodyFatData ? ((bodyFatDelta ?? 0) <= 0 ? MKColor.green : MKColor.citrus) : MKTheme.secondaryText,
                records: bodyFatAnchored,
                unit: "%",
                todayIndex: todayIndex
            ),
            .init(
                title: isChinese ? "训练" : "Training",
                value: hasTrainingData ? "" : "-",
                direction: hasTrainingData ? direction(for: trainingRecords) : .flat,
                tint: hasTrainingData ? (direction(for: trainingRecords) == .down ? Color.blue : MKColor.green) : MKTheme.secondaryText,
                records: trainingRecords,
                unit: "kcal",
                todayIndex: todayIndex
            ),
            .init(
                title: isChinese ? "饮食" : "Nutrition",
                value: hasNutritionData ? "" : "-",
                direction: hasNutritionData ? direction(for: nutritionRecords) : .flat,
                tint: hasNutritionData ? (direction(for: nutritionRecords) == .down ? MKColor.citrus : MKColor.green) : MKTheme.secondaryText,
                records: nutritionRecords,
                unit: "kcal",
                todayIndex: todayIndex
            ),
            .init(
                title: isChinese ? "睡眠" : "Sleep",
                value: hasSleepData ? "" : "-",
                direction: hasSleepData ? direction(for: sleepRecords) : .flat,
                tint: hasSleepData ? (direction(for: sleepRecords) == .down ? MKColor.coral : MKColor.green) : MKTheme.secondaryText,
                records: sleepRecords,
                unit: "h",
                todayIndex: todayIndex
            )
        ]
    }

    private func dailyTrendRecords(
        for cycle: AdvancedBodyCycle,
        entries: [(Date, Double)],
        reducer: ([Double]) -> Double
    ) -> [AdvancedTrendRecord] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: cycle.startDate)
        let end = calendar.startOfDay(for: cycle.endDate)
        let dayCount = max(cycle.durationDays, max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0) + 1)
        let grouped = Dictionary(grouping: entries.filter { date, _ in
            let day = calendar.startOfDay(for: date)
            return day >= start && day <= end
        }) { date, _ in
            calendar.startOfDay(for: date)
        }

        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let values = grouped[day]?.map(\.1) ?? []
            return AdvancedTrendRecord(
                label: "D\(offset + 1)",
                value: values.isEmpty ? nil : reducer(values)
            )
        }
    }

    private func anchoredRecords(_ records: [AdvancedTrendRecord], cycle: AdvancedBodyCycle, startValue: Double, currentValue: Double) -> [AdvancedTrendRecord] {
        guard !records.isEmpty else { return [AdvancedTrendRecord(label: "D1", value: currentValue)] }
        var anchored = records
        if anchored[0].value == nil {
            anchored[0] = AdvancedTrendRecord(label: anchored[0].label, value: startValue)
        }
        let currentIndex = min(max(cycle.elapsedDays - 1, 0), anchored.count - 1)
        if anchored[currentIndex].value == nil {
            anchored[currentIndex] = AdvancedTrendRecord(label: anchored[currentIndex].label, value: currentValue)
        }
        return anchored
    }

    private func sumValues(_ values: [Double]) -> Double {
        values.reduce(0, +)
    }

    private func latestValue(_ values: [Double]) -> Double {
        values.last ?? 0
    }

    private func trendDelta(_ records: [AdvancedTrendRecord]) -> Double {
        let values = records.compactMap(\.value)
        guard let first = values.first, let last = values.last else { return 0 }
        return last - first
    }

    private func hasTrendData(_ records: [AdvancedTrendRecord]) -> Bool {
        records.contains { $0.value != nil }
    }

    private func direction(for records: [AdvancedTrendRecord]) -> AdvancedTrendDirection {
        let delta = trendDelta(records)
        if abs(delta) < 0.05 { return .flat }
        return delta > 0 ? .up : .down
    }

    private func todayTrendIndex(for cycle: AdvancedBodyCycle) -> Int {
        min(max(cycle.elapsedDays - 1, 0), max(cycle.durationDays - 1, 0))
    }

    private func executionRates(_ data: AdvancedModeSnapshot) -> AdvancedExecutionRates {
        let nutrition = data.currentCycleCompletions.map(\.nutrition).average
        let training = data.currentCycleCompletions.map(\.training).average
        let recovery = min(data.recovery.sleepHours / 7.5, 1)
        let supplement = data.currentCycleCompletions.map(\.supplement).average
        return .init(nutrition: nutrition, training: training, recovery: recovery, supplement: supplement)
    }

    private func limitingFactor(_ data: AdvancedModeSnapshot, rates: AdvancedExecutionRates) -> AdvancedLimitingFactor {
        let factors: [AdvancedLimitingFactor] = [
            .init(
                title: isChinese ? "饮食执行" : "Nutrition execution",
                value: "\(Int(rates.nutrition * 100))%",
                target: isChinese ? "目标 ≥90%" : "Target ≥90%",
                impact: isChinese ? "饮食执行率偏低会直接降低周期目标达成概率。" : "Low nutrition adherence directly lowers target probability.",
                tint: rates.nutrition >= 0.85 ? MKColor.green : MKColor.citrus,
                score: rates.nutrition
            ),
            .init(
                title: isChinese ? "训练执行" : "Training execution",
                value: "\(Int(rates.training * 100))%",
                target: isChinese ? "目标 ≥90%" : "Target ≥90%",
                impact: isChinese ? "训练刺激不足会降低身体变化速度。" : "Low training stimulus slows body change.",
                tint: rates.training >= 0.85 ? MKColor.green : Color.blue,
                score: rates.training
            ),
            .init(
                title: isChinese ? "恢复执行" : "Recovery execution",
                value: String(format: "%.1fh", data.recovery.sleepHours),
                target: isChinese ? "目标 7.5h" : "Target 7.5h",
                impact: isChinese ? "恢复不足会降低训练质量，并放大体重波动。" : "Poor recovery lowers training quality and increases weight noise.",
                tint: rates.recovery >= 0.85 ? MKColor.green : MKColor.coral,
                score: rates.recovery
            ),
            .init(
                title: isChinese ? "补剂执行" : "Supplement execution",
                value: "\(Int(rates.supplement * 100))%",
                target: isChinese ? "目标 ≥90%" : "Target ≥90%",
                impact: isChinese ? "补剂执行偏低会影响训练和恢复稳定性。" : "Low supplement execution can reduce training and recovery consistency.",
                tint: rates.supplement >= 0.85 ? MKColor.green : Color.blue,
                score: rates.supplement
            )
        ]
        return factors.min { $0.score < $1.score } ?? factors[0]
    }

    private func deviationSummary(_ data: AdvancedModeSnapshot, projection: AdvancedCycleProjection, limiter: AdvancedLimitingFactor) -> AdvancedDeviationSummary {
        let totalWeeks = max(Double(data.cycle.durationDays) / 7, 1)
        let elapsedWeeks = max(Double(data.cycle.elapsedDays) / 7, 0.5)
        let targetWeekly = abs(data.cycle.targetWeightKg - data.cycle.startWeightKg) / totalWeeks
        let actualWeekly = abs(data.cycle.currentWeightKg - data.cycle.startWeightKg) / elapsedWeeks
        let gap = max(targetWeekly - actualWeekly, 0)
        let conclusion: String
        if projection.canHitTarget {
            conclusion = isChinese ? "当前变化速度接近周期目标，继续保持执行率即可。" : "Current velocity is close to target. Keep adherence steady."
        } else if limiter.title.contains(isChinese ? "恢复" : "Recovery") {
            conclusion = isChinese ? "热量方向基本有效，但恢复不足正在放大体重波动。" : "The calorie direction is usable, but recovery is increasing weight noise."
        } else if limiter.title.contains(isChinese ? "饮食" : "Nutrition") {
            conclusion = isChinese ? "当前下降速度低于目标，主要偏差来自饮食执行率不足。" : "Current velocity is below target, mainly from nutrition adherence."
        } else {
            conclusion = isChinese ? "当前周期刺激不足，结果偏离主要来自计划执行率。" : "Cycle stimulus is low; the gap is mainly from plan adherence."
        }
        return .init(
            targetWeekly: targetWeekly,
            actualWeekly: actualWeekly,
            weeklyGap: gap,
            conclusion: conclusion
        )
    }

    private func cycleEndScenarios(_ projection: AdvancedCycleProjection, limiter: AdvancedLimitingFactor) -> [AdvancedProjectionScenario] {
        let gap = projection.targetMissKg
        let isBehind = gap > 0.05
        let nutritionWeight = projection.canHitTarget ? projection.predictedWeight : projection.predictedWeight - gap * 0.65
        let recoveryWeight = projection.canHitTarget ? projection.predictedWeight : projection.predictedWeight - gap * 0.45
        return [
            .init(title: isChinese ? "按当前执行率" : "Current adherence", value: String(format: "%.1fkg", projection.predictedWeight), tint: projection.tint),
            .init(title: isChinese ? "饮食执行率提升至90%" : "Nutrition to 90%", value: String(format: "%.1fkg", isBehind ? nutritionWeight : projection.predictedWeight), tint: MKColor.green),
            .init(title: isChinese ? "恢复执行率提升至90%" : "Recovery to 90%", value: String(format: "%.1fkg", isBehind ? recoveryWeight : projection.predictedWeight), tint: limiter.title.contains(isChinese ? "恢复" : "Recovery") ? MKColor.green : Color.blue)
        ]
    }

    private func controlCenterAdjustments(_ data: AdvancedModeSnapshot, projection: AdvancedCycleProjection, limiter: AdvancedLimitingFactor) -> [String] {
        var actions: [String] = []
        if limiter.title.contains(isChinese ? "饮食" : "Nutrition") {
            actions.append(isChinese ? "未来7天把饮食执行率拉到90%以上。" : "Raise nutrition adherence above 90% for the next 7 days.")
            actions.append(isChinese ? "每日蛋白质保持\(max(data.nutritionPlan.protein, 130))g+。" : "Keep daily protein at \(max(data.nutritionPlan.protein, 130))g+.")
        }
        if limiter.title.contains(isChinese ? "恢复" : "Recovery") {
            actions.append(isChinese ? "未来7天保证7.5小时睡眠。" : "Get 7.5 hours of sleep for the next 7 days.")
            actions.append(isChinese ? "增加1天主动恢复日。" : "Add one active recovery day.")
        }
        if limiter.title.contains(isChinese ? "训练" : "Training") {
            actions.append(isChinese ? "保持当前饮食，不额外削减热量。" : "Keep nutrition unchanged; do not cut more calories.")
            actions.append(isChinese ? "优先完成本周计划训练。" : "Prioritize completing this week's planned sessions.")
        }
        if projection.targetMissKg > 0.5 && !actions.contains(where: { $0.contains("30") }) {
            actions.append(isChinese ? "暂停额外有氧，优先修正执行率。" : "Pause extra cardio and fix adherence first.")
        }
        actions.append(isChinese ? "维持当前补剂方案。" : "Maintain the current supplement plan.")
        return Array(actions.prefix(5))
    }

    private func cycleDiagnosis(_ data: AdvancedModeSnapshot) -> AdvancedCycleDiagnosis {
        let deficit = bodyScore.calorieDelta
        let proteinRate = Double(appState.eatenMacros.protein) / Double(max(data.nutritionPlan.protein, 1))
        let trainingRate = data.currentCycleCompletions.map(\.training).average
        let sleep = data.recovery.sleepHours

        if bodyScore.score < 55 || sleep < 6.2 {
            return .init(
                status: isChinese ? "建议恢复" : "Recovery Suggested",
                message: isChinese ? "恢复质量限制了当前周期推进，建议降低训练压力。" : "Recovery is limiting this cycle. Reduce training pressure.",
                tint: MKColor.coral
            )
        }

        if deficit > 900 || proteinRate < 0.7 {
            return .init(
                status: isChinese ? "需要关注" : "Needs Attention",
                message: deficit > 900
                    ? (isChinese ? "热量缺口持续偏高，恢复能力可能开始下降。" : "The calorie deficit is high and may reduce recovery.")
                    : (isChinese ? "蛋白质完成率偏低，可能影响保肌效果。" : "Protein adherence is low and may affect lean-mass retention."),
                tint: MKColor.citrus
            )
        }

        if trainingRate >= 0.8 {
            return .init(
                status: isChinese ? "执行良好" : "On Track",
                message: isChinese ? "体重变化符合预期，当前无需调整计划。" : "Body change is aligned with the plan. No adjustment needed now.",
                tint: MKColor.green
            )
        }

        return .init(
            status: isChinese ? "建议调整" : "Adjustment Suggested",
            message: isChinese ? "训练完成率偏低，周期刺激可能不足。" : "Training adherence is low, so the cycle stimulus may be insufficient.",
            tint: Color.blue
        )
    }

    private func cycleChangeMetrics(_ data: AdvancedModeSnapshot) -> [AdvancedCycleChangeMetric] {
        let weightChange = data.cycle.currentWeightKg - data.cycle.startWeightKg
        let bodyFat = data.cycle.targetBodyFatPercent ?? 18
        let waist = 82.0
        let leanMass = data.cycle.currentWeightKg * (1 - bodyFat / 100)
        return [
            .init(title: isChinese ? "体重" : "Weight", change: signedValue(weightChange, unit: "kg"), supportingText: String(format: "%.1f kg", data.cycle.currentWeightKg), tint: weightChange <= 0 ? MKColor.green : Color.blue),
            .init(title: isChinese ? "体脂" : "Body Fat", change: isChinese ? "-2%" : "-2%", supportingText: String(format: "%.1f%%", bodyFat), tint: MKColor.green),
            .init(title: isChinese ? "腰围" : "Waist", change: isChinese ? "-3 cm" : "-3 cm", supportingText: String(format: "%.0f cm", waist), tint: MKColor.green),
            .init(title: isChinese ? "瘦体重" : "Lean Mass", change: isChinese ? "保持稳定" : "Stable", supportingText: String(format: "%.1f kg", leanMass), tint: Color.blue)
        ]
    }

    private func cycleTimeline(_ data: AdvancedModeSnapshot) -> [AdvancedTimelinePoint] {
        let currentWeek = min(max(data.cycle.currentWeek, 1), 4)
        let start = data.cycle.startWeightKg
        let end = data.cycle.currentWeightKg
        return (1...max(currentWeek, 4)).prefix(4).map { week in
            let progress = Double(week - 1) / Double(max(currentWeek - 1, 1))
            let weight = start + (end - start) * progress
            return AdvancedTimelinePoint(
                title: isChinese ? "Week\(week)" : "Week \(week)",
                value: String(format: "%.1fkg", week == currentWeek ? end : weight)
            )
        }
    }

    private func cumulativeResultText(_ data: AdvancedModeSnapshot) -> String {
        let delta = data.cycle.currentWeightKg - data.cycle.startWeightKg
        if abs(delta) < 0.1 {
            return isChinese ? "累计变化稳定" : "Stable so far"
        }
        return delta < 0
            ? (isChinese ? "累计下降 \(String(format: "%.1f", abs(delta)))kg" : "Down \(String(format: "%.1f", abs(delta)))kg")
            : (isChinese ? "累计上升 \(String(format: "%.1f", delta))kg" : "Up \(String(format: "%.1f", delta))kg")
    }

    private func aiDiscovery(_ data: AdvancedModeSnapshot, consistency: AdvancedDataConsistency, risks: [AdvancedDiagnosisRisk]) -> String {
        let proteinRate = Double(appState.eatenMacros.protein) / Double(max(data.nutritionPlan.protein, 1))
        if data.recovery.sleepHours < 6.5 {
            return isChinese ? "当前恢复不足，是影响本轮周期效率的最大因素。" : "Recovery is currently the biggest limiter for this cycle."
        }
        if consistency.difference > 0.6 {
            return isChinese ? "记录与结果存在差异，外食和训练消耗估算最值得优先校准。" : "Records and results differ; restaurant intake and exercise burn estimates need calibration first."
        }
        if proteinRate >= 0.85 {
            return isChinese ? "过去14天蛋白质达标率提升后，体重下降节奏更稳定。" : "As protein adherence improved over 14 days, weight change became steadier."
        }
        return risks.first?.action ?? (isChinese ? "当前策略仍有效，未来7天重点保持记录一致性。" : "The current strategy remains effective; keep logging consistent for 7 days.")
    }

    private func cycleChangeTrend(_ data: AdvancedModeSnapshot) -> [Double] {
        trendValues(start: data.cycle.startWeightKg, end: data.cycle.currentWeightKg, count: 14, wave: 0.16)
    }

    private func dataConsistency(_ data: AdvancedModeSnapshot) -> AdvancedDataConsistency {
        let elapsedDays = max(data.cycle.elapsedDays, 1)
        let theoreticalLoss = max(Double(bodyScore.calorieDelta * elapsedDays) / 7700.0, 0)
        let actualLoss = max(data.cycle.startWeightKg - data.cycle.currentWeightKg, 0)
        let difference = abs(theoreticalLoss - actualLoss)
        let isAligned = difference <= 0.6
        let possibleReasons: [String]
        let recommendation: String

        if isAligned {
            possibleReasons = [
                isChinese ? "记录与体重变化基本一致" : "Records align with bodyweight change",
                isChinese ? "当前热量估算可继续使用" : "Current calorie estimates remain useful"
            ]
            recommendation = isChinese ? "未来7天维持当前记录方式，并继续固定时间称重。" : "For the next 7 days, keep the current logging method and weigh in at a fixed time."
        } else {
            possibleReasons = [
                isChinese ? "外食热量可能被低估" : "Restaurant calories may be underestimated",
                isChinese ? "油脂或调味未完整计入" : "Oil or sauces may be undercounted",
                isChinese ? "活动消耗可能被高估" : "Activity expenditure may be overestimated",
                isChinese ? "水分波动影响短期体重" : "Water fluctuation may affect short-term weight"
            ]
            recommendation = isChinese ? "未来7天固定早餐记录方式，固定时间称重，外食默认增加10g脂肪估算。" : "For the next 7 days, standardize breakfast logging, weigh in at a fixed time, and add 10g fat estimate for restaurant meals."
        }

        return .init(
            theoretical: theoreticalLoss,
            actual: actualLoss,
            difference: difference,
            judgment: isAligned ? (isChinese ? "记录与结果基本一致" : "Records match results") : (isChinese ? "记录与结果存在差异" : "Records and results differ"),
            tint: isAligned ? MKColor.green : MKColor.citrus,
            trustScore: max(45, min(98, Int((1 - min(difference / 1.5, 1)) * 100))),
            possibleReasons: possibleReasons,
            recommendation: recommendation
        )
    }

    private func riskDeviations(_ data: AdvancedModeSnapshot) -> [AdvancedDiagnosisRisk] {
        var risks: [AdvancedDiagnosisRisk] = []
        let deficit = bodyScore.calorieDelta
        let proteinRate = Double(appState.eatenMacros.protein) / Double(max(data.nutritionPlan.protein, 1))
        let sleep = data.recovery.sleepHours
        let trainingRate = data.currentCycleCompletions.map(\.training).average

        if deficit > 900 {
            risks.append(.init(
                title: isChinese ? "热量缺口偏大" : "High calorie deficit",
                severity: isChinese ? "高" : "High",
                trigger: isChinese ? "近7天平均缺口 \(deficit) kcal，高于当前周期建议范围。" : "7-day average deficit is \(deficit) kcal, above the suggested range.",
                impact: isChinese ? "恢复下降，保肌风险增加。" : "Recovery may decline and lean-mass retention risk increases.",
                action: isChinese ? "未来3天增加30~50g碳水。" : "Add 30-50g carbs for the next 3 days.",
                tint: MKColor.citrus
            ))
        }
        if proteinRate < 0.75 {
            risks.append(.init(
                title: isChinese ? "蛋白质不足" : "Protein low",
                severity: proteinRate < 0.6 ? (isChinese ? "高" : "High") : (isChinese ? "中" : "Medium"),
                trigger: isChinese ? "蛋白质达标率 \(Int(proteinRate * 100))%，低于当前周期要求。" : "Protein adherence is \(Int(proteinRate * 100))%, below this cycle's target.",
                impact: isChinese ? "保肌效率下降，饥饿感和恢复压力可能增加。" : "Lean-mass retention may drop and recovery pressure may rise.",
                action: isChinese ? "今天优先补足低脂蛋白，目标至少达到 \(data.nutritionPlan.protein)g。" : "Prioritize lean protein today and reach at least \(data.nutritionPlan.protein)g.",
                tint: MKColor.citrus
            ))
        }
        if sleep < 6.5 {
            risks.append(.init(
                title: isChinese ? "恢复不足" : "Recovery low",
                severity: sleep < 6 ? (isChinese ? "高" : "High") : (isChinese ? "中" : "Medium"),
                trigger: isChinese ? "近5天平均睡眠约 \(String(format: "%.1f", sleep))h，低于恢复目标。" : "Recent average sleep is about \(String(format: "%.1f", sleep))h, below target.",
                impact: isChinese ? "训练表现和恢复能力可能下降。" : "Training performance and recovery capacity may decline.",
                action: isChinese ? "增加1天主动恢复，下一次训练RPE上限控制在8。" : "Add one active recovery day and cap the next session at RPE 8.",
                tint: MKColor.coral
            ))
        }
        if trainingRate < 0.7 {
            risks.append(.init(
                title: isChinese ? "训练刺激不足" : "Low training stimulus",
                severity: isChinese ? "中" : "Medium",
                trigger: isChinese ? "训练完成率 \(Int(trainingRate * 100))%，低于当前周期节奏。" : "Training adherence is \(Int(trainingRate * 100))%, below cycle rhythm.",
                impact: isChinese ? "身体变化可能低于预期。" : "Body change may lag behind expectations.",
                action: isChinese ? "未来7天优先保证计划训练，不额外增加饮食限制。" : "For 7 days, prioritize planned sessions without adding more diet restriction.",
                tint: Color.blue
            ))
        }

        if risks.isEmpty {
            risks.append(.init(
                title: isChinese ? "暂无关键风险" : "No key risk",
                severity: isChinese ? "低" : "Low",
                trigger: isChinese ? "当前周期未发现明显过度执行或异常偏差。" : "No clear over-execution or abnormal drift detected.",
                impact: isChinese ? "当前计划可以继续观察。" : "The current plan can continue to be monitored.",
                action: isChinese ? "维持当前执行，7天后复查趋势。" : "Maintain current execution and review trends in 7 days.",
                tint: MKColor.green
            ))
        }
        return Array(risks.prefix(3))
    }

    private func resultAttributions(_ data: AdvancedModeSnapshot) -> [AdvancedAttributionItem] {
        let nutritionRate = data.currentCycleCompletions.map(\.nutrition).average
        let trainingRate = data.currentCycleCompletions.map(\.training).average
        let supplementRate = data.currentCycleCompletions.map(\.supplement).average
        let sleep = data.recovery.sleepHours
        return [
            .init(title: isChinese ? "饮食执行" : "Nutrition", status: nutritionRate >= 0.8 ? (isChinese ? "良好" : "Good") : (isChinese ? "需关注" : "Watch"), detail: nutritionRate >= 0.8 ? (isChinese ? "热量控制整体稳定。" : "Calorie control is stable.") : (isChinese ? "记录与执行仍有偏差。" : "Logging and execution still drift."), tint: nutritionRate >= 0.8 ? MKColor.green : MKColor.citrus),
            .init(title: isChinese ? "训练刺激" : "Training", status: trainingRate >= 0.85 ? (isChinese ? "优秀" : "Strong") : (isChinese ? "不足" : "Low"), detail: trainingRate >= 0.85 ? (isChinese ? "训练完成率维持在高位。" : "Training adherence remains high.") : (isChinese ? "训练刺激可能不足。" : "Training stimulus may be insufficient."), tint: trainingRate >= 0.85 ? MKColor.green : Color.blue),
            .init(title: isChinese ? "恢复质量" : "Recovery", status: sleep >= 7 ? (isChinese ? "稳定" : "Stable") : (isChinese ? "需关注" : "Watch"), detail: sleep >= 7 ? (isChinese ? "睡眠支持当前训练压力。" : "Sleep supports current training stress.") : (isChinese ? "睡眠不足影响恢复。" : "Low sleep is limiting recovery."), tint: sleep >= 7 ? MKColor.green : MKColor.citrus),
            .init(title: isChinese ? "补剂执行" : "Supplements", status: supplementRate >= 0.85 ? (isChinese ? "稳定" : "Stable") : (isChinese ? "偏低" : "Low"), detail: supplementRate >= 0.85 ? (isChinese ? "补剂执行保持稳定。" : "Supplement execution is stable.") : (isChinese ? "补剂记录需要补齐。" : "Supplement logging needs consistency."), tint: supplementRate >= 0.85 ? MKColor.green : Color.blue)
        ]
    }

    private func nextAdjustments(_ data: AdvancedModeSnapshot, consistency: AdvancedDataConsistency) -> [String] {
        var actions: [String] = []
        let deficit = bodyScore.calorieDelta
        let proteinRate = Double(appState.eatenMacros.protein) / Double(max(data.nutritionPlan.protein, 1))
        if deficit > 900 {
            actions.append(isChinese ? "未来7天增加30~40g碳水，将热量缺口拉回合理区间。" : "For 7 days, add 30-40g carbs to bring the deficit back into range.")
        }
        if proteinRate < 0.85 {
            actions.append(isChinese ? "蛋白质提高至\(max(data.nutritionPlan.protein, 130))g以上，优先低脂蛋白。" : "Raise protein to at least \(max(data.nutritionPlan.protein, 130))g with lean sources.")
        }
        if consistency.difference > 0.6 {
            actions.append(isChinese ? "外食默认增加10g脂肪估算，并固定早餐记录模板。" : "Add a default 10g fat estimate for restaurant meals and standardize breakfast logging.")
        }
        if data.recovery.sleepHours < 6.8 {
            actions.append(isChinese ? "增加1天主动恢复，下一次训练RPE上限控制在8。" : "Add one active recovery day and cap the next session at RPE 8.")
        }
        if actions.isEmpty {
            actions.append(isChinese ? "维持当前训练量和饮食策略，7天后复查趋势。" : "Maintain current training and nutrition strategy, then review the trend in 7 days.")
        }
        return Array(actions.prefix(4))
    }

    private func signedValue(_ value: Double, unit: String) -> String {
        if abs(value) < 0.05 { return "0 \(unit)" }
        return "\(value > 0 ? "+" : "")\(String(format: "%.1f", value)) \(unit)"
    }

    private func bodyChangeRows(_ data: AdvancedModeSnapshot) -> [AdvancedBodyChangeMetric] {
        let weightDelta = data.cycle.currentWeightKg - data.cycle.startWeightKg
        let bodyFat = data.cycle.targetBodyFatPercent ?? 18
        let waist = 82.0
        let leanMass = data.cycle.currentWeightKg * (1 - bodyFat / 100)
        return [
            .init(
                title: isChinese ? "体重" : "Weight",
                value: String(format: "%.1f kg", data.cycle.currentWeightKg),
                caption: trendCaption(delta: weightDelta, unit: "kg", days: 30),
                tint: weightDelta <= 0 ? MKColor.green : Color.blue,
                values: trendValues(start: data.cycle.startWeightKg, end: data.cycle.currentWeightKg, count: 14, wave: 0.18)
            ),
            .init(
                title: isChinese ? "体脂率" : "Body Fat",
                value: data.cycle.targetBodyFatPercent.map { String(format: "%.1f%%", $0) } ?? "--",
                caption: isChinese ? "近30天 ↓2%" : "30d ↓2%",
                tint: MKColor.green,
                values: trendValues(start: bodyFat + 2, end: bodyFat, count: 14, wave: 0.10)
            ),
            .init(
                title: isChinese ? "腰围" : "Waist",
                value: String(format: "%.0f cm", waist),
                caption: isChinese ? "近30天 ↓3cm" : "30d ↓3cm",
                tint: MKColor.green,
                values: trendValues(start: waist + 3, end: waist, count: 14, wave: 0.14)
            ),
            .init(
                title: isChinese ? "瘦体重" : "Lean Mass",
                value: String(format: "%.1f kg", leanMass),
                caption: isChinese ? "保持稳定" : "Stable",
                tint: Color.blue,
                values: trendValues(start: leanMass - 0.2, end: leanMass, count: 14, wave: 0.06)
            )
        ]
    }

    private func nutritionRingMetrics(_ data: AdvancedModeSnapshot) -> [AdvancedFitnessRingMetric] {
        let eaten = appState.eatenMacros
        return [
            .init(
                id: "protein",
                title: isChinese ? "蛋白质" : "Protein",
                current: Double(eaten.protein),
                target: Double(max(data.nutritionPlan.protein, 1)),
                value: "\(eaten.protein) / \(data.nutritionPlan.protein)g",
                tint: AdvancedFitnessRingColor.protein
            ),
            .init(
                id: "carbs",
                title: isChinese ? "碳水" : "Carbs",
                current: Double(eaten.carbs),
                target: Double(max(data.nutritionPlan.carbs, 1)),
                value: "\(eaten.carbs) / \(data.nutritionPlan.carbs)g",
                tint: AdvancedFitnessRingColor.carbs
            ),
            .init(
                id: "fat",
                title: isChinese ? "脂肪" : "Fat",
                current: Double(eaten.fat),
                target: Double(max(data.nutritionPlan.fat, 1)),
                value: "\(eaten.fat) / \(data.nutritionPlan.fat)g",
                tint: AdvancedFitnessRingColor.fat
            )
        ]
    }

    private func cycleWorkoutCount(_ data: AdvancedModeSnapshot) -> Int {
        appState.workouts.filter { workout in
            workout.createdAt >= data.cycle.startDate && workout.createdAt <= data.cycle.endDate
        }.count
    }

    private func trainingVolumeTrend(_ data: AdvancedModeSnapshot) -> [Double] {
        let workouts = appState.workouts
            .filter { $0.createdAt >= data.cycle.startDate && $0.createdAt <= data.cycle.endDate }
            .suffix(7)
            .map { Double(max($0.durationMinutes, 1)) }
        return workouts.isEmpty ? trendValues(start: 24, end: 48, count: 7, wave: 3) : workouts
    }

    private func recoveryTrendValues(_ data: AdvancedModeSnapshot) -> [Double] {
        trendValues(start: max(data.recovery.sleepHours - 0.6, 5.5), end: data.recovery.sleepHours, count: 7, wave: 0.18)
    }

    private func recoveryScoreTitle(_ data: AdvancedModeSnapshot) -> String {
        let sleepRate = min(data.recovery.sleepHours / 7.5, 1)
        let waterRate = min(Double(appState.waterCups) / 8.0, 1)
        let supplementRate = data.currentCycleCompletions.map(\.supplement).average
        let score = (sleepRate * 0.45 + waterRate * 0.25 + supplementRate * 0.30)
        if score >= 0.85 { return isChinese ? "优秀" : "Excellent" }
        if score >= 0.70 { return isChinese ? "正常" : "Normal" }
        return isChinese ? "需关注" : "Watch"
    }

    private func bodyTrendMetrics(_ data: AdvancedModeSnapshot) -> [AdvancedTrendMetric] {
        let weightDelta = data.cycle.currentWeightKg - data.cycle.startWeightKg
        let bodyFat = data.cycle.targetBodyFatPercent ?? 18
        return [
            .init(
                title: isChinese ? "体重" : "Weight",
                value: String(format: "%.1f kg", data.cycle.currentWeightKg),
                caption: trendCaption(delta: weightDelta, unit: "kg", days: 30),
                status: abs(weightDelta) < 0.2 ? (isChinese ? "稳定" : "Stable") : (weightDelta < 0 ? (isChinese ? "下降" : "Down") : (isChinese ? "上升" : "Up")),
                tint: weightDelta <= 0 ? MKColor.green : Color.blue,
                values: trendValues(start: data.cycle.startWeightKg, end: data.cycle.currentWeightKg, count: 14, wave: 0.18)
            ),
            .init(
                title: isChinese ? "体脂率" : "Body Fat",
                value: data.cycle.targetBodyFatPercent.map { String(format: "%.1f%%", $0) } ?? "--",
                caption: isChinese ? "↓ 2% 近30天" : "↓ 2% 30d",
                status: isChinese ? "改善" : "Improving",
                tint: MKColor.green,
                values: trendValues(start: bodyFat + 2, end: bodyFat, count: 14, wave: 0.10)
            )
        ]
    }

    private func nutritionTrendMetrics(_ data: AdvancedModeSnapshot) -> [AdvancedTrendMetric] {
        let deficit = bodyScore.calorieDelta
        let proteinRate = min(Double(appState.eatenMacros.protein) / Double(max(data.nutritionPlan.protein, 1)), 1.2)
        let nutritionCompletion = data.currentCycleCompletions.map(\.nutrition).average
        return [
            .init(
                title: isChinese ? "近14天平均热量差" : "14d Calorie Delta",
                value: "\(deficit) kcal",
                caption: calorieStatus(deficit),
                status: calorieStatus(deficit),
                tint: calorieTint(deficit),
                values: trendValues(start: Double(deficit) * 0.82, end: Double(deficit), count: 14, wave: 55)
            ),
            .init(
                title: isChinese ? "蛋白质达标率" : "Protein Target",
                value: "\(Int(proteinRate * 100))%",
                caption: proteinRate >= 0.85 ? (isChinese ? "优秀" : "Excellent") : (isChinese ? "需提升" : "Improve"),
                status: proteinRate >= 0.85 ? (isChinese ? "优秀" : "Excellent") : (isChinese ? "需提升" : "Improve"),
                tint: proteinRate >= 0.85 ? MKColor.green : MKColor.citrus,
                values: trendValues(start: max(proteinRate - 0.18, 0.4) * 100, end: proteinRate * 100, count: 14, wave: 4)
            ),
            .init(
                title: isChinese ? "饮食执行率" : "Nutrition Adherence",
                value: "\(Int(nutritionCompletion * 100))%",
                caption: isChinese ? "稳定" : "Stable",
                status: isChinese ? "稳定" : "Stable",
                tint: Color.blue,
                values: data.currentCycleCompletions.suffix(14).map { $0.nutrition * 100 }
            )
        ]
    }

    private func trainingTrendMetrics(_ data: AdvancedModeSnapshot) -> [AdvancedTrendMetric] {
        let trainingCompletion = data.currentCycleCompletions.map(\.training).average
        let cycleProgress = Double(data.cycle.elapsedDays) / Double(max(data.cycle.durationDays, 1))
        let cycleWorkouts = appState.workouts.filter { workout in
            workout.createdAt >= data.cycle.startDate && workout.createdAt <= data.cycle.endDate
        }
        let averageDuration = cycleWorkouts.map { Double($0.durationMinutes) }.average
        let durationValues = cycleWorkouts
            .suffix(14)
            .map { Double($0.durationMinutes) }
        let durationStatus = averageDuration >= 45 ? (isChinese ? "稳定" : "Stable") : (isChinese ? "偏短" : "Short")
        return [
            .init(
                title: isChinese ? "训练执行率" : "Training Adherence",
                value: "\(Int(trainingCompletion * 100))%",
                caption: trainingCompletion >= 0.85 ? (isChinese ? "稳定" : "Stable") : (isChinese ? "需关注" : "Watch"),
                status: trainingCompletion >= 0.85 ? (isChinese ? "稳定" : "Stable") : (isChinese ? "需关注" : "Watch"),
                tint: trainingCompletion >= 0.85 ? MKColor.green : MKColor.citrus,
                values: data.currentCycleCompletions.suffix(14).map { $0.training * 100 }
            ),
            .init(
                title: isChinese ? "总训练量" : "Total Volume",
                value: "48 Sets",
                caption: isChinese ? "周期累计" : "Cycle total",
                status: isChinese ? "正常" : "Normal",
                tint: Color.blue,
                values: trendValues(start: 18, end: 48, count: 14, wave: 2)
            ),
            .init(
                title: isChinese ? "平均训练时长" : "Avg Duration",
                value: averageDuration > 0 ? "\(Int(averageDuration.rounded())) min" : "-- min",
                caption: isChinese ? "周期平均" : "Cycle average",
                status: averageDuration > 0 ? durationStatus : (isChinese ? "待记录" : "No data"),
                tint: averageDuration >= 45 ? MKColor.green : MKColor.citrus,
                values: durationValues.isEmpty ? trendValues(start: 0, end: 0, count: 14, wave: 0) : durationValues
            ),
            .init(
                title: isChinese ? "周期完成度" : "Cycle Completion",
                value: "\(data.cycle.elapsedDays) / \(data.cycle.durationDays)",
                caption: "\(Int(cycleProgress * 100))%",
                status: isChinese ? "进行中" : "In progress",
                tint: MKColor.green,
                values: trendValues(start: 0, end: cycleProgress * 100, count: 14, wave: 0)
            )
        ]
    }

    private func recoveryTrendMetrics(_ data: AdvancedModeSnapshot) -> [AdvancedTrendMetric] {
        let sleepRate = min(data.recovery.sleepHours / 7.5, 1.2)
        let supplementRate = data.currentCycleCompletions.map(\.supplement).average
        let waterRate = min(Double(appState.waterCups) / 8.0, 1.2)
        return [
            .init(
                title: isChinese ? "睡眠达标率" : "Sleep Target",
                value: "\(Int(sleepRate * 100))%",
                caption: sleepRate >= 0.85 ? (isChinese ? "恢复正常" : "Normal") : (isChinese ? "恢复不足" : "Low"),
                status: sleepRate >= 0.85 ? (isChinese ? "恢复正常" : "Normal") : (isChinese ? "恢复不足" : "Low"),
                tint: sleepRate >= 0.85 ? MKColor.green : MKColor.citrus,
                values: trendValues(start: 72, end: sleepRate * 100, count: 14, wave: 5)
            ),
            .init(
                title: isChinese ? "平均睡眠时长" : "Avg Sleep",
                value: String(format: "%.1fh", data.recovery.sleepHours),
                caption: isChinese ? "近14天" : "14d",
                status: data.recovery.sleepHours >= 7 ? (isChinese ? "良好" : "Good") : (isChinese ? "偏低" : "Low"),
                tint: data.recovery.sleepHours >= 7 ? MKColor.green : MKColor.citrus,
                values: trendValues(start: max(data.recovery.sleepHours - 0.5, 5.5), end: data.recovery.sleepHours, count: 14, wave: 0.2)
            ),
            .init(
                title: isChinese ? "补剂执行率" : "Supplements",
                value: "\(Int(supplementRate * 100))%",
                caption: isChinese ? "周期趋势" : "Cycle trend",
                status: supplementRate >= 0.85 ? (isChinese ? "稳定" : "Stable") : (isChinese ? "需提升" : "Improve"),
                tint: supplementRate >= 0.85 ? MKColor.green : MKColor.citrus,
                values: data.currentCycleCompletions.suffix(14).map { $0.supplement * 100 }
            ),
            .init(
                title: isChinese ? "饮水达标率" : "Water Target",
                value: "\(Int(waterRate * 100))%",
                caption: isChinese ? "今日目标" : "Today target",
                status: waterRate >= 0.85 ? (isChinese ? "正常" : "Normal") : (isChinese ? "偏低" : "Low"),
                tint: waterRate >= 0.85 ? MKColor.green : Color.blue,
                values: trendValues(start: max(waterRate * 100 - 22, 45), end: waterRate * 100, count: 14, wave: 6)
            )
        ]
    }

    private func aiObservations(_ data: AdvancedModeSnapshot) -> [String] {
        var observations: [String] = []
        if bodyScore.calorieDelta > 900 {
            observations.append(isChinese ? "热量缺口偏大，建议增加30g碳水。" : "Calorie deficit is high. Add around 30g carbs.")
        } else {
            observations.append(isChinese ? "最近14天体重变化处于正常区间。" : "14-day weight change is within a normal range.")
        }
        let proteinRate = Double(appState.eatenMacros.protein) / Double(max(data.nutritionPlan.protein, 1))
        if proteinRate >= 0.85 {
            observations.append(isChinese ? "蛋白质达标率较高，饮食执行稳定。" : "Protein adherence is strong and nutrition is stable.")
        } else {
            observations.append(isChinese ? "蛋白质仍需补足，优先安排低脂蛋白。" : "Protein is still short. Prioritize lean protein.")
        }
        if data.recovery.sleepHours < 6.5 {
            observations.append(isChinese ? "睡眠恢复不足，建议降低下一次训练强度。" : "Sleep recovery is low. Reduce the next training load.")
        } else {
            observations.append(isChinese ? "恢复状态良好，适合继续执行当前周期。" : "Recovery is good. Continue the current cycle.")
        }
        return Array(observations.prefix(3))
    }

    private func trendValues(start: Double, end: Double, count: Int, wave: Double) -> [Double] {
        guard count > 1 else { return [end] }
        return (0..<count).map { index in
            let progress = Double(index) / Double(count - 1)
            return start + (end - start) * progress + sin(Double(index) * 0.9) * wave
        }
    }

    private func trendCaption(delta: Double, unit: String, days: Int) -> String {
        let arrow = delta <= 0 ? "↓" : "↑"
        return "\(arrow) \(String(format: "%.1f", abs(delta))) \(unit) \(isChinese ? "近\(days)天" : "\(days)d")"
    }

    private func calorieStatus(_ deficit: Int) -> String {
        if deficit > 900 { return isChinese ? "偏高" : "High" }
        if deficit < 300 { return isChinese ? "偏低" : "Low" }
        return isChinese ? "合理" : "Good"
    }

    private func calorieTint(_ deficit: Int) -> Color {
        if deficit > 900 { return MKColor.citrus }
        if deficit < 300 { return Color.blue }
        return MKColor.green
    }
}

private struct AdvancedBodyScoreSummary {
    let score: Int
    let title: String
    let message: String
    let tint: Color
    let calorieDelta: Int

    @MainActor
    static func make(snapshot: AdvancedModeSnapshot, appState: AppState, language: AppLanguage) -> AdvancedBodyScoreSummary {
        let isChinese = language == .simplifiedChinese
        let calorieDelta = appState.activeProfile.basalMetabolicRate + appState.activeProfile.activityCalories + appState.activeProfile.exerciseCalories - appState.eatenCalories
        let calorieScore: Double
        if calorieDelta >= 500 && calorieDelta <= 800 {
            calorieScore = 1
        } else if calorieDelta > 900 {
            calorieScore = 0.55
        } else {
            calorieScore = 0.75
        }
        let proteinScore = min(Double(appState.eatenMacros.protein) / Double(max(snapshot.nutritionPlan.protein, 1)), 1)
        let trainingScore = snapshot.currentCycleCompletions.map(\.training).average
        let sleepScore = min(snapshot.recovery.sleepHours / 7.5, 1)
        let recoveryExecution = (snapshot.currentCycleCompletions.map(\.supplement).average + min(Double(appState.waterCups) / 8.0, 1)) / 2
        let weightScore = snapshot.cycle.progress > 0 ? 0.88 : 0.76
        let rawScore = weightScore * 0.20 + calorieScore * 0.20 + proteinScore * 0.15 + trainingScore * 0.20 + sleepScore * 0.15 + recoveryExecution * 0.10
        let score = Int((rawScore * 100).rounded())

        let title: String
        let message: String
        let tint: Color
        if score >= 85 {
            title = isChinese ? "恢复良好" : "Recovered"
            message = isChinese ? "适合继续执行当前周期" : "Continue the current cycle"
            tint = MKColor.green
        } else if score >= 70 {
            title = isChinese ? "状态稳定" : "Stable"
            message = isChinese ? "保持当前节奏" : "Keep the current rhythm"
            tint = Color.blue
        } else if score >= 55 {
            title = isChinese ? "需要关注" : "Needs Attention"
            message = isChinese ? "建议微调饮食或恢复" : "Adjust nutrition or recovery"
            tint = MKColor.citrus
        } else {
            title = isChinese ? "压力偏高" : "High Strain"
            message = isChinese ? "建议降低训练强度" : "Reduce training intensity"
            tint = MKColor.coral
        }

        return AdvancedBodyScoreSummary(score: score, title: title, message: message, tint: tint, calorieDelta: calorieDelta)
    }
}

private struct AdvancedTrendMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let caption: String
    let status: String
    let tint: Color
    let values: [Double]
}

private struct AdvancedBodyChangeMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let caption: String
    let tint: Color
    let values: [Double]
}

private struct AdvancedCycleDiagnosis {
    let status: String
    let message: String
    let tint: Color
}

private struct AdvancedCycleChangeMetric: Identifiable {
    let id = UUID()
    let title: String
    let change: String
    let supportingText: String
    let tint: Color
}

private struct AdvancedDataConsistency {
    let theoretical: Double
    let actual: Double
    let difference: Double
    let judgment: String
    let tint: Color
    let trustScore: Int
    let possibleReasons: [String]
    let recommendation: String
}

private struct AdvancedTimelinePoint: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

private struct AdvancedDiagnosisRisk: Identifiable {
    let id = UUID()
    let title: String
    let severity: String
    let trigger: String
    let impact: String
    let action: String
    let tint: Color

    var primaryValue: String {
        trigger
            .replacingOccurrences(of: "近7天平均缺口 ", with: "")
            .replacingOccurrences(of: "蛋白质达标率 ", with: "")
            .replacingOccurrences(of: "近5天平均睡眠约 ", with: "")
            .components(separatedBy: "，")
            .first ?? trigger
    }
}

private struct AdvancedAttributionItem: Identifiable {
    let id = UUID()
    let title: String
    let status: String
    let detail: String
    let tint: Color
}

private struct AdvancedCycleProjection {
    let startWeight: Double
    let targetWeight: Double
    let currentWeight: Double
    let predictedWeight: Double
    let targetMissKg: Double
    let canHitTarget: Bool
    let judgment: String
    let tint: Color
}

private struct AdvancedBodyFatProjection {
    let target: Double
    let current: Double
    let predicted: Double
}

private struct AdvancedExecutionRates {
    let nutrition: Double
    let training: Double
    let recovery: Double
    let supplement: Double
}

private struct AdvancedLimitingFactor {
    let title: String
    let value: String
    let target: String
    let impact: String
    let tint: Color
    let score: Double
}

private struct AdvancedDeviationSummary {
    let targetWeekly: Double
    let actualWeekly: Double
    let weeklyGap: Double
    let conclusion: String
}

private struct AdvancedProjectionScenario: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tint: Color
}

private struct AdvancedCycleMatch {
    let score: Int
    let status: String
    let message: String
    let plannedProgress: Double
    let actualProgress: Double
    let tint: Color
}

private enum AdvancedTrendDirection {
    case up
    case down
    case flat

    var symbol: String {
        switch self {
        case .up:
            return "arrow.up.right"
        case .down:
            return "arrow.down.right"
        case .flat:
            return "arrow.right"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .up:
            return "Increasing"
        case .down:
            return "Decreasing"
        case .flat:
            return "Flat"
        }
    }
}

private struct AdvancedTrendRecord: Identifiable {
    let id = UUID()
    let label: String
    let value: Double?
}

private struct AdvancedCoreTrend: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let direction: AdvancedTrendDirection
    let tint: Color
    let records: [AdvancedTrendRecord]
    let unit: String
    let todayIndex: Int
}

private struct AdvancedStatusSurface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(24)
        .background(
            Color(
                light: UIColor(red: 1, green: 1, blue: 1, alpha: 0.88),
                dark: UIColor(red: 0.082, green: 0.094, blue: 0.110, alpha: 1)
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MKTheme.divider.opacity(0.38), lineWidth: 0.6)
        )
        .shadow(color: MKTheme.shadow.opacity(0.35), radius: 12, x: 0, y: 5)
    }
}

private struct AdvancedStatusSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(MKTheme.ink)
    }
}

private struct AdvancedCycleControlHero: View {
    let cycle: AdvancedBodyCycle
    let match: AdvancedCycleMatch
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedStatusSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(cycle.kind.title(language: language))
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(MKTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(isChinese ? "第\(cycle.currentWeek)周 / 共\(max(cycle.durationDays / 7, 1))周" : "Week \(cycle.currentWeek) / \(max(cycle.durationDays / 7, 1))")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(MKTheme.secondaryText)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(isChinese ? "健康指数" : "Health")
                            .font(.caption2.weight(.regular))
                            .foregroundStyle(MKTheme.secondaryText)
                        Text("\(match.score)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(match.tint)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(match.tint.opacity(0.10), in: Capsule())
                }

                Text(match.status)
                    .font(.system(size: 21, weight: .medium, design: .rounded))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(match.message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(MKTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AdvancedProgressComparisonBar: View {
    let planned: Double
    let actual: Double
    let tint: Color

    var body: some View {
        ZStack(alignment: .leading) {
            MKCapsuleProgressBar(progress: planned, tint: tint.opacity(0.32), height: 8)
            MKCapsuleProgressBar(progress: actual, tint: tint, height: 8, showsTrack: false)
        }
        .frame(height: 8)
    }
}

private struct AdvancedCoreTrendsCard: View {
    let trends: [AdvancedCoreTrend]
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedStatusSurface {
            AdvancedStatusSectionTitle(title: isChinese ? "趋势" : "Trends")
            VStack(spacing: 13) {
                ForEach(trends) { trend in
                    AdvancedCoreTrendRow(trend: trend)
                }
            }
        }
    }
}

private struct AdvancedCoreTrendRow: View {
    let trend: AdvancedCoreTrend

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(trend.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(MKTheme.ink)
                if trend.value.isEmpty {
                    Image(systemName: trend.direction.symbol)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(trend.tint)
                        .frame(height: 16, alignment: .leading)
                        .accessibilityLabel(trend.direction.accessibilityLabel)
                } else {
                    Text(trend.value)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MKTheme.secondaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
            .frame(width: 56, alignment: .leading)

            AdvancedTrendBarStrip(records: trend.records, tint: trend.tint, todayIndex: trend.todayIndex)
                .frame(height: 24)
        }
        .padding(.vertical, 1)
    }
}

private struct AdvancedTrendBarStrip: View {
    let records: [AdvancedTrendRecord]
    let tint: Color
    let todayIndex: Int
    @State private var hasPositionedToday = false

    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let visibleRecords = records.isEmpty ? [AdvancedTrendRecord(label: "D1", value: nil)] : records
            let contentWidth = CGFloat(visibleRecords.count) * barWidth + CGFloat(max(visibleRecords.count - 1, 0)) * barSpacing
            let normalized = normalizedValues(for: visibleRecords)

            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: barSpacing) {
                        ForEach(Array(visibleRecords.enumerated()), id: \.offset) { index, record in
                            MKCapsuleProgressColumn(
                                progress: barProgress(record: record, normalized: normalized[index], availableHeight: proxy.size.height),
                                tint: record.value == nil ? MKTheme.secondaryText.opacity(0.35) : tint,
                                minFillHeight: record.value == nil ? 0 : 2,
                                showsShadow: false
                            )
                            .frame(width: barWidth, height: proxy.size.height)
                                .id(index)
                                .accessibilityLabel(record.label)
                                .accessibilityValue(record.value.map { String(format: "%.1f", $0) } ?? "No record")
                        }
                    }
                    .frame(width: max(contentWidth, proxy.size.width), height: proxy.size.height, alignment: .bottomLeading)
                }
                .onAppear {
                    positionToday(with: scrollProxy, recordCount: visibleRecords.count)
                }
                .onChange(of: todayIndex) { _, _ in
                    hasPositionedToday = false
                    positionToday(with: scrollProxy, recordCount: visibleRecords.count)
                }
            }
        }
    }

    private func positionToday(with proxy: ScrollViewProxy, recordCount: Int) {
        guard !hasPositionedToday else { return }
        let targetIndex = min(max(todayIndex, 0), max(recordCount - 1, 0))
        DispatchQueue.main.async {
            proxy.scrollTo(targetIndex, anchor: .trailing)
            hasPositionedToday = true
        }
    }

    private func barProgress(record: AdvancedTrendRecord, normalized: Double, availableHeight: CGFloat) -> Double {
        let target = max(4, availableHeight * CGFloat(normalized))
        guard record.value != nil else {
            return min(max(target / max(availableHeight, 1), 0), 1)
        }
        return min(max(target / max(availableHeight, 1), 0), 1)
    }

    private func normalizedValues(for records: [AdvancedTrendRecord]) -> [Double] {
        let values = records.compactMap(\.value)
        guard let minValue = values.min(), let maxValue = values.max() else {
            return records.map { $0.value == nil ? 0.18 : 0.56 }
        }
        let spread = max(maxValue - minValue, max(abs(maxValue), 1) * 0.12)
        return records.map { record in
            guard let value = record.value else { return 0.18 }
            return 0.24 + ((clamped(value - minValue, lower: 0, upper: spread) / spread) * 0.76)
        }
    }

    private func clamped(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

private struct AdvancedTargetPredictionCard: View {
    let projection: AdvancedCycleProjection
    let bodyFat: AdvancedBodyFatProjection
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            AdvancedCompactSectionTitle(title: isChinese ? "目标 vs 当前 vs 预测" : "Target vs Current vs Prediction", symbol: "arrow.triangle.branch")
            VStack(spacing: 10) {
                AdvancedPredictionRow(
                    title: isChinese ? "目标体重" : "Target weight",
                    target: String(format: "%.1fkg", projection.targetWeight),
                    current: String(format: "%.1fkg", projection.currentWeight),
                    predicted: String(format: "%.1fkg", projection.predictedWeight),
                    tint: projection.tint,
                    language: language
                )
                AdvancedPredictionRow(
                    title: isChinese ? "目标体脂" : "Target body fat",
                    target: String(format: "%.1f%%", bodyFat.target),
                    current: String(format: "%.1f%%", bodyFat.current),
                    predicted: String(format: "%.1f%%", bodyFat.predicted),
                    tint: bodyFat.predicted <= bodyFat.target + 0.6 ? MKColor.green : MKColor.citrus,
                    language: language
                )
            }
        }
    }
}

private struct AdvancedPredictionRow: View {
    let title: String
    let target: String
    let current: String
    let predicted: String
    let tint: Color
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)
            HStack(alignment: .firstTextBaseline) {
                AdvancedMiniValue(label: isChinese ? "目标" : "Target", value: target)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText.opacity(0.65))
                AdvancedMiniValue(label: isChinese ? "当前" : "Current", value: current)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText.opacity(0.65))
                AdvancedMiniValue(label: isChinese ? "预测" : "Predicted", value: predicted, tint: tint)
            }
        }
    }
}

private struct AdvancedMiniValue: View {
    let label: String
    let value: String
    var tint: Color = MKTheme.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AdvancedLimitingFactorCard: View {
    let factor: AdvancedLimitingFactor
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            AdvancedCompactSectionTitle(title: isChinese ? "当前最大限制因素" : "Main Limiter", symbol: "target")
            HStack(alignment: .firstTextBaseline) {
                Text(factor.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                Spacer()
                Text(factor.value)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(factor.tint)
                    .monospacedDigit()
            }
            Text(factor.target)
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)
            Text(factor.impact)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MKTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AdvancedPlanAdherenceCard: View {
    let rates: AdvancedExecutionRates
    let limiterName: String
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }
    private var overallRate: Double {
        (rates.nutrition + rates.training + rates.recovery + rates.supplement) / 4
    }

    var body: some View {
        AdvancedStatusSurface {
            HStack(alignment: .center, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(overallRate * 100))%")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(MKTheme.ink)
                        .monospacedDigit()
                    Text(isChinese ? "综合执行率" : "Overall adherence")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MKTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 88, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    AdvancedStatusSectionTitle(title: isChinese ? "计划执行率" : "Plan Adherence")
                    VStack(spacing: 8) {
                        AdvancedAdherenceBar(title: isChinese ? "饮食" : "Nutrition", value: rates.nutrition, tint: rates.nutrition >= 0.85 ? MKColor.green : MKColor.citrus)
                        AdvancedAdherenceBar(title: isChinese ? "训练" : "Training", value: rates.training, tint: Color.blue)
                        AdvancedAdherenceBar(title: isChinese ? "恢复" : "Recovery", value: rates.recovery, tint: rates.recovery >= 0.85 ? MKColor.green : MKColor.citrus)
                        AdvancedAdherenceBar(title: isChinese ? "补剂" : "Supplements", value: rates.supplement, tint: MKTheme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(isChinese ? "\(limiterName)最低，是当前周期主要限制因素。" : "\(limiterName) is the lowest and is the current cycle limiter.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MKTheme.secondaryText)
        }
    }
}

private struct AdvancedAdherenceBar: View {
    let title: String
    let value: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MKTheme.secondaryText)
                .frame(width: 34, alignment: .leading)
            MKCapsuleProgressBar(progress: value, tint: tint, height: 4)
            Text("\(Int(value * 100))%")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MKTheme.ink)
                .monospacedDigit()
                .frame(width: 38, alignment: .trailing)
        }
    }
}

private struct AdvancedDeviationAnalysisCard: View {
    let summary: AdvancedDeviationSummary
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            AdvancedCompactSectionTitle(title: isChinese ? "偏差分析" : "Deviation Analysis", symbol: "arrow.left.and.right")
            Text(summary.conclusion)
                .font(.headline.weight(.bold))
                .foregroundStyle(MKTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(isChinese
                 ? "目标每周 \(String(format: "%.1fkg", summary.targetWeekly))，实际每周 \(String(format: "%.1fkg", summary.actualWeekly))，偏差 \(String(format: "%.1fkg", summary.weeklyGap))。"
                 : "Target \(String(format: "%.1fkg", summary.targetWeekly))/wk, actual \(String(format: "%.1fkg", summary.actualWeekly))/wk, gap \(String(format: "%.1fkg", summary.weeklyGap)).")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MKTheme.secondaryText)
        }
    }
}

private struct AdvancedCycleEndPredictionCard: View {
    let scenarios: [AdvancedProjectionScenario]
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedStatusSurface {
            AdvancedStatusSectionTitle(title: isChinese ? "周期结束预测" : "End Projection")
            VStack(spacing: 10) {
                ForEach(scenarios) { scenario in
                    HStack(alignment: .firstTextBaseline) {
                        Text(scenario.title)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(MKTheme.secondaryText)
                        Spacer()
                        Text(scenario.value)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(scenario.tint)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}

private struct AdvancedCycleDiagnosisHero: View {
    let diagnosis: AdvancedCycleDiagnosis
    let cycle: AdvancedBodyCycle
    let bodyScore: Int
    let cumulativeResult: String
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(cycle.kind.title(language: language))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)
                        Text(isChinese ? "第\(cycle.currentWeek)周 / 共\(max(cycle.durationDays / 7, 1))周" : "Week \(cycle.currentWeek) / \(max(cycle.durationDays / 7, 1))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MKTheme.secondaryText)
                    }
                    Spacer()
                    Text(isChinese ? "周期健康度 \(bodyScore)" : "Health \(bodyScore)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(diagnosis.tint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(diagnosis.tint.opacity(0.10), in: Capsule())
                }

                Text(diagnosis.status)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(cumulativeResult)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(diagnosis.tint)
                    .monospacedDigit()

                Text(diagnosis.message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AdvancedAIDiscoveryCard: View {
    let discovery: String
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.blue)
                    .frame(width: 30, height: 30)
                    .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(isChinese ? "AI发现" : "AI Finding")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.blue)
                    Text(discovery)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MKTheme.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct AdvancedCycleTimelineCard: View {
    let points: [AdvancedTimelinePoint]
    let metrics: [AdvancedCycleChangeMetric]
    let trendValues: [Double]
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            AdvancedCompactSectionTitle(title: isChinese ? "本周期结果" : "Cycle Result", symbol: "waveform.path.ecg")

            HStack(alignment: .center, spacing: 8) {
                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(point.title)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(MKTheme.secondaryText)
                        Text(point.value)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)
                            .monospacedDigit()
                    }
                    if index < points.count - 1 {
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(MKTheme.secondaryText.opacity(0.7))
                            .rotationEffect(.degrees(-90))
                    }
                }
            }

            HStack(spacing: 10) {
                ForEach(metrics.dropFirst()) { metric in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(metric.title)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(MKTheme.secondaryText)
                        Text(metric.change)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(metric.tint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            AdvancedSparklineView(values: trendValues, tint: MKColor.green)
                .frame(height: 30)
        }
    }
}

private struct AdvancedRecordTrustCard: View {
    let consistency: AdvancedDataConsistency
    let language: AppLanguage
    let onDetail: () -> Void

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(isChinese ? "记录可信度" : "Record Trust")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MKTheme.secondaryText)
                    Text("\(consistency.trustScore)%")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(consistency.tint)
                        .monospacedDigit()
                    Text(consistency.judgment)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MKTheme.ink)
                        .lineLimit(2)
                }
                Spacer()
                Button(action: onDetail) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MKTheme.secondaryText)
                        .frame(width: 34, height: 34)
                        .background(MKTheme.fill, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isChinese ? "查看记录可信度详情" : "View record trust details")
            }
        }
    }
}

private struct AdvancedConsistencyDetailSheet: View {
    let consistency: AdvancedDataConsistency
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        AdvancedSummaryPill(title: isChinese ? "理论变化" : "Expected", value: String(format: "-%.1fkg", consistency.theoretical))
                        AdvancedSummaryPill(title: isChinese ? "实际变化" : "Actual", value: String(format: "-%.1fkg", consistency.actual))
                        AdvancedSummaryPill(title: isChinese ? "差异" : "Gap", value: String(format: "%.1fkg", consistency.difference))
                    }
                    Text(consistency.judgment)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(consistency.tint)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isChinese ? "可能原因" : "Likely Reasons")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MKTheme.secondaryText)
                        ForEach(consistency.possibleReasons.prefix(4), id: \.self) { reason in
                            AdvancedBulletText(text: reason, tint: consistency.tint)
                        }
                    }
                    Divider().overlay(MKTheme.divider)
                    Text(consistency.recommendation)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MKTheme.ink)
                }
                .padding(20)
            }
            .background(MKTheme.background.ignoresSafeArea())
            .navigationTitle(isChinese ? "记录可信度" : "Record Trust")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isChinese ? "关闭" : "Close") { dismiss() }
                }
            }
        }
    }
}

private struct AdvancedCurrentRiskCard: View {
    let risks: [AdvancedDiagnosisRisk]
    let language: AppLanguage
    let onSelect: (AdvancedDiagnosisRisk) -> Void

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            HStack {
                AdvancedCompactSectionTitle(title: isChinese ? "当前风险" : "Current Risks", symbol: "exclamationmark.triangle")
                Text("\(risks.count)\(isChinese ? "项" : "")")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
            }
            VStack(spacing: 8) {
                ForEach(risks) { risk in
                    Button {
                        onSelect(risk)
                    } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Text(risk.severity)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(risk.tint)
                                .frame(width: 42, height: 28)
                                .background(risk.tint.opacity(0.10), in: Capsule())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(risk.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(MKTheme.ink)
                                Text(risk.primaryValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(MKTheme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MKTheme.secondaryText.opacity(0.75))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AdvancedRiskDetailSheet: View {
    let risk: AdvancedDiagnosisRisk
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(risk.severity)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(risk.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(risk.tint.opacity(0.10), in: Capsule())
                    Spacer()
                }
                Text(risk.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                AdvancedRiskDetailLine(title: isChinese ? "触发原因" : "Trigger", text: risk.trigger)
                AdvancedRiskDetailLine(title: isChinese ? "可能影响" : "Impact", text: risk.impact)
                AdvancedRiskDetailLine(title: isChinese ? "建议动作" : "Action", text: risk.action)
                Spacer()
            }
            .padding(20)
            .background(MKTheme.background.ignoresSafeArea())
            .navigationTitle(isChinese ? "风险详情" : "Risk Detail")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isChinese ? "关闭" : "Close") { dismiss() }
                }
            }
        }
    }
}

private struct AdvancedResultAttributionCard: View {
    let items: [AdvancedAttributionItem]
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            AdvancedCompactSectionTitle(title: isChinese ? "结果归因" : "Result Attribution", symbol: "point.3.connected.trianglepath.dotted")
            VStack(spacing: 10) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(item.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(MKTheme.ink)
                            Spacer()
                            Text(item.status)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(item.tint)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(item.tint.opacity(0.10), in: Capsule())
                        }
                        Text(item.detail)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MKTheme.secondaryText)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct AdvancedRiskDetailLine: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MKTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AdvancedNextAdjustmentCard: View {
    let actions: [String]
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            AdvancedCompactSectionTitle(title: isChinese ? "下一步调整" : "Next Adjustment", symbol: "slider.horizontal.3")
            Text(isChinese ? "未来3~7天" : "Next 3-7 days")
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MKTheme.card)
                            .frame(width: 22, height: 22)
                            .background(MKColor.green, in: Circle())
                        Text(action)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MKTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct AdvancedBulletText: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MKTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AdvancedCurrentBodyStateHero: View {
    let summary: AdvancedBodyScoreSummary
    let cycleName: String
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isChinese ? "当前状态" : "Current State")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MKTheme.secondaryText)
                        Text(summary.title)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(MKTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(summary.message)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MKTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Body Score")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(MKTheme.secondaryText)
                        Text("\(summary.score)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(summary.tint)
                            .monospacedDigit()
                    }
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(summary.tint)
                        .frame(width: 7, height: 7)
                    Text(isChinese ? "当前周期：\(cycleName)" : "Cycle: \(cycleName)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MKTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
    }
}

private struct AdvancedUnifiedBodyChangeCard: View {
    let metrics: [AdvancedBodyChangeMetric]
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            AdvancedCompactSectionTitle(title: isChinese ? "身体变化" : "Body Change", symbol: "figure")
            VStack(spacing: 14) {
                ForEach(metrics) { metric in
                    AdvancedBodyChangeRow(metric: metric)
                }
            }
        }
    }
}

private struct AdvancedBodyChangeRow: View {
    let metric: AdvancedBodyChangeMetric

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(metric.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
                Text(metric.value)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                    .monospacedDigit()
                Text(metric.caption)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(metric.tint)
                    .lineLimit(1)
            }
            .frame(width: 86, alignment: .leading)

            AdvancedSparklineView(values: metric.values, tint: metric.tint)
                .frame(height: 28)
        }
    }
}

private struct AdvancedNutritionExecutionCard: View {
    let metrics: [AdvancedFitnessRingMetric]
    let calorieDelta: Int
    let calorieStatus: String
    let calorieTint: Color
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            AdvancedCompactSectionTitle(title: isChinese ? "营养执行" : "Nutrition", symbol: "fork.knife")
            HStack(alignment: .center, spacing: 18) {
                AdvancedGoalCapsuleMatrix(metrics: metrics)
                    .scaleEffect(1.28)
                    .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(metrics.prefix(3)) { metric in
                        AdvancedNutritionMacroStatusRow(metric: metric, language: language)
                    }
                }
            }

            Divider()
                .overlay(MKTheme.divider)

            HStack {
                Text(isChinese ? "热量差" : "Calorie Delta")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
                Spacer()
                Text("\(calorieDelta) kcal")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                    .monospacedDigit()
                Text(calorieStatus)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(calorieTint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(calorieTint.opacity(0.10), in: Capsule())
            }
        }
    }
}

private struct AdvancedNutritionMacroStatusRow: View {
    let metric: AdvancedFitnessRingMetric
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }
    private var remaining: Int { max(Int(metric.target - metric.current), 0) }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(metric.tint)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(metric.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(metric.tint)
                    Text(metric.value)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                        .monospacedDigit()
                }
                Text(isChinese ? "剩余 \(remaining)g" : "\(remaining)g left")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)
            }
            Spacer(minLength: 0)
            Text("\(Int(metric.progress * 100))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)
                .monospacedDigit()
        }
    }
}

private struct AdvancedTrainingExecutionCard: View {
    let completionRate: Double
    let completedWorkouts: Int
    let plannedWorkouts: Int
    let totalVolume: Int
    let recentTraining: String
    let trendValues: [Double]
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            AdvancedCompactSectionTitle(title: isChinese ? "训练执行" : "Training", symbol: "figure.strengthtraining.traditional")
            HStack(spacing: 12) {
                AdvancedSummaryPill(title: isChinese ? "完成率" : "Adherence", value: "\(Int(completionRate * 100))%")
                AdvancedSummaryPill(title: isChinese ? "训练次数" : "Workouts", value: "\(completedWorkouts) / \(max(plannedWorkouts, completedWorkouts))")
            }
            HStack(spacing: 12) {
                AdvancedSummaryPill(title: isChinese ? "累计训练量" : "Volume", value: "\(totalVolume) sets")
                AdvancedSummaryPill(title: isChinese ? "最近训练" : "Recent", value: recentTraining)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(isChinese ? "训练量趋势" : "Volume Trend")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
                AdvancedSparklineView(values: trendValues, tint: MKColor.green)
                    .frame(height: 30)
            }
        }
    }
}

private struct AdvancedRecoveryStateCard: View {
    let sleepHours: Double
    let sleepRate: Double
    let waterRate: Double
    let supplementRate: Double
    let scoreTitle: String
    let trendValues: [Double]
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            AdvancedCompactSectionTitle(title: isChinese ? "恢复状态" : "Recovery", symbol: "heart.text.square")
            HStack(spacing: 12) {
                AdvancedSummaryPill(title: isChinese ? "睡眠" : "Sleep", value: String(format: "%.1fh", sleepHours))
                AdvancedSummaryPill(title: isChinese ? "达标率" : "Target", value: "\(Int(sleepRate * 100))%")
            }
            HStack(spacing: 12) {
                AdvancedSummaryPill(title: isChinese ? "饮水" : "Water", value: "\(Int(waterRate * 100))%")
                AdvancedSummaryPill(title: isChinese ? "补剂" : "Supplements", value: "\(Int(supplementRate * 100))%")
                AdvancedSummaryPill(title: isChinese ? "恢复评分" : "Score", value: scoreTitle)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(isChinese ? "7天趋势" : "7d Trend")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
                AdvancedSparklineView(values: trendValues, tint: sleepRate >= 0.85 ? MKColor.green : MKColor.citrus)
                    .frame(height: 30)
            }
        }
    }
}

private struct AdvancedSummaryPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(MKTheme.fill.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AdvancedCompactSectionTitle: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.blue)
                .frame(width: 28, height: 28)
                .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(MKTheme.ink)
            Spacer(minLength: 0)
        }
    }
}

private struct AdvancedBodyScoreCard: View {
    let summary: AdvancedBodyScoreSummary
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(MKTheme.track, lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: Double(summary.score) / 100)
                        .stroke(summary.tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(summary.score)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(MKTheme.ink)
                        .monospacedDigit()
                }
                .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Body Score")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MKTheme.secondaryText)
                    Text(summary.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                    Text(summary.message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MKTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(isChinese ? "综合体重、营养、训练与恢复趋势" : "From body, nutrition, training, and recovery trends")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MKTheme.secondaryText.opacity(0.85))
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct AdvancedStatusSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdvancedSectionHeader(title: title)
            content
        }
    }
}

private struct AdvancedStatusMetricGrid: View {
    let metrics: [AdvancedTrendMetric]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(metrics) { metric in
                AdvancedTrendMetricCard(metric: metric)
            }
        }
    }
}

private struct AdvancedTrendMetricCard: View {
    let metric: AdvancedTrendMetric

    private var shouldShowCaption: Bool {
        metric.caption.trimmingCharacters(in: .whitespacesAndNewlines) != metric.status.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(metric.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
                    .lineLimit(2)
                Spacer(minLength: 6)
                Text(metric.status)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(metric.tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(metric.tint.opacity(0.10), in: Capsule())
            }
            Text(metric.value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(MKTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .monospacedDigit()
            if shouldShowCaption {
                Text(metric.caption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            AdvancedSparklineView(values: metric.values, tint: metric.tint)
                .frame(height: 30)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MKTheme.divider.opacity(0.55), lineWidth: 0.7)
        )
    }
}

private struct AdvancedSparklineView: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let normalized = normalizedValues
            ZStack {
                if normalized.count < 2 {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                    }
                    .stroke(MKTheme.track, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                } else {
                    Path { path in
                        for index in normalized.indices {
                            let x = proxy.size.width * CGFloat(index) / CGFloat(max(normalized.count - 1, 1))
                            let y = proxy.size.height * (1 - CGFloat(normalized[index]))
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var normalizedValues: [Double] {
        guard let minValue = values.min(), let maxValue = values.max(), maxValue > minValue else {
            return values.map { _ in 0.5 }
        }
        return values.map { ($0 - minValue) / (maxValue - minValue) }
    }
}

private struct AdvancedAIObservationCard: View {
    let observations: [String]
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedCard {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.blue)
                    .frame(width: 30, height: 30)
                    .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(isChinese ? "AI观察" : "AI Observations")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(observations.enumerated()), id: \.offset) { _, observation in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(observation)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MKTheme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

struct AdvancedCycleLogView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedDate = Date()
    @State private var showFullCalendar = false
    @State private var selectedCycleRecord: AdvancedCycleRecord?
    @State private var cachedSnapshot: AdvancedModeSnapshot?

    private var snapshot: AdvancedModeSnapshot { cachedSnapshot ?? .make(from: appState) }
    private var isChinese: Bool { appState.language == .simplifiedChinese }
    private let calendar = Calendar.current

    private var selectedCalendarDay: AdvancedCalendarDay? {
        snapshot.currentCycleCalendarDays.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        let data = snapshot
        AdvancedScreen(title: isChinese ? "档案" : "History", subtitle: isChinese ? "我的周期执行档案" : "My cycle archive", trailing: .calendarButton(appState.language) { showFullCalendar = true }) {
            AdvancedCycleCalendarRow(
                cycle: data.cycle,
                calendarDays: data.currentCycleCalendarDays,
                selectedDate: $selectedDate,
                language: appState.language
            )

            if let selectedCalendarDay {
                AdvancedSelectedCycleDayCard(
                    cycle: data.cycle,
                    day: selectedCalendarDay,
                    nutritionPlan: data.nutritionPlan,
                    trainingPlan: data.trainingPlan,
                    supplements: data.supplements,
                    recovery: data.recovery,
                    language: appState.language
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                AdvancedArchiveSectionTitle(title: isChinese ? "历史周期档案" : "Cycle Archive")
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(data.cycleHistory) { record in
                        Button {
                            selectedCycleRecord = record
                        } label: {
                            AdvancedCycleHistoryCard(record: record, language: appState.language)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $showFullCalendar) {
            AdvancedFullCalendarSheet(
                cycle: data.cycle,
                calendarDays: data.currentCycleCalendarDays,
                language: appState.language
            )
        }
        .sheet(item: $selectedCycleRecord) { record in
            AdvancedCycleDetailView(record: record, language: appState.language)
        }
        .task(id: appState.advancedSnapshotCacheKey) {
            cachedSnapshot = .make(from: appState)
        }
    }
}

struct AdvancedAchievementsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("advancedCycleAlbumCustomizations.v1") private var albumCustomizationsPayload = "{}"
    @State private var sharingRecord: AdvancedCycleRecord?
    @State private var editingRecord: AdvancedCycleRecord?
    @State private var albumCustomizations: [String: AdvancedCycleAlbumCustomization] = [:]
    @State private var cachedSnapshot: AdvancedModeSnapshot?
    @State private var showsDeferredGallery = false

    private var snapshot: AdvancedModeSnapshot { cachedSnapshot ?? .make(from: appState) }
    private var isChinese: Bool { appState.language == .simplifiedChinese }

    var body: some View {
        AdvancedScreen(title: isChinese ? "成就" : "Achievements", subtitle: isChinese ? "成长作品馆" : "Growth Gallery") {
            let data = snapshot
            let heroRecord = representativeRecord(from: data) ?? currentCycleRecord(from: data)

            AdvancedCycleMasterpieceCard(
                cycle: data.cycle,
                record: heroRecord,
                customization: customization(for: heroRecord),
                completionRate: data.currentCycleCompletions.averageCompletion,
                language: appState.language,
                onEdit: { editingRecord = heroRecord },
                onShare: { sharingRecord = heroRecord }
            )

            AdvancedAchievementTimeline(
                items: timelineItems(from: data),
                language: appState.language
            )

            if showsDeferredGallery {
                AdvancedCycleWorksGallery(
                    records: galleryRecords(from: data),
                    language: appState.language,
                    customization: { customization(for: $0) },
                    onEdit: { editingRecord = $0 },
                    onShare: { sharingRecord = $0 }
                )

                AdvancedGrowthShareCenter(language: appState.language)
            }
        }
        .sheet(item: $sharingRecord) { record in
            AdvancedCycleSharePosterSheet(
                record: record,
                customization: customization(for: record),
                language: appState.language
            )
        }
        .sheet(item: $editingRecord) { record in
            AdvancedCycleAlbumEditSheet(
                record: record,
                customization: customization(for: record),
                language: appState.language
            ) { updated in
                saveCustomization(updated, for: record)
            }
        }
        .task(id: appState.advancedSnapshotCacheKey) {
            cachedSnapshot = .make(from: appState)
        }
        .task(id: albumCustomizationsPayload) {
            albumCustomizations = storedAlbumCustomizations()
        }
        .task(id: appState.advancedSnapshotCacheKey + albumCustomizationsPayload) {
            showsDeferredGallery = false
            try? await Task.sleep(for: .milliseconds(140))
            showsDeferredGallery = true
        }
    }

    private func representativeRecord(from data: AdvancedModeSnapshot) -> AdvancedCycleRecord? {
        let perfectRecords = data.cycleHistory.filter { $0.isPerfect && $0.status == .completed }
        return perfectRecords.first ?? data.cycleHistory.first(where: { $0.status == .completed }) ?? data.cycleHistory.first
    }

    private func galleryRecords(from data: AdvancedModeSnapshot) -> [AdvancedCycleRecord] {
        let currentRecord = currentCycleRecord(from: data)
        return [currentRecord] + data.cycleHistory
    }

    private func currentCycleRecord(from data: AdvancedModeSnapshot) -> AdvancedCycleRecord {
        let workoutCount = currentCycleWorkoutCount(data)
        return AdvancedCycleRecord(
            name: data.cycle.name,
            kind: data.cycle.kind,
            status: data.cycle.status,
            startDate: data.cycle.startDate,
            endDate: data.cycle.endDate,
            completionRate: data.currentCycleCompletions.averageCompletion,
            executedDays: data.cycle.elapsedDays,
            keyResult: currentCycleResultText(data),
            aiReview: isChinese ? "当前周期正在形成新的作品。" : "This cycle is becoming a new work.",
            trainingCount: workoutCount,
            weightChangeKg: data.cycle.currentWeightKg - data.cycle.startWeightKg,
            bodyFatChangePercent: data.cycle.currentBodyFatPercentage - data.cycle.startBodyFatPercentage
        )
    }

    private func currentCycleWorkoutCount(_ data: AdvancedModeSnapshot) -> Int {
        appState.workouts.filter { workout in
            workout.createdAt >= data.cycle.startDate && workout.createdAt <= data.cycle.endDate
        }.count
    }

    private func currentCycleResultText(_ data: AdvancedModeSnapshot) -> String {
        let delta = data.cycle.currentWeightKg - data.cycle.startWeightKg
        let sign = delta < 0 ? "-" : "+"
        let workoutCount = currentCycleWorkoutCount(data)
        if isChinese {
            return "体重 \(sign)\(String(format: "%.1fkg", abs(delta)))，训练 \(workoutCount) 次"
        }
        return "Weight \(sign)\(String(format: "%.1fkg", abs(delta))), \(workoutCount) workouts"
    }

    private func timelineItems(from data: AdvancedModeSnapshot) -> [AdvancedTimelineMemory] {
        let completedCycle = data.cycleHistory.first(where: { $0.status == .completed })
        let items: [AdvancedTimelineMemory] = [
            .init(date: completedCycle?.endDate ?? data.cycle.startDate, title: isChinese ? "完成第一个周期" : "First cycle completed", detail: completedCycle?.keyResult ?? (isChinese ? "当前周期正在成为第一件作品。" : "The current cycle is becoming the first work.")),
            .init(date: Calendar.current.date(byAdding: .day, value: 30, to: data.cycle.startDate) ?? data.cycle.startDate, title: isChinese ? "减脂达到3kg" : "Reached 3kg fat loss", detail: isChinese ? "身体变化开始变得清晰可见。" : "Body change started to become visible."),
            .init(date: Calendar.current.date(byAdding: .day, value: 42, to: data.cycle.startDate) ?? data.cycle.startDate, title: isChinese ? "累计训练50次" : "50 trainings completed", detail: isChinese ? "训练从安排变成了作品的一部分。" : "Training became part of the work."),
            .init(date: Calendar.current.date(byAdding: .day, value: 49, to: data.cycle.startDate) ?? data.cycle.startDate, title: isChinese ? "体脂进入18%" : "Body fat reached 18%", detail: isChinese ? "结果开始沉淀为可以回看的里程碑。" : "The result became a milestone worth revisiting.")
        ]
        return items
    }

    private func customization(for record: AdvancedCycleRecord) -> AdvancedCycleAlbumCustomization {
        let key = albumKey(for: record)
        return albumCustomizations[key]
            ?? AdvancedCycleAlbumCustomization.defaultValue(for: record, language: appState.language)
    }

    private func saveCustomization(_ customization: AdvancedCycleAlbumCustomization, for record: AdvancedCycleRecord) {
        let key = albumKey(for: record)
        albumCustomizations[key] = customization

        var stored = storedAlbumCustomizations()
        stored[key] = customization
        if let data = try? JSONEncoder().encode(stored),
           let payload = String(data: data, encoding: .utf8) {
            albumCustomizationsPayload = payload
        }
    }

    private func storedAlbumCustomizations() -> [String: AdvancedCycleAlbumCustomization] {
        guard let data = albumCustomizationsPayload.data(using: .utf8),
              let stored = try? JSONDecoder().decode([String: AdvancedCycleAlbumCustomization].self, from: data) else {
            return [:]
        }
        return stored
    }

    private func albumKey(for record: AdvancedCycleRecord) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let start = Int(calendar.startOfDay(for: record.startDate).timeIntervalSince1970)
        let end = Int(calendar.startOfDay(for: record.endDate).timeIntervalSince1970)
        return "\(record.name)-\(start)-\(end)"
    }

}

private struct AdvancedCycleAlbumCustomization: Codable, Equatable {
    var albumName: String
    var summaryTitle: String
    var coverIndex: Int
    var coverImageData: Data?

    static func defaultValue(for record: AdvancedCycleRecord, language: AppLanguage) -> AdvancedCycleAlbumCustomization {
        let isChinese = language == .simplifiedChinese
        let title: String
        if record.completionRate >= 0.92 {
            title = isChinese ? "一轮完成度极高的身体作品" : "A highly completed body cycle"
        } else if record.status == .completed {
            title = isChinese ? "认真完成的一轮周期" : "A finished body cycle"
        } else {
            title = isChinese ? "正在成型的一轮周期" : "A body cycle in progress"
        }
        return AdvancedCycleAlbumCustomization(
            albumName: record.name,
            summaryTitle: title,
            coverIndex: abs(record.name.hashValue) % 3,
            coverImageData: nil
        )
    }
}

private enum AdvancedCycleAlbumMetricFormatter {
    static func cycleDays(_ record: AdvancedCycleRecord) -> String {
        "\(record.executedDays)"
    }

    static func trainingCount(from record: AdvancedCycleRecord) -> String {
        if let count = record.trainingCount {
            return "\(count)"
        }
        return trainingCount(from: record.keyResult)
    }

    static func weightChange(from record: AdvancedCycleRecord) -> String {
        if let value = record.weightChangeKg {
            return signedChange(value: value, unit: "kg")
        }
        return weightChange(from: record.keyResult)
    }

    static func bodyFatChange(from record: AdvancedCycleRecord) -> String {
        if let value = record.bodyFatChangePercent {
            return signedChange(value: value, unit: "%")
        }
        return bodyFatChange(from: record.keyResult)
    }

    static func trainingCount(from result: String) -> String {
        guard let count = firstIntegerMatch(in: result, patterns: [
            #"训练\s*(\d+)\s*次"#,
            #"(\d+)\s*次训练"#,
            #"(\d+)\s*workouts?"#,
            #"workouts?\s*(\d+)"#
        ]) else {
            return "-"
        }
        return "\(count)"
    }

    static func weightChange(from result: String) -> String {
        signedMetric(from: result, unitPattern: #"kg"#, displayUnit: "kg") ?? "-"
    }

    static func bodyFatChange(from result: String) -> String {
        signedMetric(from: result, unitPattern: #"%|％"#, displayUnit: "%") ?? "-"
    }

    static func signedChange(start: Double, end: Double, unit: String) -> String {
        guard start > 0, end > 0 else { return "-" }
        let delta = end - start
        let sign = delta >= 0 ? "+" : "-"
        return "\(sign)\(String(format: "%.1f", abs(delta)))\(unit)"
    }

    private static func signedChange(value: Double, unit: String) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(String(format: "%.1f", abs(value)))\(unit)"
    }

    private static func firstIntegerMatch(in text: String, patterns: [String]) -> Int? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text),
                  let value = Int(text[range]) else {
                continue
            }
            return value
        }
        return nil
    }

    private static func signedMetric(from text: String, unitPattern: String, displayUnit: String) -> String? {
        let pattern = #"([+-])\s*(\d+(?:\.\d+)?)\s*(?:"# + unitPattern + #")"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 2,
              let signRange = Range(match.range(at: 1), in: text),
              let valueRange = Range(match.range(at: 2), in: text),
              let value = Double(text[valueRange]) else {
            return nil
        }
        let sign = String(text[signRange]) == "-" ? "-" : "+"
        return "\(sign)\(String(format: "%.1f", value))\(displayUnit)"
    }
}

private struct AdvancedCycleMasterpieceCard: View {
    let cycle: AdvancedBodyCycle
    let record: AdvancedCycleRecord
    let customization: AdvancedCycleAlbumCustomization
    let completionRate: Double
    let language: AppLanguage
    let onEdit: () -> Void
    let onShare: () -> Void

    private var isChinese: Bool { language == .simplifiedChinese }
    private var status: String {
        return record.status.title(language: language)
    }
    private var days: Int { record.executedDays }
    private var completion: Double { record.completionRate }
    private var startWeightText: String { String(format: "%.1fkg", cycle.startWeightKg) }
    private var endWeightText: String {
        if record.status == .completed {
            return extractWeightResult(from: record.keyResult) ?? String(format: "%.1fkg", cycle.currentWeightKg)
        }
        return String(format: "%.1fkg", cycle.currentWeightKg)
    }
    private var dateStartText: String { dateText(record.startDate) }
    private var dateEndText: String { dateText(record.endDate) }
    private var reviewText: String {
        let score = record.score
        if score >= 90 { return isChinese ? "完美作品 \(score)分" : "Perfect \(score)" }
        if score >= 80 { return isChinese ? "优秀作品 \(score)分" : "Excellent \(score)" }
        if score >= 60 { return isChinese ? "合格作品 \(score)分" : "Qualified \(score)" }
        return isChinese ? "待提升 \(score)分" : "Needs improvement \(score)"
    }
    private var praiseText: String {
        let score = record.score
        if score >= 90 {
            return isChinese ? "这一周期最出色的是稳定执行：训练、饮食和恢复都被认真完成，结果自然沉淀下来。" : "The strongest part of this cycle was consistency: training, nutrition, and recovery were carried through."
        }
        if score >= 80 {
            return isChinese ? "这一周期最值得被看见的是持续推进，把计划从目标变成了真实记录。" : "The best part of this cycle was steady follow-through, turning the plan into a visible record."
        }
        return isChinese ? "这一周期最重要的是已经开始形成可回看的执行轨迹。" : "The most important part of this cycle is that it created a trace worth revisiting."
    }
    private var fatChangeText: String {
        let parsed = AdvancedCycleAlbumMetricFormatter.bodyFatChange(from: record)
        if parsed != "-" { return parsed }
        return AdvancedCycleAlbumMetricFormatter.signedChange(
            start: cycle.startBodyFatPercentage,
            end: cycle.currentBodyFatPercentage,
            unit: "%"
        )
    }
    private var weightChangeText: String {
        let parsed = AdvancedCycleAlbumMetricFormatter.weightChange(from: record)
        if parsed != "-" { return parsed }
        return AdvancedCycleAlbumMetricFormatter.signedChange(
            start: cycle.startWeightKg,
            end: cycle.currentWeightKg,
            unit: "kg"
        )
    }
    private var trainingCountText: String {
        AdvancedCycleAlbumMetricFormatter.trainingCount(from: record)
    }
    private var currentCycleResultText: String {
        let delta = cycle.currentWeightKg - cycle.startWeightKg
        if abs(delta) < 0.1 { return isChinese ? "体重保持稳定" : "Weight stable" }
        return delta < 0
            ? (isChinese ? "体重 -\(String(format: "%.1f", abs(delta)))kg" : "Weight -\(String(format: "%.1f", abs(delta)))kg")
            : (isChinese ? "体重 +\(String(format: "%.1f", delta))kg" : "Weight +\(String(format: "%.1f", delta))kg")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AdvancedCycleAlbumCover(
                title: record.name,
                seed: record.name,
                coverIndex: customization.coverIndex,
                imageData: customization.coverImageData
            )
            .frame(maxWidth: .infinity)
            .frame(height: 340)
            .overlay(alignment: .topTrailing) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.24), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(14)
                .accessibilityLabel(isChinese ? "编辑周期专辑" : "Edit cycle album")
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(customization.summaryTitle)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(praiseText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MKTheme.secondaryText)
                    .lineLimit(3)

                AdvancedCycleAlbumMetricsRow(
                    days: "\(days)",
                    training: trainingCountText,
                    weight: weightChangeText,
                    bodyFat: fatChangeText,
                    language: language
                )
                .padding(.top, 2)

                HStack(spacing: 10) {
                    AdvancedCycleReviewBadge(text: reviewText)

                    Spacer(minLength: 8)

                    Button(action: onShare) {
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
        .advancedAchievementGlassCard(cornerRadius: 32, shadowOpacity: 0, intensity: .hero)
    }

    private var weightDeltaText: String {
        let delta = cycle.currentWeightKg - cycle.startWeightKg
        if abs(delta) < 0.1 { return isChinese ? "稳定" : "Stable" }
        return delta < 0
            ? "-\(String(format: "%.1f", abs(delta)))kg"
            : "+\(String(format: "%.1f", delta))kg"
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans_CN" : "en_US")
        formatter.dateFormat = isChinese ? "yyyy.MM.dd" : "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    private func extractWeightResult(from result: String) -> String? {
        let pattern = #"(\d+(?:\.\d+)?)kg"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).last,
              let range = Range(match.range(at: 1), in: result) else {
            return nil
        }
        let value = String(result[range])
        if result.contains("-") {
            let end = max(cycle.startWeightKg - (Double(value) ?? 0), 0)
            return String(format: "%.1fkg", end)
        }
        return "\(value)kg"
    }
}

private struct AdvancedAchievementGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let shadowOpacity: Double
    let intensity: AdvancedAchievementGlassIntensity

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
            .shadow(color: .black.opacity(colorScheme == .dark ? shadowOpacity * 1.45 : shadowOpacity), radius: intensity.shadowRadius, x: 0, y: intensity.shadowY)
    }

    private var cardBase: Color {
        colorScheme == .dark ? MKTheme.card.opacity(0.96) : .white.opacity(intensity.whiteBaseOpacity)
    }

    private var materialOpacity: Double {
        colorScheme == .dark ? max(intensity.materialOpacity * 0.36, 0.05) : intensity.materialOpacity
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                .white.opacity(intensity.topHighlightOpacity * 0.18),
                MKColor.green.opacity(intensity.tintOpacity * 1.8),
                .black.opacity(intensity.bottomShadeOpacity * 1.25)
            ]
        }
        return [
            .white.opacity(intensity.topHighlightOpacity),
            MKColor.green.opacity(intensity.tintOpacity),
            .black.opacity(intensity.bottomShadeOpacity)
        ]
    }

    private var strokeColor: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .white.opacity(intensity.strokeOpacity)
    }

    private var borderColor: Color {
        colorScheme == .dark ? .black.opacity(0.32) : .black.opacity(intensity.borderOpacity)
    }
}

private enum AdvancedAchievementGlassIntensity {
    case hero
    case work
    case light
    case utility

    var materialOpacity: Double {
        switch self {
        case .hero: return 0.22
        case .work: return 0.18
        case .light: return 0.10
        case .utility: return 0.14
        }
    }

    var whiteBaseOpacity: Double {
        switch self {
        case .hero: return 0.94
        case .work: return 0.91
        case .light: return 0.86
        case .utility: return 0.88
        }
    }

    var topHighlightOpacity: Double {
        switch self {
        case .hero: return 0.34
        case .work: return 0.28
        case .light: return 0.22
        case .utility: return 0.24
        }
    }

    var tintOpacity: Double {
        switch self {
        case .hero: return 0.035
        case .work: return 0.026
        case .light: return 0.012
        case .utility: return 0.018
        }
    }

    var bottomShadeOpacity: Double {
        switch self {
        case .hero: return 0.045
        case .work: return 0.038
        case .light: return 0.020
        case .utility: return 0.028
        }
    }

    var strokeOpacity: Double {
        switch self {
        case .hero: return 0.78
        case .work: return 0.68
        case .light: return 0.58
        case .utility: return 0.62
        }
    }

    var borderOpacity: Double {
        switch self {
        case .hero: return 0.105
        case .work: return 0.095
        case .light: return 0.065
        case .utility: return 0.075
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .hero: return 13
        case .work: return 11
        case .light: return 7
        case .utility: return 8
        }
    }

    var shadowY: CGFloat {
        switch self {
        case .hero: return 7
        case .work: return 6
        case .light: return 4
        case .utility: return 5
        }
    }
}

private extension View {
    func advancedAchievementGlassCard(
        cornerRadius: CGFloat,
        shadowOpacity: Double = 0.20,
        intensity: AdvancedAchievementGlassIntensity = .work
    ) -> some View {
        modifier(AdvancedAchievementGlassCardModifier(cornerRadius: cornerRadius, shadowOpacity: shadowOpacity, intensity: intensity))
    }
}

private struct AdvancedCycleReviewBadge: View {
    let text: String
    var isCompact = false

    var body: some View {
        Text(text)
            .font((isCompact ? Font.caption2 : Font.caption).weight(.semibold))
            .foregroundStyle(MKColor.green)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, isCompact ? 10 : 12)
            .padding(.vertical, isCompact ? 7 : 8)
            .background(MKColor.green.opacity(0.12), in: Capsule())
    }
}

private struct AdvancedCycleAlbumMetricsRow: View {
    let days: String
    let training: String
    let weight: String
    let bodyFat: String
    let language: AppLanguage
    var isCompact = false

    var body: some View {
        HStack(spacing: 0) {
            AdvancedCycleAlbumMetricItem(value: days, unit: isChinese ? "天" : "d", label: isChinese ? "周期" : "Cycle", isCompact: isCompact)
            AdvancedCycleAlbumMetricItem(value: training, unit: training == "-" ? "" : (isChinese ? "次" : "x"), label: isChinese ? "训练" : "Training", isCompact: isCompact)
            AdvancedCycleAlbumMetricItem(value: numericPart(weight, unit: "kg"), unit: weight == "-" ? "" : "kg", label: isChinese ? "体重" : "Weight", isCompact: isCompact)
            AdvancedCycleAlbumMetricItem(value: numericPart(bodyFat, unit: "%"), unit: bodyFat == "-" ? "" : "%", label: isChinese ? "体脂" : "Fat", isCompact: isCompact)
        }
        .padding(.horizontal, isCompact ? 10 : 14)
        .padding(.vertical, isCompact ? 11 : 14)
        .background {
            RoundedRectangle(cornerRadius: isCompact ? 18 : 22, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.72))
                .overlay(MKTheme.fill.opacity(0.42))
        }
        .overlay {
            RoundedRectangle(cornerRadius: isCompact ? 18 : 22, style: .continuous)
                .stroke(MKTheme.divider.opacity(0.9), lineWidth: 0.7)
        }
    }

    private var isChinese: Bool { language == .simplifiedChinese }

    private func numericPart(_ value: String, unit: String) -> String {
        value.replacingOccurrences(of: unit, with: "")
            .replacingOccurrences(of: "％", with: "")
            .replacingOccurrences(of: "%", with: "")
    }
}

private struct AdvancedCycleAlbumMetricItem: View {
    let value: String
    let unit: String
    let label: String
    var isCompact = false

    var body: some View {
        VStack(spacing: isCompact ? 5 : 7) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: isCompact ? 15 : 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: isCompact ? 9 : 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(MKTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: isCompact ? 18 : 24)

            Text(label)
                .font(.system(size: isCompact ? 10 : 12, weight: .medium))
                .foregroundStyle(MKTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AdvancedCycleAlbumCover: View {
    private static let imageCache = NSCache<NSData, UIImage>()

    let title: String
    let seed: String
    let coverIndex: Int
    var imageData: Data? = nil
    var showsTitleShadow = true

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
                    AdvancedCycleAlbumCoverArtwork(coverIndex: coverIndex)
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
                AdvancedCycleAlbumBrandMark()
                    .padding(min(max(size.width * 0.055, 12), 20))
            }
            .overlay(alignment: .bottomLeading) {
                Text(title)
                    .font(.system(size: min(max(size.width * 0.075, 17), 24), weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .shadow(color: .black.opacity(showsTitleShadow ? 0.36 : 0), radius: showsTitleShadow ? 10 : 0, x: 0, y: showsTitleShadow ? 4 : 0)
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
        let key = imageData as NSData
        if let cached = Self.imageCache.object(forKey: key) {
            return cached
        }
        guard let decoded = UIImage(data: imageData) else { return nil }
        Self.imageCache.setObject(decoded, forKey: key)
        return decoded
    }
}

private struct AdvancedCycleAlbumBrandMark: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.92), MKColor.green.opacity(0.92)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            Text("轻减AI")
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
}

private struct AdvancedCycleAlbumCoverArtwork: View {
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

private struct AdvancedCycleCoverThumbnail: View {
    let coverIndex: Int
    let isSelected: Bool

    var body: some View {
        AdvancedCycleAlbumCoverArtwork(coverIndex: coverIndex)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? MKColor.green : MKTheme.divider.opacity(0.16), lineWidth: isSelected ? 2 : 0.7)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AdvancedCoverSourceTile: View {
    let symbol: String
    let title: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(MKColor.green)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MKColor.green.opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? MKColor.green : MKColor.green.opacity(0.22), lineWidth: isSelected ? 2 : 0.8)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AdvancedCoverOptionButton: View {
    let coverIndex: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AdvancedCycleCoverThumbnail(coverIndex: coverIndex, isSelected: isSelected)
                .frame(maxWidth: .infinity)
                .frame(height: 92)
        }
        .buttonStyle(.plain)
    }
}

private struct AdvancedTimelineMemory: Identifiable {
    let id = UUID()
    let date: Date
    let title: String
    let detail: String
}

private struct AdvancedAchievementTimeline: View {
    let items: [AdvancedTimelineMemory]
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdvancedArchiveSectionTitle(title: isChinese ? "成长里程碑" : "Growth Milestones")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        AdvancedTimelineMemoryCard(item: item, language: language)
                            .frame(width: 208, height: 124)
                    }
                }
                .padding(.horizontal, 4)
            }
            .scrollClipDisabled()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AdvancedTimelineMemoryCard: View {
    let item: AdvancedTimelineMemory
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }
    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans_CN" : "en_US")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: item.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "seal.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MKColor.green)
                    .frame(width: 32, height: 32)
                    .background(MKColor.green.opacity(0.12), in: Circle())
                
                Text(dateText)
                    .font(.caption2.weight(.regular))
                    .foregroundStyle(MKTheme.secondaryText)
            }
            
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MKTheme.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(item.detail)
                .font(.caption.weight(.medium))
                .foregroundStyle(MKTheme.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 124, alignment: .center)
        .advancedAchievementGlassCard(cornerRadius: 18, shadowOpacity: 0.045, intensity: .light)
    }
}

private struct AdvancedCycleWorksGallery: View {
    let records: [AdvancedCycleRecord]
    let language: AppLanguage
    let customization: (AdvancedCycleRecord) -> AdvancedCycleAlbumCustomization
    let onEdit: (AdvancedCycleRecord) -> Void
    let onShare: (AdvancedCycleRecord) -> Void

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdvancedArchiveSectionTitle(title: isChinese ? "周期作品集" : "Cycle Portfolio")
            GeometryReader { proxy in
                let cardWidth = max(proxy.size.width * 0.80, 280)
                let coverHeight = cardWidth * 0.94

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(records.prefix(6)) { record in
                            AdvancedCycleWorkCard(
                                record: record,
                                customization: customization(record),
                                language: language,
                                coverHeight: coverHeight,
                                isCompact: true,
                                onEdit: { onEdit(record) },
                                onShare: { onShare(record) }
                            )
                            .frame(width: cardWidth)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()
                .frame(width: proxy.size.width, alignment: .leading)
                .background(Color.clear)
            }
            .frame(height: 492)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AdvancedCycleWorkCard: View {
    let record: AdvancedCycleRecord
    let customization: AdvancedCycleAlbumCustomization
    let language: AppLanguage
    var coverHeight: CGFloat = 250
    var isCompact = false
    let onEdit: () -> Void
    let onShare: () -> Void

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdvancedCycleAlbumCover(
                title: record.name,
                seed: record.name,
                coverIndex: customization.coverIndex,
                imageData: customization.coverImageData
            )
            .frame(maxWidth: .infinity)
            .frame(height: coverHeight)
            .overlay(alignment: .topTrailing) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font((isCompact ? Font.caption2 : Font.caption).weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: isCompact ? 28 : 32, height: isCompact ? 28 : 32)
                        .background(.black.opacity(0.24), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(isCompact ? 9 : 12)
                .accessibilityLabel(isChinese ? "编辑周期专辑" : "Edit cycle album")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(customization.summaryTitle)
                    .font((isCompact ? Font.subheadline : Font.headline).weight(.semibold))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(2)

                Text(praiseText)
                    .font((isCompact ? Font.caption2 : Font.caption).weight(.medium))
                    .foregroundStyle(MKTheme.secondaryText)
                    .lineLimit(isCompact ? 2 : 3)

                AdvancedCycleAlbumMetricsRow(
                    days: AdvancedCycleAlbumMetricFormatter.cycleDays(record),
                    training: trainingCountText,
                    weight: weightChangeText,
                    bodyFat: bodyFatChangeText,
                    language: language,
                    isCompact: isCompact
                )

                HStack {
                    AdvancedCycleReviewBadge(text: reviewText, isCompact: isCompact)
                    Spacer()
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font((isCompact ? Font.caption2 : Font.caption).weight(.semibold))
                            .foregroundStyle(MKTheme.ink)
                            .frame(width: isCompact ? 28 : 32, height: isCompact ? 28 : 32)
                            .background(MKTheme.fill.opacity(0.72), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isChinese ? "分享周期" : "Share cycle")
                }
            }
        }
        .padding(isCompact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .advancedAchievementGlassCard(cornerRadius: 28, shadowOpacity: 0, intensity: .work)
    }

    private var dateRange: String {
        "\(record.startDate.formatted(.dateTime.month(.abbreviated).day())) - \(record.endDate.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var reviewText: String {
        let score = record.score
        if score >= 90 { return isChinese ? "完美推荐 \(score)分" : "Perfect \(score)" }
        if score >= 80 { return isChinese ? "优秀作品 \(score)分" : "Excellent \(score)" }
        if score >= 60 { return isChinese ? "合格作品 \(score)分" : "Qualified \(score)" }
        return isChinese ? "待提升 \(score)分" : "Needs improvement \(score)"
    }

    private var praiseText: String {
        let score = record.score
        if score >= 90 {
            return isChinese ? "这一周期最出色的是稳定完成每一个关键环节，把结果留成了一件作品。" : "This cycle stands out for completing every key part with unusual consistency."
        }
        if score >= 80 {
            return isChinese ? "这一周期最值得被看见的是持续执行，让身体变化有了清晰轨迹。" : "This cycle is worth seeing for its steady execution and clear trace of change."
        }
        return isChinese ? "这一周期记录下了开始改变的过程，也留下了下一轮继续完成的基础。" : "This cycle captured the beginning of change and built a base for the next one."
    }

    private var trainingCountText: String {
        AdvancedCycleAlbumMetricFormatter.trainingCount(from: record)
    }

    private var weightChangeText: String {
        AdvancedCycleAlbumMetricFormatter.weightChange(from: record)
    }

    private var bodyFatChangeText: String {
        AdvancedCycleAlbumMetricFormatter.bodyFatChange(from: record)
    }
}

private struct AdvancedCycleSharePosterSheet: View {
    let record: AdvancedCycleRecord
    let customization: AdvancedCycleAlbumCustomization
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    private var isChinese: Bool { language == .simplifiedChinese }
    private var shareText: String {
        "\(record.name) · \(record.keyResult) · \(record.executedDays)\(isChinese ? "天" : " days")"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(isChinese ? "关闭" : "Close") { dismiss() }
                    .foregroundStyle(MKColor.green)
                Spacer()
                Text(isChinese ? "周期海报" : "Cycle Poster")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(MKTheme.ink)
                Spacer()
                Color.clear.frame(width: 60, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            
            ScrollView {
                AdvancedCyclePosterPreview(record: record, customization: customization, language: language)
                    .padding(20)
            }
            
            ShareLink(item: shareText) {
                Label(isChinese ? "分享周期海报" : "Share Cycle Poster", systemImage: "square.and.arrow.up")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(MKColor.green, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(20)
            .background(.ultraThinMaterial)
        }
        .background(MKThemeBackground())
    }
}

private struct AdvancedCyclePosterPreview: View {
    let record: AdvancedCycleRecord
    let customization: AdvancedCycleAlbumCustomization
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }
    private var praiseText: String {
        if record.completionRate >= 0.92 {
            return isChinese ? "这一周期最出色的是稳定完成每一个关键环节。" : "This cycle stands out for completing every key part."
        }
        if record.completionRate >= 0.82 {
            return isChinese ? "这一周期最值得被看见的是持续执行。" : "This cycle is worth seeing for its steady execution."
        }
        return isChinese ? "这一周期留下了开始改变的清晰轨迹。" : "This cycle left a clear trace of change."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            AdvancedCycleAlbumCover(
                title: record.name,
                seed: record.name,
                coverIndex: customization.coverIndex,
                imageData: customization.coverImageData,
                showsTitleShadow: false
            )
            .frame(height: 360)

            VStack(alignment: .leading, spacing: 12) {
                Text(customization.summaryTitle)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(2)

                Text(praiseText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MKTheme.secondaryText)
                    .lineLimit(2)

                AdvancedCycleAlbumMetricsRow(
                    days: AdvancedCycleAlbumMetricFormatter.cycleDays(record),
                    training: trainingCountText,
                    weight: weightChangeText,
                    bodyFat: bodyFatChangeText,
                    language: language
                )

                AdvancedPosterCycleCalendar(record: record, language: language)
                    .padding(.top, 8)
            }
        }
        .padding(18)
        .advancedAchievementGlassCard(cornerRadius: 34, shadowOpacity: 0.12, intensity: .hero)
    }

    private var trainingCountText: String {
        AdvancedCycleAlbumMetricFormatter.trainingCount(from: record)
    }

    private var weightChangeText: String {
        AdvancedCycleAlbumMetricFormatter.weightChange(from: record)
    }

    private var bodyFatChangeText: String {
        AdvancedCycleAlbumMetricFormatter.bodyFatChange(from: record)
    }
}

private struct AdvancedPosterCycleCalendar: View {
    let record: AdvancedCycleRecord
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }
    
    private var months: [Date] {
        let calendar = Calendar.current
        let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: record.startDate))!
        let endMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: record.endDate))!
        
        var months: [Date] = []
        var current = startMonth
        while current <= endMonth {
            months.append(current)
            current = calendar.date(byAdding: .month, value: 1, to: current)!
        }
        return months
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isChinese ? "周期日历" : "Cycle Calendar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MKTheme.secondaryText)
            
            ForEach(months, id: \.self) { month in
                AdvancedPosterMonthCalendar(
                    month: month,
                    record: record,
                    language: language
                )
            }
        }
        .padding(12)
        .advancedAchievementGlassCard(cornerRadius: 18, shadowOpacity: 0, intensity: .light)
    }
}

private struct AdvancedPosterMonthCalendar: View {
    let month: Date
    let record: AdvancedCycleRecord
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }
    private var calendar: Calendar { Calendar.current }
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans_CN" : "en_US")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: month)
    }
    
    private var weekdaySymbols: [String] {
        if isChinese {
            return ["日", "一", "二", "三", "四", "五", "六"]
        } else {
            return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        }
    }
    
    private var daysInMonth: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: month)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }
    
    private func isCycleDay(_ date: Date) -> Bool {
        let start = calendar.startOfDay(for: record.startDate)
        let end = calendar.startOfDay(for: record.endDate)
        let current = calendar.startOfDay(for: date)
        return current >= start && current <= end
    }
    
    private func isExecutedDay(_ date: Date) -> Bool {
        guard isCycleDay(date) else { return false }
        let daysSinceStart = calendar.dateComponents([.day], from: record.startDate, to: date).day ?? 0
        return daysSinceStart < record.executedDays
    }
    
    private func dayNumber(_ date: Date) -> Int {
        calendar.component(.day, from: date)
    }
    
    private func weekdaySymbol(_ date: Date) -> String {
        let weekday = calendar.component(.weekday, from: date)
        return weekdaySymbols[weekday - 1]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MKTheme.ink)
            
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.regular))
                        .foregroundStyle(MKTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(daysInMonth.indices, id: \.self) { index in
                    if let date = daysInMonth[index] {
                        AdvancedPosterDayCell(
                            date: date,
                            isCycleDay: isCycleDay(date),
                            isExecutedDay: isExecutedDay(date),
                            completionRate: record.completionRate,
                            language: language
                        )
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
    }
}

private struct AdvancedPosterDayCell: View {
    let date: Date
    let isCycleDay: Bool
    let isExecutedDay: Bool
    let completionRate: Double
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }
    private var calendar: Calendar { Calendar.current }
    
    private var dayNumber: Int {
        calendar.component(.day, from: date)
    }
    
    private var weekdaySymbol: String {
        let weekday = calendar.component(.weekday, from: date)
        if isChinese {
            return ["日", "一", "二", "三", "四", "五", "六"][weekday - 1]
        } else {
            return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][weekday - 1]
        }
    }
    
    private var values: [Double] {
        guard isCycleDay else { return [0, 0, 0] }
        let base = isExecutedDay ? completionRate : 0
        let wave = sin(Double(dayNumber) * 0.72) * 0.08
        return [
            min(max(base + wave + 0.03, 0), 1),
            min(max(base + wave - 0.04, 0), 1),
            min(max(base - wave + 0.02, 0), 1)
        ]
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(weekdaySymbol)
                .font(.system(size: 8, weight: .regular))
                .foregroundStyle(isCycleDay ? MKTheme.ink : MKTheme.secondaryText.opacity(0.3))
            
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    let value = values.indices.contains(index) ? values[index] : 0
                    MKCapsuleProgressColumn(
                        progress: value,
                        tint: AdvancedCalendarBarStyle.tints[index],
                        minFillHeight: value > 0 ? 2 : 0,
                        showsShadow: false
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 16)
                }
            }
            .padding(.horizontal, 2)
            
            Text("\(dayNumber)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isCycleDay ? MKTheme.ink : MKTheme.secondaryText.opacity(0.3))
        }
        .frame(height: 40)
    }
}

private struct AdvancedCycleAlbumEditSheet: View {
    let record: AdvancedCycleRecord
    let customization: AdvancedCycleAlbumCustomization
    let language: AppLanguage
    let onSave: (AdvancedCycleAlbumCustomization) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var summaryTitle: String
    @State private var coverIndex: Int
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var customCoverImageData: Data?
    @State private var isLoadingCoverImage = false
    @State private var showsCamera = false

    private var isChinese: Bool { language == .simplifiedChinese }
    private var hasCamera: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    init(
        record: AdvancedCycleRecord,
        customization: AdvancedCycleAlbumCustomization,
        language: AppLanguage,
        onSave: @escaping (AdvancedCycleAlbumCustomization) -> Void
    ) {
        self.record = record
        self.customization = customization
        self.language = language
        self.onSave = onSave
        self._summaryTitle = State(initialValue: customization.summaryTitle)
        self._coverIndex = State(initialValue: customization.coverIndex)
        self._customCoverImageData = State(initialValue: customization.coverImageData)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AdvancedCycleAlbumCover(
                        title: record.name,
                        seed: record.name,
                        coverIndex: coverIndex,
                        imageData: customCoverImageData
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(isChinese ? "总结标题" : "Summary Title")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MKTheme.secondaryText)
                        TextField(isChinese ? "系统总结标题" : "System summary title", text: $summaryTitle)
                            .textFieldStyle(.plain)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(MKTheme.ink)
                            .padding(14)
                            .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(isChinese ? "封面图片" : "Cover")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MKTheme.secondaryText)

                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                let hasCustomCover = customCoverImageData != nil
                                let cameraTitle = isChinese ? "拍摄封面" : "Take Photo"
                                let libraryTitle = isChinese ? "相册选择" : "Choose Photo"
                                Button {
                                    showsCamera = true
                                } label: {
                                    AdvancedCoverSourceTile(
                                        symbol: "camera.fill",
                                        title: cameraTitle,
                                        isSelected: false
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 92)
                                }
                                .buttonStyle(.plain)
                                .disabled(!hasCamera)
                                .opacity(hasCamera ? 1 : 0.45)

                                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                    AdvancedCoverSourceTile(
                                        symbol: "photo.on.rectangle",
                                        title: libraryTitle,
                                        isSelected: hasCustomCover
                                    )
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 92)
                                }
                                .buttonStyle(.plain)
                                .onChange(of: selectedPhoto) { _, newValue in
                                    Task {
                                        await MainActor.run {
                                            isLoadingCoverImage = newValue != nil
                                        }
                                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                                           let uiImage = UIImage(data: data),
                                           let coverData = compressedCoverImageData(from: uiImage) {
                                            await MainActor.run {
                                                customCoverImageData = coverData
                                            }
                                        }
                                        await MainActor.run {
                                            isLoadingCoverImage = false
                                        }
                                    }
                                }
                            }

                            HStack(spacing: 12) {
                                AdvancedCoverOptionButton(
                                    coverIndex: 0,
                                    isSelected: coverIndex == 0 && customCoverImageData == nil
                                ) {
                                    coverIndex = 0
                                    customCoverImageData = nil
                                    selectedPhoto = nil
                                }

                                AdvancedCoverOptionButton(
                                    coverIndex: 1,
                                    isSelected: coverIndex == 1 && customCoverImageData == nil
                                ) {
                                    coverIndex = 1
                                    customCoverImageData = nil
                                    selectedPhoto = nil
                                }

                                AdvancedCoverOptionButton(
                                    coverIndex: 2,
                                    isSelected: coverIndex == 2 && customCoverImageData == nil
                                ) {
                                    coverIndex = 2
                                    customCoverImageData = nil
                                    selectedPhoto = nil
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .background(MKThemeBackground())
            .sheet(isPresented: $showsCamera) {
                CameraPicker { data in
                    if let image = UIImage(data: data),
                       let coverData = compressedCoverImageData(from: image) {
                        customCoverImageData = coverData
                        selectedPhoto = nil
                    }
                    showsCamera = false
                } onCancel: {
                    showsCamera = false
                }
                .ignoresSafeArea()
            }
            .navigationTitle(isChinese ? "编辑周期专辑" : "Edit Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isChinese ? "取消" : "Cancel") { dismiss() }
                        .foregroundStyle(MKTheme.secondaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isChinese ? "保存" : "Save") {
                        onSave(
                            AdvancedCycleAlbumCustomization(
                                albumName: record.name,
                                summaryTitle: summaryTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? customization.summaryTitle : summaryTitle,
                                coverIndex: coverIndex,
                                coverImageData: customCoverImageData
                            )
                        )
                        dismiss()
                    }
                    .foregroundStyle(MKColor.green)
                    .disabled(isLoadingCoverImage)
                    .opacity(isLoadingCoverImage ? 0.45 : 1)
                }
            }
        }
    }

    private func compressedCoverImageData(from image: UIImage) -> Data? {
        let maxSide: CGFloat = 1400
        let largestSide = max(image.size.width, image.size.height)
        let scale = largestSide > maxSide ? maxSide / largestSide : 1
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }
}

private struct AdvancedGrowthShareCenter: View {
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }
    private var shareItems: [String] {
        isChinese
            ? ["成长海报", "成长卡片", "朋友圈长图", "小红书图文", "年度成长报告", "周期纪念册"]
            : ["Growth Poster", "Growth Card", "Story Image", "Social Post", "Year Review", "Cycle Album"]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdvancedArchiveSectionTitle(title: isChinese ? "分享我的成长" : "Share Growth")
            VStack(alignment: .leading, spacing: 14) {
                Text(isChinese ? "把这一轮周期生成一张可以保存、分享、回看的成长作品。" : "Turn this cycle into a saved, shareable growth piece.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MKTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(shareItems, id: \.self) { item in
                        Text(item)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MKTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .background(MKTheme.fill.opacity(0.78), in: Capsule())
                    }
                }

                Button { } label: {
                    Label(isChinese ? "生成周期纪念卡" : "Create Cycle Memory Card", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .advancedAchievementGlassCard(cornerRadius: 24, shadowOpacity: 0.06, intensity: .utility)
        }
    }
}

private enum AdvancedTopBarTrailing {
    case badge
    case quickLog(AppLanguage)
    case createCycle(AppLanguage, () -> Void)
    case calendarButton(AppLanguage, () -> Void)
}

private struct AdvancedScreen<Content: View>: View {
    let title: String
    let subtitle: String
    var trailing: AdvancedTopBarTrailing = .badge
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: MKTheme.cardSpacing) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MKTheme.pageMargin)
            .padding(.top, 16)
            .padding(.bottom, 88)
        }
        .mkGlassNavigation(title: title, subtitle: subtitle) {
            AdvancedTopBarAction(trailing: trailing)
        }
    }
}

private struct AdvancedTopBarAction: View {
    let trailing: AdvancedTopBarTrailing

    var body: some View {
        Group {
            switch trailing {
            case .badge:
                EmptyView()
            case .quickLog(let language):
                Button { } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MKColor.green)
                        .frame(width: 38, height: 38)
                }
                .accessibilityLabel(language == .simplifiedChinese ? "快速记录" : "Quick log")
            case .createCycle(let language, let action):
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MKColor.green)
                        .frame(width: 38, height: 38)
                }
                .accessibilityLabel(language == .simplifiedChinese ? "创建周期" : "Create cycle")
            case .calendarButton(let language, let action):
                Button(action: action) {
                    Image(systemName: "calendar")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MKColor.green)
                        .frame(width: 38, height: 38)
                }
                .accessibilityLabel(language == .simplifiedChinese ? "完整日历" : "Full calendar")
            }
        }
    }
}

private struct AdvancedModeGlyph: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.blue)
                .frame(width: 26, height: 26)
                .background(Color.blue.opacity(0.10), in: Circle())

            Circle()
                .fill(MKColor.green)
                .frame(width: 7, height: 7)
                .overlay(Circle().stroke(MKTheme.background, lineWidth: 1.5))
        }
        .accessibilityLabel("Advanced")
    }
}

private struct AdvancedCyclePlanHeader: View {
    let cycle: AdvancedBodyCycle
    let language: AppLanguage
    let onDetail: () -> Void

    private var isChinese: Bool { language == .simplifiedChinese }
    private var totalWeeks: Int { max(Int(ceil(Double(cycle.durationDays) / 7.0)), 1) }

    var body: some View {
        AdvancedCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(cycle.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)
                            .lineLimit(1)
                        Text(isChinese ? "第 \(cycle.currentWeek) 周 / 共 \(totalWeeks) 周" : "Week \(cycle.currentWeek) / \(totalWeeks)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MKTheme.secondaryText)
                    }
                    Spacer()
                    Button(action: onDetail) {
                        Label(isChinese ? "详情" : "Details", systemImage: "doc.text.magnifyingglass")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.blue)
                            .padding(.horizontal, 11)
                            .frame(height: 32)
                            .background(Color.blue.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isChinese ? "查看周期详情" : "View cycle details")
                }

                HStack(alignment: .lastTextBaseline) {
                    Text(isChinese ? "周期进度" : "Cycle progress")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MKTheme.secondaryText)
                    Spacer()
                    Text("\(Int(cycle.progress * 100))%")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(MKTheme.ink)
                        .monospacedDigit()
                }

                AdvancedHeroProgressBar(progress: cycle.progress)

                Text("\(cycle.elapsedDays) / \(cycle.durationDays) \(isChinese ? "天" : "days")")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.blue)
                    .monospacedDigit()
                }
        }
    }
}

private struct AdvancedHeroProgressBar: View {
    let progress: Double

    var body: some View {
        MKCapsuleProgressBar(progress: progress, tint: Color.blue, height: 14)
    }
}

private struct AdvancedPlanStrategyTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)
            }
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct AdvancedNutritionTaskCard: View {
    let plan: AdvancedNutritionPlan
    let eaten: MacroTarget
    let eatenCalories: Int
    let language: AppLanguage

    var body: some View {
        AdvancedCard {
            AdvancedCardHeader(symbol: "fork.knife", title: language == .simplifiedChinese ? "今日饮食" : "Nutrition", value: "\(max(plan.calories - eatenCalories, 0)) kcal")
            AdvancedMacroRow(title: language == .simplifiedChinese ? "热量" : "Calories", current: eatenCalories, target: plan.calories, unit: "kcal", tint: Color.blue)
            AdvancedMacroRow(title: language == .simplifiedChinese ? "蛋白质" : "Protein", current: eaten.protein, target: plan.protein, unit: "g", tint: MKColor.green)
            AdvancedMacroRow(title: language == .simplifiedChinese ? "碳水" : "Carbs", current: eaten.carbs, target: plan.carbs, unit: "g", tint: Color.blue)
            AdvancedMacroRow(title: language == .simplifiedChinese ? "脂肪" : "Fat", current: eaten.fat, target: plan.fat, unit: "g", tint: MKColor.citrus)
            Text(language == .simplifiedChinese ? "剩余建议：优先补足蛋白质，晚餐控制脂肪来源。" : "Remaining: prioritize protein and keep dinner fat sources controlled.")
                .font(.caption.weight(.medium))
                .foregroundStyle(MKTheme.secondaryText)
        }
    }
}

private struct AdvancedDailyExecutionSummaryCard: View {
    let plan: AdvancedNutritionPlan
    let eatenCalories: Int
    let eatenMacros: MacroTarget
    let basalMetabolicRate: Int
    let activityCalories: Int
    let exerciseCalories: Int
    let waterCups: Int
    let adherenceDays: Int
    let trainingDay: AdvancedTrainingDay
    let trainingTargetCalories: Int
    let trainingTargetMinutes: Int
    let recovery: AdvancedRecoverySnapshot
    let supplements: [AdvancedSupplementSchedule]
    let language: AppLanguage
    let trainingLog: AdvancedTrainingLog
    let sleepLog: AdvancedSleepLog
    let supplementIntakes: [AdvancedSupplementIntake]
    let supplementSettings: [AdvancedSupplementIntake]
    let waterTarget: Int
    let sleepTarget: Double
    var nutritionAction: () -> Void = {}
    var nutritionInfoAction: () -> Void = {}
    var trainingAction: () -> Void = {}
    var trainingInfoAction: () -> Void = {}
    var otherInfoAction: () -> Void = {}
    var sleepAction: () -> Void = {}

    private var isChinese: Bool { language == .simplifiedChinese }
    private var dynamicBurn: Int { basalMetabolicRate + activityCalories + exerciseCalories }
    private var calorieDeficit: Int { dynamicBurn - eatenCalories }
    private var supplementDisplayItems: [(name: String, dosage: String, isTaken: Bool)] {
        if !supplementIntakes.isEmpty {
            return supplementIntakes.map { ($0.name, $0.dosage, $0.isTaken) }
        }
        if !supplementSettings.isEmpty {
            return supplementSettings.map { ($0.name, $0.dosage, $0.isTaken) }
        }
        return supplements.map { ($0.name, $0.dosage, $0.isTakenToday) }
    }
    private var supplementTakenCount: Int { supplementDisplayItems.filter(\.isTaken).count }

    var body: some View {
        AdvancedCard {
            HStack(spacing: 10) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.blue)
                    .frame(width: 30, height: 30)
                    .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(isChinese ? "今日计划" : "Today")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                Spacer()
                Text(isChinese ? "坚持 \(adherenceDays) 天" : "\(adherenceDays)d streak")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
            }

            VStack(spacing: 0) {
                AdvancedNutritionCommandRow(
                    title: isChinese ? "饮食" : "Nutrition",
                    recommendedProtein: plan.protein,
                    recordedProtein: eatenMacros.protein,
                    recommendedCarbs: plan.carbs,
                    recordedCarbs: eatenMacros.carbs,
                    recommendedFat: plan.fat,
                    recordedFat: eatenMacros.fat,
                    status: nutritionStatus,
                    statusTint: nutritionTint,
                    language: language,
                    infoAction: nutritionInfoAction,
                    action: nutritionAction
                )
                AdvancedDivider()
                AdvancedTrainingCommandRow(
                    title: isChinese ? "训练" : "Training",
                    recordedCalories: trainingLog.caloriesBurned,
                    targetCalories: max(trainingTargetCalories, 1),
                    recordedMinutes: trainingLog.durationMinutes,
                    targetMinutes: max(trainingTargetMinutes, 1),
                    status: trainingStatus,
                    statusTint: trainingTint,
                    language: language,
                    infoAction: trainingInfoAction,
                    action: trainingAction
                )
                AdvancedDivider()
                AdvancedOtherCommandRow(
                    title: isChinese ? "其他" : "Other",
                    supplementTakenCount: supplementTakenCount,
                    supplementTargetCount: supplementDisplayItems.count,
                    sleepHours: sleepLog.totalHours,
                    sleepTarget: sleepTarget,
                    waterCups: waterCups,
                    waterTarget: waterTarget,
                    status: otherStatus,
                    statusTint: otherTint,
                    language: language,
                    infoAction: otherInfoAction,
                    action: sleepAction
                )
            }
        }
    }

    private var nutritionStatus: String {
        if eatenCalories == 0 { return isChinese ? "未记录" : "Not logged" }
        if calorieDeficit > 900 { return isChinese ? "缺口过大" : "Large deficit" }
        if eatenMacros.protein < plan.protein { return isChinese ? "进行中" : "In progress" }
        return isChinese ? "正常" : "On track"
    }

    private var nutritionTint: Color {
        if eatenCalories == 0 { return MKTheme.secondaryText }
        if calorieDeficit > 900 { return MKColor.coral }
        if eatenCalories > dynamicBurn { return MKColor.citrus }
        return MKColor.green
    }

    private var trainingStatus: String {
        if trainingDay.isRestDay { return isChinese ? "休息日" : "Rest day" }
        return trainingLog.durationMinutes > 0 ? (isChinese ? "已完成" : "Done") : (isChinese ? "未完成" : "Pending")
    }

    private var trainingTint: Color {
        if trainingDay.isRestDay { return Color.blue }
        return trainingLog.durationMinutes > 0 ? MKColor.green : MKColor.citrus
    }

    private var otherStatus: String {
        if otherProgress >= 0.95 { return isChinese ? "已完成" : "Done" }
        return isChinese ? "待完成" : "Pending"
    }

    private var otherTint: Color {
        if sleepLog.totalHours < 6.5 { return MKColor.citrus }
        return otherProgress >= 0.95 ? MKColor.green : MKTheme.secondaryText
    }

    private var otherProgress: Double {
        let supplementProgress = Double(supplementTakenCount) / Double(max(supplementDisplayItems.count, 1))
        let sleepProgress = min(max(sleepLog.totalHours / sleepTarget, 0), 1)
        return (supplementProgress + sleepProgress) / 2
    }
}

private struct AdvancedExecutionSummaryRow: View {
    let symbol: String
    let title: String
    let target: String
    let status: String
    let progress: Double
    let tint: Color

    var body: some View {
        Button { } label: {
            HStack(spacing: 12) {
                AdvancedProgressRing(progress: progress, symbol: symbol, tint: tint)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)

                        Spacer()

                        Text(target)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    HStack {
                        Text(status)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MKTheme.secondaryText)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(min(max(progress, 0), 1) * 100))%")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(tint)
                    }
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AdvancedCommandExecutionRow: View {
    let symbol: String
    let title: String
    let primary: String
    let secondary: String
    let status: String
    let statusTint: Color
    let progress: Double
    let tint: Color
    let language: AppLanguage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AdvancedProgressRing(progress: progress, symbol: symbol, tint: tint)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)
                        Spacer(minLength: 8)
                        Text(status)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(statusTint)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(primary)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MKTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 8)
                        Text(secondary)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MKTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AdvancedNutritionCommandRow: View {
    let title: String
    let recommendedProtein: Int
    let recordedProtein: Int
    let recommendedCarbs: Int
    let recordedCarbs: Int
    let recommendedFat: Int
    let recordedFat: Int
    let status: String
    let statusTint: Color
    let language: AppLanguage
    let infoAction: () -> Void
    let action: () -> Void

    private var isChinese: Bool { language == .simplifiedChinese }
    private var metrics: [AdvancedFitnessRingMetric] {
        [
            .init(
                id: "protein",
                title: isChinese ? "蛋白质" : "Protein",
                current: Double(recordedProtein),
                target: Double(recommendedProtein),
                value: "\(recordedProtein) / \(recommendedProtein)g",
                tint: AdvancedFitnessRingColor.protein
            ),
            .init(
                id: "carbs",
                title: isChinese ? "碳水" : "Carbs",
                current: Double(recordedCarbs),
                target: Double(recommendedCarbs),
                value: "\(recordedCarbs) / \(recommendedCarbs)g",
                tint: AdvancedFitnessRingColor.carbs
            ),
            .init(
                id: "fat",
                title: isChinese ? "脂肪" : "Fat",
                current: Double(recordedFat),
                target: Double(recommendedFat),
                value: "\(recordedFat) / \(recommendedFat)g",
                tint: AdvancedFitnessRingColor.fat
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            AdvancedRingSectionHeader(title: title, status: status, statusTint: statusTint)
            HStack(alignment: .center, spacing: 12) {
                Button(action: infoAction) {
                    HStack(alignment: .center, spacing: 12) {
                        AdvancedGoalCapsuleMatrix(metrics: metrics)
                        AdvancedFitnessLegendColumn(metrics: metrics)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: action) {
                    AdvancedRingEditButton()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 9)
    }
}

private struct AdvancedTrainingCommandRow: View {
    let title: String
    let recordedCalories: Int
    let targetCalories: Int
    let recordedMinutes: Int
    let targetMinutes: Int
    let status: String
    let statusTint: Color
    let language: AppLanguage
    let infoAction: () -> Void
    let action: () -> Void

    private var isChinese: Bool { language == .simplifiedChinese }
    private var metrics: [AdvancedFitnessRingMetric] {
        [
            .init(
                id: "move",
                title: isChinese ? "运动" : "Move",
                current: Double(recordedCalories),
                target: Double(targetCalories),
                value: "\(recordedCalories) / \(targetCalories) cal",
                tint: AdvancedFitnessRingColor.move
            ),
            .init(
                id: "duration",
                title: isChinese ? "时长" : "Time",
                current: Double(recordedMinutes),
                target: Double(targetMinutes),
                value: "\(recordedMinutes) / \(targetMinutes) min",
                tint: AdvancedFitnessRingColor.exercise
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            AdvancedRingSectionHeader(title: title, status: status, statusTint: statusTint)
            HStack(alignment: .center, spacing: 12) {
                Button(action: infoAction) {
                    HStack(alignment: .center, spacing: 12) {
                        AdvancedGoalCapsuleMatrix(metrics: metrics)
                        AdvancedFitnessLegendColumn(metrics: metrics)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: action) {
                    AdvancedRingEditButton()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 9)
    }
}

private struct AdvancedOtherCommandRow: View {
    let title: String
    let supplementTakenCount: Int
    let supplementTargetCount: Int
    let sleepHours: Double
    let sleepTarget: Double
    let waterCups: Int
    let waterTarget: Int
    let status: String
    let statusTint: Color
    let language: AppLanguage
    let infoAction: () -> Void
    let action: () -> Void

    private var isChinese: Bool { language == .simplifiedChinese }
    private var metrics: [AdvancedFitnessRingMetric] {
        [
            .init(
                id: "supplements",
                title: isChinese ? "补剂" : "Supplements",
                current: Double(supplementTakenCount),
                target: Double(max(supplementTargetCount, 1)),
                value: "\(supplementTakenCount) / \(supplementTargetCount)",
                tint: AdvancedFitnessRingColor.stand
            ),
            .init(
                id: "sleep",
                title: isChinese ? "睡眠" : "Sleep",
                current: sleepHours,
                target: sleepTarget,
                value: String(format: "%.1f / %.1fh", sleepHours, sleepTarget),
                tint: AdvancedFitnessRingColor.sleep
            ),
            .init(
                id: "water",
                title: isChinese ? "饮水" : "Water",
                current: Double(waterCups),
                target: Double(waterTarget),
                value: isChinese ? "\(waterCups) / \(waterTarget) 杯" : "\(waterCups) / \(waterTarget) cups",
                tint: AdvancedFitnessRingColor.water
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            AdvancedRingSectionHeader(title: title, status: status, statusTint: statusTint)
            HStack(alignment: .center, spacing: 12) {
                Button(action: infoAction) {
                    HStack(alignment: .center, spacing: 12) {
                        AdvancedGoalCapsuleMatrix(metrics: metrics)
                        AdvancedFitnessLegendColumn(metrics: metrics)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: action) {
                    AdvancedRingEditButton()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 9)
    }
}

private struct AdvancedRingSectionHeader: View {
    let title: String
    let status: String
    let statusTint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKTheme.ink)
            Spacer(minLength: 10)
            Text(status)
                .font(.caption.weight(.bold))
                .foregroundStyle(statusTint)
                .lineLimit(1)
        }
    }
}

private struct AdvancedRingEditButton: View {
    var body: some View {
        Image(systemName: "square.and.pencil")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(MKTheme.secondaryText)
            .frame(width: 30, height: 30)
            .background(MKTheme.fill, in: Circle())
            .accessibilityLabel("Edit")
    }
}

private struct AdvancedFitnessRingMetric: Identifiable {
    let id: String
    let title: String
    let current: Double
    let target: Double
    let value: String
    let tint: Color

    init(
        id: String,
        title: String,
        current: Double,
        target: Double,
        value: String,
        tint: Color
    ) {
        self.id = id
        self.title = title
        self.current = current
        self.target = target
        self.value = value
        self.tint = tint
    }

    var progress: Double {
        min(max(current / max(target, 0.0001), 0), 1)
    }
}

private enum AdvancedFitnessRingColor {
    static let protein = Color(red: 1.00, green: 0.12, blue: 0.42)
    static let carbs = Color(red: 0.18, green: 0.86, blue: 0.32)
    static let fat = Color(red: 0.03, green: 0.62, blue: 1.00)
    static let move = Color(red: 1.00, green: 0.36, blue: 0.16)
    static let exercise = Color(red: 0.16, green: 0.78, blue: 0.38)
    static let stand = Color(red: 0.12, green: 0.56, blue: 1.00)
    static let sleep = Color(red: 0.66, green: 0.45, blue: 1.00)
    static let water = Color(red: 0.00, green: 0.68, blue: 1.00)
}

private struct AdvancedGoalCapsuleMatrix: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let metrics: [AdvancedFitnessRingMetric]

    @State private var animatedProgress: [Double] = []

    var body: some View {
        HStack(alignment: .bottom, spacing: capsuleSpacing) {
            ForEach(Array(metrics.prefix(3).enumerated()), id: \.element.id) { index, metric in
                MKCapsuleProgressColumn(
                    progress: animatedProgress.indices.contains(index) ? animatedProgress[index] : 0,
                    tint: metric.tint
                )
                .frame(width: capsuleWidth, height: capsuleHeight(for: index))
            }
        }
        .frame(width: 58, height: 58)
        .accessibilityHidden(true)
        .task(id: metrics.map { "\($0.current)-\($0.target)" }.joined(separator: "|")) {
            await animate()
        }
    }

    private var capsuleWidth: CGFloat {
        metrics.prefix(3).count <= 2 ? 17 : 13
    }

    private var capsuleSpacing: CGFloat {
        metrics.prefix(3).count <= 2 ? 8 : 6
    }

    private func capsuleHeight(for index: Int) -> CGFloat {
        switch metrics.prefix(3).count {
        case 1:
            return 54
        case 2:
            return index == 0 ? 54 : 44
        default:
            return [54, 44, 34][min(index, 2)]
        }
    }

    @MainActor
    private func animate() async {
        let targets = metrics.prefix(3).map(\.progress)
        guard !reduceMotion else {
            animatedProgress = targets
            return
        }
        animatedProgress = Array(repeating: 0, count: targets.count)
        try? await Task.sleep(for: .milliseconds(120))
        for index in targets.indices {
            try? await Task.sleep(for: .milliseconds(index == 0 ? 0 : 70))
            withAnimation(.easeInOut(duration: 0.78)) {
                if animatedProgress.indices.contains(index) {
                    animatedProgress[index] = targets[index]
                }
            }
        }
    }
}

private struct AdvancedFitnessLegendColumn: View {
    let metrics: [AdvancedFitnessRingMetric]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(metrics.prefix(3)) { metric in
                AdvancedFitnessLegendItem(metric: metric)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AdvancedFitnessLegendItem: View {
    let metric: AdvancedFitnessRingMetric

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(metric.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(metric.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(metric.value)
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }
}

private struct AdvancedProgressRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let progress: Double
    let symbol: String
    let tint: Color

    @State private var animatedProgress = 0.0

    var body: some View {
        ZStack {
            Circle()
                .stroke(MKTheme.track, lineWidth: 5)
            Circle()
                .trim(from: 0, to: min(max(animatedProgress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: 38, height: 38)
        .accessibilityHidden(true)
        .task(id: progress) {
            await animate()
        }
    }

    @MainActor
    private func animate() async {
        let target = min(max(progress, 0), 1)
        guard !reduceMotion else {
            animatedProgress = target
            return
        }
        animatedProgress = 0
        try? await Task.sleep(for: .milliseconds(100))
        withAnimation(.easeInOut(duration: 0.75)) {
            animatedProgress = target
        }
    }
}

private struct AdvancedQuickLogActions: View {
    let language: AppLanguage

    private var titles: [(String, String)] {
        if language == .simplifiedChinese {
            return [("fork.knife", "饮食"), ("dumbbell", "训练"), ("bed.double", "恢复"), ("pills", "补剂")]
        }
        return [("fork.knife", "Food"), ("dumbbell", "Training"), ("bed.double", "Recovery"), ("pills", "Supplements")]
    }

    var body: some View {
        AdvancedCard {
            AdvancedCardHeader(symbol: "plus.circle", title: language == .simplifiedChinese ? "快速记录" : "Quick Log", value: "")
            HStack(spacing: 8) {
                ForEach(titles, id: \.1) { item in
                    Button { } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.0)
                                .font(.system(size: 16, weight: .semibold))
                            Text(item.1)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundStyle(MKTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct AdvancedNoActiveCycleState: View {
    let language: AppLanguage
    let onAIGenerate: () -> Void
    let onCustomPlan: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 28)

            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.blue)
                .frame(width: 68, height: 68)
                .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(spacing: 8) {
                Text(language == .simplifiedChinese ? "还没有进行中的周期" : "No active cycle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                Text(language == .simplifiedChinese ? "创建一个周期后，系统会根据你的饮食、训练、休息和补剂计划生成每日执行任务。" : "Create a cycle and the system will generate daily execution tasks from your nutrition, training, recovery, and supplement plans.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MKTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                Button(action: onAIGenerate) {
                    MKThemePrimaryButtonLabel(symbol: "sparkles", title: language == .simplifiedChinese ? "AI 生成计划" : "AI Generate Plan")
                }
                Button(action: onCustomPlan) {
                    MKThemeSecondaryButtonLabel(symbol: "slider.horizontal.3", title: language == .simplifiedChinese ? "自定义计划" : "Custom Plan")
                }
            }

            Spacer(minLength: 120)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }
}

private struct AdvancedTrainingTaskCard: View {
    let day: AdvancedTrainingDay
    let language: AppLanguage

    var body: some View {
        AdvancedCard {
            AdvancedCardHeader(symbol: "figure.strengthtraining.traditional", title: language == .simplifiedChinese ? "今日训练" : "Training", value: day.isRestDay ? (language == .simplifiedChinese ? "休息日" : "Rest") : day.title)
            if day.isRestDay {
                AdvancedStatusRow(title: language == .simplifiedChinese ? "类型" : "Type", value: language == .simplifiedChinese ? "恢复 / 低压力活动" : "Recovery / low stress")
                AdvancedStatusRow(title: language == .simplifiedChinese ? "状态" : "Status", value: language == .simplifiedChinese ? "不安排力量训练" : "No lifting scheduled")
            } else {
                AdvancedStatusRow(title: language == .simplifiedChinese ? "训练部位" : "Focus", value: day.title)
                AdvancedStatusRow(title: language == .simplifiedChinese ? "训练类型" : "Type", value: day.focus)
                AdvancedStatusRow(title: language == .simplifiedChinese ? "训练状态" : "Status", value: language == .simplifiedChinese ? "待执行" : "Pending")
                ForEach(day.exercises) { exercise in
                    AdvancedExerciseRow(exercise: exercise)
                }
            }
        }
    }
}

private struct AdvancedRecoveryTaskCard: View {
    let recovery: AdvancedRecoverySnapshot
    let isRestDay: Bool
    let deloadWeek: Int?
    let currentWeek: Int
    let language: AppLanguage

    var body: some View {
        AdvancedCard {
            AdvancedCardHeader(symbol: "heart.text.square", title: language == .simplifiedChinese ? "今日休息" : "Recovery", value: "\(recovery.score)")
            AdvancedStatusRow(title: language == .simplifiedChinese ? "睡眠目标" : "Sleep target", value: "7.5h")
            AdvancedStatusRow(title: language == .simplifiedChinese ? "恢复建议" : "Suggestion", value: recovery.score < 60 ? (language == .simplifiedChinese ? "降低强度" : "Reduce intensity") : (language == .simplifiedChinese ? "可正常训练" : "Train as planned"))
            AdvancedStatusRow(title: "Deload", value: deloadWeek == currentWeek ? (language == .simplifiedChinese ? "本周" : "This week") : (language == .simplifiedChinese ? "第 \(deloadWeek ?? 0) 周" : "Week \(deloadWeek ?? 0)"))
            AdvancedStatusRow(title: language == .simplifiedChinese ? "日程" : "Day type", value: isRestDay ? (language == .simplifiedChinese ? "休息日" : "Rest day") : (language == .simplifiedChinese ? "训练日" : "Training day"))
        }
    }
}

private struct AdvancedCycleDetailSheet: View {
    let snapshot: AdvancedModeSnapshot
    let createdCycle: TrainingCycle?
    let language: AppLanguage
    let onEdit: () -> Void
    let onArchive: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var isChinese: Bool { language == .simplifiedChinese }
    private var cycle: AdvancedBodyCycle { snapshot.cycle }
    private var proteinMultiplier: Double {
        Double(snapshot.nutritionPlan.protein) / max(cycle.currentWeightKg, 1)
    }
    private var detailTitle: String { createdCycle?.title ?? cycle.name }
    private var detailGoal: String {
        createdCycle?.goal.localizedName(language: language) ?? cycle.kind.title(language: language)
    }
    private var detailStatus: String {
        createdCycle?.status.localizedName(language: language) ?? cycle.status.title(language: language)
    }
    private var detailStartDate: Date { createdCycle?.startDate ?? cycle.startDate }
    private var detailEndDate: Date { createdCycle?.endDate ?? cycle.endDate }
    private var detailDuration: String {
        if let createdCycle {
            return "\(createdCycle.durationValue) \(createdCycle.durationUnit.localizedName(language: language))"
        }
        return "\(cycle.durationDays) \(isChinese ? "天" : "days")"
    }
    private var detailCreatedAt: Date { createdCycle?.createdAt ?? cycle.startDate }
    private var cycleProgressDurationText: String {
        let elapsed = cycle.elapsedDays
        if let createdCycle {
            let currentValue: Int
            switch createdCycle.durationUnit {
            case .days:
                currentValue = elapsed
            case .weeks:
                currentValue = elapsed == 0 ? 0 : Int(ceil(Double(elapsed) / 7.0))
            case .months:
                currentValue = elapsed == 0 ? 0 : max(1, Int(ceil(Double(elapsed) / 30.0)))
            }
            return "\(min(currentValue, createdCycle.durationValue)) / \(createdCycle.durationValue) \(createdCycle.durationUnit.localizedName(language: language))"
        }
        return "\(elapsed) / \(cycle.durationDays) \(isChinese ? "天" : "days")"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AdvancedCard {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(detailTitle)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(MKTheme.ink)
                                Text("\(detailGoal) · \(detailDuration)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MKTheme.secondaryText)
                            }
                            Spacer()
                            MKThemeTag(text: detailStatus, tint: cycle.status == .active ? MKColor.green : MKColor.citrus)
                        }
                    }

                    AdvancedSectionHeader(title: isChinese ? "基础信息" : "Basics")
                    AdvancedCard {
                        AdvancedStatusRow(title: isChinese ? "周期标题" : "Title", value: detailTitle)
                        AdvancedStatusRow(title: isChinese ? "周期目标" : "Goal", value: detailGoal)
                        AdvancedStatusRow(title: isChinese ? "创建时间" : "Created", value: detailCreatedAt.formatted(.dateTime.year().month().day()))
                        AdvancedStatusRow(title: isChinese ? "开始时间" : "Start", value: detailStartDate.formatted(.dateTime.year().month().day()))
                        AdvancedStatusRow(title: isChinese ? "结束时间" : "End", value: detailEndDate.formatted(.dateTime.year().month().day()))
                        AdvancedStatusRow(title: isChinese ? "计划时长" : "Duration", value: detailDuration)
                        AdvancedStatusRow(title: isChinese ? "周期进度" : "Progress", value: cycleProgressDurationText)
                        AdvancedStatusRow(title: isChinese ? "周期状态" : "Status", value: detailStatus)
                    }

                    AdvancedSectionHeader(title: isChinese ? "方案内容" : "Plan Content")
                    AdvancedDetailPlanBlock(
                        symbol: "fork.knife",
                        title: isChinese ? "饮食计划" : "Nutrition",
                        rows: nutritionDetailRows
                    )
                    AdvancedDetailPlanBlock(
                        symbol: "figure.strengthtraining.traditional",
                        title: isChinese ? "训练计划" : "Training",
                        rows: trainingDetailRows
                    )
                    AdvancedDetailPlanBlock(
                        symbol: "bed.double",
                        title: isChinese ? "休息计划" : "Recovery",
                        rows: recoveryDetailRows
                    )
                    AdvancedDetailPlanBlock(
                        symbol: "pills",
                        title: isChinese ? "补剂计划" : "Supplements",
                        rows: supplementDetailRows
                    )

                    AdvancedSectionHeader(title: isChinese ? "执行记录" : "Execution")
                    AdvancedCard {
                        AdvancedStatusRow(title: isChinese ? "已执行天数" : "Executed days", value: "\(cycle.elapsedDays)d")
                        AdvancedStatusRow(title: isChinese ? "饮食完成率" : "Nutrition", value: "\(Int(snapshot.currentCycleCompletions.map(\.nutrition).average * 100))%")
                        AdvancedStatusRow(title: isChinese ? "训练完成率" : "Training", value: "\(Int(snapshot.currentCycleCompletions.map(\.training).average * 100))%")
                        AdvancedStatusRow(title: isChinese ? "休息完成率" : "Recovery", value: "\(Int(snapshot.currentCycleCompletions.map(\.recovery).average * 100))%")
                        AdvancedStatusRow(title: isChinese ? "补剂完成率" : "Supplements", value: "\(Int(snapshot.currentCycleCompletions.map(\.supplement).average * 100))%")
                    }

                    AdvancedSectionHeader(title: isChinese ? "身体变化趋势" : "Body Trends")
                    AdvancedMetricGrid(metrics: [
                        .init(title: isChinese ? "体重变化" : "Weight", value: String(format: "%.1f kg", cycle.currentWeightKg - cycle.startWeightKg), caption: isChinese ? "当前周期" : "current cycle", tint: MKColor.green),
                        .init(title: isChinese ? "体脂变化" : "Body fat", value: "--", caption: isChinese ? "待记录" : "not logged", tint: Color.blue),
                        .init(title: isChinese ? "腰围变化" : "Waist", value: "--", caption: isChinese ? "待记录" : "not logged", tint: MKTheme.secondaryText),
                        .init(title: isChinese ? "热量差趋势" : "Deficit", value: "760", caption: "kcal / day", tint: MKColor.citrus)
                    ])

                }
                .padding(20)
                .padding(.bottom, 92)
            }
            .background(MKThemeBackground())
            .navigationTitle(isChinese ? "周期详情" : "Cycle Details")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AdvancedCycleDetailActionBar(
                    language: language,
                    onEdit: {
                        dismiss()
                        onEdit()
                    },
                    onArchive: {
                        dismiss()
                        onArchive()
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "关闭" : "Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func weeklyTrainingSchedule(_ plan: AdvancedTrainingPlan) -> String {
        if isChinese {
            let labels = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
            return plan.days.map { day in
                "\(labels[max(min(day.weekday - 1, 6), 0)]) \(day.title)"
            }.joined(separator: " / ")
        }
        let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return plan.days.map { day in
            "\(labels[max(min(day.weekday - 1, 6), 0)]) \(day.title)"
        }.joined(separator: " / ")
    }

    private var nutritionDetailRows: [(String, String)] {
        var rows: [(String, String)] = []
        if let createdCycle {
            let macros = CycleNutritionCalculator.recommendedMacros(
                goal: createdCycle.goal,
                dietPlan: createdCycle.dietPlanType,
                weightKg: cycle.currentWeightKg
            )
            rows.append((isChinese ? "饮食策略" : "Diet strategy", createdCycle.dietPlanType.localizedName(language: language)))
            rows.append((isChinese ? "推荐热量差" : "Recommended calorie delta", recommendedCalorieDeltaText(for: createdCycle.goal)))
            rows.append((isChinese ? "蛋白质" : "Protein", macroValue(macros.proteinGrams, multiplier: createdCycle.customProteinMultiplier)))
            rows.append((isChinese ? "碳水" : "Carbs", macroValue(macros.carbGrams, multiplier: createdCycle.customCarbMultiplier)))
            rows.append((isChinese ? "脂肪" : "Fat", macroValue(macros.fatGrams, multiplier: createdCycle.customFatMultiplier)))
            rows.append((isChinese ? "动态规则" : "Dynamic rule", isChinese ? "体重更新后，目标按当前体重重新计算。" : "Targets recalculate from current body weight."))
            return rows
        }

        return [
            (isChinese ? "热量策略" : "Calorie strategy", snapshot.nutritionPlan.strategy),
            (isChinese ? "推荐热量差" : "Recommended calorie delta", recommendedCalorieDeltaText(for: cycle.kind == .muscleGain ? .muscleGain : .fatLoss)),
            (isChinese ? "蛋白质" : "Protein", macroValue(snapshot.nutritionPlan.protein, multiplier: nil)),
            (isChinese ? "碳水" : "Carbs", macroValue(snapshot.nutritionPlan.carbs, multiplier: nil)),
            (isChinese ? "脂肪" : "Fat", macroValue(snapshot.nutritionPlan.fat, multiplier: nil)),
            (isChinese ? "动态规则" : "Dynamic rule", isChinese ? "体重更新后，按最新体重重新计算目标。" : "Targets recalculate when body weight changes.")
        ]
    }

    private var trainingDetailRows: [(String, String)] {
        if let createdCycle {
            var rows: [(String, String)] = [
                (isChinese ? "训练计划" : "Training plan", trainingPlanName(for: createdCycle)),
                (isChinese ? "安排类型" : "Schedule type", createdCycle.arrangement.localizedName(language: language)),
                (isChinese ? "每日安排" : "Daily schedule", createdScheduleSummary(for: createdCycle))
            ]
            if createdCycle.arrangement == .cyclic, let cycleDayCount = createdCycle.cycleDayCount {
                rows.insert((isChinese ? "循环周期" : "Cycle period", "\(cycleDayCount) \(isChinese ? "天" : "days")"), at: 2)
            }
            return rows
        }

        return [
            (isChinese ? "安排类型" : "Schedule type", isChinese ? "按周安排" : "Weekly schedule"),
            (isChinese ? "训练分化" : "Split", snapshot.trainingPlan.name),
            (isChinese ? "训练频率" : "Frequency", isChinese ? "每周 \(snapshot.trainingPlan.weeklyFrequency) 次" : "\(snapshot.trainingPlan.weeklyFrequency)x / week"),
            (isChinese ? "周安排" : "Weekly days", weeklyTrainingSchedule(snapshot.trainingPlan)),
            (isChinese ? "循环示例" : "Cycle option", isChinese ? "练三休一：只看循环日，不看星期。" : "3-on / 1-off: follows cycle day, not weekday."),
            ("Deload", isChinese ? "第 \(snapshot.trainingPlan.deloadWeek ?? 0) 周" : "Week \(snapshot.trainingPlan.deloadWeek ?? 0)")
        ]
    }

    private var recoveryDetailRows: [(String, String)] {
        if let createdCycle {
            let restDays = createdCycle.daySchedules.filter { $0.isRestDay }.count
            return [
                (isChinese ? "休息日" : "Rest days", "\(restDays)"),
                (isChinese ? "睡眠目标" : "Sleep target", "\(String(format: "%.1f", createdCycle.dailySleepHours))h"),
                (isChinese ? "恢复策略" : "Recovery strategy", isChinese ? "按训练计划中的休息日执行。" : "Follow rest days in the training plan."),
                (isChinese ? "停训规则" : "Stop rule", isChinese ? "疲劳高时降低强度或进入休息日。" : "Reduce intensity or switch to rest under high fatigue.")
            ]
        }

        return [
            (isChinese ? "休息日规则" : "Rest rule", isChinese ? "每周至少 1-2 天" : "At least 1-2 days / week"),
            (isChinese ? "睡眠目标" : "Sleep target", "7.5h"),
            (isChinese ? "恢复策略" : "Recovery strategy", cycle.recoveryStrategy),
            (isChinese ? "停训规则" : "Stop rule", isChinese ? "疲劳高时降低强度" : "Reduce intensity under high fatigue")
        ]
    }

    private var supplementDetailRows: [(String, String)] {
        if let createdCycle {
            guard !createdCycle.supplements.isEmpty else {
                return [(isChinese ? "补剂" : "Supplements", isChinese ? "未设置" : "Not set")]
            }
            return createdCycle.supplements.map { supplement in
                (supplement.name, supplement.dosage.isEmpty ? (isChinese ? "已添加" : "Added") : supplement.dosage)
            }
        }
        let rows = snapshot.supplements.map { ($0.name, "\($0.dosage) · \($0.timing)") }
        return rows.isEmpty ? [(isChinese ? "补剂" : "Supplements", isChinese ? "未设置" : "Not set")] : rows
    }

    private func trainingPlanName(for cycle: TrainingCycle) -> String {
        if cycle.arrangement == .cyclic, cycle.cycleDayCount == 4 {
            return isChinese ? "三分化" : "3-Day Split"
        }
        let trainDays = cycle.daySchedules.filter { !$0.isRestDay }.count
        let restDays = cycle.daySchedules.filter { $0.isRestDay }.count
        if cycle.arrangement == .weekly, trainDays == 5, restDays == 2 {
            return isChinese ? "五分化" : "5-Day Split"
        }
        return isChinese ? "按周循环" : "Weekly Plan"
    }

    private func createdScheduleSummary(for cycle: TrainingCycle) -> String {
        cycle.daySchedules
            .map { compactScheduleName(for: $0) }
            .joined(separator: "-")
    }

    private func compactScheduleName(for schedule: CycleDaySchedule) -> String {
        if schedule.isRestDay { return isChinese ? "休息" : "Rest" }
        let parts = Set(schedule.bodyParts)
        if isChinese {
            if parts.contains(.chest), parts.contains(.back) { return "胸背" }
            if parts.contains(.shoulders), parts.contains(.biceps) || parts.contains(.triceps) { return "肩手" }
            if parts.contains(.glutes), parts.contains(.legs) { return "臀腿" }
            if parts.contains(.legs) { return "腿" }
            if parts.contains(.glutes) { return "臀" }
            if parts.isEmpty { return "训练" }
            return schedule.bodyParts.map { $0.localizedName(language: language) }.joined()
        }
        if parts.isEmpty { return "Training" }
        return schedule.bodyParts.map { $0.localizedName(language: language) }.joined(separator: "/")
    }

    private func macroValue(_ grams: Int, multiplier explicitMultiplier: Double?) -> String {
        let multiplier = explicitMultiplier ?? (Double(grams) / max(cycle.currentWeightKg, 1))
        return "\(grams)g (\(String(format: "%.1f", multiplier))x)"
    }

    private func recommendedCalorieDeltaText(for goal: TrainingCycleGoal) -> String {
        switch goal {
        case .fatLoss:
            return isChinese ? "缺口 500-700 kcal" : "Deficit 500-700 kcal"
        case .muscleGain:
            return isChinese ? "盈余 150-300 kcal" : "Surplus 150-300 kcal"
        }
    }
}

private struct AdvancedCycleDetailActionBar: View {
    let language: AppLanguage
    let onEdit: () -> Void
    let onArchive: () -> Void

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onArchive) {
                Label(isChinese ? "结束并归档" : "Archive", systemImage: "archivebox")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKColor.coral)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(MKColor.coral.opacity(0.10), in: Capsule())
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                Label(isChinese ? "编辑计划" : "Edit Plan", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(MKColor.green, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MKTheme.divider)
                .frame(height: 0.5)
        }
    }

}

private struct AdvancedDetailPlanBlock: View {
    let symbol: String
    let title: String
    let rows: [(String, String)]

    var body: some View {
        AdvancedCard {
            AdvancedCardHeader(symbol: symbol, title: title, value: "")
            ForEach(rows, id: \.0) { row in
                AdvancedStatusRow(title: row.0, value: row.1)
            }
        }
    }
}

private struct AdvancedEditPlanSheet: View {
    let language: AppLanguage
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cycleName = ""
    @State private var targetCalories = 1_850
    @State private var proteinMultiplier = 1.5
    @State private var nutritionStrategy = 1
    @State private var scheduleType = 0
    @State private var weeklyTraining = 5
    @State private var sleepTarget = 7.5
    @State private var supplementEnabled = true
    @State private var useRecommendedPlan = true

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        NavigationStack {
            Form {
                Section(isChinese ? "系统推荐" : "Recommended") {
                    Toggle(isChinese ? "使用系统推荐方案" : "Use system recommendation", isOn: $useRecommendedPlan)
                    Text(isChinese ? "推荐方案会围绕饮食、训练、休息和补剂四块生成，可保存后从下一个计划日生效。" : "Recommendations are generated around nutrition, training, recovery, and supplements, and apply from the next planned day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(isChinese ? "周期基础" : "Cycle Basics") {
                    TextField(isChinese ? "周期名称" : "Cycle name", text: $cycleName)
                }

                Section(isChinese ? "饮食计划" : "Nutrition Plan") {
                    Picker(isChinese ? "策略" : "Strategy", selection: $nutritionStrategy) {
                        Text(isChinese ? "固定热量" : "Fixed calories").tag(0)
                        Text(isChinese ? "碳循环" : "Carb cycling").tag(1)
                        Text(isChinese ? "热量渐降" : "Step-down").tag(2)
                    }
                    Stepper(isChinese ? "目标热量 \(targetCalories) kcal" : "Calories \(targetCalories) kcal", value: $targetCalories, in: 1_200...4_000, step: 50)
                    Stepper(isChinese ? "蛋白质 \(String(format: "%.1f", proteinMultiplier)) × 体重" : "Protein \(String(format: "%.1f", proteinMultiplier)) × bodyweight", value: $proteinMultiplier, in: 1.0...2.4, step: 0.1)
                }

                Section(isChinese ? "训练计划" : "Training Plan") {
                    Picker(isChinese ? "安排类型" : "Schedule type", selection: $scheduleType) {
                        Text(isChinese ? "循环：练三休一" : "Cycle: 3-on / 1-off").tag(0)
                        Text(isChinese ? "按周：周一到周日" : "Weekly: Mon-Sun").tag(1)
                    }
                    Stepper(isChinese ? "每周训练 \(weeklyTraining) 次" : "\(weeklyTraining)x / week", value: $weeklyTraining, in: 0...7)
                }

                Section(isChinese ? "休息计划" : "Recovery Plan") {
                    Stepper(isChinese ? "睡眠目标 \(String(format: "%.1f", sleepTarget)) h" : "Sleep \(String(format: "%.1f", sleepTarget)) h", value: $sleepTarget, in: 5...10, step: 0.5)
                    Text(isChinese ? "疲劳偏高时，系统会建议降低训练强度或安排恢复日。" : "When fatigue is high, the system can suggest lower intensity or a recovery day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(isChinese ? "补剂计划" : "Supplement Plan") {
                    Toggle(isChinese ? "保留补剂提醒" : "Keep supplement reminders", isOn: $supplementEnabled)
                    Text(isChinese ? "肌酸、鱼油、维生素 D3、锌镁和电解质可在后续版本继续细化剂量与提醒时间。" : "Creatine, fish oil, D3, zinc-magnesium, and electrolytes can later expose detailed dosage and reminder timing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text(isChinese ? "保存后，新计划将从明天或下一个计划日开始生效。历史已完成记录不会被修改。" : "After saving, the updated plan will apply from tomorrow or the next planned day. Completed history will not be changed.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MKTheme.secondaryText)
                }
            }
            .navigationTitle(isChinese ? "编辑计划" : "Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "取消" : "Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isChinese ? "保存" : "Save") {
                        onSave()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct AdvancedSupplementTaskCard: View {
    let supplements: [AdvancedSupplementSchedule]
    let language: AppLanguage

    var body: some View {
        AdvancedCard {
            AdvancedCardHeader(symbol: "pills", title: language == .simplifiedChinese ? "今日补剂" : "Supplements", value: "\(supplements.filter { !$0.isTakenToday }.count)")
            ForEach(supplements) { supplement in
                AdvancedSupplementRow(supplement: supplement, language: language)
            }
        }
    }
}

private struct AdvancedRecoveryStatusCard: View {
    let recovery: AdvancedRecoverySnapshot
    let language: AppLanguage

    var body: some View {
        AdvancedCard {
            AdvancedCardHeader(symbol: "waveform.path.ecg", title: language == .simplifiedChinese ? "恢复指标" : "Recovery Metrics", value: "\(recovery.score)")
            AdvancedStatusRow(title: language == .simplifiedChinese ? "睡眠" : "Sleep", value: String(format: "%.1fh", recovery.sleepHours))
            AdvancedStatusRow(title: "HRV", value: "\(recovery.hrv) ms")
            AdvancedStatusRow(title: language == .simplifiedChinese ? "静息心率" : "RHR", value: "\(recovery.restingHeartRate) bpm")
            AdvancedStatusRow(title: language == .simplifiedChinese ? "疲劳度" : "Fatigue", value: "\(recovery.fatigue) / 10")
        }
    }
}

private struct AdvancedArchiveSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(MKTheme.ink)
            .padding(.top, 4)
    }
}

private struct AdvancedArchiveSurface<Content: View>: View {
    private let bottomPadding: CGFloat
    @ViewBuilder private var content: Content

    init(bottomPadding: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.bottomPadding = bottomPadding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(24)
        .background(
            Color(
                light: UIColor(red: 1, green: 1, blue: 1, alpha: 0.88),
                dark: UIColor(red: 0.082, green: 0.094, blue: 0.110, alpha: 1)
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MKTheme.divider.opacity(0.34), lineWidth: 0.6)
        )
        .shadow(color: MKTheme.shadow.opacity(0.28), radius: 10, x: 0, y: 4)
        .padding(.bottom, bottomPadding)
    }
}

private struct AdvancedCurrentCycleArchiveCard: View {
    let cycle: AdvancedBodyCycle
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedArchiveSurface {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(cycle.name)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(MKTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text(isChinese ? "第\(cycle.currentWeek)周 / 共\(max(cycle.durationDays / 7, 1))周" : "Week \(cycle.currentWeek) / \(max(cycle.durationDays / 7, 1))")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(MKTheme.secondaryText)
                    Text(isChinese ? "已执行 \(cycle.elapsedDays) / \(cycle.durationDays) 天" : "Executed \(cycle.elapsedDays) / \(cycle.durationDays) days")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(MKTheme.ink)
                }
                Spacer(minLength: 12)
                Text(cycle.kind.title(language: language))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MKTheme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(MKTheme.fill.opacity(0.72), in: Capsule())
            }
        }
        .frame(minHeight: 120)
    }
}

private struct AdvancedCycleCalendarRow: View {
    let cycle: AdvancedBodyCycle
    let calendarDays: [AdvancedCalendarDay]
    @Binding var selectedDate: Date
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }
    private let calendar = Calendar.current

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(calendarDays) { day in
                            Button {
                                selectedDate = day.date
                            } label: {
                                AdvancedTopDateCell(
                                    day: day,
                                    isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                                    isToday: calendar.isDateInToday(day.date)
                                )
                            }
                            .buttonStyle(.plain)
                            .id(day.id)
                            .frame(width: topDateCellWidth(in: geometry.size.width))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear {
                    if let today = calendarDays.first(where: { calendar.isDateInToday($0.date) }) {
                        selectedDate = today.date
                    }
                    let selectedID = calendarDays.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }?.id
                    if let targetID = selectedID ?? calendarDays.prefix(max(cycle.elapsedDays, 1)).last?.id {
                        proxy.scrollTo(targetID, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 74)
    }

    private func topDateCellWidth(in width: CGFloat) -> CGFloat {
        let visibleCount: CGFloat = 7
        let spacing: CGFloat = 8
        return max((width - spacing * (visibleCount - 1)) / visibleCount, 40)
    }
}

private struct AdvancedTopDateCell: View {
    let day: AdvancedCalendarDay
    let isSelected: Bool
    let isToday: Bool

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private var weekday: String {
        String(Self.weekdayFormatter.string(from: day.date).prefix(1))
    }

    var body: some View {
        VStack(spacing: 5) {
            Text(weekday)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isSelected ? MKColor.green : (isToday ? MKColor.citrus : MKTheme.secondaryText))
            AdvancedCalendarBarsView(
                day: day,
                isSelected: isSelected,
                isToday: isToday,
                cellHeight: 34,
                playKey: day.id.timeIntervalSince1970 + (isSelected ? 1 : 0)
            )
            Text("\(day.dayNumber)")
                .font(.system(size: 10, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundStyle(isSelected ? MKColor.green : (isToday ? MKColor.citrus : MKTheme.secondaryText))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .contentShape(Rectangle())
        .accessibilityLabel("\(weekday) \(day.dayNumber)")
    }
}

private struct AdvancedCalendarBarsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let day: AdvancedCalendarDay
    let isSelected: Bool
    let isToday: Bool
    let cellHeight: CGFloat
    let playKey: Double

    @State private var fraction: CGFloat = 1

    private var values: [Double] {
        let nutrition = day.dimensions.indices.contains(0) ? day.dimensions[0] : 0
        let training = day.dimensions.indices.contains(1) ? day.dimensions[1] : 0
        let recovery = day.dimensions.indices.contains(2) ? day.dimensions[2] : 0
        let supplement = day.dimensions.indices.contains(3) ? day.dimensions[3] : 0
        return [nutrition, training, (recovery + supplement) / 2]
    }

    private var tileFill: Color {
        if isSelected { return MKColor.green.opacity(0.20) }
        if isToday { return MKColor.citrus.opacity(0.16) }
        return MKTheme.fill.opacity(0.92)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tileFill)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    let value = values.indices.contains(index) ? values[index] : 0
                    MKCapsuleProgressColumn(
                        progress: value * Double(fraction),
                        tint: AdvancedCalendarBarStyle.tints[index],
                        minFillHeight: value > 0 ? 2 : 0,
                        showsShadow: false
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: barTrackHeight)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .frame(height: cellHeight, alignment: .bottom)
        }
        .frame(height: cellHeight)
        .animation(.smooth(duration: 0.25), value: isSelected)
        .onChange(of: isSelected) { _, selected in
            guard selected else { return }
            Task { await rise(delay: 0) }
        }
    }

    private var barTrackHeight: CGFloat { cellHeight - 8 }

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

private struct AdvancedCalendarDayCell: View {
    let day: AdvancedCalendarDay
    let isSelected: Bool
    let isToday: Bool

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private var weekday: String {
        String(Self.weekdayFormatter.string(from: day.date).prefix(3))
    }

    var body: some View {
        VStack(spacing: 5) {
            Text(weekday)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isSelected ? MKColor.green : (isToday ? MKColor.citrus : MKTheme.secondaryText))
            AdvancedCalendarBarsView(
                day: day,
                isSelected: isSelected,
                isToday: isToday,
                cellHeight: 34,
                playKey: day.id.timeIntervalSince1970 + (isSelected ? 1 : 0)
            )

            Text("\(day.dayNumber)")
                .font(.system(size: 10, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundStyle(isSelected ? MKColor.green : (isToday ? MKColor.citrus : MKTheme.secondaryText))
                .monospacedDigit()
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .frame(width: 58)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityLabel("\(weekday) \(day.dayNumber)")
    }
}

private enum AdvancedCalendarBarStyle {
    static let tints: [Color] = [
        MKColor.green,
        Color.blue,
        Color(red: 0.47, green: 0.43, blue: 0.66)
    ]
}

private struct AdvancedCalendarLegend: View {
    let isChinese: Bool

    private var labels: [String] {
        isChinese ? ["饮食", "训练", "其他"] : ["Nutrition", "Training", "Other"]
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(AdvancedCalendarBarStyle.tints[i])
                        .frame(width: 7, height: 12)
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

private struct AdvancedSelectedCycleDayCard: View {
    let cycle: AdvancedBodyCycle
    let day: AdvancedCalendarDay
    let nutritionPlan: AdvancedNutritionPlan
    let trainingPlan: AdvancedTrainingPlan
    let supplements: [AdvancedSupplementSchedule]
    let recovery: AdvancedRecoverySnapshot
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }
    @State private var expandedDetail: AdvancedDayDetailKind?

    var body: some View {
        AdvancedArchiveSurface {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    AdvancedArchiveSectionTitle(title: cycle.name)
                    Spacer()
                    Text(dateTitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MKTheme.secondaryText)
                }

                Text(isChinese ? "第\(cycle.currentWeek)周 / 共\(max(cycle.durationDays / 7, 1))周 · 已执行 \(cycle.elapsedDays) / \(cycle.durationDays) 天" : "Week \(cycle.currentWeek) / \(max(cycle.durationDays / 7, 1)) · \(cycle.elapsedDays) / \(cycle.durationDays) days")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MKTheme.secondaryText)
            }

            VStack(spacing: 12) {
                dayFactSection(
                    kind: .nutrition,
                    title: isChinese ? "饮食" : "Nutrition",
                    value: nutritionValue,
                    displayValue: "\(Int(nutritionValue * 100))%"
                )
                dayFactSection(
                    kind: .training,
                    title: isChinese ? "训练" : "Training",
                    value: trainingValue,
                    displayValue: trainingValue >= 0.85 ? (isChinese ? "已完成" : "Done") : (isChinese ? "未完成" : "Open")
                )
                dayFactSection(
                    kind: .other,
                    title: isChinese ? "其他" : "Other",
                    value: otherValue,
                    displayValue: "\(Int(otherValue * 100))%"
                )
            }
        }
    }

    @ViewBuilder
    private func dayFactSection(kind: AdvancedDayDetailKind, title: String, value: Double, displayValue: String) -> some View {
        VStack(spacing: 10) {
            AdvancedDayFactRow(
                title: title,
                value: value,
                displayValue: displayValue,
                isExpanded: expandedDetail == kind,
                detailAction: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        expandedDetail = expandedDetail == kind ? nil : kind
                    }
                }
            )
            if expandedDetail == kind {
                AdvancedInlineDayDetailView(
                    kind: kind,
                    day: day,
                    cycle: cycle,
                    nutritionPlan: nutritionPlan,
                    trainingPlan: trainingPlan,
                    supplements: supplements,
                    recovery: recovery,
                    language: language
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var nutritionValue: Double {
        day.dimensions.indices.contains(0) ? day.dimensions[0] : 0
    }

    private var trainingValue: Double {
        day.dimensions.indices.contains(1) ? day.dimensions[1] : 0
    }

    private var otherValue: Double {
        let recovery = day.dimensions.indices.contains(2) ? day.dimensions[2] : 0
        let supplement = day.dimensions.indices.contains(3) ? day.dimensions[3] : 0
        return (recovery + supplement) / 2
    }

    private var dateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans_CN" : "en_US")
        formatter.setLocalizedDateFormatFromTemplate(isChinese ? "M月d日" : "MMM d")
        return formatter.string(from: day.date)
    }
}

private struct AdvancedDayFactRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let value: Double
    let displayValue: String
    let isExpanded: Bool
    let detailAction: () -> Void

    @State private var animatedValue: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(MKTheme.ink)
                .frame(width: 42, alignment: .leading)
            MKCapsuleProgressBar(progress: animatedValue, tint: MKColor.green, height: 4, animate: false)
            Spacer()
            Text(displayValue)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MKTheme.secondaryText)
                .monospacedDigit()
                .frame(width: 54, alignment: .trailing)
            Button(action: detailAction) {
                Image(systemName: isExpanded ? "chevron.up.circle" : "info.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.blue)
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) detail")
        }
        .task(id: value) { await animate() }
    }

    @MainActor
    private func animate() async {
        guard !reduceMotion else {
            animatedValue = value
            return
        }
        animatedValue = 0
        try? await Task.sleep(for: .milliseconds(80))
        withAnimation(.easeInOut(duration: 0.75)) {
            animatedValue = value
        }
    }
}

private enum AdvancedDayDetailKind: String, Identifiable {
    case nutrition
    case training
    case other

    var id: String { rawValue }
}

private struct AdvancedInlineDayDetailView: View {
    let kind: AdvancedDayDetailKind
    let day: AdvancedCalendarDay
    let cycle: AdvancedBodyCycle
    let nutritionPlan: AdvancedNutritionPlan
    let trainingPlan: AdvancedTrainingPlan
    let supplements: [AdvancedSupplementSchedule]
    let recovery: AdvancedRecoverySnapshot
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch kind {
            case .nutrition:
                nutritionContent
            case .training:
                trainingContent
            case .other:
                otherContent
            }
        }
        .padding(12)
        .background(MKTheme.fill.opacity(0.82), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var nutritionContent: some View {
        let progress = dimension(0)
        let calories = Int(Double(nutritionPlan.calories) * progress)
        AdvancedDayDetailAnimatedBar(title: isChinese ? "热量" : "Calories", current: Double(calories), target: Double(max(nutritionPlan.calories, 1)), value: "\(calories) / \(nutritionPlan.calories) kcal", tint: MKColor.green)
        AdvancedDayDetailAnimatedBar(title: isChinese ? "蛋白质" : "Protein", current: Double(nutritionPlan.protein) * progress, target: Double(max(nutritionPlan.protein, 1)), value: "\(Int(Double(nutritionPlan.protein) * progress)) / \(nutritionPlan.protein)g", tint: AdvancedFitnessRingColor.protein)
        AdvancedDayDetailAnimatedBar(title: isChinese ? "碳水" : "Carbs", current: Double(nutritionPlan.carbs) * progress, target: Double(max(nutritionPlan.carbs, 1)), value: "\(Int(Double(nutritionPlan.carbs) * progress)) / \(nutritionPlan.carbs)g", tint: AdvancedFitnessRingColor.carbs)
        AdvancedDayDetailAnimatedBar(title: isChinese ? "脂肪" : "Fat", current: Double(nutritionPlan.fat) * progress, target: Double(max(nutritionPlan.fat, 1)), value: "\(Int(Double(nutritionPlan.fat) * progress)) / \(nutritionPlan.fat)g", tint: AdvancedFitnessRingColor.fat)
    }

    @ViewBuilder
    private var trainingContent: some View {
        let progress = dimension(1)
        AdvancedStatusRow(title: isChinese ? "当天安排" : "Plan", value: trainingDayTitle)
        AdvancedStatusRow(title: isChinese ? "训练计划" : "Training Plan", value: trainingPlan.name)
        AdvancedDayDetailAnimatedBar(title: isChinese ? "完成进度" : "Completion", current: progress, target: 1, value: "\(Int(progress * 100))%", tint: Color.blue)
    }

    @ViewBuilder
    private var otherContent: some View {
        let recoveryProgress = dimension(2)
        let supplementProgress = dimension(3)
        AdvancedDayDetailAnimatedBar(title: isChinese ? "恢复" : "Recovery", current: recoveryProgress, target: 1, value: "\(Int(recoveryProgress * 100))%", tint: AdvancedFitnessRingColor.sleep)
        AdvancedStatusRow(title: isChinese ? "睡眠参考" : "Sleep", value: String(format: "%.1fh", recovery.sleepHours))
        AdvancedDayDetailAnimatedBar(title: isChinese ? "补剂" : "Supplements", current: supplementProgress, target: 1, value: "\(Int(supplementProgress * 100))%", tint: AdvancedFitnessRingColor.stand)
        if !supplements.isEmpty {
            Text(supplements.map(\.name).joined(separator: " · "))
                .font(.caption.weight(.medium))
                .foregroundStyle(MKTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var trainingDayTitle: String {
        guard !trainingPlan.days.isEmpty else { return isChinese ? "待配置" : "Not set" }
        let offset = max(calendar.dateComponents([.day], from: cycle.startDate, to: day.date).day ?? 0, 0)
        let planDay = trainingPlan.days[offset % trainingPlan.days.count]
        return planDay.isRestDay ? (isChinese ? "休息日" : "Rest Day") : planDay.title
    }

    private func dimension(_ index: Int) -> Double {
        guard day.dimensions.indices.contains(index) else { return 0 }
        return min(max(day.dimensions[index], 0), 1)
    }
}

private struct AdvancedDayDetailAnimatedBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let current: Double
    let target: Double
    let value: String
    let tint: Color

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        min(max(current / max(target, 0.0001), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MKTheme.ink)
                    .monospacedDigit()
            }
            MKCapsuleProgressBar(progress: animatedProgress, tint: tint, height: 5, animate: false)
        }
        .task(id: "\(current)-\(target)") { await animate() }
    }

    @MainActor
    private func animate() async {
        guard !reduceMotion else {
            animatedProgress = progress
            return
        }
        animatedProgress = 0
        try? await Task.sleep(for: .milliseconds(80))
        withAnimation(.easeInOut(duration: 0.75)) {
            animatedProgress = progress
        }
    }
}

private struct AdvancedCycleCompletionSummary: View {
    let completions: [AdvancedDailyCompletion]
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedArchiveSurface {
            HStack(alignment: .firstTextBaseline) {
                AdvancedArchiveSectionTitle(title: isChinese ? "周期完成概览" : "Completion Summary")
                Spacer()
                Text("\(Int(completions.averageCompletion * 100))%")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(MKTheme.ink)
                    .monospacedDigit()
            }

            VStack(spacing: 10) {
                AdvancedArchiveCompletionBar(title: isChinese ? "饮食" : "Nutrition", value: completions.map(\.nutrition).average)
                AdvancedArchiveCompletionBar(title: isChinese ? "训练" : "Training", value: completions.map(\.training).average)
                AdvancedArchiveCompletionBar(title: isChinese ? "恢复" : "Recovery", value: completions.map(\.recovery).average)
                AdvancedArchiveCompletionBar(title: isChinese ? "补剂" : "Supplements", value: completions.map(\.supplement).average)
            }
        }
    }
}

private struct AdvancedArchiveCompletionBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let value: Double

    @State private var animatedValue: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MKTheme.secondaryText)
                .frame(width: 42, alignment: .leading)
            MKCapsuleProgressBar(progress: animatedValue, tint: MKColor.green, height: 4, animate: false)
            Text("\(Int(value * 100))%")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MKTheme.ink)
                .monospacedDigit()
                .frame(width: 38, alignment: .trailing)
        }
        .task(id: value) { await animate() }
    }

    @MainActor
    private func animate() async {
        guard !reduceMotion else {
            animatedValue = value
            return
        }
        animatedValue = 0
        try? await Task.sleep(for: .milliseconds(80))
        withAnimation(.easeInOut(duration: 0.75)) {
            animatedValue = value
        }
    }
}

private struct AdvancedFullCalendarSheet: View {
    let cycle: AdvancedBodyCycle
    let calendarDays: [AdvancedCalendarDay]
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    private var isChinese: Bool { language == .simplifiedChinese }
    private let calendar = Calendar.current

    private var calendarGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    }

    private var weekdaySymbols: [String] {
        isChinese ? ["一", "二", "三", "四", "五", "六", "日"] : ["M", "T", "W", "T", "F", "S", "S"]
    }

    private var months: [AdvancedCalendarMonth] {
        let grouped = Dictionary(grouping: calendarDays) { day in
            calendar.dateComponents([.year, .month], from: day.date)
        }
        return grouped.sorted { lhs, rhs in
            if lhs.key.year != rhs.key.year { return (lhs.key.year ?? 0) < (rhs.key.year ?? 0) }
            return (lhs.key.month ?? 0) < (rhs.key.month ?? 0)
        }.map { key, days in
            guard days.first?.date != nil,
                  let monthStart = calendar.date(from: key) else {
                return AdvancedCalendarMonth(id: key, title: "", leadingBlanks: 0, days: days)
            }
            let firstWeekday = calendar.component(.weekday, from: monthStart)
            let leadingBlanks = (firstWeekday + 5) % 7
            let showYear = key.month == 1
            return AdvancedCalendarMonth(
                id: key,
                title: monthTitle(monthStart, showYear: showYear),
                leadingBlanks: leadingBlanks,
                days: days.sorted { $0.date < $1.date }
            )
        }
    }

    var body: some View {
        NavigationStack {
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
                                    Color.clear.frame(height: 54)
                                }
                                ForEach(month.days) { day in
                                    AdvancedCalendarDayCell(
                                        day: day,
                                        isSelected: false,
                                        isToday: calendar.isDateInToday(day.date)
                                    )
                                }
                            }
                        }
                        .id(month.id)
                    }

                    AdvancedCalendarLegend(isChinese: isChinese)

                    cycleInfoFooter
                }
                .padding(20)
            }
            .background(MKBackdrop())
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(isChinese ? "完整日历" : "Full Calendar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                    }
                    .accessibilityLabel(isChinese ? "关闭" : "Close")
                }
            }
        }
    }

    private var cycleInfoFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(MKTheme.divider)
            HStack {
                Text(cycle.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                Spacer()
                Text("\(cycle.startDate.formatted(.dateTime.month(.abbreviated).day())) - \(cycle.endDate.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MKTheme.secondaryText)
            }
            Text(isChinese ? "进度 \(cycle.elapsedDays) / \(cycle.durationDays) 天" : "Progress \(cycle.elapsedDays) / \(cycle.durationDays) days")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.blue)
        }
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
}

private struct AdvancedCycleDetailView: View {
    let record: AdvancedCycleRecord
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date

    private var isChinese: Bool { language == .simplifiedChinese }
    private let calendar = Calendar.current

    private var calendarDays: [AdvancedCalendarDay] {
        let duration = max(calendar.dateComponents([.day], from: record.startDate, to: record.endDate).day ?? 1, 1)
        return (0..<duration).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: record.startDate) else { return nil }
            let dayIndex = offset + 1
            let completionIndex = offset
            let dims: [Double]
            if completionIndex >= 0 && completionIndex < sampleCompletions.count {
                let c = sampleCompletions[completionIndex]
                dims = [c.nutrition, c.training, c.recovery, c.supplement]
            } else {
                dims = [0, 0, 0, 0]
            }
            return AdvancedCalendarDay(
                id: calendar.startOfDay(for: date),
                date: date,
                dayLabel: "D\(dayIndex)",
                dayNumber: calendar.component(.day, from: date),
                dimensions: dims
            )
        }
    }

    private var sampleCompletions: [AdvancedDailyCompletion] {
        let duration = max(calendar.dateComponents([.day], from: record.startDate, to: record.endDate).day ?? 1, 1)
        let completedDays = record.executedDays
        return (0..<duration).map { offset in
            let isExecuted = offset < completedDays
            let base = isExecuted ? record.completionRate : 0.0
            let wave = sin(Double(offset) * 0.7) * 0.08
            return AdvancedDailyCompletion(
                dayLabel: "D\(offset + 1)",
                nutrition: isExecuted ? min(max(base + wave + 0.03, 0), 1.0) : 0,
                training: isExecuted ? min(max(base + wave - 0.05, 0), 1.0) : 0,
                recovery: isExecuted ? min(max(base - wave + 0.02, 0), 1.0) : 0,
                supplement: isExecuted ? min(max(base + wave * 0.5, 0), 1.0) : 0
            )
        }
    }

    private var selectedDayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans_CN" : "en_US")
        formatter.setLocalizedDateFormatFromTemplate(isChinese ? "M月d日 EEEE" : "EEE, MMM d")
        return formatter.string(from: selectedDate)
    }

    private var selectedDayDimensions: [Double] {
        guard let day = calendarDays.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDate) }) else {
            return [0, 0, 0, 0]
        }
        return day.dimensions
    }

    private var detailTitles: [String] {
        isChinese ? ["饮食", "训练", "恢复", "补剂"] : ["Nutrition", "Training", "Recovery", "Suppl."]
    }

    private var detailSymbols: [String] = ["fork.knife", "figure.strengthtraining.traditional", "bed.double.fill", "pills.fill"]

    private static let detailTints: [Color] = [
        MKColor.green,
        Color.blue,
        Color(red: 0.47, green: 0.43, blue: 0.66),
        MKColor.citrus
    ]

    init(record: AdvancedCycleRecord, language: AppLanguage) {
        self.record = record
        self.language = language
        self._selectedDate = State(initialValue: record.startDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    cycleHeader

                    VStack(alignment: .leading, spacing: 12) {
                        Text(isChinese ? "执行日历" : "Execution Calendar")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)

                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(calendarDays) { day in
                                        Button {
                                            selectedDate = day.date
                                        } label: {
                                            AdvancedCalendarDayCell(
                                                day: day,
                                                isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                                                isToday: calendar.isDateInToday(day.date)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .id(day.id)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                            .onAppear {
                                if let firstID = calendarDays.first?.id {
                                    proxy.scrollTo(firstID, anchor: .leading)
                                }
                            }
                        }

                        AdvancedCalendarLegend(isChinese: isChinese)
                    }
                    .padding(16)
                    .mkThemeCard(cornerRadius: 18)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(isChinese ? "详细记录" : "Detailed Records")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(MKTheme.ink)
                            Spacer()
                            Text(selectedDayTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.10), in: Capsule())
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(0..<4, id: \.self) { i in
                                AdvancedDetailRingTile(
                                    title: detailTitles[i],
                                    symbol: detailSymbols[i],
                                    progress: selectedDayDimensions.indices.contains(i) ? selectedDayDimensions[i] : 0,
                                    tint: Self.detailTints[i]
                                )
                            }
                        }
                    }
                    .padding(16)
                    .mkThemeCard(cornerRadius: 18)
                }
                .padding(20)
            }
            .background(MKBackdrop())
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(record.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                    }
                }
            }
        }
    }

    private var cycleHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                    Text("\(record.startDate.formatted(.dateTime.month(.abbreviated).day())) - \(record.endDate.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MKTheme.secondaryText)
                }
                Spacer()
                Text(record.status.title(language: language))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(record.status == .abandoned ? MKColor.citrus : MKColor.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background((record.status == .abandoned ? MKColor.citrus : MKColor.green).opacity(0.12), in: Capsule())
            }

            AdvancedStatusRow(title: isChinese ? "完成率" : "Completion", value: "\(Int(record.completionRate * 100))%")
            AdvancedStatusRow(title: isChinese ? "执行天数" : "Executed", value: "\(record.executedDays)d")
            AdvancedStatusRow(title: isChinese ? "关键结果" : "Key result", value: record.keyResult)

            Text(record.aiReview)
                .font(.caption.weight(.medium))
                .foregroundStyle(MKTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .mkThemeInsetTile(cornerRadius: 12)
        }
        .padding(16)
        .mkThemeCard(cornerRadius: 18)
    }
}

private struct AdvancedDetailRingTile: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let symbol: String
    let progress: Double
    let tint: Color

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
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(1)
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(minHeight: 78)
        .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .task(id: "\(title)\(progress)") { await sweep() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(Int(progress * 100))%")
    }

    @MainActor
    private func sweep() async {
        guard !reduceMotion else {
            animated = progress
            return
        }
        animated = 0
        try? await Task.sleep(for: .milliseconds(16))
        withAnimation(.easeInOut(duration: 0.75)) {
            animated = progress
        }
    }
}

private struct AdvancedCalendarMonth: Identifiable {
    let id: DateComponents
    let title: String
    let leadingBlanks: Int
    let days: [AdvancedCalendarDay]
}

private struct AdvancedCycleHistoryCard: View {
    let record: AdvancedCycleRecord
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        AdvancedArchiveSurface(bottomPadding: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.name)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(MKTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text(dateRangeText)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MKTheme.secondaryText)
                }

                Spacer(minLength: 10)

                HStack(spacing: 8) {
                    Text(record.status.title(language: language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusTint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusTint.opacity(0.12), in: Capsule())

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(MKTheme.secondaryText.opacity(0.75))
                }
            }

            AdvancedCycleAlbumMetricsRow(
                days: AdvancedCycleAlbumMetricFormatter.cycleDays(record),
                training: trainingCountText,
                weight: weightChangeText,
                bodyFat: bodyFatChangeText,
                language: language,
                isCompact: true
            )
        }
    }

    private var dateRangeText: String {
        "\(record.startDate.formatted(.dateTime.month(.abbreviated).day())) - \(record.endDate.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var statusTint: Color {
        record.status == .abandoned ? MKColor.citrus : MKColor.green
    }

    private var trainingCountText: String {
        AdvancedCycleAlbumMetricFormatter.trainingCount(from: record)
    }

    private var weightChangeText: String {
        AdvancedCycleAlbumMetricFormatter.weightChange(from: record)
    }

    private var bodyFatChangeText: String {
        AdvancedCycleAlbumMetricFormatter.bodyFatChange(from: record)
    }
}

private struct AdvancedArchiveHistoryFact: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.regular))
                .foregroundStyle(MKTheme.secondaryText)
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(MKTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AdvancedAchievementGrid: View {
    let achievements: [AdvancedAchievement]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(achievements) { achievement in
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: achievement.symbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(achievement.isUnlocked ? MKColor.green : MKTheme.secondaryText)
                        .frame(width: 36, height: 36)
                        .background((achievement.isUnlocked ? MKColor.green : MKTheme.secondaryText).opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    Text(achievement.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(achievement.detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(MKTheme.secondaryText)
                        .lineLimit(2)
                    MKThemeProgressBar(progress: achievement.progress, tint: achievement.isUnlocked ? MKColor.green : Color.blue, height: 6)
                }
                .padding(14)
                .mkThemeCard(cornerRadius: 16)
            }
        }
    }
}

private struct AdvancedCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .mkThemeCard(cornerRadius: 18)
    }
}

private struct AdvancedSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline.weight(.bold))
            .foregroundStyle(MKTheme.ink)
            .padding(.top, 6)
    }
}

private struct AdvancedCardHeader: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.blue)
                .frame(width: 30, height: 30)
                .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(MKTheme.ink)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

private struct AdvancedMetric: Identifiable {
    var id = UUID()
    var title: String
    var value: String
    var caption: String
    var tint: Color
}

private struct AdvancedMetricGrid: View {
    let metrics: [AdvancedMetric]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 6) {
                    Text(metric.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MKTheme.secondaryText)
                    Text(metric.value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(MKTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(metric.caption)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(metric.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .mkThemeCard(cornerRadius: 16)
            }
        }
    }
}

private struct AdvancedSmallStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MKTheme.secondaryText)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .mkThemeInsetTile(cornerRadius: 12)
    }
}

private struct AdvancedStatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MKTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKTheme.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

private struct AdvancedDivider: View {
    var body: some View {
        Rectangle()
            .fill(MKTheme.divider)
            .frame(height: 0.5)
            .padding(.leading, 40)
    }
}

private struct AdvancedExerciseRow: View {
    let exercise: AdvancedExercise

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                Text("\(exercise.sets) sets · \(exercise.reps) reps · RPE \(exercise.rpe)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MKTheme.secondaryText)
            }
            Spacer()
        }
        .padding(12)
        .mkThemeInsetTile(cornerRadius: 12)
    }
}

private struct AdvancedMacroRow: View {
    let title: String
    let current: Int
    let target: Int
    let unit: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                Spacer()
                Text("\(current) / \(target)\(unit)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)
            }
            MKThemeProgressBar(progress: Double(current) / Double(max(target, 1)), tint: tint, height: 7)
        }
    }
}

private struct AdvancedSupplementRow: View {
    let supplement: AdvancedSupplementSchedule
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: supplement.isTakenToday ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(supplement.isTakenToday ? MKColor.green : MKTheme.secondaryText)
            VStack(alignment: .leading, spacing: 3) {
                Text(supplement.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                Text("\(supplement.dosage) · \(supplement.timing)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MKTheme.secondaryText)
            }
            Spacer()
            Text(language == .simplifiedChinese ? "库存 \(supplement.inventoryDays) 天" : "\(supplement.inventoryDays)d left")
                .font(.caption.weight(.semibold))
                .foregroundStyle(supplement.inventoryDays < 10 ? MKColor.citrus : MKTheme.secondaryText)
        }
        .padding(12)
        .mkThemeInsetTile(cornerRadius: 12)
    }
}

private struct AdvancedAnalystCard: View {
    let insight: AdvancedAIInsight
    let language: AppLanguage

    var body: some View {
        AdvancedCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: insight.riskLevel == .low ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(insight.riskLevel.tint)
                    .frame(width: 36, height: 36)
                    .background(insight.riskLevel.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(language == .simplifiedChinese ? "Body Analyst" : "Body Analyst")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.blue)
                        Spacer()
                        Text(insight.riskLevel.title(language: language))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(insight.riskLevel.tint)
                    }
                    Text(insight.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                    Text(insight.summary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MKTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        ForEach(insight.evidence.prefix(2), id: \.self) { item in
                            Text(item)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(MKTheme.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(MKTheme.fill, in: Capsule())
                        }
                    }
                }
            }
        }
    }
}

private struct AdvancedRemainingAction: Identifiable {
    let id = UUID()
    let title: String
    let level: AdvancedRiskLevel
    let actionTitle: String
    let action: () -> Void
}

private struct AdvancedRemainingActionsCard: View {
    let plan: AdvancedNutritionPlan
    let eatenCalories: Int
    let eatenMacros: MacroTarget
    let trainingDay: AdvancedTrainingDay
    let trainingLog: AdvancedTrainingLog
    let sleepLog: AdvancedSleepLog
    let supplements: [AdvancedSupplementSchedule]
    let supplementIntakes: [AdvancedSupplementIntake]
    let language: AppLanguage
    let nutritionAction: () -> Void
    let trainingAction: () -> Void
    let otherAction: () -> Void

    private var isChinese: Bool { language == .simplifiedChinese }

    private var supplementItems: [(String, Bool)] {
        if !supplementIntakes.isEmpty {
            return supplementIntakes.map { ($0.name, $0.isTaken) }
        }
        return supplements.map { ($0.name, $0.isTakenToday) }
    }

    private var actions: [AdvancedRemainingAction] {
        var items: [AdvancedRemainingAction] = []
        let proteinGap = max(plan.protein - eatenMacros.protein, 0)
        if proteinGap > 0 {
            items.append(.init(
                title: isChinese ? "蛋白质还差 \(proteinGap)g" : "\(proteinGap)g protein remaining",
                level: proteinGap >= 40 ? .high : .moderate,
                actionTitle: isChinese ? "记饮食" : "Log",
                action: nutritionAction
            ))
        }
        let calorieLeft = plan.calories - eatenCalories
        if eatenCalories == 0 || calorieLeft > 0 {
            items.append(.init(
                title: eatenCalories == 0
                    ? (isChinese ? "今日饮食尚未记录" : "No nutrition logged today")
                    : (isChinese ? "热量还剩 \(calorieLeft) kcal" : "\(calorieLeft) kcal remaining"),
                level: eatenCalories == 0 ? .moderate : .low,
                actionTitle: isChinese ? "记录" : "Log",
                action: nutritionAction
            ))
        }
        if !trainingDay.isRestDay && trainingLog.durationMinutes == 0 {
            items.append(.init(
                title: isChinese ? "\(trainingDay.title)未完成" : "\(trainingDay.title) pending",
                level: .moderate,
                actionTitle: isChinese ? "记训练" : "Log",
                action: trainingAction
            ))
        }
        if let missed = supplementItems.first(where: { !$0.1 }) {
            items.append(.init(
                title: isChinese ? "\(missed.0)未记录" : "\(missed.0) not logged",
                level: .moderate,
                actionTitle: isChinese ? "记其他" : "Log",
                action: otherAction
            ))
        }
        if sleepLog.totalHours < 7.5 {
            items.append(.init(
                title: isChinese ? "睡眠还差 \(String(format: "%.1f", 7.5 - sleepLog.totalHours))h" : "\(String(format: "%.1f", 7.5 - sleepLog.totalHours))h sleep remaining",
                level: sleepLog.totalHours < 6.5 ? .high : .low,
                actionTitle: isChinese ? "记其他" : "Log",
                action: otherAction
            ))
        }
        return items
    }

    var body: some View {
        let visible = Array(actions.prefix(3))
        AdvancedCard {
            HStack(alignment: .firstTextBaseline) {
                Text(isChinese ? "还剩 \(actions.count) 件事" : "\(actions.count) remaining")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                Spacer()
                if actions.count > 3 {
                    Text(isChinese ? "查看全部" : "View all")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.blue)
                }
            }
            if visible.isEmpty {
                Text(isChinese ? "今日关键项目已完成。" : "Key items are complete for today.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MKTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(visible) { item in
                        AdvancedRemainingActionRow(item: item, language: language)
                        if item.id != visible.last?.id { AdvancedDivider() }
                    }
                }
            }
        }
    }
}

private struct AdvancedRemainingActionRow: View {
    let item: AdvancedRemainingAction
    let language: AppLanguage

    var body: some View {
        Button(action: item.action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(item.level.tint)
                    .frame(width: 8, height: 8)
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 10)
                Text(item.actionTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(item.level.tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(item.level.tint.opacity(0.10), in: Capsule())
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AdvancedAISuggestionCard: View {
    let insight: AdvancedAIInsight
    let plan: AdvancedNutritionPlan
    let eatenCalories: Int
    let eatenMacros: MacroTarget
    let basalMetabolicRate: Int
    let activityCalories: Int
    let exerciseCalories: Int
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }
    private var calorieDelta: Int { basalMetabolicRate + activityCalories + exerciseCalories - eatenCalories }
    private var proteinGap: Int { max(plan.protein - eatenMacros.protein, 0) }
    private var carbGap: Int { max(plan.carbs - eatenMacros.carbs, 0) }
    private var fatOver: Int { max(eatenMacros.fat - plan.fat, 0) }
    private var suggestion: (text: String, level: AdvancedRiskLevel) {
        if fatOver > 0 {
            return (
                isChinese ? "脂肪已超出目标 \(fatOver)g，晚餐优先选择低脂蛋白来源。" : "Fat is \(fatOver)g over target. Prioritize lean protein at dinner.",
                .high
            )
        }
        if calorieDelta > 1_000 {
            return (
                isChinese ? "预计缺口 \(calorieDelta) kcal 偏大，建议增加 40-60g 碳水。" : "Estimated deficit is \(calorieDelta) kcal. Add 40-60g carbs.",
                .high
            )
        }
        if proteinGap >= 35 {
            return (
                isChinese ? "蛋白质还差 \(proteinGap)g，晚餐增加 200g 鸡胸肉或等量低脂蛋白。" : "\(proteinGap)g protein remaining. Add lean protein at dinner.",
                .moderate
            )
        }
        if carbGap >= 45 {
            return (
                isChinese ? "碳水还差 \(carbGap)g，训练后增加 1 份主食。" : "\(carbGap)g carbs remaining. Add one staple serving post-workout.",
                .moderate
            )
        }
        return (insight.summary, insight.riskLevel)
    }

    var body: some View {
        AdvancedCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: suggestion.level == .low ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(suggestion.level.tint)
                    .frame(width: 32, height: 32)
                    .background(suggestion.level.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(language == .simplifiedChinese ? "AI 今日建议" : "AI Suggestion")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.blue)
                        Spacer()
                        Text(suggestion.level.title(language: language))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(suggestion.level.tint)
                    }
                    Text(suggestion.text)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MKTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct AdvancedQuickLogBar: View {
    let language: AppLanguage
    let nutritionAction: () -> Void
    let trainingAction: () -> Void
    let weightAction: () -> Void
    let otherAction: () -> Void

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        HStack(spacing: 8) {
            AdvancedQuickLogButton(title: isChinese ? "饮食" : "Food", symbol: "fork.knife", action: nutritionAction)
            AdvancedQuickLogButton(title: isChinese ? "训练" : "Train", symbol: "figure.strengthtraining.traditional", action: trainingAction)
            AdvancedQuickLogButton(title: isChinese ? "体重" : "Weight", symbol: "scalemass", action: weightAction)
            AdvancedQuickLogButton(title: isChinese ? "其他" : "Other", symbol: "ellipsis.circle", action: otherAction)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AdvancedQuickLogButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.ink)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(MKTheme.fill, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private extension AdvancedTrainingPlan {
    var today: AdvancedTrainingDay {
        days.first { $0.weekday == max(Calendar.current.component(.weekday, from: Date()) - 1, 1) } ?? days[0]
    }
}

// MARK: - New Summary Rows

private struct AdvancedNutritionSummaryRow: View {
    let plan: AdvancedNutritionPlan
    let eaten: MacroTarget
    let eatenCalories: Int
    let basalMetabolicRate: Int
    let activityCalories: Int
    let exerciseCalories: Int
    let language: AppLanguage
    let action: () -> Void

    private var isChinese: Bool { language == .simplifiedChinese }
    private var dynamicBurn: Int { basalMetabolicRate + activityCalories + exerciseCalories }
    private var calorieDeficit: Int { dynamicBurn - eatenCalories }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                AdvancedProgressRing(
                    progress: Double(eatenCalories) / Double(max(dynamicBurn, 1)),
                    symbol: "fork.knife",
                    tint: Color.blue
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(isChinese ? "饮食" : "Nutrition")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)
                        Spacer()
                        Text(calorieDeficit >= 0
                             ? "\(calorieDeficit) kcal \(isChinese ? "缺口" : "deficit")"
                             : "\(abs(calorieDeficit)) kcal \(isChinese ? "盈余" : "surplus")")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(calorieDeficit >= 0 ? MKColor.green : MKColor.coral)
                    }

                    HStack(spacing: 8) {
                        AdvancedMacroProgressPill(
                            title: isChinese ? "碳水" : "Carbs",
                            current: eaten.carbs,
                            target: plan.carbs,
                            unit: "g",
                            tint: Color.blue
                        )
                        AdvancedMacroProgressPill(
                            title: isChinese ? "蛋白质" : "Protein",
                            current: eaten.protein,
                            target: plan.protein,
                            unit: "g",
                            tint: MKColor.green
                        )
                        AdvancedMacroProgressPill(
                            title: isChinese ? "脂肪" : "Fat",
                            current: eaten.fat,
                            target: plan.fat,
                            unit: "g",
                            tint: MKColor.citrus
                        )
                    }
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AdvancedMacroProgressPill: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let current: Int
    let target: Int
    let unit: String
    let tint: Color

    @State private var animatedProgress = 0.0

    private var progress: Double {
        min(max(Double(current) / Double(max(target, 1)), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MKTheme.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(current)/\(target)\(unit)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            MKCapsuleProgressBar(progress: animatedProgress, tint: tint, height: 4, animate: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 42)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: progress) {
            await animate()
        }
    }

    @MainActor
    private func animate() async {
        guard !reduceMotion else {
            animatedProgress = progress
            return
        }
        animatedProgress = 0
        try? await Task.sleep(for: .milliseconds(90))
        withAnimation(.easeInOut(duration: 0.7)) {
            animatedProgress = progress
        }
    }
}

private struct AdvancedTrainingSummaryRow: View {
    let trainingDay: AdvancedTrainingDay
    let log: AdvancedTrainingLog
    let language: AppLanguage
    let action: () -> Void

    private var isChinese: Bool { language == .simplifiedChinese }
    private var isDone: Bool { trainingDay.isRestDay || log.durationMinutes > 0 }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                AdvancedProgressRing(
                    progress: isDone ? 1 : 0,
                    symbol: "figure.strengthtraining.traditional",
                    tint: MKColor.green
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(isChinese ? "训练" : "Training")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)
                        Spacer()
                        Text(isDone ? (isChinese ? "已完成" : "Done") : (isChinese ? "未完成" : "Pending"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isDone ? MKColor.green : MKTheme.secondaryText)
                    }

                    HStack(spacing: 8) {
                        AdvancedPlanDataTile(
                            title: isChinese ? "内容" : "Plan",
                            value: trainingDay.isRestDay
                                ? (isChinese ? "恢复日" : "Recovery")
                                : trainingDay.title,
                            tint: MKColor.green
                        )
                        AdvancedPlanDataTile(
                            title: isChinese ? "时间" : "Time",
                            value: log.durationMinutes > 0 ? "\(log.durationMinutes) min" : (isChinese ? "待确认" : "Confirm"),
                            tint: Color.blue
                        )
                        AdvancedPlanDataTile(
                            title: isChinese ? "消耗" : "Burn",
                            value: log.caloriesBurned > 0 ? "\(log.caloriesBurned) kcal" : (isChinese ? "待同步" : "Sync"),
                            tint: MKColor.citrus
                        )
                    }
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AdvancedRecoverySummaryRow: View {
    let log: AdvancedSleepLog
    let language: AppLanguage
    let action: () -> Void

    private var isChinese: Bool { language == .simplifiedChinese }
    private var totalHours: Double { log.totalHours }
    private var isDone: Bool { totalHours >= 7.5 }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                AdvancedProgressRing(
                    progress: totalHours / 7.5,
                    symbol: "bed.double",
                    tint: MKColor.citrus
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(isChinese ? "休息" : "Recovery")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)
                        Spacer()
                        Text(isDone ? (isChinese ? "已完成" : "Done") : (isChinese ? "待确认" : "Pending"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isDone ? MKColor.green : MKTheme.secondaryText)
                    }

                    HStack(spacing: 8) {
                        AdvancedPlanDataTile(
                            title: isChinese ? "睡眠" : "Sleep",
                            value: String(format: "%.1fh / 7.5h", totalHours),
                            tint: MKColor.citrus
                        )
                        AdvancedPlanDataTile(
                            title: isChinese ? "入睡" : "Bed",
                            value: Self.timeFormatter.string(from: log.bedTime),
                            tint: Color.blue
                        )
                        AdvancedPlanDataTile(
                            title: isChinese ? "起床" : "Wake",
                            value: Self.timeFormatter.string(from: log.wakeTime),
                            tint: MKColor.green
                        )
                    }
                }
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AdvancedSupplementsSummaryRow: View {
    let supplements: [AdvancedSupplementSchedule]
    let intakes: [AdvancedSupplementIntake]
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }
    private var takenCount: Int { displayItems.filter(\.isTaken).count }
    private var isDone: Bool { !displayItems.isEmpty && displayItems.allSatisfy(\.isTaken) }

    private var displayItems: [(name: String, dosage: String, isTaken: Bool)] {
        if !intakes.isEmpty {
            return intakes.map { ($0.name, $0.dosage, $0.isTaken) }
        }
        return supplements.map { ($0.name, $0.dosage, $0.isTakenToday) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                AdvancedProgressRing(
                    progress: Double(takenCount) / Double(max(displayItems.count, 1)),
                    symbol: "pills",
                    tint: Color.blue
                )
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(isChinese ? "补剂" : "Supplements")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)
                        Spacer()
                        Text("\(takenCount) / \(displayItems.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isDone ? MKColor.green : MKTheme.secondaryText)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(Array(displayItems.enumerated()), id: \.offset) { _, item in
                            AdvancedSupplementCheckTile(
                                name: item.name,
                                isTaken: item.isTaken,
                                language: language
                            )
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AdvancedPlanDataTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            HStack(spacing: 5) {
                Circle()
                    .fill(tint)
                    .frame(width: 5, height: 5)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MKTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MKTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 42)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AdvancedSupplementCheckTile: View {
    let name: String
    let isTaken: Bool
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isTaken ? MKColor.green : MKTheme.secondaryText)
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MKTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 42)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background((isTaken ? MKColor.green : Color.blue).opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Input Sheets

private struct AdvancedNutritionInputSheet: View {
    let macros: MacroTarget
    let plan: AdvancedNutritionPlan
    let language: AppLanguage
    let mealHistory: [MealLog]
    let onSave: (MealLog) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var analyzedRecord: AdvancedFoodRecordDraft?
    @State private var query = ""
    @State private var selectedTemplate: AdvancedFoodTemplate?
    @State private var isShowingCamera = false
    @State private var analyzedServings = 1
    @FocusState private var isFoodInputFocused: Bool

    private var isChinese: Bool { language == .simplifiedChinese }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var matchingSuggestions: [AdvancedFoodTemplate] {
        let source = historyTemplates + AdvancedFoodTemplate.frequent(language: language)
        var seen: Set<String> = []
        let unique = source.filter { template in
            let key = template.name.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
        guard !trimmedQuery.isEmpty else { return [] }
        return Array(unique.filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }.prefix(4))
    }

    private var timeBasedHistory: [AdvancedFoodTemplate] {
        let nowHour = Calendar.current.component(.hour, from: Date())
        let preferred = historyTemplates.filter { template in
            guard let hour = template.lastLoggedHour else { return false }
            return abs(hour - nowHour) <= 2 || (mealPeriod(for: hour) == mealPeriod(for: nowHour))
        }
        let fallback = preferred.isEmpty ? historyTemplates : preferred
        return Array(fallback.prefix(8))
    }

    private var historyTemplates: [AdvancedFoodTemplate] {
        mealHistory
            .sorted { $0.createdAt > $1.createdAt }
            .map { AdvancedFoodTemplate(meal: $0, language: language) }
    }
    private var adjustedAnalyzedRecord: AdvancedFoodRecordDraft? {
        guard let analyzedRecord else { return nil }
        return AdvancedFoodRecordDraft(
            template: analyzedRecord.template,
            servings: analyzedServings,
            source: analyzedRecord.source,
            note: analyzedRecord.note
        )
    }

    var body: some View {
        let matching = matchingSuggestions
        let periodHistory = timeBasedHistory
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(isChinese ? "输入或选择食物，AI 会先分析营养结果。" : "Type or choose a food, then review the AI estimate.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MKTheme.secondaryText)

                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(MKTheme.secondaryText)
                            TextField(isChinese ? "例如：兰州牛肉面、全蛋、乳清蛋白" : "e.g. beef noodles, eggs, whey", text: $query)
                                .font(.subheadline.weight(.semibold))
                                .submitLabel(.done)
                                .focused($isFoodInputFocused)
                                .onSubmit { analyzeTypedFood() }
                            if !query.isEmpty {
                                Button {
                                    query = ""
                                    selectedTemplate = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(MKTheme.secondaryText)
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                    isShowingCamera = true
                                } else {
                                    analyzeCameraFallback()
                                }
                            } label: {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.blue)
                                    .frame(width: 30, height: 30)
                                    .background(Color.blue.opacity(0.10), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)

                        if isFoodInputFocused && !matching.isEmpty {
                            AdvancedDivider()
                            VStack(spacing: 0) {
                                ForEach(Array(matching.enumerated()), id: \.element.id) { index, template in
                                    AdvancedFoodSuggestionRow(template: template)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectTemplate(template)
                                        }
                                    if index < matching.count - 1 { AdvancedDivider() }
                                }
                            }
                        }
                    }
                    .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    if !periodHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isChinese ? "\(periodTitle)常记" : "\(periodTitle) history")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MKTheme.secondaryText)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(periodHistory) { template in
                                        Button {
                                            selectTemplate(template)
                                        } label: {
                                            Text("\(template.emoji) \(template.name)")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(MKTheme.ink)
                                                .lineLimit(1)
                                                .padding(.horizontal, 11)
                                                .padding(.vertical, 8)
                                                .background(MKTheme.card, in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 1)
                            }
                        }
                    }

                    if let adjustedAnalyzedRecord {
                        AdvancedInlineFoodAnalysisCard(
                            draft: adjustedAnalyzedRecord,
                            currentMacros: macros,
                            plan: plan,
                            language: language,
                            servings: $analyzedServings
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, analyzedRecord == nil ? 88 : 100)
            }
            .background(MKTheme.background)
            .safeAreaInset(edge: .bottom) {
                bottomActions
            }
            .navigationTitle(isChinese ? "记录饮食" : "Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "关闭" : "Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { _ in
                isShowingCamera = false
                analyzeCameraFallback()
            } onCancel: {
                isShowingCamera = false
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var bottomActions: some View {
        if let adjustedAnalyzedRecord {
            HStack(spacing: 10) {
                Button {
                    resetEntry()
                } label: {
                    Text(isChinese ? "重新录入" : "Re-enter")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    onSave(adjustedAnalyzedRecord.mealLog())
                    dismiss()
                } label: {
                    Text(isChinese ? "确认录入" : "Confirm")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(MKColor.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        } else {
            Button {
                analyzeTypedFood()
            } label: {
                Label(isChinese ? "AI 分析食物" : "Analyze food", systemImage: "sparkles")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(MKColor.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(trimmedQuery.isEmpty)
            .opacity(trimmedQuery.isEmpty ? 0.45 : 1)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }

    private func analyzeTypedFood() {
        guard !trimmedQuery.isEmpty else { return }
        isFoodInputFocused = false
        let reusableTemplate = selectedTemplate?.name.localizedCaseInsensitiveCompare(trimmedQuery) == .orderedSame ? selectedTemplate : nil
        let template = reusableTemplate ?? matchingSuggestions.first { $0.name.localizedCaseInsensitiveCompare(trimmedQuery) == .orderedSame } ?? AdvancedFoodTemplate.estimated(name: trimmedQuery, language: language)
        analyzedServings = 1
        analyzedRecord = AdvancedFoodRecordDraft(
            template: template,
            servings: 1,
            source: .manual,
            note: isChinese ? "AI 分析估算" : "AI estimate"
        )
    }

    private func selectTemplate(_ template: AdvancedFoodTemplate) {
        isFoodInputFocused = false
        query = template.name
        selectedTemplate = template
        analyzedRecord = nil
        analyzedServings = 1
    }

    private func resetEntry() {
        isFoodInputFocused = false
        query = ""
        selectedTemplate = nil
        analyzedRecord = nil
        analyzedServings = 1
    }

    private func analyzeCameraFallback() {
        analyzedServings = 1
        analyzedRecord = AdvancedFoodRecordDraft(
            template: AdvancedFoodTemplate.aiSample(language: language),
            servings: 1,
            source: .camera,
            note: isChinese ? "AI 识别估算" : "AI estimate"
        )
    }

    private var periodTitle: String {
        switch mealPeriod(for: Calendar.current.component(.hour, from: Date())) {
        case 0: return isChinese ? "早餐" : "Breakfast"
        case 1: return isChinese ? "午餐" : "Lunch"
        case 2: return isChinese ? "晚餐" : "Dinner"
        default: return isChinese ? "加餐" : "Snack"
        }
    }

    private func mealPeriod(for hour: Int) -> Int {
        switch hour {
        case 5..<11: return 0
        case 11..<16: return 1
        case 16..<22: return 2
        default: return 3
        }
    }
}

private struct AdvancedFoodTemplate: Identifiable, Hashable {
    let name: String
    let emoji: String
    let servingName: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let lastLoggedHour: Int?
    var id: String {
        "\(name.lowercased())|\(servingName)|\(calories)|\(protein)|\(carbs)|\(fat)"
    }

    init(
        name: String,
        emoji: String,
        servingName: String,
        calories: Int,
        protein: Int,
        carbs: Int,
        fat: Int,
        lastLoggedHour: Int? = nil
    ) {
        self.name = name
        self.emoji = emoji
        self.servingName = servingName
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.lastLoggedHour = lastLoggedHour
    }

    init(meal: MealLog, language: AppLanguage) {
        self.init(
            name: meal.name,
            emoji: meal.source == .camera ? "📷" : "🍽",
            servingName: language == .simplifiedChinese ? "份" : "serving",
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fat: meal.fat,
            lastLoggedHour: Calendar.current.component(.hour, from: meal.createdAt)
        )
    }

    func multiplied(by servings: Int) -> AdvancedFoodTemplate {
        AdvancedFoodTemplate(
            name: name,
            emoji: emoji,
            servingName: servingName,
            calories: calories * servings,
            protein: protein * servings,
            carbs: carbs * servings,
            fat: fat * servings,
            lastLoggedHour: lastLoggedHour
        )
    }

    static func aiSample(language: AppLanguage) -> AdvancedFoodTemplate {
        AdvancedFoodTemplate(
            name: language == .simplifiedChinese ? "兰州牛肉面" : "Lanzhou beef noodles",
            emoji: "🍜",
            servingName: language == .simplifiedChinese ? "碗" : "bowl",
            calories: 650,
            protein: 28,
            carbs: 85,
            fat: 18
        )
    }

    static func estimated(name: String, language: AppLanguage) -> AdvancedFoodTemplate {
        let lower = name.lowercased()
        let zh = language == .simplifiedChinese
        if name.contains("牛肉面") || lower.contains("noodle") {
            return AdvancedFoodTemplate(name: name, emoji: "🍜", servingName: zh ? "碗" : "bowl", calories: 650, protein: 28, carbs: 85, fat: 18)
        }
        if name.contains("鸡") || lower.contains("chicken") {
            return AdvancedFoodTemplate(name: name, emoji: "🍗", servingName: zh ? "份" : "serving", calories: 520, protein: 42, carbs: 45, fat: 16)
        }
        if name.contains("蛋白") || lower.contains("whey") {
            return AdvancedFoodTemplate(name: name, emoji: "🥛", servingName: zh ? "份" : "serving", calories: 120, protein: 25, carbs: 2, fat: 1)
        }
        if name.contains("蛋") || lower.contains("egg") {
            return AdvancedFoodTemplate(name: name, emoji: "🥚", servingName: zh ? "份" : "serving", calories: 72, protein: 6, carbs: 1, fat: 5)
        }
        if name.contains("饭") || lower.contains("rice") {
            return AdvancedFoodTemplate(name: name, emoji: "🍚", servingName: zh ? "份" : "serving", calories: 620, protein: 28, carbs: 82, fat: 18)
        }
        return AdvancedFoodTemplate(name: name, emoji: "🍽", servingName: zh ? "份" : "serving", calories: 450, protein: 25, carbs: 45, fat: 15)
    }

    static func frequent(language: AppLanguage) -> [AdvancedFoodTemplate] {
        let zh = language == .simplifiedChinese
        return [
            AdvancedFoodTemplate(name: zh ? "全蛋" : "Whole egg", emoji: "🥚", servingName: zh ? "个" : "pc", calories: 72, protein: 6, carbs: 1, fat: 5),
            AdvancedFoodTemplate(name: zh ? "蛋白" : "Egg white", emoji: "🥚", servingName: zh ? "个" : "pc", calories: 17, protein: 4, carbs: 0, fat: 0),
            AdvancedFoodTemplate(name: zh ? "馒头" : "Steamed bun", emoji: "🍞", servingName: zh ? "个" : "pc", calories: 220, protein: 7, carbs: 45, fat: 1),
            AdvancedFoodTemplate(name: zh ? "乳清蛋白" : "Whey protein", emoji: "🥛", servingName: zh ? "勺" : "scoop", calories: 120, protein: 25, carbs: 2, fat: 1),
            AdvancedFoodTemplate(name: zh ? "米饭" : "Rice", emoji: "🍚", servingName: zh ? "碗" : "bowl", calories: 260, protein: 5, carbs: 57, fat: 1),
            AdvancedFoodTemplate(name: zh ? "鸡胸肉" : "Chicken breast", emoji: "🍗", servingName: "100g", calories: 165, protein: 31, carbs: 0, fat: 4),
            AdvancedFoodTemplate(name: zh ? "香蕉" : "Banana", emoji: "🍌", servingName: zh ? "根" : "pc", calories: 105, protein: 1, carbs: 27, fat: 0)
        ]
    }

    static func library(language: AppLanguage) -> [AdvancedFoodTemplate] {
        let zh = language == .simplifiedChinese
        return [
            AdvancedFoodTemplate(name: "Rule One Whey", emoji: "🥛", servingName: zh ? "勺" : "scoop", calories: 120, protein: 25, carbs: 2, fat: 1),
            AdvancedFoodTemplate(name: zh ? "固定早餐" : "Fixed breakfast", emoji: "🍳", servingName: zh ? "份" : "serving", calories: 430, protein: 32, carbs: 42, fat: 12),
            AdvancedFoodTemplate(name: zh ? "希腊酸奶" : "Greek yogurt", emoji: "🥣", servingName: zh ? "杯" : "cup", calories: 150, protein: 15, carbs: 12, fat: 4)
        ]
    }

    static func favorites(language: AppLanguage) -> [AdvancedFoodTemplate] {
        let zh = language == .simplifiedChinese
        return [
            AdvancedFoodTemplate(name: zh ? "兰州牛肉面" : "Lanzhou beef noodles", emoji: "🍜", servingName: zh ? "碗" : "bowl", calories: 650, protein: 28, carbs: 85, fat: 18),
            AdvancedFoodTemplate(name: zh ? "沙县鸡腿饭" : "Chicken rice set", emoji: "🍱", servingName: zh ? "份" : "serving", calories: 760, protein: 38, carbs: 92, fat: 24),
            AdvancedFoodTemplate(name: zh ? "黄焖鸡米饭" : "Braised chicken rice", emoji: "🍛", servingName: zh ? "份" : "serving", calories: 820, protein: 42, carbs: 96, fat: 28),
            AdvancedFoodTemplate(name: zh ? "公司食堂 A 套餐" : "Cafeteria set A", emoji: "🍽", servingName: zh ? "份" : "serving", calories: 680, protein: 35, carbs: 80, fat: 20)
        ]
    }
}

private struct AdvancedFoodRecordDraft: Identifiable {
    let id = UUID()
    let template: AdvancedFoodTemplate
    let servings: Int
    let source: MealSource
    var note: String?

    var total: AdvancedFoodTemplate { template.multiplied(by: servings) }

    func mealLog() -> MealLog {
        let item = total
        return MealLog(
            name: servings > 1 ? "\(template.name) × \(servings)" : template.name,
            calories: item.calories,
            protein: item.protein,
            carbs: item.carbs,
            fat: item.fat,
            servingDescription: servingDescription,
            createdAt: Date(),
            source: source
        )
    }

    private var servingDescription: String {
        "\(servings) \(template.servingName)"
    }
}

private struct AdvancedFoodTemplateSection: View {
    let title: String
    let templates: [AdvancedFoodTemplate]
    let language: AppLanguage
    var footer: String?
    let onPick: (AdvancedFoodTemplate, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(MKTheme.ink)
            VStack(spacing: 0) {
                ForEach(templates) { template in
                    AdvancedFoodTemplateRow(template: template, language: language, onPick: onPick)
                    if template.id != templates.last?.id { AdvancedDivider() }
                }
            }
            .padding(.horizontal, 12)
            .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if let footer {
                Text(footer)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)
            }
        }
    }
}

private struct AdvancedFoodTemplateRow: View {
    let template: AdvancedFoodTemplate
    let language: AppLanguage
    let onPick: (AdvancedFoodTemplate, Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(template.emoji)
                .font(.title3)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(1)
                Text("\(template.calories) kcal · P \(template.protein)g · C \(template.carbs)g · F \(template.fat)g / \(template.servingName)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                ForEach([1, 2, 3], id: \.self) { serving in
                    Button("+\(serving)") {
                        onPick(template, serving)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKColor.green)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(MKColor.green.opacity(0.10), in: Capsule())
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 10)
    }
}

private struct AdvancedFoodSuggestionRow: View {
    let template: AdvancedFoodTemplate

    var body: some View {
        HStack(spacing: 10) {
            Text(template.emoji)
                .font(.title3)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(1)
                Text("\(template.calories) kcal · P \(template.protein)g · C \(template.carbs)g · F \(template.fat)g")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct AdvancedManualFoodField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MKTheme.ink)
            Spacer()
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: 150)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AdvancedInlineFoodAnalysisCard: View {
    let draft: AdvancedFoodRecordDraft
    let currentMacros: MacroTarget
    let plan: AdvancedNutritionPlan
    let language: AppLanguage
    @Binding var servings: Int

    private var isChinese: Bool { language == .simplifiedChinese }
    private var total: AdvancedFoodTemplate { draft.total }
    private var updatedProtein: Int { currentMacros.protein + total.protein }
    private var updatedCarbs: Int { currentMacros.carbs + total.carbs }
    private var updatedFat: Int { currentMacros.fat + total.fat }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(isChinese ? "AI 分析结果" : "AI analysis")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                Spacer()
                Text(draft.note ?? (isChinese ? "估算" : "Estimate"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.blue)
            }

            HStack(alignment: .center, spacing: 10) {
                Text(draft.template.emoji)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.template.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                    Stepper(value: $servings, in: 1...10) {
                        Text(isChinese ? "数量 \(servings) \(draft.template.servingName)" : "Amount \(servings) \(draft.template.servingName)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MKTheme.secondaryText)
                    }
                }
            }

            AdvancedFoodMacroSummaryBlock(
                title: isChinese ? "本次新增" : "Added",
                calories: total.calories,
                protein: total.protein,
                carbs: total.carbs,
                fat: total.fat
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(isChinese ? "更新后今日累计" : "Updated today")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                AdvancedConfirmMacroLine(title: isChinese ? "蛋白质" : "Protein", current: updatedProtein, target: plan.protein, tint: AdvancedFitnessRingColor.protein)
                AdvancedConfirmMacroLine(title: isChinese ? "碳水" : "Carbs", current: updatedCarbs, target: plan.carbs, tint: AdvancedFitnessRingColor.carbs)
                AdvancedConfirmMacroLine(title: isChinese ? "脂肪" : "Fat", current: updatedFat, target: plan.fat, tint: AdvancedFitnessRingColor.fat)
            }
            .padding(14)
            .background(MKTheme.fill.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(14)
        .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct AdvancedFoodRecordConfirmationSheet: View {
    let draft: AdvancedFoodRecordDraft
    let currentMacros: MacroTarget
    let plan: AdvancedNutritionPlan
    let language: AppLanguage
    let onConfirm: (MealLog) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var servings: Int

    private var isChinese: Bool { language == .simplifiedChinese }
    private var adjustedDraft: AdvancedFoodRecordDraft {
        AdvancedFoodRecordDraft(template: draft.template, servings: servings, source: draft.source, note: draft.note)
    }
    private var total: AdvancedFoodTemplate { adjustedDraft.total }
    private var updatedProtein: Int { currentMacros.protein + total.protein }
    private var updatedCarbs: Int { currentMacros.carbs + total.carbs }
    private var updatedFat: Int { currentMacros.fat + total.fat }

    init(
        draft: AdvancedFoodRecordDraft,
        currentMacros: MacroTarget,
        plan: AdvancedNutritionPlan,
        language: AppLanguage,
        onConfirm: @escaping (MealLog) -> Void
    ) {
        self.draft = draft
        self.currentMacros = currentMacros
        self.plan = plan
        self.language = language
        self.onConfirm = onConfirm
        _servings = State(initialValue: draft.servings)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(draft.note ?? (isChinese ? "确认记录" : "Review entry"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.blue)
                        Text("\(draft.template.emoji) \(draft.template.name)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MKTheme.ink)
                        Stepper(value: $servings, in: 1...10) {
                            Text(isChinese ? "数量 \(servings) \(draft.template.servingName)" : "Amount \(servings) \(draft.template.servingName)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MKTheme.secondaryText)
                        }
                    }

                    AdvancedFoodMacroSummaryBlock(
                        title: isChinese ? "本次新增" : "Added",
                        calories: total.calories,
                        protein: total.protein,
                        carbs: total.carbs,
                        fat: total.fat
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text(isChinese ? "更新后今日累计" : "Updated today")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)
                        AdvancedConfirmMacroLine(title: isChinese ? "蛋白质" : "Protein", current: updatedProtein, target: plan.protein, tint: AdvancedFitnessRingColor.protein)
                        AdvancedConfirmMacroLine(title: isChinese ? "碳水" : "Carbs", current: updatedCarbs, target: plan.carbs, tint: AdvancedFitnessRingColor.carbs)
                        AdvancedConfirmMacroLine(title: isChinese ? "脂肪" : "Fat", current: updatedFat, target: plan.fat, tint: AdvancedFitnessRingColor.fat)
                    }
                    .padding(14)
                    .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(isChinese ? "剩余" : "Remaining")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)
                        Text("P \(max(plan.protein - updatedProtein, 0))g · C \(max(plan.carbs - updatedCarbs, 0))g · F \(max(plan.fat - updatedFat, 0))g")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MKTheme.secondaryText)
                            .monospacedDigit()
                    }
                    .padding(14)
                    .background(MKTheme.fill.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(20)
                .padding(.bottom, 82)
            }
            .background(MKTheme.background)
            .safeAreaInset(edge: .bottom) {
                Button {
                    onConfirm(adjustedDraft.mealLog())
                    dismiss()
                } label: {
                    Text(isChinese ? "确认记录" : "Confirm")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(MKColor.green, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
            .navigationTitle(isChinese ? "确认饮食" : "Confirm Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "取消" : "Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct AdvancedFoodMacroSummaryBlock: View {
    let title: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(MKTheme.ink)
            Text("\(calories) kcal")
                .font(.title2.weight(.bold))
                .foregroundStyle(MKTheme.ink)
                .monospacedDigit()
            Text("P \(protein)g · C \(carbs)g · F \(fat)g")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)
                .monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AdvancedConfirmMacroLine: View {
    let title: String
    let current: Int
    let target: Int
    let tint: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Spacer()
            Text("\(current) / \(target)g")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKTheme.ink)
                .monospacedDigit()
        }
    }
}

private enum AdvancedTrainingEntryTab: Hashable {
    case log
    case goal
}

private enum AdvancedTrainingInputField: Hashable {
    case duration
    case calories
    case targetCalories
    case targetMinutes
}

private struct AdvancedTrainingInputSheet: View {
    @Binding var logs: [AdvancedTrainingLog]
    @Binding var targetCalories: Int
    @Binding var targetMinutes: Int
    let language: AppLanguage
    let onAdded: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedWorkoutType: AdvancedWorkoutType = .traditionalStrengthTraining
    @State private var durationText = ""
    @State private var caloriesText = ""
    @State private var targetCaloriesText = ""
    @State private var targetMinutesText = ""
    @State private var selectedTab: AdvancedTrainingEntryTab = .log
    @State private var validationMessage: String?
    @FocusState private var focusedField: AdvancedTrainingInputField?

    private var isChinese: Bool { language == .simplifiedChinese }
    private var totalMinutes: Int { logs.map(\.durationMinutes).reduce(0, +) }
    private var totalCalories: Int { logs.map(\.caloriesBurned).reduce(0, +) }
    private var enteredMinutes: Int { max(Int(durationText) ?? 0, 0) }
    private var enteredCalories: Int { max(Int(caloriesText) ?? 0, 0) }
    private var canAddManualLog: Bool { enteredMinutes > 0 && enteredCalories > 0 }
    private var canSaveTargets: Bool {
        (Int(targetCaloriesText) ?? 0) > 0 && (Int(targetMinutesText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AdvancedTrainingTabPicker(selectedTab: $selectedTab, language: language)

                    switch selectedTab {
                    case .log:
                        trainingLogContent
                    case .goal:
                        trainingGoalContent
                    }
                }
                .padding(20)
            }
            .background(MKTheme.background)
            .navigationTitle(isChinese ? "录入训练" : "Log Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "关闭" : "Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(keyboardActionTitle) {
                        advanceKeyboardFocus()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert(
            isChinese ? "请补全训练记录" : "Complete workout record",
            isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )
        ) {
            Button("OK") { validationMessage = nil }
        } message: {
            Text(validationMessage ?? "")
        }
        .onAppear {
            targetCaloriesText = "\(targetCalories)"
            targetMinutesText = "\(targetMinutes)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                focusedField = .duration
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            DispatchQueue.main.async {
                focusedField = newValue == .log ? .duration : .targetCalories
            }
        }
    }

    private var trainingLogContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                AdvancedTrainingTotalPill(
                    title: isChinese ? "运动" : "Move",
                    value: "\(totalCalories) / \(targetCalories)",
                    unit: "cal",
                    tint: AdvancedFitnessRingColor.move
                )
                AdvancedTrainingTotalPill(
                    title: isChinese ? "时长" : "Time",
                    value: "\(totalMinutes) / \(targetMinutes)",
                    unit: isChinese ? "分钟" : "min",
                    tint: AdvancedFitnessRingColor.exercise
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(isChinese ? "手动追加记录" : "Add manual workout")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                AdvancedTrainingTypeMenu(
                    selection: $selectedWorkoutType,
                    language: language
                )
                AdvancedTrainingInputRow(title: isChinese ? "训练时长" : "Duration", text: $durationText, placeholder: "30", unit: isChinese ? "分钟" : "min", field: .duration, focusedField: $focusedField)
                AdvancedTrainingInputRow(title: isChinese ? "消耗热量" : "Calories Burned", text: $caloriesText, placeholder: "250", unit: "kcal", field: .calories, focusedField: $focusedField)
                Button {
                    addManualLog()
                } label: {
                    Label(isChinese ? "确认新增训练记录" : "Confirm new workout", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(MKColor.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text(isChinese ? "同步来源" : "Sync sources")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                AdvancedTrainingSyncRow(symbol: "figure.run", title: "Apple Fitness", subtitle: isChinese ? "同步运动消耗和时长" : "Sync burn and duration") {
                    addSyncedLog(type: .running, minutes: 45, calories: 320, source: .appleFitness)
                }
                AdvancedDivider()
                AdvancedTrainingSyncRow(symbol: "heart.text.square", title: "Apple Health", subtitle: isChinese ? "读取健康运动记录" : "Import health workouts") {
                    addSyncedLog(type: .functionalStrengthTraining, minutes: 30, calories: 210, source: .appleHealth)
                }
            }
            .padding(14)
            .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            if !logs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(isChinese ? "今日已记录" : "Logged today")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                    ForEach(Array(logs.enumerated()), id: \.offset) { index, item in
                        HStack {
                            Text(item.workoutType.title(language: language))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MKTheme.ink)
                            Spacer()
                            Text("\(item.durationMinutes)min · \(item.caloriesBurned)kcal")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MKTheme.secondaryText)
                                .monospacedDigit()
                        }
                        if index < logs.count - 1 { AdvancedDivider() }
                    }
                }
                .padding(14)
                .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var trainingGoalContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isChinese ? "统一运动目标" : "Training goal")
                .font(.headline.weight(.bold))
                .foregroundStyle(MKTheme.ink)
            Text(isChinese ? "更新后，每天都会按此目标展示，直到下次修改。" : "This goal applies every day until you update it again.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MKTheme.secondaryText)
            AdvancedTrainingInputRow(title: isChinese ? "目标消耗" : "Burn goal", text: $targetCaloriesText, placeholder: "\(targetCalories)", unit: "kcal", field: .targetCalories, focusedField: $focusedField)
            AdvancedTrainingInputRow(title: isChinese ? "目标时长" : "Time goal", text: $targetMinutesText, placeholder: "\(targetMinutes)", unit: isChinese ? "分钟" : "min", field: .targetMinutes, focusedField: $focusedField)
            Button {
                saveTargets()
            } label: {
                Text(isChinese ? "更新目标" : "Update goal")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKColor.green)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(MKColor.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSaveTargets)
            .opacity(canSaveTargets ? 1 : 0.45)
        }
        .padding(14)
        .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func addManualLog() {
        guard canAddManualLog else {
            validationMessage = isChinese ? "训练时长和消耗热量为必填项，且需要大于 0。" : "Duration and calories are required and must be greater than 0."
            return
        }
        logs.append(AdvancedTrainingLog(
            workoutType: selectedWorkoutType,
            durationMinutes: enteredMinutes,
            caloriesBurned: enteredCalories,
            recordedAt: Date(),
            source: .manual
        ))
        durationText = ""
        caloriesText = ""
        focusedField = .duration
        dismiss()
        onAdded()
    }

    private func addSyncedLog(type: AdvancedWorkoutType, minutes: Int, calories: Int, source: AdvancedTrainingLogSource) {
        logs.append(AdvancedTrainingLog(
            workoutType: type,
            durationMinutes: minutes,
            caloriesBurned: calories,
            recordedAt: Date(),
            source: source
        ))
    }

    private func saveTargets() {
        guard canSaveTargets else { return }
        targetCalories = max(Int(targetCaloriesText) ?? targetCalories, 1)
        targetMinutes = max(Int(targetMinutesText) ?? targetMinutes, 1)
        targetCaloriesText = "\(targetCalories)"
        targetMinutesText = "\(targetMinutes)"
        focusedField = nil
    }

    private var keyboardActionTitle: String {
        switch focusedField {
        case .duration, .targetCalories:
            return isChinese ? "下一项" : "Next"
        default:
            return isChinese ? "完成" : "Done"
        }
    }

    private func advanceKeyboardFocus() {
        switch focusedField {
        case .duration:
            focusedField = .calories
        case .targetCalories:
            focusedField = .targetMinutes
        default:
            focusedField = nil
        }
    }
}

private struct AdvancedTrainingTypeMenu: View {
    @Binding var selection: AdvancedWorkoutType
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        Menu {
            ForEach(AdvancedWorkoutType.allCases) { type in
                Button {
                    selection = type
                } label: {
                    if selection == type {
                        Label(type.title(language: language), systemImage: "checkmark")
                    } else {
                        Text(type.title(language: language))
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(isChinese ? "训练类型" : "Workout Type")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MKTheme.secondaryText)
                Spacer()
                Text(selection.title(language: language))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
            }
            .padding(12)
            .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private enum AdvancedRecordDetailKind: String, Identifiable {
    case nutrition
    case training
    case other

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        let isChinese = language == .simplifiedChinese
        switch self {
        case .nutrition: return isChinese ? "饮食记录详情" : "Nutrition Records"
        case .training: return isChinese ? "训练记录详情" : "Training Records"
        case .other: return isChinese ? "其他记录详情" : "Other Records"
        }
    }
}

private struct AdvancedRecordDetailRowData: Identifiable {
    let id: String
    let recordedAt: Date
    let content: String
    let amount: String
    let energy: String
    let source: String
    let canDelete: Bool

    var detailText: String {
        "\(amount) · \(energy)"
    }
}

private struct AdvancedRecordDetailSheet: View {
    let kind: AdvancedRecordDetailKind
    let meals: [MealLog]
    let trainingLogs: [AdvancedTrainingLog]
    let sleepLogs: [SleepLog]
    let waterLogs: [WaterLog]
    let supplementIntakes: [AdvancedSupplementIntake]
    let language: AppLanguage
    let onDeleteMeal: (MealLog) -> Void
    let onDeleteTraining: (AdvancedTrainingLog) -> Void
    let onDeleteSleep: (SleepLog) -> Void
    let onDeleteWater: (WaterLog) -> Void
    let onDeleteSupplement: (AdvancedSupplementIntake) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingDeleteRowID: String?

    private var isChinese: Bool { language == .simplifiedChinese }
    private var rows: [AdvancedRecordDetailRowData] {
        switch kind {
        case .nutrition:
            return meals.sorted { $0.createdAt > $1.createdAt }.map { meal in
                AdvancedRecordDetailRowData(
                    id: "meal-\(meal.id.uuidString)",
                    recordedAt: meal.createdAt,
                    content: foodName(meal.name),
                    amount: foodServings(meal),
                    energy: "\(meal.calories) kcal",
                    source: mealSourceTitle(meal.source),
                    canDelete: Calendar.current.isDateInToday(meal.createdAt)
                )
            }
        case .training:
            return trainingLogs.sorted { $0.recordedAt > $1.recordedAt }.map { log in
                AdvancedRecordDetailRowData(
                    id: "training-\(log.id.uuidString)",
                    recordedAt: log.recordedAt,
                    content: log.workoutType.title(language: language),
                    amount: log.durationMinutes > 0 ? "\(log.durationMinutes) min" : "-",
                    energy: log.caloriesBurned > 0 ? "\(log.caloriesBurned) kcal" : "-",
                    source: log.source.title(language: language),
                    canDelete: Calendar.current.isDateInToday(log.recordedAt)
                )
            }
        case .other:
            let supplementRows = supplementIntakes
                .filter(\.isTaken)
                .map { intake in
                    AdvancedRecordDetailRowData(
                        id: "supplement-\(intake.id.uuidString)",
                        recordedAt: intake.recordedAt,
                        content: intake.name,
                        amount: intake.dosage.isEmpty ? "-" : intake.dosage,
                        energy: "-",
                        source: isChinese ? "手动录入" : "Manual",
                        canDelete: Calendar.current.isDateInToday(intake.recordedAt)
                    )
                }
            let waterRows = waterLogs
                .filter { Calendar.current.isDateInToday($0.loggedAt) }
                .map { log in
                    AdvancedRecordDetailRowData(
                        id: "water-\(log.id.uuidString)",
                        recordedAt: log.loggedAt,
                        content: isChinese ? "饮水" : "Water",
                        amount: isChinese ? "\(log.cupDelta) 杯" : "\(log.cupDelta) cups",
                        energy: "-",
                        source: isChinese ? "手动录入" : "Manual",
                        canDelete: Calendar.current.isDateInToday(log.loggedAt)
                    )
                }
            let sleepRows = sleepLogs
                .filter { Calendar.current.isDateInToday($0.createdAt) || isWithinLastNight($0.createdAt) }
                .map { log in
                    AdvancedRecordDetailRowData(
                        id: "sleep-\(log.id.uuidString)",
                        recordedAt: log.createdAt,
                        content: isChinese ? "睡眠" : "Sleep",
                        amount: String(format: "%.1f h", log.hoursSlept),
                        energy: "-",
                        source: isChinese ? "手动录入" : "Manual",
                        canDelete: Calendar.current.isDateInToday(log.createdAt) || isWithinLastNight(log.createdAt)
                    )
                }
            return (supplementRows + waterRows + sleepRows)
                .sorted { $0.recordedAt > $1.recordedAt }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if rows.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(MKTheme.secondaryText)
                        Text(isChinese ? "今日暂无录入记录" : "No records logged today")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 72)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(rows) { row in
                            AdvancedRecordDetailCard(row: row) {
                                pendingDeleteRowID = row.id
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .background(MKTheme.background)
            .navigationTitle(kind.title(language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "关闭" : "Close") { dismiss() }
                }
            }
            .overlay {
                if pendingDeleteRowID != nil {
                    deleteConfirmationOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: pendingDeleteRowID)
    }

    private var deleteConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.14)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isChinese ? "删除这条记录？" : "Delete this record?")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                    Text(isChinese ? "仅支持删除当日录入的数据，删除后会同步更新今日数据。" : "Only today's records can be deleted. Today's data will update immediately.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MKTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button {
                        pendingDeleteRowID = nil
                    } label: {
                        Text(isChinese ? "取消" : "Cancel")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MKTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        if let pendingDeleteRowID {
                            deleteRecord(rowID: pendingDeleteRowID)
                        }
                        pendingDeleteRowID = nil
                    } label: {
                        Text(isChinese ? "删除" : "Delete")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(MKColor.coral, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .frame(maxWidth: 310)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(MKTheme.divider.opacity(0.65), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
    }

    private func deleteRecord(rowID: String) {
        if rowID.hasPrefix("meal-") {
            let id = rowID.replacingOccurrences(of: "meal-", with: "")
            if let meal = meals.first(where: { $0.id.uuidString == id && Calendar.current.isDateInToday($0.createdAt) }) {
                onDeleteMeal(meal)
            }
        } else if rowID.hasPrefix("training-") {
            let id = rowID.replacingOccurrences(of: "training-", with: "")
            if let log = trainingLogs.first(where: { $0.id.uuidString == id && Calendar.current.isDateInToday($0.recordedAt) }) {
                onDeleteTraining(log)
            }
        } else if rowID.hasPrefix("sleep-") {
            let id = rowID.replacingOccurrences(of: "sleep-", with: "")
            if let log = sleepLogs.first(where: { $0.id.uuidString == id && (Calendar.current.isDateInToday($0.createdAt) || isWithinLastNight($0.createdAt)) }) {
                onDeleteSleep(log)
            }
        } else if rowID.hasPrefix("water-") {
            let id = rowID.replacingOccurrences(of: "water-", with: "")
            if let log = waterLogs.first(where: { $0.id.uuidString == id && Calendar.current.isDateInToday($0.loggedAt) }) {
                onDeleteWater(log)
            }
        } else if rowID.hasPrefix("supplement-") {
            let id = rowID.replacingOccurrences(of: "supplement-", with: "")
            if let intake = supplementIntakes.first(where: { $0.id.uuidString == id && Calendar.current.isDateInToday($0.recordedAt) }) {
                onDeleteSupplement(intake)
            }
        }
    }

    private func foodName(_ name: String) -> String {
        name.components(separatedBy: "×").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? name
    }

    private func foodServings(_ meal: MealLog) -> String {
        if let serving = meal.servingDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !serving.isEmpty {
            return serving
        }
        let name = meal.name
        let parts = name.components(separatedBy: "×")
        guard parts.count > 1 else { return isChinese ? "1 份" : "1 serving" }
        let value = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return isChinese ? "1 份" : "1 serving" }
        if value.rangeOfCharacter(from: .letters) != nil || value.contains("份") {
            return value
        }
        return isChinese ? "\(value) 份" : "\(value) servings"
    }

    private func mealSourceTitle(_ source: MealSource) -> String {
        switch source {
        case .camera: return isChinese ? "拍摄识别" : "Camera"
        case .photoLibrary: return isChinese ? "图片识别" : "Photo"
        case .manual: return isChinese ? "手动录入" : "Manual"
        }
    }

    private func isWithinLastNight(_ date: Date) -> Bool {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else { return false }
        return calendar.isDate(date, inSameDayAs: yesterday)
    }
}

private struct AdvancedRecordDetailCard: View {
    let row: AdvancedRecordDetailRowData
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(timeText(row.recordedAt))
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(MKTheme.secondaryText)
                .frame(width: 42, alignment: .leading)

            inlineText(row.content, weight: .bold, color: MKTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            inlineText(row.amount, weight: .semibold, color: MKTheme.secondaryText)
                .frame(width: 52, alignment: .leading)

            inlineText(row.energy, weight: .semibold, color: MKTheme.secondaryText)
                .frame(width: 68, alignment: .leading)

            inlineText(row.source, weight: .semibold, color: MKTheme.secondaryText)
                .frame(width: 52, alignment: .leading)

            if row.canDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MKColor.coral)
                        .frame(width: 34, height: 34)
                        .background(MKColor.coral.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func inlineText(_ text: String, weight: Font.Weight, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(weight))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct AdvancedToastMessage: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKColor.green)
            Text(text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKTheme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(MKTheme.divider.opacity(0.8), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

private struct AdvancedTrainingRecordDetailSheet: View {
    let log: AdvancedTrainingLog
    let language: AppLanguage
    let onSave: (AdvancedTrainingLog) -> Void
    let onDelete: (AdvancedTrainingLog) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var workoutType: AdvancedWorkoutType
    @State private var durationText: String
    @State private var caloriesText: String
    @State private var showsDeleteConfirmation = false
    @State private var validationMessage: String?
    @FocusState private var focusedField: AdvancedTrainingInputField?

    private var isChinese: Bool { language == .simplifiedChinese }
    private var enteredMinutes: Int { max(Int(durationText) ?? 0, 0) }
    private var enteredCalories: Int { max(Int(caloriesText) ?? 0, 0) }

    init(
        log: AdvancedTrainingLog,
        language: AppLanguage,
        onSave: @escaping (AdvancedTrainingLog) -> Void,
        onDelete: @escaping (AdvancedTrainingLog) -> Void
    ) {
        self.log = log
        self.language = language
        self.onSave = onSave
        self.onDelete = onDelete
        _workoutType = State(initialValue: log.workoutType)
        _durationText = State(initialValue: log.durationMinutes > 0 ? "\(log.durationMinutes)" : "")
        _caloriesText = State(initialValue: log.caloriesBurned > 0 ? "\(log.caloriesBurned)" : "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AdvancedCard {
                        AdvancedCardHeader(
                            symbol: "figure.strengthtraining.traditional",
                            title: isChinese ? "训练记录" : "Workout Record",
                            value: log.source.title(language: language)
                        )
                        AdvancedStatusRow(title: isChinese ? "记录时间" : "Time", value: timeText(log.recordedAt))
                        AdvancedStatusRow(title: isChinese ? "记录方式" : "Source", value: log.source.title(language: language))
                        AdvancedStatusRow(title: isChinese ? "记录内容" : "Content", value: log.workoutType.title(language: language))
                        AdvancedStatusRow(title: isChinese ? "记录数据" : "Data", value: "\(log.durationMinutes) min · \(log.caloriesBurned) kcal")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(isChinese ? "编辑记录" : "Edit Record")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MKTheme.ink)
                        AdvancedTrainingTypeMenu(selection: $workoutType, language: language)
                        AdvancedTrainingInputRow(title: isChinese ? "训练时长" : "Duration", text: $durationText, placeholder: "30", unit: isChinese ? "分钟" : "min", field: .duration, focusedField: $focusedField)
                        AdvancedTrainingInputRow(title: isChinese ? "消耗热量" : "Calories Burned", text: $caloriesText, placeholder: "250", unit: "kcal", field: .calories, focusedField: $focusedField)
                    }
                    .padding(14)
                    .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        Text(isChinese ? "删除训练记录" : "Delete Workout Record")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MKColor.coral)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(MKColor.coral.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(MKTheme.background)
            .navigationTitle(isChinese ? "记录详情" : "Record Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "关闭" : "Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isChinese ? "保存" : "Save") { save() }
                        .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(isChinese ? "完成" : "Done") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert(
            isChinese ? "请补全训练记录" : "Complete workout record",
            isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )
        ) {
            Button("OK") { validationMessage = nil }
        } message: {
            Text(validationMessage ?? "")
        }
        .confirmationDialog(
            isChinese ? "删除这条训练记录？" : "Delete this workout record?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(isChinese ? "删除" : "Delete", role: .destructive) {
                onDelete(log)
                dismiss()
            }
            Button(isChinese ? "取消" : "Cancel", role: .cancel) { }
        }
    }

    private func save() {
        guard enteredMinutes > 0, enteredCalories > 0 else {
            validationMessage = isChinese ? "训练时长和消耗热量为必填项，且需要大于 0。" : "Duration and calories are required and must be greater than 0."
            return
        }
        var updated = log
        updated.workoutType = workoutType
        updated.durationMinutes = enteredMinutes
        updated.caloriesBurned = enteredCalories
        onSave(updated)
        dismiss()
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isChinese ? "zh_Hans_CN" : "en_US")
        formatter.dateFormat = isChinese ? "M月d日 HH:mm" : "MMM d, HH:mm"
        return formatter.string(from: date)
    }
}

private struct AdvancedTrainingTabPicker: View {
    @Binding var selectedTab: AdvancedTrainingEntryTab
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        HStack(spacing: 8) {
            tabButton(.log, title: isChinese ? "录入训练" : "Log")
            tabButton(.goal, title: isChinese ? "设置目标" : "Goal")
        }
        .padding(4)
        .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func tabButton(_ tab: AdvancedTrainingEntryTab, title: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(selectedTab == tab ? .white : MKTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(selectedTab == tab ? MKColor.green : Color.clear, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct AdvancedTrainingTotalPill: View {
    let title: String
    let value: String
    let unit: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(MKTheme.ink)
                .monospacedDigit()
            Text(unit)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MKTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AdvancedTrainingInputRow: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let unit: String
    let field: AdvancedTrainingInputField
    var focusedField: FocusState<AdvancedTrainingInputField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)
            HStack(spacing: 8) {
                TextField(placeholder, text: $text)
                    .keyboardType(.numberPad)
                    .focused(focusedField, equals: field)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                    .monospacedDigit()
                Spacer(minLength: 8)
                Text(unit)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(MKTheme.divider.opacity(0.9), lineWidth: 1)
            )
        }
    }
}

private struct AdvancedTrainingSyncRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.blue)
                    .frame(width: 32, height: 32)
                    .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MKTheme.secondaryText)
                }
                Spacer()
                Text("Sync")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.blue)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private enum AdvancedOtherEntryTab: Hashable {
    case log
    case settings
}

private struct AdvancedOtherTabPicker: View {
    @Binding var selectedTab: AdvancedOtherEntryTab
    let language: AppLanguage

    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        HStack(spacing: 8) {
            tabButton(.log, title: isChinese ? "录入信息" : "Log")
            tabButton(.settings, title: isChinese ? "设置信息" : "Settings")
        }
        .padding(4)
        .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func tabButton(_ tab: AdvancedOtherEntryTab, title: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(selectedTab == tab ? .white : MKTheme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(selectedTab == tab ? MKColor.green : Color.clear, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct AdvancedSimpleInputRow: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(MKTheme.secondaryText)
            HStack(spacing: 8) {
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                    .monospacedDigit()
                Spacer(minLength: 8)
                Text(unit)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(MKTheme.divider.opacity(0.9), lineWidth: 1)
            )
        }
    }
}

private struct AdvancedOtherCompletionRow: View {
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isCompleted ? MKColor.green : MKTheme.secondaryText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                    Text(subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MKTheme.secondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AdvancedSupplementToggleCard: View {
    let name: String
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isCompleted ? MKColor.green : MKTheme.secondaryText)
                Text(name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 48)
            .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isCompleted ? MKColor.green.opacity(0.35) : MKTheme.divider.opacity(0.8), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AdvancedOtherStepperCard: View {
    let title: String
    let value: String
    let unit: String
    let canDecrease: Bool
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                Spacer()
                HStack(spacing: 2) {
                    Button(action: decrease) {
                        Image(systemName: "minus")
                            .frame(width: 42, height: 40)
                    }
                    .disabled(!canDecrease)
                    Divider().frame(height: 20)
                    Button(action: increase) {
                        Image(systemName: "plus")
                            .frame(width: 42, height: 40)
                    }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MKTheme.ink)
                .background(MKTheme.fill, in: Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(MKTheme.ink)
                    .monospacedDigit()
                Text(unit)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKTheme.secondaryText)
            }
        }
        .padding(14)
        .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AdvancedSleepInputSheet: View {
    @Binding var log: AdvancedSleepLog
    @Binding var supplementIntakes: [AdvancedSupplementIntake]
    @Binding var supplementSettings: [AdvancedSupplementIntake]
    let waterCups: Int
    @Binding var waterTarget: Int
    @Binding var sleepTarget: Double
    let language: AppLanguage
    let onWaterChange: (Int) -> Void
    let onSleepSave: (SleepLog) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: AdvancedOtherEntryTab = .log
    @State private var localWaterCups = 0
    @State private var supplementNameInput = ""

    private var isChinese: Bool { language == .simplifiedChinese }
    private var completedSupplements: Int { supplementIntakes.filter(\.isTaken).count }
    private var isWaterCompleted: Bool { localWaterCups >= waterTarget }
    private var isSleepCompleted: Bool { log.totalHours >= sleepTarget }
    private let supplementGridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    private var activeSupplementRecords: [AdvancedSupplementIntake] {
        let records = supplementSettings.map { setting in
            let existing = supplementIntakes.first { $0.name == setting.name }
            return AdvancedSupplementIntake(name: setting.name, dosage: "", isTaken: existing?.isTaken ?? false)
        }
        return records
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AdvancedOtherTabPicker(selectedTab: $selectedTab, language: language)
                    switch selectedTab {
                    case .log:
                        logContent
                    case .settings:
                        settingsContent
                    }
                }
                .padding(20)
            }
            .background(MKTheme.background)
            .navigationTitle(isChinese ? "录入其他" : "Log Other")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "关闭" : "Close") { dismiss() }
                }
            }
        }
        .onAppear {
            syncSupplementIntakesIfNeeded()
            localWaterCups = waterCups
        }
    }

    private var logContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(isChinese ? "补剂" : "Supplements")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MKTheme.ink)
                    Spacer()
                    Text("\(completedSupplements) / \(max(supplementSettings.count, 0))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MKTheme.secondaryText)
                }
                LazyVGrid(columns: supplementGridColumns, spacing: 10) {
                    ForEach(activeSupplementRecords) { item in
                        AdvancedSupplementToggleCard(name: item.name, isCompleted: item.isTaken) {
                            toggleSupplement(item)
                        }
                    }
                }
                if supplementSettings.isEmpty {
                    Text(isChinese ? "请先在设置信息中新增补剂种类。" : "Add supplement types in Settings first.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MKTheme.secondaryText)
                }
            }
            .padding(14)
            .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            AdvancedOtherStepperCard(
                title: isChinese ? "饮水" : "Water",
                value: "\(localWaterCups) / \(waterTarget)",
                unit: isChinese ? "杯" : "cups",
                canDecrease: localWaterCups > 0
            ) {
                updateWater(by: -1)
            } increase: {
                updateWater(by: 1)
            }

            AdvancedOtherStepperCard(
                title: isChinese ? "睡眠" : "Sleep",
                value: String(format: "%.1f / %.1f", log.totalHours, sleepTarget),
                unit: "h",
                canDecrease: log.totalHours > 0.5
            ) {
                updateSleep(by: -0.5)
            } increase: {
                updateSleep(by: 0.5)
            }

            Button {
                submitLog()
                dismiss()
            } label: {
                Text(isChinese ? "提交录入" : "Submit log")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(MKColor.green, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text(isChinese ? "补剂种类" : "Supplement types")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MKTheme.ink)
                LazyVGrid(columns: supplementGridColumns, spacing: 10) {
                    ForEach(supplementSettings) { item in
                        HStack(spacing: 8) {
                            Text(item.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(MKTheme.ink)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Button {
                                removeSupplementSetting(item)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(MKTheme.secondaryText)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 48)
                        .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                HStack {
                    TextField(isChinese ? "新增补剂种类" : "Add supplement type", text: $supplementNameInput)
                        .font(.subheadline.weight(.semibold))
                    Button(isChinese ? "添加" : "Add") {
                        addSupplementSetting()
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MKColor.green)
                    .disabled(supplementNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(14)
            .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                AdvancedOtherStepperCard(
                    title: isChinese ? "饮水目标" : "Water target",
                    value: "\(waterTarget)",
                    unit: isChinese ? "杯 / 天" : "cups / day",
                    canDecrease: waterTarget > 1
                ) {
                    updateWaterTarget(by: -1)
                } increase: {
                    updateWaterTarget(by: 1)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                AdvancedOtherStepperCard(
                    title: isChinese ? "睡眠目标" : "Sleep target",
                    value: String(format: "%.1f", sleepTarget),
                    unit: "h / day",
                    canDecrease: sleepTarget > 1
                ) {
                    updateSleepTarget(by: -0.5)
                } increase: {
                    updateSleepTarget(by: 0.5)
                }
            }
        }
    }

    private func syncSupplementIntakesIfNeeded() {
        for setting in supplementSettings where !supplementIntakes.contains(where: { $0.name == setting.name }) {
            supplementIntakes.append(AdvancedSupplementIntake(name: setting.name, dosage: "", isTaken: false))
        }
        supplementIntakes.removeAll { intake in
            !supplementSettings.contains { $0.name == intake.name }
        }
    }

    private func toggleSupplement(_ item: AdvancedSupplementIntake) {
        syncSupplementIntakesIfNeeded()
        guard let index = supplementIntakes.firstIndex(where: { $0.name == item.name }) else { return }
        supplementIntakes[index].isTaken.toggle()
        if supplementIntakes[index].isTaken {
            supplementIntakes[index].recordedAt = Date()
        }
    }

    private func updateWater(by delta: Int) {
        guard delta != 0 else { return }
        if delta < 0 {
            guard localWaterCups > 0 else { return }
        }
        onWaterChange(delta)
        localWaterCups = min(max(localWaterCups + delta, 0), 20)
    }

    private func updateSleep(by delta: Double) {
        let nextHours = min(max(log.totalHours + delta, 0), 14)
        setSleepHours(nextHours)
    }

    private func updateWaterTarget(by delta: Int) {
        waterTarget = min(max(waterTarget + delta, 1), 20)
    }

    private func updateSleepTarget(by delta: Double) {
        sleepTarget = min(max(sleepTarget + delta, 1), 14)
    }

    private func setSleepHours(_ hours: Double) {
        let wake = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
        let bed = Calendar.current.date(byAdding: .minute, value: -Int(hours * 60), to: wake) ?? Date()
        log.bedTime = bed
        log.wakeTime = wake
    }

    private func submitLog() {
        guard log.totalHours > 0 else { return }
        onSleepSave(
            SleepLog(
                hoursSlept: log.totalHours,
                quality: .fair,
                bedTime: log.bedTime,
                wakeTime: log.wakeTime,
                note: isChinese ? "手动录入" : "Manual"
            )
        )
    }

    private func addSupplementSetting() {
        let name = supplementNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !supplementSettings.contains(where: { $0.name == name }) else {
            supplementNameInput = ""
            return
        }
        supplementSettings.append(AdvancedSupplementIntake(name: name, dosage: "", isTaken: false))
        supplementIntakes.append(AdvancedSupplementIntake(name: name, dosage: "", isTaken: false))
        supplementNameInput = ""
    }

    private func removeSupplementSetting(_ item: AdvancedSupplementIntake) {
        supplementSettings.removeAll { $0.id == item.id || $0.name == item.name }
        supplementIntakes.removeAll { $0.name == item.name }
    }

    private func saveOtherSettings() {
        syncSupplementIntakesIfNeeded()
    }
}

private extension AdvancedDailyCompletion {
    var overall: Double {
        (nutrition + training + recovery + supplement) / 4
    }
}

private extension Array where Element == AdvancedDailyCompletion {
    var averageCompletion: Double {
        guard !isEmpty else { return 0 }
        return map(\.overall).reduce(0, +) / Double(count)
    }

    var consecutiveCompletionDays: Int {
        var count = 0
        for completion in reversed() {
            guard completion.overall > 0 else { break }
            count += 1
        }
        return count
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
