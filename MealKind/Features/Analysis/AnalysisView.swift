import SwiftUI
import SwiftData
import PhotosUI

struct AnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var storedSettings: [StoredUserSettings]
    @Query(sort: \StoredDailyTask.createdAt) private var storedTasks: [StoredDailyTask]
    @Environment(AppState.self) private var appState
    @State private var draft = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingImageData: Data?
    @State private var messages: [AnalysisMessage] = []

    private var l10n: L10n { L10n(language: appState.language) }
    private var isChinese: Bool { appState.language == .simplifiedChinese }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        AnalysisBubble(message: message, language: appState.language)
                            .id(message.id)
                    }
                    guideChips
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 92)
            }
            .mkGlassNavigation(
                title: isChinese ? "AI 教练" : "AI Coach",
                subtitle: isChinese ? "低压力地解决今天的问题。" : "Low-pressure support for today."
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                inputBar
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(.clear)
            }
            .onAppear {
                seedMessagesIfNeeded()
            }
            .onChange(of: messages.count) { _, _ in
                guard let last = messages.last?.id else { return }
                withAnimation(.smooth) {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                handlePhoto(newValue)
            }
        }
    }

    private var guideChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isChinese ? "常用问题" : "Common questions")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowChips(items: guideQuestions) { question in
                send(question)
            }
        }
        .padding(14)
        .mkGlassSurface(cornerRadius: 22, tint: .white.opacity(0.08), isInteractive: true)
    }

    @ViewBuilder
    private var inputBar: some View {
        let hasPendingImage = pendingImageData != nil
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: hasPendingImage ? "photo.fill" : "plus")
                    .font(.headline.bold())
                    .frame(width: 42, height: 42)
                    .foregroundStyle(hasPendingImage ? MKColor.green : .primary)
                    .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(MKTheme.track, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            TextField(l10n.t(.analysisInputPlaceholder), text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .mkGlassSurface(cornerRadius: 18, tint: .white.opacity(0.16), isInteractive: true)

            Button {
                send(draft)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.bold())
                    .frame(width: 42, height: 42)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingImageData == nil)
            .buttonStyle(MKPrimaryActionStyle(tint: MKColor.green))
        }
        .padding(8)
        .mkGlassSurface(cornerRadius: 28, tint: .white.opacity(0.22), isInteractive: true)
    }

    private var guideQuestions: [String] {
        if isChinese {
            return [
                "今天吃多了怎么办？",
                "晚上想吃零食怎么办？",
                "聚餐怎么吃轻松一点？",
                "今天任务能不能简单一点？"
            ]
        }

        return [
            "I ate more than planned. What now?",
            "What if I want snacks tonight?",
            "How do I handle a social meal?",
            "Can today’s task be easier?"
        ]
    }

    private func seedMessagesIfNeeded() {
        guard messages.isEmpty else { return }
        messages = [
            AnalysisMessage(
                text: openingPrompt,
                isUser: false,
                imageData: nil
            )
        ]
    }

    private var openingPrompt: String {
        if isChinese {
            return "今天已经完成 \(appState.todayCompletionText) 个小任务。你可以问我：吃多了怎么办、想吃零食怎么办、聚餐怎么选，或者把今天任务变简单一点。"
        }

        return "You have completed \(appState.todayCompletionText) small tasks today. Ask about eating more than planned, snacks, social meals, or making today’s task easier."
    }

    private func send(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || pendingImageData != nil else { return }
        let image = pendingImageData
        messages.append(AnalysisMessage(text: text.isEmpty ? (isChinese ? "请分析这张图" : "Please analyze this image") : text, isUser: true, imageData: image))
        draft = ""
        pendingImageData = nil

        let response = handleCommand(text, hasImage: image != nil)
        messages.append(AnalysisMessage(text: response, isUser: false, imageData: nil))
    }

    private func handleCommand(_ text: String, hasImage: Bool) -> String {
        let lower = text.lowercased()
        if lower.contains("太难") || lower.contains("简单") || lower.contains("easier") || lower.contains("hard") {
            return makePendingTaskEasier()
        }
        if hasImage {
            return isChinese ? "我已收到图片。如果这是食物，建议到【拍照】保存，这样午餐任务也会完成。现在先给你一个轻量策略：正常吃蛋白质和蔬菜，主食少一点，饮料尽量无糖。" : "I received the image. If it is food, save it from Scan so the lunch task completes too. For now: eat protein and vegetables normally, keep starch a little smaller, and choose an unsweetened drink if possible."
        }
        return smartReply(for: lower)
    }

    private func smartReply(for text: String) -> String {
        AICoachAdvisor.reply(to: text, language: appState.language)
    }

    private func makePendingTaskEasier() -> String {
        guard let task = appState.todayTasks.first(where: { $0.status == .pending }) else {
            return isChinese ? "今天的任务已经完成了。接下来不用加码，保持轻松就好。" : "Today’s tasks are already complete. No need to add more."
        }

        appState.makeTaskEasier(id: task.id)
        if let storedTask = storedTasks.first(where: { $0.id == task.id }),
           let updatedTask = appState.dailyTasks.first(where: { $0.id == task.id }) {
            storedTask.taskDescription = updatedTask.description
            storedTask.difficulty = updatedTask.difficulty
            try? modelContext.save()
        }

        return isChinese ? "已把「\(task.title)」变简单。今天只做最小版本就可以。" : "I made “\(task.title)” easier. The smallest version is enough today."
    }

    private func handlePhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            pendingImageData = try? await item.loadTransferable(type: Data.self)
        }
    }

    private var currentSettings: StoredUserSettings {
        LocalRecordRepository.settings(from: storedSettings, modelContext: modelContext)
    }
}

private struct AnalysisMessage: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var isUser: Bool
    var imageData: Data?
}

private struct AnalysisBubble: View {
    let message: AnalysisMessage
    let language: AppLanguage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 44) }
            VStack(alignment: .leading, spacing: 8) {
                if message.imageData != nil {
                    Label(language == .simplifiedChinese ? "已附加图片" : "Image attached", systemImage: "photo")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MKColor.green)
                }
                Text(message.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(13)
            .frame(maxWidth: message.isUser ? 300 : .infinity, alignment: .leading)
            .mkGlassSurface(
                cornerRadius: 18,
                tint: message.isUser ? MKColor.subtleGreen.opacity(0.24) : .white.opacity(0.08),
                isInteractive: false
            )
            if !message.isUser { Spacer(minLength: 44) }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

private struct FlowChips: View {
    let items: [String]
    let action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button(item) { action(item) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(MKTheme.track, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}
