import SwiftUI

struct RecordView: View {
    @Environment(AppState.self) private var appState
    private var l10n: L10n { L10n(language: appState.language) }
    private var summary: InsightsSummary { appState.insightsSummary }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MKTheme.cardSpacing) {
                if appState.experienceMode == .professional {
                    macroRings
                } else {
                    todayRings
                }
                calendarCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .mkGlassNavigation(
            title: l10n.t(.record),
            subtitle: appState.language == .simplifiedChinese ? "本周记录概览。" : "This week's log overview."
        )
    }

    private var todayRings: some View {
        HStack(spacing: 16) {
            ZStack {
                Ring(progress: calorieProgress, color: MKColor.green, lineWidth: 14)
                Ring(progress: Double(appState.waterCups) / 8.0, color: MKColor.sky, lineWidth: 9)
                    .padding(20)
                Ring(progress: appState.meals.isEmpty ? 0 : 1, color: MKColor.citrus, lineWidth: 6)
                    .padding(36)
            }
            .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.t(.todayRings))
                    .font(.headline)
                Text(appState.budget.isOverBudget ? l10n.t(.keepNextMealSimple) : l10n.t(.onTrackToday))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    RecordPill(title: l10n.t(.eaten), value: "\(appState.budget.eatenCalories)")
                    RecordPill(title: l10n.t(.water), value: "\(appState.waterCups)")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .mkGlassSurface(cornerRadius: 26, tint: .white.opacity(0.08))
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(l10n.t(.calendar))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                ForEach(Array(summary.days.enumerated()), id: \.element.id) { index, day in
                    VStack(spacing: 7) {
                        Text(dayLabel(index))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ZStack {
                            Ring(progress: progress(for: day), color: day.balance > 0 ? MKColor.citrus : MKColor.green, lineWidth: 5)
                            Text("\(Calendar.current.component(.day, from: day.date))")
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                        }
                        .frame(width: 34, height: 34)
                    }
                }
            }
        }
        .padding(16)
        .mkGlassSurface(cornerRadius: 24, tint: .white.opacity(0.06))
    }

    private var macroRings: some View {
        HStack(spacing: 16) {
            ZStack {
                ForEach(Array(MacroKind.allCases.enumerated()), id: \.element.id) { index, macro in
                    Ring(
                        progress: appState.macroProgress.progress(for: macro),
                        color: macro.color,
                        lineWidth: CGFloat(15 - index * 3)
                    )
                    .padding(CGFloat(index * 20))
                }
            }
            .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 8) {
                Text(appState.language == .simplifiedChinese ? "今日三环" : "Today rings")
                    .font(.headline)
                Text(appState.language == .simplifiedChinese ? "蛋白、碳水、脂肪" : "Protein, carbs, fat")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 5) {
                    ForEach(MacroKind.allCases) { macro in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(macro.color)
                                .frame(width: 7, height: 7)
                            Text(macro.title(language: appState.language))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(macro.value(in: appState.macroProgress.eaten))/\(macro.value(in: appState.macroProgress.target))g")
                                .font(.caption.bold())
                                .monospacedDigit()
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .mkGlassSurface(cornerRadius: 26, tint: .white.opacity(0.08))
    }

    private var calorieProgress: Double {
        Double(appState.budget.eatenCalories) / Double(max(appState.budget.dailyGoal, 1))
    }

    private func progress(for day: DailyEnergyBalance) -> Double {
        guard day.eatenCalories > 0 else { return 0 }
        return min(Double(day.eatenCalories) / Double(max(day.goalCalories, 1)), 1)
    }

    private func dayLabel(_ index: Int) -> String {
        if appState.language == .simplifiedChinese {
            return ["一", "二", "三", "四", "五", "六", "日"][index]
        }
        return ["M", "T", "W", "T", "F", "S", "S"][index]
    }
}

private struct Ring: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(MKTheme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct RecordPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
