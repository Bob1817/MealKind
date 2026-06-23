import SwiftUI

private enum CycleTrainingPlanPreset: String, CaseIterable, Identifiable {
    case threeSplit
    case fiveSplit
    case weekly

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .threeSplit: return "三分化"
            case .fiveSplit: return "五分化"
            case .weekly: return "按周循环"
            }
        }
        switch self {
        case .threeSplit: return "3-Day Split"
        case .fiveSplit: return "5-Day Split"
        case .weekly: return "Weekly Plan"
        }
    }

    func subtitle(language: AppLanguage) -> String {
        if language == .simplifiedChinese {
            switch self {
            case .threeSplit: return "练三休一，4 天循环"
            case .fiveSplit: return "练五休二，按周循环"
            case .weekly: return "周一到周日自由安排"
            }
        }
        switch self {
        case .threeSplit: return "Train 3, rest 1"
        case .fiveSplit: return "Train 5, rest 2"
        case .weekly: return "Customize Mon-Sun"
        }
    }
}

struct TrainingCycleCreationSheet: View {
    let language: AppLanguage
    let weightKilograms: Double
    let editingCycle: TrainingCycle?
    var onSave: (TrainingCycle) -> Void
    var onArchive: (TrainingCycle) -> Void
    var onCheckOverlap: (TrainingCycle) -> TrainingCycle?

    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    private let totalSteps = 5

    // Step 1: Basic
    @State private var title = ""
    @State private var goal: TrainingCycleGoal = .fatLoss

