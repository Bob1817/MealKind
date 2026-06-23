import SwiftUI
import PhotosUI
import SwiftData
import UIKit

struct ScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredDailyTask.createdAt) private var storedTasks: [StoredDailyTask]
    @Environment(AppState.self) private var appState
    @State private var activeSheet: ScanSheet?
    @State private var showsTips = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedSource: MealSource = .photoLibrary
    @State private var showsCamera = false
    private var l10n: L10n { L10n(language: appState.language) }

    private var hasCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var isAdvanced: Bool {
        appState.experienceMode == .professional
    }

    var body: some View {
        ScrollView {
            if isAdvanced {
                VStack(alignment: .leading, spacing: 14) {
                    scanHero
                    scanTips
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    scanLifestyleHero
                    scanActivityEntry
                    scanMoreWaysSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .mkGlassNavigation(title: l10n.t(.scan), subtitle: scanSubtitle)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .smartReview:
                SmartScanReviewSheet(
                    imageData: selectedImageData,
                    plan: appState.selectedPlan,
                    remainingBeforeSave: appState.budget.remaining,
                    weightKilograms: appState.weightKilograms,
                    profile: appState.profile,
                    language: appState.language,
                    source: selectedSource,
                    bodyOSContext: appState.foodAnalysisContext()
                ) { result, source in
                    appState.saveScannedMeal(
                        result: result,
                        source: source,
                        imageData: selectedImageData,
                        modelContext: modelContext
                    )
                    syncCompletedMealPhotoTask()
                    activeSheet = nil
                } onSaveWorkout: { workout in
                    appState.saveWorkout(workout, modelContext: modelContext)
                    activeSheet = nil
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .manualWorkout:
                ManualWorkoutSheet(
                    weightKilograms: appState.weightKilograms,
                    profile: appState.profile,
                    language: appState.language
                ) { workout in
                    appState.saveWorkout(workout, modelContext: modelContext)
                    activeSheet = nil
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            case .activity:
                LifestyleActivitySheet(
                    weightKilograms: appState.weightKilograms,
                    profile: appState.profile,
                    language: appState.language
                ) { workout in
                    appState.saveWorkout(workout, modelContext: modelContext)
                    activeSheet = nil
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showsCamera) {
            CameraPicker { data in
                selectedImageData = data
                selectedSource = .camera
                activeSheet = .smartReview
                showsCamera = false
            } onCancel: {
                showsCamera = false
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var scanHero: some View {
        let uploadTitle = appState.language == .simplifiedChinese ? "从相册选择" : "Choose from library"

        VStack(alignment: .leading, spacing: 16) {
            Label(scanHeroTitle, systemImage: isAdvanced ? "chart.bar.doc.horizontal.fill" : "viewfinder")
                .font(.headline)
                .foregroundStyle(MKColor.green)

            Text(scanHeroMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                if hasCamera {
                    Button {
                        showsCamera = true
                    } label: {
                        Label(l10n.t(.takePhoto), systemImage: "camera.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(MKPrimaryActionStyle(tint: MKColor.green))
                }

                if hasCamera {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(uploadTitle, systemImage: "photo")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .foregroundStyle(.primary)
                            .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(MKTheme.divider, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .onChange(of: selectedPhoto) { _, newValue in
                        handlePhotoSelection(newValue)
                    }
                } else {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(uploadTitle, systemImage: "photo")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(MKPrimaryActionStyle(tint: MKColor.green))
                    .onChange(of: selectedPhoto) { _, newValue in
                        handlePhotoSelection(newValue)
                    }
                }

                Button {
                    activeSheet = .manualWorkout
                } label: {
                    Label(
                        appState.language == .simplifiedChinese ? "手动记训练" : "Log workout manually",
                        systemImage: "figure.strengthtraining.traditional"
                    )
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.primary)
                    .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(MKTheme.divider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .mkGlassSurface(cornerRadius: 28, tint: .white.opacity(0.18))
    }

    private var scanSubtitle: String {
        if appState.language == .simplifiedChinese {
            return isAdvanced ? "采集饮食和训练数据。" : "顺手留下一条记录。"
        }
        return isAdvanced ? "Capture food and training data." : "Leave one light record."
    }

    private var scanHeroTitle: String {
        if appState.language == .simplifiedChinese {
            return isAdvanced ? "采集今天的数据" : "记录一下"
        }
        return isAdvanced ? "Capture today's data" : "Log something"
    }

    private var scanHeroMessage: String {
        if appState.language == .simplifiedChinese {
            return isAdvanced
                ? "拍食物用于估算热量和宏量，也可以手动记录训练。系统会把这些数据用于今天的营养、恢复和策略调整。"
                : "可以拍一餐，也可以简单记一次运动。先留下记录，细节之后再补也可以。"
        }
        return isAdvanced
            ? "Food photos estimate calories and macros; manual workouts complete training data. These inputs adjust nutrition, recovery, and strategy."
            : "Snap one meal or log one movement. Start with a simple note; details can come later."
    }

    private var scanTips: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy) {
                    showsTips.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(MKColor.sky)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t(.betterScanTips))
                            .font(.subheadline.weight(.semibold))
                        Text(l10n.t(.betterScanTipsSubtitle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(showsTips ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showsTips {
                VStack(alignment: .leading, spacing: 10) {
                    TipLine(l10n.t(.betterScanTipWholePlate))
                    TipLine(l10n.t(.betterScanTipSauces))
                    TipLine(l10n.t(.betterScanTipEdit))
                }
                .padding(.top, 16)
            }
        }
        .padding(14)
        .mkGlassSurface(cornerRadius: 22, tint: .white.opacity(0.12), isInteractive: true)
    }

    // MARK: - Lifestyle Mode（任务执行视角）

    private var isChinese: Bool { appState.language == .simplifiedChinese }

    // Hero：今天记录一件事 + 超大「拍食物」主按钮（相册选择降为弱入口）。
    private var scanLifestyleHero: some View {
        let photoTitle = isChinese ? "拍食物" : "Snap food"

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isChinese ? "今天记录一件事" : "Log one thing today")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(MKColor.ink)
                Text(isChinese ? "吃了什么，或者做了什么" : "What you ate, or what you did")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if hasCamera {
                Button {
                    showsCamera = true
                } label: {
                    CaptureBigPhotoButtonLabel(title: photoTitle)
                }
                .buttonStyle(MKPrimaryActionStyle(tint: MKColor.green))
            } else {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    CaptureBigPhotoButtonLabel(title: photoTitle)
                }
                .buttonStyle(MKPrimaryActionStyle(tint: MKColor.green))
                .onChange(of: selectedPhoto) { _, newValue in
                    handlePhotoSelection(newValue)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .mkGlassSurface(cornerRadius: 28)
    }

    // 第二入口：记录活动（散步 / 跑步 / 骑车 / 瑜伽 / 逛街）。
    private var scanActivityEntry: some View {
        Button {
            activeSheet = .activity
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MKColor.green)
                    .frame(width: 46, height: 46)
                    .background(MKColor.green.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(isChinese ? "记录活动" : "Log activity")
                        .font(.headline)
                        .foregroundStyle(MKColor.ink)
                    Text(isChinese ? "散步、跑步、骑车、瑜伽、逛街" : "Walk, run, cycle, yoga, errands")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .mkGlassSurface(cornerRadius: 24)
        }
        .buttonStyle(.plain)
    }

    private var scanMoreWaysSection: some View {
        let libraryTitle = isChinese ? "从相册选择" : "Choose from library"
        let librarySubtitle = isChinese ? "已有照片时使用" : "Use an existing photo"

        return VStack(alignment: .leading, spacing: 10) {
            Text(isChinese ? "更多方式" : "More ways")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(MKColor.ink)

            VStack(spacing: 0) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    CaptureMoreWayRow(
                        symbol: "photo",
                        title: libraryTitle,
                        subtitle: librarySubtitle
                    )
                }
                .buttonStyle(.plain)
                .onChange(of: selectedPhoto) { _, newValue in
                    handlePhotoSelection(newValue)
                }

                Divider().overlay(MKTheme.divider).padding(.leading, 44)

                Button {
                    activeSheet = .activity
                } label: {
                    CaptureMoreWayRow(
                        symbol: "clock.arrow.circlepath",
                        title: isChinese ? "简单补录" : "Simple backfill",
                        subtitle: isChinese ? "补记刚刚做过的活动" : "Add a recent light activity"
                    )
                }
                .buttonStyle(.plain)

                Divider().overlay(MKTheme.divider).padding(.leading, 44)

                Button {
                    activeSheet = .manualWorkout
                } label: {
                    CaptureMoreWayRow(
                        symbol: "square.and.pencil",
                        title: isChinese ? "手动记录" : "Manual entry",
                        subtitle: isChinese ? "需要细一点时再用" : "Use only when details matter"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mkGlassSurface(cornerRadius: 24)
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            selectedImageData = try? await item.loadTransferable(type: Data.self)
            selectedSource = .photoLibrary
            activeSheet = .smartReview
        }
    }

    private func syncCompletedMealPhotoTask() {
        guard
            let updatedTask = appState.dailyTasks.first(where: { $0.taskType == .mealPhoto && $0.status == .completed }),
            let storedTask = storedTasks.first(where: { $0.id == updatedTask.id })
        else { return }

        storedTask.status = .completed
        storedTask.completedAt = updatedTask.completedAt ?? Date()
        try? modelContext.save()
    }
}

private enum ScanSheet: Identifiable {
    case smartReview
    case manualWorkout
    case activity
    var id: String { String(describing: self) }
}

private enum SmartScanKind {
    case food
    case workout
    case unknown
}

private struct CaptureBigPhotoButtonLabel: View {
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.system(size: 34, weight: .semibold))
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

private struct CaptureMoreWayRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MKColor.green)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MKColor.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct SmartScanReviewSheet: View {
    let imageData: Data?
    let plan: DietPlan
    let remainingBeforeSave: Int
    let weightKilograms: Double
    let profile: UserEnergyProfile
    let language: AppLanguage
    let source: MealSource
    let bodyOSContext: BodyOSAnalysisContext?
    let onSaveMeal: (FoodAnalysisResult, MealSource) -> Void
    let onSaveWorkout: (WorkoutLog) -> Void

    @Environment(\.services) private var services
    @State private var kind: SmartScanKind = .unknown
    @State private var result: FoodAnalysisResult?
    @State private var selectedFoodIndexes: Set<Int> = [0]
    @State private var portion = 1.0
    @State private var workoutType: WorkoutType = .walking
    @State private var durationText = "30"
    @State private var heartRateText = ""
    @State private var note = ""
    @State private var showsNutritionDetails = false

    private var l10n: L10n { L10n(language: language) }
    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                switch kind {
                case .food:
                    foodReview
                case .workout:
                    workoutReview
                case .unknown:
                    unknownReview
                }
            }
            .padding(20)
        }
        .background(MKBackdrop())
        .task {
            kind = classify(imageData)
            if kind == .food {
                result = await services.analyzeMealImage(imageData, plan, remainingBeforeSave, language, bodyOSContext)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(isChinese ? "AI 图片识别" : "AI image scan", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(MKColor.green)
            Text(headerText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 26, tint: .white.opacity(0.16))
    }

    private var headerText: String {
        switch kind {
        case .food:
            return isChinese ? "识别为食物。先看这顿怎么吃，必要时再修正分量。" : "Looks like food. Start with how to eat it, then adjust the portion if needed."
        case .workout:
            return isChinese ? "识别为运动或运动截图。当前版本仍可作为基础记录保存。" : "Looks like a workout or workout screenshot. This can still be saved as a basic log."
        case .unknown:
            return isChinese ? "暂时无法明确识别这张图片是食物还是运动。" : "I cannot clearly tell whether this is food or workout data."
        }
    }

    private var foodReview: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(result?.mealName ?? l10n.t(.analyzing))
                    .font(.title3.bold())
                Text(result?.summary ?? (isChinese ? "正在生成这顿的温和吃法建议..." : "Creating a gentle eating suggestion..."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(isChinese ? "建议" : "Suggestion")
                    .font(.subheadline.weight(.semibold))
                ForEach(Array(adviceLines.enumerated()), id: \.offset) { index, advice in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(MKColor.background)
                            .frame(width: 22, height: 22)
                            .background(MKColor.green, in: Circle())
                        Text(advice)
                            .font(.body.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Text(adjustedResult.taskCompletionImpact ?? (isChinese ? "保存后，今天午餐任务就完成了。" : "Saving this will complete today's lunch photo task."))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MKColor.green)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(isChinese ? "需要修正时再改" : "Adjust only if needed")
                    .font(.subheadline.weight(.semibold))

                ForEach(Array(foodItems.enumerated()), id: \.offset) { index, item in
                    Button {
                        if selectedFoodIndexes.contains(index) {
                            selectedFoodIndexes.remove(index)
                        } else {
                            selectedFoodIndexes.insert(index)
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedFoodIndexes.contains(index) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedFoodIndexes.contains(index) ? MKColor.green : .secondary)
                            Text(item)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                        .padding(11)
                        .background(MKTheme.fill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    Text(isChinese ? "食用分量" : "Portion")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(portion * 100))%")
                        .font(.subheadline.bold())
                        .monospacedDigit()
                }
                Slider(value: $portion, in: 0.25...1.5, step: 0.05)
                    .tint(MKColor.green)
            }

            DisclosureGroup(isExpanded: $showsNutritionDetails) {
                VStack(spacing: 10) {
                    ResultLine(title: l10n.t(.estimate), value: "\(adjustedCalories) \(l10n.t(.kcalUnit))")
                    ResultLine(title: l10n.t(.protein), value: "\(adjustedProtein)g")
                    ResultLine(title: l10n.t(.carbs), value: "\(adjustedCarbs)g")
                    ResultLine(title: l10n.t(.fat), value: "\(adjustedFat)g")
                    ResultLine(title: l10n.t(.confidence), value: (result?.confidence ?? .low).localizedName(language: language))
                }
                .padding(.top, 10)
            } label: {
                Label(isChinese ? "查看详细数据" : "View detailed data", systemImage: "chart.pie")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(14)
            .mkGlassSurface(cornerRadius: 18, tint: .white.opacity(0.12), isInteractive: true)

            Button {
                onSaveMeal(adjustedResult, source)
            } label: {
                Text(isChinese ? "保存这餐" : "Save this meal")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(MKPrimaryActionStyle(tint: MKColor.green))
            .disabled(result == nil || selectedFoodIndexes.isEmpty)
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 30, tint: .white.opacity(0.22))
    }

    private var workoutReview: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker(isChinese ? "运动类型" : "Workout type", selection: $workoutType) {
                ForEach(WorkoutType.allCases) { workoutType in
                    Text(workoutType.localizedName(language: language)).tag(workoutType)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .mkGlassSurface(cornerRadius: 18, tint: .white.opacity(0.16), isInteractive: true)

            HStack(spacing: 10) {
                WorkoutInputField(title: isChinese ? "时长" : "Duration", value: $durationText, unit: isChinese ? "分钟" : "min")
                WorkoutInputField(title: isChinese ? "平均心率" : "Avg HR", value: $heartRateText, unit: "bpm")
            }

            TextField(isChinese ? "补充参考，例如步数、配速、强度" : "Notes, e.g. steps, pace, intensity", text: $note)
                .textFieldStyle(.plain)
                .padding(14)
                .mkGlassSurface(cornerRadius: 18, tint: .white.opacity(0.16), isInteractive: true)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(estimatedWorkoutCalories)")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(MKColor.green)
                Text(l10n.t(.kcalUnit))
                    .font(.headline.bold())
                    .foregroundStyle(.secondary)
            }

            Button {
                onSaveWorkout(
                    WorkoutLog(
                        type: workoutType,
                        durationMinutes: durationMinutes,
                        averageHeartRate: averageHeartRate,
                        calories: estimatedWorkoutCalories,
                        note: note.isEmpty ? (isChinese ? "AI 图片识别后确认" : "Confirmed after AI image scan") : note,
                        source: .screenshot,
                        imageData: imageData
                    )
                )
            } label: {
                Text(isChinese ? "确认运动并计入今日" : "Confirm workout and log")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(MKPrimaryActionStyle(tint: MKColor.green))
        }
        .padding(18)
        .mkGlassSurface(cornerRadius: 30, tint: .white.opacity(0.22))
    }

    private var unknownReview: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(isChinese ? "无法识别图片内容" : "Image not recognized")
                .font(.title3.bold())
            Text(isChinese ? "请重新拍摄完整餐盘、食品包装、运动手表或步数截图。" : "Please capture a full plate, food package, workout watch, or step screenshot.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .mkGlassSurface(cornerRadius: 30, tint: .white.opacity(0.18))
    }

    private var foodItems: [String] {
        let base = result?.mealName ?? (isChinese ? "主食物" : "Main food")
        return isChinese ? [base, "配菜/酱料", "饮品"] : [base, "Sides or sauce", "Drink"]
    }

    private var adviceLines: [String] {
        let lines = result?.plainAdvice.isEmpty == false ? result?.plainAdvice : result?.actions
        let resolved = lines ?? []
        if !resolved.isEmpty {
            return Array(resolved.prefix(3))
        }
        return isChinese
            ? ["米饭留三分之一", "肉和蔬菜正常吃", "饮料少喝一点"]
            : ["Leave one third of the rice", "Eat protein and vegetables normally", "Drink a little less"]
    }

    private var selectedFoodRatio: Double {
        max(Double(selectedFoodIndexes.count), 1) / Double(foodItems.count)
    }

    private var adjustedCalories: Int {
        Int(Double(result?.estimatedCalories ?? 0) * selectedFoodRatio * portion)
    }

    private var adjustedProtein: Int {
        Int(Double(result?.protein ?? 0) * selectedFoodRatio * portion)
    }

    private var adjustedCarbs: Int {
        Int(Double(result?.carbs ?? 0) * selectedFoodRatio * portion)
    }

    private var adjustedFat: Int {
        Int(Double(result?.fat ?? 0) * selectedFoodRatio * portion)
    }

    private var adjustedResult: FoodAnalysisResult {
        let original = result ?? FoodAnalysisResult(
            mealName: l10n.t(.scannedMeal),
            estimatedCalories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            servingDescription: nil,
            confidence: .low,
            decision: .adjust,
            actions: [l10n.t(.betterScanTipEdit), l10n.t(.savePartForLater)],
            summary: nil,
            plainAdvice: adviceLines,
            taskCompletionImpact: isChinese ? "保存后，今天午餐任务就完成了。" : "Saving this will complete today's lunch photo task.",
            celebration: isChinese ? "你完成了今天最关键的一步。" : "You completed the most important small step today."
        )
        return FoodAnalysisResult(
            mealName: original.mealName,
            estimatedCalories: adjustedCalories,
            protein: adjustedProtein,
            carbs: adjustedCarbs,
            fat: adjustedFat,
            servingDescription: adjustedServingDescription,
            confidence: original.confidence,
            decision: original.decision,
            actions: original.actions,
            summary: original.summary,
            plainAdvice: original.plainAdvice,
            taskCompletionImpact: original.taskCompletionImpact,
            celebration: original.celebration
        )
    }

    private var adjustedServingDescription: String? {
        if let serving = result?.servingDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !serving.isEmpty {
            let percentage = Int((portion * 100).rounded())
            return percentage == 100 ? serving : "\(serving) · \(percentage)%"
        }
        let percentage = Int((portion * 100).rounded())
        return percentage == 100 ? nil : "\(percentage)%"
    }

    private var durationMinutes: Int {
        max(Int(durationText) ?? 0, 1)
    }

    private var averageHeartRate: Int? {
        let value = Int(heartRateText)
        return value == 0 ? nil : value
    }

    private var estimatedWorkoutCalories: Int {
        EnergyCalculator.workoutCalories(
            type: workoutType,
            weightKilograms: weightKilograms,
            durationMinutes: durationMinutes,
            averageHeartRate: averageHeartRate,
            age: profile.age
        )
    }

    private func classify(_ data: Data?) -> SmartScanKind {
        guard
            let data,
            data.count > 2_000,
            let image = UIImage(data: data)
        else { return .unknown }

        let ratio = image.size.height / max(image.size.width, 1)
        if ratio > 1.55 {
            return .workout
        }
        return .food
    }
}

private struct ManualWorkoutSheet: View {
    let weightKilograms: Double
    let profile: UserEnergyProfile
    let language: AppLanguage
    let onSave: (WorkoutLog) -> Void

    @State private var type: WorkoutType = .walking
    @State private var durationText = "30"
    @State private var heartRateText = ""
    @State private var note = ""

    private var l10n: L10n { L10n(language: language) }

    private var durationMinutes: Int {
        max(Int(durationText) ?? 0, 1)
    }

    private var averageHeartRate: Int? {
        let value = Int(heartRateText)
        return value == 0 ? nil : value
    }

    private var estimatedCalories: Int {
        EnergyCalculator.workoutCalories(
            type: type,
            weightKilograms: weightKilograms,
            durationMinutes: durationMinutes,
            averageHeartRate: averageHeartRate,
            age: profile.age
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(language == .simplifiedChinese ? "记录运动消耗" : "Log workout burn")
                        .font(.title2.bold())

                    Picker(language == .simplifiedChinese ? "运动类型" : "Workout type", selection: $type) {
                        ForEach(WorkoutType.allCases) { workoutType in
                            Text(workoutType.localizedName(language: language)).tag(workoutType)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .mkGlassSurface(cornerRadius: 18, tint: .white.opacity(0.16), isInteractive: true)

                    HStack(spacing: 10) {
                        WorkoutInputField(
                            title: language == .simplifiedChinese ? "时长" : "Duration",
                            value: $durationText,
                            unit: language == .simplifiedChinese ? "分钟" : "min"
                        )
                        WorkoutInputField(
                            title: language == .simplifiedChinese ? "平均心率" : "Avg HR",
                            value: $heartRateText,
                            unit: "bpm"
                        )
                    }

                    TextField(language == .simplifiedChinese ? "补充参考，例如坡度、步数、强度" : "Notes, e.g. incline, steps, intensity", text: $note)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .mkGlassSurface(cornerRadius: 18, tint: .white.opacity(0.16), isInteractive: true)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(estimatedCalories)")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(MKColor.green)
                        Text(l10n.t(.kcalUnit))
                            .font(.headline.bold())
                            .foregroundStyle(.secondary)
                    }
                    Text(language == .simplifiedChinese ? "基于 MET、体重、时间和心率修正估算。" : "Estimated from MET, weight, duration, and heart-rate adjustment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        onSave(
                            WorkoutLog(
                                type: type,
                                durationMinutes: durationMinutes,
                                averageHeartRate: averageHeartRate,
                                calories: estimatedCalories,
                                note: note,
                                source: .manual
                            )
                        )
                    } label: {
                        Text(language == .simplifiedChinese ? "保存到今日" : "Save to today")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(MKPrimaryActionStyle(tint: MKColor.green))
                }
                .padding(20)
            }
            .background(MKBackdrop())
        }
    }
}

// Lifestyle 活动记录：两步极简——做了什么 + 多久，不填表单、不展示热量。
private struct LifestyleActivitySheet: View {
    let weightKilograms: Double
    let profile: UserEnergyProfile
    let language: AppLanguage
    let onSave: (WorkoutLog) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var type: WorkoutType = .walking
    @State private var minutes: Int = 30

    private var isChinese: Bool { language == .simplifiedChinese }

    private let typeOptions: [WorkoutType] = [.walking, .running, .cycling, .yoga, .other]
    private let durationOptions: [Int] = [15, 30, 60, 90]

    private var estimatedCalories: Int {
        EnergyCalculator.workoutCalories(
            type: type,
            weightKilograms: weightKilograms,
            durationMinutes: minutes,
            averageHeartRate: nil,
            age: profile.age
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(isChinese ? "今天做了什么？" : "What did you do?")
                            .font(.headline)
                            .foregroundStyle(MKColor.ink)

                        VStack(spacing: 0) {
                            ForEach(Array(typeOptions.enumerated()), id: \.offset) { index, option in
                                Button {
                                    type = option
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: type == option ? "largecircle.fill.circle" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(type == option ? MKColor.green : MKTheme.secondaryText.opacity(0.5))
                                        Text(option.localizedName(language: language))
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(MKColor.ink)
                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)

                                if index < typeOptions.count - 1 {
                                    Divider().overlay(MKTheme.divider).padding(.leading, 32)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .mkGlassSurface(cornerRadius: 22)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(isChinese ? "多久？" : "How long?")
                            .font(.headline)
                            .foregroundStyle(MKColor.ink)

                        HStack(spacing: 10) {
                            ForEach(durationOptions, id: \.self) { value in
                                Button {
                                    minutes = value
                                } label: {
                                    Text(durationLabel(value))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(minutes == value ? .white : MKColor.ink)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            minutes == value ? MKColor.green : MKTheme.fill,
                                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        onSave(
                            WorkoutLog(
                                type: type,
                                durationMinutes: minutes,
                                averageHeartRate: nil,
                                calories: estimatedCalories,
                                note: "",
                                source: .manual
                            )
                        )
                    } label: {
                        Text(isChinese ? "完成" : "Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(MKPrimaryActionStyle(tint: MKColor.green))
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
            }
        }
    }

    private func durationLabel(_ value: Int) -> String {
        if value >= 90 {
            return isChinese ? "90+ 分钟" : "90+ min"
        }
        return isChinese ? "\(value) 分钟" : "\(value) min"
    }
}

private struct WorkoutEstimateSheet: View {
    let workout: WorkoutLog
    let language: AppLanguage
    let onSave: (WorkoutLog) -> Void

    private var l10n: L10n { L10n(language: language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(language == .simplifiedChinese ? "运动截图分析" : "Workout screenshot", systemImage: "waveform.path.ecg.rectangle")
                .font(.headline)
                .foregroundStyle(MKColor.green)

            Text(language == .simplifiedChinese ? "已根据截图入口生成一条保守估算。后续接入服务端 OCR 后，可自动读取步数、心率和运动时长。" : "A conservative estimate was created from this screenshot entry. Server OCR can later read steps, heart rate, and duration automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(workout.calories)")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(MKColor.green)
                Text(l10n.t(.kcalUnit))
                    .font(.headline.bold())
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ResultLine(title: language == .simplifiedChinese ? "类型" : "Type", value: workout.type.localizedName(language: language))
                ResultLine(title: language == .simplifiedChinese ? "时长" : "Duration", value: "\(workout.durationMinutes) min")
                ResultLine(title: language == .simplifiedChinese ? "参考" : "Reference", value: workout.note)
            }

            Button {
                onSave(workout)
            } label: {
                Text(language == .simplifiedChinese ? "保存运动消耗" : "Save workout burn")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(MKPrimaryActionStyle(tint: MKColor.green))
        }
        .padding(20)
        .background(MKBackdrop())
    }
}

private struct WorkoutInputField: View {
    let title: String
    @Binding var value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                TextField("0", text: $value)
                    .keyboardType(.numberPad)
                    .font(.title3.bold())
                    .monospacedDigit()
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .mkGlassSurface(cornerRadius: 18, tint: .white.opacity(0.16), isInteractive: true)
    }
}

private struct ResultLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .mkGlassSurface(cornerRadius: 16, tint: .white.opacity(0.12))
    }
}

private struct TipLine: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(MKColor.green)
            Text(text)
                .font(.subheadline)
        }
    }
}
