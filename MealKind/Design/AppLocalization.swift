import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            "English"
        case .simplifiedChinese:
            "简体中文"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .english:
            "en"
        case .simplifiedChinese:
            "zh-Hans"
        }
    }
}

enum L10nKey: String {
    case today
    case scan
    case analysis
    case snap
    case record
    case plan
    case insights
    case me
    case startToday
    case changePlanAnytime
    case chooseStartingStyle
    case gentleLifestyle
    case gentleLifestyleSubtitle
    case steadyFatLoss
    case steadyFatLossSubtitle
    case moreStructure
    case moreStructureSubtitle
    case youCanStillEat
    case overBy
    case kcalLeft
    case kcalOver
    case onTrackToday
    case keepNextMealSimple
    case nextMove
    case scanMeal
    case clearSuggestion
    case log
    case water
    case weight
    case howTodayCalculated
    case calculationSubtitle
    case scanSubtitle
    case scanYourMeal
    case scanHeroSubtitle
    case takePhoto
    case chooseMealPhoto
    case betterScanTips
    case betterScanTipsSubtitle
    case mealScanned
    case mealPhoto
    case checkingMeal
    case eatNormallySummary
    case adjustSummary
    case estimate
    case afterSave
    case howToEatIt
    case detailsTitle
    case detailsSubtitle
    case recognized
    case confidence
    case protein
    case carbs
    case fat
    case saveToToday
    case profilePrivacyPlan
    case languageAndRegion
    case healthPermissions
    case notConnected
    case privacyAIMemory
    case termsDisclaimer
    case viewPlans
    case proTitle
    case proDescription
    case currentPlan
    case todayGoal
    case deficit
    case planGuardrails
    case showPlanDetails
    case advancedAdjustments
    case baseBurn
    case movement
    case exercise
    case minimumFloor
    case dailyActivity
    case recordAgainst
    case todayGoalNote
    case eaten
    case goal
    case quickLog
    case quickLogSubtitle
    case lightMeal
    case regularMeal
    case largeMeal
    case weightRecorded
    case weeklyTrendMessage
    case lastResult
    case fitTodaySaved
    case betterScanTipWholePlate
    case betterScanTipSauces
    case betterScanTipEdit
    case insightsSubtitle
    case weeklyBalance
    case withinGentleRange
    case kindReview
    case weeklyReviewText
    case logged
    case meals
    case cups
    case currentPlanLifestyleCut
    case currentPlanCarbStepDown
    case currentPlanHighProtein
    case rulePrioritizeProtein
    case ruleKeepDinnerLight
    case ruleSaveLeftovers
    case ruleProteinFirst
    case ruleHalfRiceDinner
    case ruleKeepSaucesLight
    case ruleFinishProtein
    case ruleAddVegetables
    case ruleKeepSnacksSimple
    case nextLifestyleCut
    case nextCarbStepDown
    case nextHighProtein
    case kcalUnit
    case lunchBowl
    case scannedMeal
    case burgerMeal
    case analyzing
    case left
    case over
    case savePartForLater
    case fallbackFitSummary
    case fallbackAdjustSummary
    case todayProgressSubtitle
    case analysisSubtitle
    case analysisPrompt
    case analysisInputPlaceholder
    case progressReview
    case problemSolving
    case settingsHelp
    case recordSubtitle
    case calendar
    case todayRings
    case foodImpact
    case riceComparison
    case burgerComparison
    case planSettings
    case calorieDeficit
    case targetDeficitRange
    case intake
    case burn
    case inRange
    case tooSmall
    case tooLarge
}

struct L10n {
    let language: AppLanguage

    func t(_ key: L10nKey) -> String {
        switch language {
        case .english:
            english[key] ?? key.rawValue
        case .simplifiedChinese:
            simplifiedChinese[key] ?? english[key] ?? key.rawValue
        }
    }
}

