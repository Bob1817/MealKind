# 05 工程级文档：iOS 原生项目实施细则

版本：V2.0 Engineering  
适用对象：Codex / Claude Code / Cursor / iOS 原生开发  
技术方向：Swift + SwiftUI + SwiftData + HealthKit + StoreKit 2 + Supabase

---

## 0. 项目目标

开发 iOS 原生 App：轻减AI / Qingjian AI。

核心定位：

```text
AI Body OS
普通用户：减脂习惯助手
进阶用户：训练、营养、恢复、周期管理系统
```

---

## 1. 技术栈

```text
Language: Swift
UI: SwiftUI
Local Persistence: SwiftData
Remote Backend: Supabase
Auth: Supabase Auth + Sign in with Apple
AI: Server-side AI Gateway
Health: HealthKit
Subscription: StoreKit 2
Notifications: UserNotifications
Charts: Swift Charts
```

---

## 2. 项目目录结构

```text
QingjianAI/
├── App/
│   ├── QingjianAIApp.swift
│   ├── AppRouter.swift
│   └── AppEnvironment.swift
│
├── Features/
│   ├── Today/
│   ├── Scan/
│   ├── BodyLog/
│   ├── Progress/
│   ├── Me/
│   ├── Onboarding/
│   └── Subscription/
│
├── Core/
│   ├── Models/
│   ├── Engines/
│   │   ├── StateEngine/
│   │   ├── CycleEngine/
│   │   ├── NutritionEngine/
│   │   ├── RecoveryEngine/
│   │   └── StrategyEngine/
│   ├── Repositories/
│   ├── Services/
│   └── DesignSystem/
│
├── Infrastructure/
│   ├── Supabase/
│   ├── HealthKit/
│   ├── StoreKit/
│   ├── AI/
│   └── Notifications/
│
└── Tests/
```

---

## 3. 主导航

5 个 Tab：

```swift
enum MainTab {
    case today
    case scan
    case bodyLog
    case progress
    case me
}
```

UI：

```text
Today    今日
Scan     拍照
BodyLog  记录
Progress 进展
Me       我的
```

---

## 4. 模式控制

```swift
enum UserMode: String, Codable {
    case lifestyle
    case advanced
}
```

### lifestyle

展示：

- 今日策略
- 简单任务
- 拍照建议
- 体重趋势

隐藏：

- TDEE
- BMR
- 宏量营养细节
- 训练周期复杂数据

### advanced

展示：

- 热量
- 蛋白质
- 碳水
- 脂肪
- 训练日
- 恢复指数
- 睡眠
- 补剂
- 周期

---

## 5. Today 页面

### 5.1 ViewModel

```swift
@Observable
final class TodayViewModel {
    var dashboard: TodayDashboard?
    var strategies: [TodayStrategyItem] = []
    var isLoading = false

    func loadToday()
    func refreshStrategy()
    func completeAction(_ action: StrategyAction)
}
```

### 5.2 页面组件

```swift
TodayView
 ├── CurrentStateCard
 ├── EnergySummaryCard
 ├── TodayStrategyCard
 ├── QuickScanButton
 └── GentleMessageCard
```

### 5.3 普通用户 Today

```text
今天目标：
完成两个小动作即可。

策略：
午餐前拍一下。
晚餐主食少一点。
```

### 5.4 进阶用户 Today

```text
减脂期 第4周
胸背训练日
恢复指数 82

Calories 1650 / 2200
Protein 120 / 160g
Carbs 150 / 220g
Fat 45 / 55g
```

---

## 6. Scan 页面

### 6.1 功能

- 拍照
- 相册选择
- 上传图片
- AI 分析
- 展示建议
- 用户修正
- 保存记录

### 6.2 ViewModel

```swift
@Observable
final class ScanViewModel {
    var selectedImage: UIImage?
    var analysisResult: FoodAnalysisResult?
    var isAnalyzing = false

    func analyzeImage()
    func saveMealRecord()
    func updateFoodItem(_ item: FoodItem)
}
```

---

