import SwiftUI
import SwiftData

struct HabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredDailyTask.createdAt) private var storedTasks: [StoredDailyTask]
    @Environment(AppState.self) private var appState

    private var isChinese: Bool { appState.language == .simplifiedChinese }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                introCard
                activeHabitList
                todayAdjustmentCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .mkGlassNavigation(
            title: isChinese ? "习惯" : "Habit",
            subtitle: isChinese ? "正在养成的减脂小动作。" : "Small actions you are building."
        )
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(isChinese ? "微习惯系统" : "Tiny habit system", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(MKColor.green)

            Text(isChinese ? "每个习惯都由锚点、一个很小的动作和完成后的庆祝组成。太难时，系统会把任务变轻。" : "Each habit has an anchor, one tiny behavior, and a small celebration. When it feels hard, make it lighter.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .mkGlassSurface(cornerRadius: 28, tint: .white.opacity(0.16))
    }

    private var activeHabitList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isChinese ? "当前习惯" : "Active habits")
                .font(.headline)

            ForEach(appState.activeHabits) { habit in
                HabitCard(habit: habit, isChinese: isChinese)
            }
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 28, tint: .white.opacity(0.14))
    }

    private var todayAdjustmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isChinese ? "今天觉得太难？" : "Too hard today?")
                .font(.headline)
            Text(isChinese ? "选择一个未完成任务，先降到更容易完成的版本。" : "Pick one pending task and make it easier for today.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(appState.todayTasks.filter { $0.status != .completed }) { task in
                Button {
                    makeEasier(task)
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(MKColor.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.subheadline.weight(.semibold))
                            Text(isChinese ? "难度 \(task.difficulty)" : "Difficulty \(task.difficulty)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 28, tint: MKColor.subtleGreen.opacity(0.18))
    }

    private func makeEasier(_ task: DailyTask) {
        appState.makeTaskEasier(id: task.id)
        if let updatedTask = appState.dailyTasks.first(where: { $0.id == task.id }) {
            LocalRecordRepository.syncTask(updatedTask, in: storedTasks, modelContext: modelContext)
        }
    }
}

private struct HabitCard: View {
    let habit: Habit
    let isChinese: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(.headline)
                    Text(isChinese ? "难度 \(habit.difficulty)" : "Difficulty \(habit.difficulty)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MKColor.green)
                }
                Spacer()
                Image(systemName: "leaf.fill")
                    .foregroundStyle(MKColor.green)
            }

            HabitLine(title: isChinese ? "锚点" : "Anchor", value: habit.anchor, symbol: "link")
            HabitLine(title: isChinese ? "小动作" : "Tiny behavior", value: habit.tinyBehavior, symbol: "hand.tap")
            HabitLine(title: isChinese ? "庆祝" : "Celebration", value: habit.celebration, symbol: "sparkles")
        }
        .padding(14)
        .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HabitLine: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