private let english: [L10nKey: String] = [
    .today: "Today",
    .scan: "Scan",
    .analysis: "Analysis",
    .snap: "Snap",
    .record: "Record",
    .plan: "Plan",
    .insights: "Insights",
    .me: "Me",
    .startToday: "Start today",
    .changePlanAnytime: "You can change your plan anytime.",
    .chooseStartingStyle: "Choose a starting style",
    .gentleLifestyle: "Gentle lifestyle",
    .gentleLifestyleSubtitle: "Small changes, low pressure.",
    .steadyFatLoss: "Steady fat loss",
    .steadyFatLossSubtitle: "A clear daily target with flexible meals.",
    .moreStructure: "More structure",
    .moreStructureSubtitle: "More plan rules, still simple by default.",
    .youCanStillEat: "You can still eat",
    .overBy: "Over by",
    .kcalLeft: "kcal left",
    .kcalOver: "kcal over",
    .onTrackToday: "You're on track today",
    .keepNextMealSimple: "Keep the next meal simple",
    .nextMove: "Next move",
    .scanMeal: "Scan meal",
    .clearSuggestion: "Get one clear eating suggestion",
    .log: "Log",
    .water: "Water",
    .weight: "Weight",
    .howTodayCalculated: "How today is calculated",
    .calculationSubtitle: "BMR, movement, exercise, plan deficit",
    .scanSubtitle: "Ask how to eat this meal.",
    .scanYourMeal: "Snap your meal",
    .scanHeroSubtitle: "MealKind gives a low-pressure eating suggestion first.",
    .takePhoto: "Take photo",
    .chooseMealPhoto: "Choose meal photo",
    .betterScanTips: "Better scan tips",
    .betterScanTipsSubtitle: "Optional, only when you need it",
    .mealScanned: "Meal scanned",
    .mealPhoto: "Meal photo",
    .checkingMeal: "Checking this meal...",
    .eatNormallySummary: "Eat it normally and record it. Stay with your plan by keeping the next snack simple.",
    .adjustSummary: "You can still eat it. Keep the starch smaller and let the next meal stay lighter.",
    .estimate: "Estimate",
    .afterSave: "After save",
    .howToEatIt: "How to eat it",
    .detailsTitle: "Food and nutrition details",
    .detailsSubtitle: "For checking or editing before saving",
    .recognized: "Recognized",
    .confidence: "Confidence",
    .protein: "Protein",
    .carbs: "Carbs",
    .fat: "Fat",
    .saveToToday: "Save to today",
    .profilePrivacyPlan: "Profile, reminders, privacy, and data.",
    .languageAndRegion: "Language and region",
    .healthPermissions: "Health permissions",
    .notConnected: "Not connected",
    .privacyAIMemory: "Privacy and AI memory",
    .termsDisclaimer: "Terms and disclaimer",
    .viewPlans: "View plans",
    .proTitle: "MealKind Pro",
    .proDescription: "Unlimited scans, AI coaching, weekly reviews, and habit adjustments.",
    .currentPlan: "Current plan",
    .todayGoal: "Today goal",
    .deficit: "Deficit",
    .planGuardrails: "Plan guardrails",
    .showPlanDetails: "Show plan details",
    .advancedAdjustments: "For advanced adjustments",
    .baseBurn: "Base burn",
    .movement: "Movement",
    .exercise: "Exercise",
    .minimumFloor: "Minimum floor",
    .dailyActivity: "daily activity",
    .recordAgainst: "Record against",
    .todayGoalNote: "today's goal",
    .eaten: "Eaten",
    .goal: "Goal",
    .quickLog: "Quick log",
    .quickLogSubtitle: "Pick a simple record. Detailed food editing can come later.",
    .lightMeal: "Light meal",
    .regularMeal: "Regular meal",
    .largeMeal: "Large meal",
    .weightRecorded: "Weight recorded",
    .weeklyTrendMessage: "Keep watching the weekly trend, not a single day.",
    .lastResult: "Last result",
    .fitTodaySaved: "Fit today · saved as 720 kcal",
    .betterScanTipWholePlate: "Include the whole plate.",
    .betterScanTipSauces: "Photograph sauces and drinks too.",
    .betterScanTipEdit: "Edit the estimate if it feels off.",
    .insightsSubtitle: "Look at the week, not one meal.",
    .weeklyBalance: "Weekly balance",
    .withinGentleRange: "Still within a gentle range",
    .kindReview: "Kind review",
    .weeklyReviewText: "Your best pattern this week is recording before dinner. Keep that, and let social meals be flexible instead of perfect.",
    .logged: "Logged",
    .meals: "meals",
    .cups: "cups",
    .currentPlanLifestyleCut: "Lifestyle Cut",
    .currentPlanCarbStepDown: "531 Carb Step-down",
    .currentPlanHighProtein: "High Protein",
    .rulePrioritizeProtein: "Prioritize protein",
    .ruleKeepDinnerLight: "Keep dinner light",
    .ruleSaveLeftovers: "Save leftovers if full",
    .ruleProteinFirst: "Protein first",
    .ruleHalfRiceDinner: "Half rice at dinner",
    .ruleKeepSaucesLight: "Keep sauces light",
    .ruleFinishProtein: "Finish protein",
    .ruleAddVegetables: "Add vegetables",
    .ruleKeepSnacksSimple: "Keep snacks simple",
    .nextLifestyleCut: "Eat normally, just keep dinner light.",
    .nextCarbStepDown: "Keep carbs lighter for your next meal.",
    .nextHighProtein: "Build the next meal around protein.",
    .kcalUnit: "kcal",
    .lunchBowl: "Lunch bowl",
    .scannedMeal: "Scanned meal",
    .burgerMeal: "Burger meal",
    .analyzing: "Analyzing",
    .left: "left",
    .over: "over",
    .savePartForLater: "Save part for later",
    .fallbackFitSummary: "This meal is okay. Eat normally and keep the next choice simple.",
    .fallbackAdjustSummary: "This meal is okay. Make the starch a little smaller.",
    .todayProgressSubtitle: "Today's task progress, kept simple.",
    .analysisSubtitle: "Talk with AI about progress, questions, and settings.",
    .analysisPrompt: "What would you like to understand today?",
    .analysisInputPlaceholder: "Ask about progress, meals, or plan settings",
    .progressReview: "Progress review",
    .problemSolving: "Solve a problem",
    .settingsHelp: "Settings help",
    .recordSubtitle: "Calendar rings for your daily rhythm.",
    .calendar: "Calendar",
    .todayRings: "Today's rings",
    .foodImpact: "Impact on today",
    .riceComparison: "About %.1f bowls of rice",
    .burgerComparison: "About %.1f burgers",
    .planSettings: "Plan settings",
    .calorieDeficit: "Calorie gap",
    .targetDeficitRange: "Target range",
    .intake: "Intake",
    .burn: "Burn",
    .inRange: "In range",
    .tooSmall: "Gap is small",
    .tooLarge: "Gap is high"
]