    // Step 2: Training
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .weekOfYear, value: 8, to: Date()) ?? Date()
    @State private var hasEndDate = true
    @State private var durationValue = 8
    @State private var durationText = "8"
    @State private var durationUnit: DurationUnit = .weeks
    @State private var arrangement: TrainingArrangement = .cyclic
    @State private var trainingPlanPreset: CycleTrainingPlanPreset = .threeSplit
    @State private var cycleDayCount = 4
    @State private var daySchedules: [CycleDaySchedule] = []
    @State private var isSyncingDates = false

    // Step 3: Diet
    @State private var dietPlanType: CycleDietPlanType = .carbCycling
    @State private var customProteinMultiplier = 1.8
    @State private var customCarbMultiplier = 2.5
    @State private var customFatMultiplier = 0.9

    // Step 4: Supplements
    @State private var supplements: [CycleSupplement] = []
    @State private var customSupplementName = ""
    @State private var customSupplementDosage = ""

    // Overlap
    @State private var showOverlapAlert = false
    @State private var pendingCycle: TrainingCycle?
    @State private var didHydrateEditingCycle = false
    @State private var isHydratingInitialState = false

    private var isChinese: Bool { language == .simplifiedChinese }
    private var isEditing: Bool { editingCycle != nil }

    init(
        language: AppLanguage,
        weightKilograms: Double,
        editingCycle: TrainingCycle? = nil,
        onSave: @escaping (TrainingCycle) -> Void,
        onArchive: @escaping (TrainingCycle) -> Void,
        onCheckOverlap: @escaping (TrainingCycle) -> TrainingCycle?
    ) {
        self.language = language
        self.weightKilograms = weightKilograms
        self.editingCycle = editingCycle
        self.onSave = onSave
        self.onArchive = onArchive
        self.onCheckOverlap = onCheckOverlap
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepProgressView
                Divider()
                stepContent
                Spacer()
                bottomButtons
            }
            .background(MKTheme.background)
            .navigationTitle(isEditing ? (isChinese ? "编辑训练周期" : "Edit Training Cycle") : (isChinese ? "创建训练周期" : "New Training Cycle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isChinese ? "取消" : "Cancel") { dismiss() }
                }
            }
        }
        .onChange(of: trainingPlanPreset) { _, _ in
            guard !isHydratingInitialState else { return }
            applyTrainingPreset()
        }
        .onChange(of: startDate) { _, _ in handleStartDateChange() }
        .onChange(of: endDate) { _, _ in handleEndDateChange() }
        .onChange(of: durationText) { _, _ in handleDurationTextChange() }
        .onChange(of: durationUnit) { _, _ in handleDurationUnitChange() }
        .onAppear {
            hydrateEditingCycleIfNeeded()
        }
        .confirmationDialog(
            isChinese ? "存在重叠周期" : "Overlapping Cycle",
            isPresented: $showOverlapAlert,
            titleVisibility: .visible
        ) {
            Button(isChinese ? "覆盖并生效" : "Replace & Activate", role: .destructive) {
                guard let cycle = pendingCycle else { return }
                onArchive(cycle)
                onSave(cycle)
                dismiss()
            }
            Button(isChinese ? "取消" : "Cancel", role: .cancel) {
                pendingCycle = nil
            }
        } message: {
            if let overlap = pendingCycle.flatMap({ onCheckOverlap($0) }) {
                Text(isChinese
                    ? "当前已有进行中或待开始的周期「\(overlap.title)」（\(overlap.startDate.formatted(date: .abbreviated, time: .omitted)) - \(overlap.endDate.formatted(date: .abbreviated, time: .omitted))）与新周期冲突。覆盖后旧周期会被归档，新周期立即生效。"
                    : "The existing cycle \"\(overlap.title)\" (\(overlap.startDate.formatted(date: .abbreviated, time: .omitted)) – \(overlap.endDate.formatted(date: .abbreviated, time: .omitted))) overlaps. Replacing it archives the old cycle and activates the new one.")
            }
        }
    }

    // MARK: - Step Progress

    private var stepProgressView: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? MKColor.green : MKTheme.track)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.2), value: step)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            switch step {
            case 0: step1BasicInfo
            case 1: step2TrainingPlan
            case 2: step3DietPlan
            case 3: step4Supplements
            case 4: step5Summary
            default: EmptyView()
            }
        }
    }

    // MARK: - Step 1: Basic Info

    private var step1BasicInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(isChinese ? "基本信息" : "Basic Info")

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isChinese ? "周期标题 *" : "Cycle Title *")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    TextField(isChinese ? "例如：8 周减脂周期" : "e.g. 8-week fat loss cycle", text: $title)
                        .font(.headline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 48)
                        .background(MKTheme.track.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(MKTheme.divider.opacity(0.9), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(isChinese ? "周期目标" : "Goal")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ForEach(TrainingCycleGoal.allCases) { g in
                            selectablePill(
                                title: g.localizedName(language: language),
                                isSelected: goal == g
                            ) {
                                goal = g
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            cycleDateRangeCard
        }
        .padding(20)
    }

    private var cycleDateRangeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isChinese ? "起止时间" : "Date Range")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            DatePicker(
                isChinese ? "开始时间" : "Start",
                selection: $startDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)

            HStack {
                if hasEndDate {
                    DatePicker(
                        isChinese ? "结束时间" : "End",
                        selection: $endDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                } else {
                    Text(isChinese ? "结束时间" : "End")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MKColor.ink)
                    Spacer()
                    Button(isChinese ? "设置" : "Set") {
                        hasEndDate = true
                        syncEndDateFromDuration()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MKColor.green)
                }
            }

            Divider().overlay(MKTheme.divider)

            VStack(alignment: .leading, spacing: 8) {
                Text(isChinese ? "计划时长" : "Duration")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    TextField("0", text: $durationText)
                        .keyboardType(.numberPad)
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(MKTheme.track.opacity(0.65), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(MKTheme.divider.opacity(0.9), lineWidth: 1)
                        )

                    Picker("", selection: $durationUnit) {
                        ForEach(DurationUnit.allCases) { unit in
                            Text(unit.localizedName(language: language)).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 92, height: 44)
                    .background(MKTheme.track.opacity(0.65), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }

                Text(hasEndDate
                    ? (isChinese ? "设置起止时间后，计划时长会自动同步。" : "Duration syncs with the date range.")
                    : (isChinese ? "未设置结束时间时，计划时长为 0。" : "Duration is 0 until an end date is set."))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func selectablePill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isSelected ? .white : MKColor.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(isSelected ? MKColor.green : MKTheme.track, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Training Plan

    private var step2TrainingPlan: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(isChinese ? "训练计划" : "Training Plan")

            VStack(alignment: .leading, spacing: 12) {
                Text(isChinese ? "选择训练计划" : "Choose plan")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                ForEach(CycleTrainingPlanPreset.allCases) { preset in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            trainingPlanPreset = preset
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: trainingPlanPreset == preset ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(trainingPlanPreset == preset ? MKColor.green : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.title(language: language))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(MKColor.ink)
                                Text(preset.subtitle(language: language))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(trainingPlanPreset == preset ? MKColor.subtleGreen : MKTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(isChinese ? "计划安排" : "Schedule")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(trainingPlanPreset.subtitle(language: language))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                ForEach($daySchedules) { $schedule in
                    dayScheduleRow(schedule: $schedule)
                }
            }
            .padding(14)
            .background(MKTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(20)
    }

    private func dayScheduleRow(schedule: Binding<CycleDaySchedule>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(schedule.wrappedValue.dayLabel(
                language: language,
                arrangement: arrangement
            ))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MKColor.ink)

            FlowChipSelection(
                selectedParts: schedule.bodyParts,
                isRestDay: schedule.isRestDay,
                language: language
            )
        }
        .padding(12)
        .background(MKTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Step 3: Diet Plan

    private var step3DietPlan: some View {
        let macros = CycleNutritionCalculator.recommendedMacros(
            goal: goal,
            dietPlan: dietPlanType,
            weightKg: weightKilograms
        )
        return VStack(alignment: .leading, spacing: 20) {
            sectionHeader(isChinese ? "饮食计划" : "Diet Plan")

            VStack(alignment: .leading, spacing: 8) {
                Text(isChinese ? "选择饮食计划" : "Select Diet Plan")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MKColor.ink)
                ForEach(CycleDietPlanType.allCases) { plan in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            dietPlanType = plan
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: dietPlanType == plan ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(dietPlanType == plan ? MKColor.green : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.localizedName(language: language))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(MKColor.ink)
                                Text(plan.localizedDescription(language: language))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(dietPlanType == plan ? MKColor.subtleGreen : MKTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Macro recommendations
            VStack(alignment: .leading, spacing: 8) {
                Text(isChinese ? "推荐营养素" : "Recommended Macros")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MKColor.ink)

                if dietPlanType == .custom {
                    customMacroInputs
                } else {
                    macroDisplayCard(macros: macros)
                }
            }
        }
        .padding(20)
    }

    private func macroDisplayCard(macros: CycleNutritionCalculator.MacroResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(macros.formattedDescription(weightKg: weightKilograms, language: language), id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(MKColor.ink)
            }
            if dietPlanType == .carbCycling {
                Text(isChinese
                    ? "训练日碳水较高，休息日碳水为 \(Int(weightKilograms * 1.5))g"
                    : "Rest day carbs: \(Int(weightKilograms * 1.5))g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MKColor.subtleGreen)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var customMacroInputs: some View {
        VStack(spacing: 12) {
            macroStepperRow(
                label: isChinese ? "蛋白质倍数" : "Protein Multiplier",
                value: $customProteinMultiplier,
                range: 1.0...3.0,
                step: 0.1,
                unit: "g/kg"
            )
            macroStepperRow(
                label: isChinese ? "碳水倍数" : "Carb Multiplier",
                value: $customCarbMultiplier,
                range: 0.5...8.0,
                step: 0.5,
                unit: "g/kg"
            )
            macroStepperRow(
                label: isChinese ? "脂肪倍数" : "Fat Multiplier",
                value: $customFatMultiplier,
                range: 0.5...2.5,
                step: 0.1,
                unit: "g/kg"
            )

            let custom = CycleNutritionCalculator.customMacros(
                weightKg: weightKilograms,
                proteinMultiplier: customProteinMultiplier,
                carbMultiplier: customCarbMultiplier,
                fatMultiplier: customFatMultiplier
            )
            macroDisplayCard(macros: custom)
        }
    }

    private func macroStepperRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(MKColor.ink)
            Spacer()
            Text("\(String(format: "%.1f", value.wrappedValue)) \(unit)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .scaleEffect(0.8)
        }
    }

    // MARK: - Step 4: Supplements

    private var step4Supplements: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(isChinese ? "补剂" : "Supplements")

            // System recommendations
            VStack(alignment: .leading, spacing: 8) {
                Text(isChinese ? "系统推荐" : "Recommended")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MKColor.ink)

                let recommended = CycleSupplement.systemRecommended(language: language)
                ForEach(recommended) { supp in
                    let isAdded = supplements.contains { $0.category == supp.category }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(supp.name)
                                .font(.subheadline)
                                .foregroundStyle(MKColor.ink)
                            Text(supp.dosage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            if isAdded {
                                supplements.removeAll { $0.category == supp.category }
                            } else {
                                supplements.append(supp)
                            }
                        } label: {
                            Text(isAdded ? (isChinese ? "已添加" : "Added") : (isChinese ? "添加" : "Add"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(isAdded ? .secondary : MKColor.green)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isAdded ? MKTheme.track : MKColor.subtleGreen)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(10)
                    .background(MKTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Custom supplement
            VStack(alignment: .leading, spacing: 8) {
                Text(isChinese ? "自定义补剂" : "Custom Supplement")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MKColor.ink)

                HStack(spacing: 8) {
                    TextField(isChinese ? "名称" : "Name", text: $customSupplementName)
                        .textFieldStyle(.roundedBorder)
                    TextField(isChinese ? "用量" : "Dosage", text: $customSupplementDosage)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 100)
                    Button {
                        guard !customSupplementName.isEmpty else { return }
                        supplements.append(CycleSupplement(
                            name: customSupplementName,
                            dosage: customSupplementDosage,
                            category: .custom
                        ))
                        customSupplementName = ""
                        customSupplementDosage = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(MKColor.green)
                    }
                    .disabled(customSupplementName.isEmpty)
                }
            }

            // Added supplements list
            if !supplements.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isChinese ? "已添加" : "Added Supplements")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(MKColor.ink)

                    ForEach(supplements) { supp in
                        HStack {
                            Text(supp.name)
                                .font(.subheadline)
                                .foregroundStyle(MKColor.ink)
                            Spacer()
                            Text(supp.dosage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                supplements.removeAll { $0.id == supp.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(MKTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(20)
    }

    // MARK: - Step 5: Summary

    private var step5Summary: some View {
        let cycle = buildCycle()
        return VStack(alignment: .leading, spacing: 20) {
            sectionHeader(isChinese ? "确认信息" : "Summary")

            summaryRow(isChinese ? "标题" : "Title", value: cycle.title)
            summaryRow(isChinese ? "目标" : "Goal", value: cycle.goal.localizedName(language: language))
            summaryRow(isChinese ? "开始时间" : "Start", value: cycle.startDate.formatted(date: .abbreviated, time: .omitted))
            summaryRow(isChinese ? "时长" : "Duration", value: "\(cycle.durationValue) \(cycle.durationUnit.localizedName(language: language))")
            summaryRow(isChinese ? "结束时间" : "End", value: cycle.endDate.formatted(date: .abbreviated, time: .omitted))
            summaryRow(isChinese ? "训练计划" : "Training Plan", value: trainingPlanPreset.title(language: language))

            if cycle.arrangement == .cyclic, let days = cycle.cycleDayCount {
                summaryRow(isChinese ? "循环天数" : "Cycle Days", value: "\(days)")
            }

            let restDays = cycle.daySchedules.filter(\.isRestDay).count
            let trainDays = cycle.daySchedules.count - restDays
            summaryRow(isChinese ? "训练/休息" : "Train/Rest", value: "\(trainDays) / \(restDays)")

            summaryRow(isChinese ? "饮食计划" : "Diet Plan", value: cycle.dietPlanType.localizedName(language: language))
            summaryRow(isChinese ? "补剂数量" : "Supplements", value: "\(cycle.supplements.count)")
            summaryRow(isChinese ? "每日睡眠" : "Daily Sleep", value: "8 \(isChinese ? "小时" : "hours")")
        }
        .padding(20)
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MKColor.ink)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    Text(isChinese ? "上一步" : "Back")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(MKTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }

            Button {
                if step < totalSteps - 1 {
                    withAnimation { step += 1 }
                } else {
                    createCycle()
                }
            } label: {
                Text(step < totalSteps - 1
                    ? (isChinese ? "下一步" : "Next")
                    : (isEditing ? (isChinese ? "保存计划" : "Save Plan") : (isChinese ? "创建周期" : "Create Cycle")))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(MKColor.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(step == 0 && title.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(step == 0 && title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.bold))
            .foregroundStyle(MKColor.ink)
    }

    private func rebuildDaySchedules() {
        let count = arrangement == .cyclic ? cycleDayCount : 7
        let existing = daySchedules
        daySchedules = (1...count).map { dayIndex in
            if dayIndex <= existing.count {
                var s = existing[dayIndex - 1]
                s.dayIndex = dayIndex
                return s
            }
            return CycleDaySchedule(dayIndex: dayIndex)
        }
    }

    private func applyTrainingPreset() {
        var nextArrangement: TrainingArrangement
        var nextCycleDayCount: Int
        var nextSchedules: [CycleDaySchedule]

        switch trainingPlanPreset {
        case .threeSplit:
            nextArrangement = .cyclic
            nextCycleDayCount = 4
            nextSchedules = [
                CycleDaySchedule(dayIndex: 1, bodyParts: [.chest, .back]),
                CycleDaySchedule(dayIndex: 2, bodyParts: [.legs, .glutes]),
                CycleDaySchedule(dayIndex: 3, bodyParts: [.shoulders, .biceps, .triceps]),
                CycleDaySchedule(dayIndex: 4, bodyParts: [], isRestDay: true)
            ]
        case .fiveSplit:
            nextArrangement = .weekly
            nextCycleDayCount = 7
            nextSchedules = [
                CycleDaySchedule(dayIndex: 1, bodyParts: [.chest]),
                CycleDaySchedule(dayIndex: 2, bodyParts: [.back]),
                CycleDaySchedule(dayIndex: 3, bodyParts: [.legs, .glutes]),
                CycleDaySchedule(dayIndex: 4, bodyParts: [.shoulders, .core]),
                CycleDaySchedule(dayIndex: 5, bodyParts: [.biceps, .triceps]),
                CycleDaySchedule(dayIndex: 6, bodyParts: [], isRestDay: true),
                CycleDaySchedule(dayIndex: 7, bodyParts: [], isRestDay: true)
            ]
        case .weekly:
            nextArrangement = .weekly
            nextCycleDayCount = 7
            if daySchedules.count == 7 {
                nextSchedules = daySchedules.enumerated().map { offset, schedule in
                    var updated = schedule
                    updated.dayIndex = offset + 1
                    return updated
                }
            } else {
                nextSchedules = (1...7).map { CycleDaySchedule(dayIndex: $0) }
            }
        }

        daySchedules = nextSchedules
        arrangement = nextArrangement
        cycleDayCount = nextCycleDayCount
    }

    private func hydrateEditingCycleIfNeeded() {
        guard !didHydrateEditingCycle else { return }
        didHydrateEditingCycle = true
        guard let editingCycle else {
            syncEndDateFromDuration()
            applyTrainingPreset()
            return
        }

        isHydratingInitialState = true
        isSyncingDates = true
        title = editingCycle.title
        goal = editingCycle.goal
        startDate = editingCycle.startDate
        endDate = editingCycle.endDate
        hasEndDate = true
        durationValue = editingCycle.durationValue
        durationText = "\(editingCycle.durationValue)"
        durationUnit = editingCycle.durationUnit
        arrangement = editingCycle.arrangement
        cycleDayCount = editingCycle.cycleDayCount ?? (editingCycle.arrangement == .cyclic ? editingCycle.daySchedules.count : 7)
        daySchedules = editingCycle.daySchedules
        dietPlanType = editingCycle.dietPlanType
        customProteinMultiplier = editingCycle.customProteinMultiplier ?? customProteinMultiplier
        customCarbMultiplier = editingCycle.customCarbMultiplier ?? customCarbMultiplier
        customFatMultiplier = editingCycle.customFatMultiplier ?? customFatMultiplier
        supplements = editingCycle.supplements
        trainingPlanPreset = preset(for: editingCycle)
        isSyncingDates = false
        isHydratingInitialState = false
    }

    private func preset(for cycle: TrainingCycle) -> CycleTrainingPlanPreset {
        if cycle.arrangement == .cyclic, cycle.cycleDayCount == 4 {
            return .threeSplit
        }
        let trainDays = cycle.daySchedules.filter { !$0.isRestDay }.count
        let restDays = cycle.daySchedules.filter { $0.isRestDay }.count
        if cycle.arrangement == .weekly, trainDays == 5, restDays == 2 {
            return .fiveSplit
        }
        return .weekly
    }

    private func handleStartDateChange() {
        guard !isSyncingDates else { return }
        isSyncingDates = true
        if hasEndDate {
            if endDate < startDate {
                endDate = startDate
            }
            syncDurationFromDateRange()
        } else {
            durationValue = 0
            durationText = "0"
        }
        isSyncingDates = false
    }

    private func handleEndDateChange() {
        guard !isSyncingDates else { return }
        isSyncingDates = true
        hasEndDate = true
        if endDate < startDate {
            endDate = startDate
        }
        syncDurationFromDateRange()
        isSyncingDates = false
    }

    private func handleDurationTextChange() {
        guard !isSyncingDates else { return }
        let filtered = durationText.filter(\.isNumber)
        if filtered != durationText {
            durationText = filtered
            return
        }
        durationValue = Int(filtered) ?? 0
        syncEndDateFromDuration()
    }

    private func handleDurationUnitChange() {
        guard !isSyncingDates else { return }
        syncEndDateFromDuration()
    }

    private func syncDurationFromDateRange() {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        let dayCount = max(Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0, 0)
        let value: Int
        switch durationUnit {
        case .days:
            value = dayCount
        case .weeks:
            value = dayCount == 0 ? 0 : Int(ceil(Double(dayCount) / 7.0))
        case .months:
            let months = Calendar.current.dateComponents([.month], from: start, to: end).month ?? 0
            value = max(months, dayCount == 0 ? 0 : Int(ceil(Double(dayCount) / 30.0)))
        }
        durationValue = value
        durationText = "\(value)"
    }

    private func syncEndDateFromDuration() {
        guard !isSyncingDates else { return }
        isSyncingDates = true
        if durationValue <= 0 {
            hasEndDate = false
            endDate = startDate
            durationText = "0"
            isSyncingDates = false
            return
        }
        hasEndDate = true
        let component: Calendar.Component
        switch durationUnit {
        case .days: component = .day
        case .weeks: component = .weekOfYear
        case .months: component = .month
        }
        endDate = Calendar.current.date(byAdding: component, value: durationValue, to: startDate) ?? startDate
        durationText = "\(durationValue)"
        isSyncingDates = false
    }

    private func buildCycle() -> TrainingCycle {
        var cycle = TrainingCycle(
            title: title.trimmingCharacters(in: .whitespaces),
            goal: goal,
            startDate: startDate,
            durationValue: durationValue,
            durationUnit: durationUnit,
            arrangement: arrangement,
            cycleDayCount: arrangement == .cyclic ? cycleDayCount : nil,
            daySchedules: daySchedules,
            dietPlanType: dietPlanType,
            customProteinMultiplier: dietPlanType == .custom ? customProteinMultiplier : nil,
            customCarbMultiplier: dietPlanType == .custom ? customCarbMultiplier : nil,
            customFatMultiplier: dietPlanType == .custom ? customFatMultiplier : nil,
            supplements: supplements
        )
        if let editingCycle {
            cycle.id = editingCycle.id
            cycle.status = editingCycle.status
            cycle.createdAt = editingCycle.createdAt
        }
        return cycle
    }

    private func createCycle() {
        let cycle = buildCycle()
        if isEditing {
            onSave(cycle)
            dismiss()
            return
        }
        if let _ = onCheckOverlap(cycle) {
            pendingCycle = cycle
            showOverlapAlert = true
        } else {
            onSave(cycle)
        }
    }
}

// MARK: - Flow Chip Selection

private struct FlowChipSelection: View {
    @Binding var selectedParts: [TrainingBodyPart]
    @Binding var isRestDay: Bool
    let language: AppLanguage

    private let allParts = TrainingBodyPart.allCases.filter { $0 != .fullBody }
    private var isChinese: Bool { language == .simplifiedChinese }

    var body: some View {
        WrappingHStack(horizontalSpacing: 6, verticalSpacing: 6) {
            Button {
                isRestDay.toggle()
                if isRestDay {
                    selectedParts.removeAll()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bed.double")
                        .font(.caption2)
                    Text(isChinese ? "休息日" : "Rest")
                        .font(.caption)
                }
                .foregroundStyle(isRestDay ? .white : MKColor.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isRestDay ? MKColor.citrus : MKTheme.track)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            ForEach(allParts) { part in
                let isSelected = !isRestDay && selectedParts.contains(part)
                Button {
                    if isRestDay {
                        isRestDay = false
                    }
                    if isSelected {
                        selectedParts.removeAll { $0 == part }
                    } else {
                        selectedParts.append(part)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: part.symbol)
                            .font(.caption2)
                        Text(part.localizedName(language: language))
                            .font(.caption)
                    }
                    .foregroundStyle(isSelected ? .white : MKColor.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isSelected ? MKColor.green : MKTheme.track)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Simple Wrapping HStack

private struct WrappingHStack: Layout {
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, origin) in result.origins.enumerated() where index < subviews.count {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + horizontalSpacing
            maxX = max(maxX, x - horizontalSpacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}