## 7. BodyLog 页面

### 7.1 普通用户

显示：

- 体重
- 饮水
- 步数
- 饮食记录

### 7.2 进阶用户

显示：

- 饮食
- 宏量营养
- 训练
- 睡眠
- 饮水
- 补剂
- 体重
- 体脂
- 围度

### 7.3 组件

```swift
BodyLogView
 ├── NutritionLogSection
 ├── WorkoutLogSection
 ├── SleepLogSection
 ├── WaterLogSection
 ├── SupplementLogSection
 └── MeasurementLogSection
```

---

## 8. Progress 页面

### 8.1 普通用户

- 本周完成了什么
- 体重趋势
- 最稳定行为
- 下周一个重点

### 8.2 进阶用户

- 周热量趋势
- 蛋白达标率
- 训练完成率
- 恢复趋势
- 睡眠趋势
- 体重/体脂趋势

---

## 9. Engine 本地实现

### 9.1 StateEngine

```swift
protocol StateEngineProtocol {
    func resolve(input: StateInput) -> BodyState
}
```

### 9.2 NutritionEngine

```swift
protocol NutritionEngineProtocol {
    func calculateTarget(input: NutritionInput) -> NutritionTarget
}
```

### 9.3 StrategyEngine

```swift
protocol StrategyEngineProtocol {
    func generate(input: StrategyInput) -> TodayStrategy
}
```

---

## 10. Repository 层

```swift
protocol MealRepository {
    func fetchMeals(date: Date) async throws -> [MealRecord]
    func saveMeal(_ meal: MealRecord) async throws
}

protocol StrategyRepository {
    func fetchTodayStrategy(date: Date) async throws -> TodayStrategy
    func saveStrategy(_ strategy: TodayStrategy) async throws
}
```

---

## 11. Supabase 同步策略

### 11.1 本地优先

所有记录先写 SwiftData。

### 11.2 后台同步

网络可用时同步 Supabase。

### 11.3 冲突处理

规则：

```text
手动修改优先
updated_at 最新优先
AI 结果不覆盖用户修正
```

---

## 12. HealthKit

### 12.1 读取

- 体重
- 步数
- 活动能量
- 睡眠
- 心率
- 静息心率
- HRV

### 12.2 写入

V1 不写入 HealthKit。  
只读取。

---

## 13. StoreKit 2

订阅层级：

```swift
enum SubscriptionTier {
    case free
    case pro
    case proPlus
}
```

Free：

- 基础记录
- 每日有限 AI 分析

Pro：

- 无限拍照
- AI 教练
- 周复盘

Pro Plus：

- 周期管理
- 恢复分析
- 高级策略
- 补剂系统

---

## 14. Design System

### 14.1 风格

```text
克制
简约
高级
安静
温和
低信息密度
```

### 14.2 色彩

```swift
enum AppColor {
    static let background
    static let card
    static let primaryGreen
    static let softOrange
    static let textPrimary
    static let textSecondary
}
```

### 14.3 组件

```text
AppCard
PrimaryButton
SecondaryButton
MetricRing
MacroBar
StrategyCard
GentleMessage
```

---

## 15. Codex 开发顺序

### Phase 1

- 项目结构
- Design System
- 5 Tab
- SwiftData Models
- Mock 数据

### Phase 2

- Today
- BodyLog
- StateEngine
- NutritionEngine
- StrategyEngine

### Phase 3

- Scan
- AIService Mock
- MealRecord 保存

### Phase 4

- Supabase
- Auth
- Sync

### Phase 5

- HealthKit
- StoreKit 2
- Notifications

---

## 16. 验收标准

1. App 可运行。
2. 5 Tab 正常切换。
3. lifestyle / advanced 两种模式展示不同。
4. Today 可显示当前策略。
5. BodyLog 可记录饮食、睡眠、补剂。
6. Scan 可用 Mock AI 返回结果。
7. StrategyEngine 单元测试通过。
8. StateEngine 单元测试通过。
9. UI 风格克制简约。
10. 所有核心模型支持 Codable。