private let simplifiedChinese: [L10nKey: String] = [
    .today: "今日",
    .scan: "拍照",
    .analysis: "分析",
    .snap: "拍一拍",
    .record: "记录",
    .plan: "方案",
    .insights: "复盘",
    .me: "我的",
    .startToday: "开始今日计划",
    .changePlanAnytime: "之后可以随时调整方案。",
    .chooseStartingStyle: "选择一个开始方式",
    .gentleLifestyle: "温和生活化",
    .gentleLifestyleSubtitle: "小调整、低压力。",
    .steadyFatLoss: "稳定减脂",
    .steadyFatLossSubtitle: "清晰每日目标，饮食保持弹性。",
    .moreStructure: "更有结构",
    .moreStructureSubtitle: "规则更多，但默认仍然简单。",
    .youCanStillEat: "今天还可吃",
    .overBy: "已超出",
    .kcalLeft: "千卡可用",
    .kcalOver: "千卡",
    .onTrackToday: "今天仍在计划内",
    .keepNextMealSimple: "下一餐简单一点就好",
    .nextMove: "下一步",
    .scanMeal: "拍照分析",
    .clearSuggestion: "获得一句清楚建议",
    .log: "记录",
    .water: "喝水",
    .weight: "体重",
    .howTodayCalculated: "今日目标怎么算",
    .calculationSubtitle: "基础代谢、活动、运动、方案缺口",
    .scanSubtitle: "看看这顿怎么吃。",
    .scanYourMeal: "拍一拍当前食物",
    .scanHeroSubtitle: "MealKind 会先给出低压力吃法建议。",
    .takePhoto: "拍照",
    .chooseMealPhoto: "选择食物照片",
    .betterScanTips: "拍得更准的小提示",
    .betterScanTipsSubtitle: "需要时再看",
    .mealScanned: "已分析这餐",
    .mealPhoto: "食物照片",
    .checkingMeal: "正在分析这餐...",
    .eatNormallySummary: "可以正常吃并记录。下一份零食简单一点，就能继续贴近计划。",
    .adjustSummary: "可以吃，只是主食少一点，下一餐清淡一点。",
    .estimate: "估算",
    .afterSave: "保存后",
    .howToEatIt: "怎么吃",
    .detailsTitle: "食物和营养详情",
    .detailsSubtitle: "保存前可检查或修正",
    .recognized: "识别结果",
    .confidence: "置信度",
    .protein: "蛋白质",
    .carbs: "碳水",
    .fat: "脂肪",
    .saveToToday: "保存到今日",
    .profilePrivacyPlan: "资料、提醒、隐私和数据。",
    .languageAndRegion: "语言和地区",
    .healthPermissions: "健康权限",
    .notConnected: "未连接",
    .privacyAIMemory: "隐私和 AI 记忆",
    .termsDisclaimer: "条款和免责声明",
    .viewPlans: "查看订阅",
    .proTitle: "MealKind 会员版",
    .proDescription: "无限拍照分析、AI 教练、周复盘和习惯调整。",
    .currentPlan: "当前方案",
    .todayGoal: "今日目标",
    .deficit: "计划缺口",
    .planGuardrails: "方案规则",
    .showPlanDetails: "查看方案详情",
    .advancedAdjustments: "给进阶调整使用",
    .baseBurn: "基础消耗",
    .movement: "日常活动",
    .exercise: "运动消耗",
    .minimumFloor: "最低下限",
    .dailyActivity: "日常活动",
    .recordAgainst: "记录目标",
    .todayGoalNote: "今日目标",
    .eaten: "已摄入",
    .goal: "目标",
    .quickLog: "快速记录",
    .quickLogSubtitle: "选择一个简单记录，详细编辑可以之后再做。",
    .lightMeal: "轻量一餐",
    .regularMeal: "普通一餐",
    .largeMeal: "偏大一餐",
    .weightRecorded: "体重已记录",
    .weeklyTrendMessage: "看一周趋势，不被某一天影响。",
    .lastResult: "最近结果",
    .fitTodaySaved: "适合今日 · 已保存 720 千卡",
    .betterScanTipWholePlate: "尽量拍到完整餐盘。",
    .betterScanTipSauces: "酱料和饮料也一起拍到。",
    .betterScanTipEdit: "如果估算不准，可以手动修正。",
    .insightsSubtitle: "看一周，不纠结某一餐。",
    .weeklyBalance: "周热量平衡",
    .withinGentleRange: "仍在温和范围内",
    .kindReview: "温和复盘",
    .weeklyReviewText: "这周最有帮助的是晚餐前先记录。继续保持，社交餐可以弹性一点，不必追求完美。",
    .logged: "已记录",
    .meals: "餐",
    .cups: "杯",
    .currentPlanLifestyleCut: "生活化减脂",
    .currentPlanCarbStepDown: "531 碳水渐降",
    .currentPlanHighProtein: "高蛋白控热量",
    .rulePrioritizeProtein: "优先吃蛋白质",
    .ruleKeepDinnerLight: "晚餐轻一点",
    .ruleSaveLeftovers: "吃饱就留一部分",
    .ruleProteinFirst: "先吃蛋白质",
    .ruleHalfRiceDinner: "晚餐主食半份",
    .ruleKeepSaucesLight: "酱汁少一点",
    .ruleFinishProtein: "蛋白质尽量吃完",
    .ruleAddVegetables: "加一份蔬菜",
    .ruleKeepSnacksSimple: "零食简单一点",
    .nextLifestyleCut: "正常吃，晚餐轻一点就好。",
    .nextCarbStepDown: "下一餐碳水稍微轻一点。",
    .nextHighProtein: "下一餐围绕蛋白质来搭配。",
    .kcalUnit: "千卡",
    .lunchBowl: "午餐碗",
    .scannedMeal: "已扫描餐食",
    .burgerMeal: "汉堡餐",
    .analyzing: "分析中",
    .left: "可用",
    .over: "超出",
    .savePartForLater: "留一部分稍后再吃",
    .fallbackFitSummary: "这顿可以吃，正常吃就好，下一次选择简单一点。",
    .fallbackAdjustSummary: "这顿可以吃，把主食稍微少一点就好。",
    .todayProgressSubtitle: "今日任务进度，简单看清。",
    .analysisSubtitle: "和 AI 沟通进度、问题和设置。",
    .analysisPrompt: "今天想了解什么？",
    .analysisInputPlaceholder: "询问进度、饮食或方案设置",
    .progressReview: "进度复盘",
    .problemSolving: "解决问题",
    .settingsHelp: "设置帮助",
    .recordSubtitle: "用日历圆环查看每天的节奏。",
    .calendar: "日历",
    .todayRings: "今日圆环",
    .foodImpact: "对今日任务的影响",
    .riceComparison: "约 %.1f 碗米饭",
    .burgerComparison: "约 %.1f 个汉堡",
    .planSettings: "减脂方案",
    .calorieDeficit: "热量差",
    .targetDeficitRange: "合理区间",
    .intake: "饮食",
    .burn: "消耗",
    .inRange: "区间内",
    .tooSmall: "热量差偏小",
    .tooLarge: "热量差偏大"
]
