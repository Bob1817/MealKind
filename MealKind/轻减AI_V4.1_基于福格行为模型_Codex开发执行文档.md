# 轻减AI V4.1 产品设计与开发执行文档
## 基于《福格行为模型》的 AI 减脂习惯执行系统

> 面向 Codex / Claude Code / Cursor / 开发团队使用  
> 产品目标：将“轻减AI”从普通减脂记录工具，重构为以微习惯、低压力执行、AI 建档、AI 拍照建议为核心的 iOS 原生减脂习惯系统。  
> UI 要求：克制、简约、高级、低信息密度、温和、无焦虑感。

---

## 0. 开发总目标

请基于本文件设计并开发一款 iOS 原生 App：**轻减AI / Qingjian AI**。

产品不是传统热量记录 App，也不是专业健身工具，而是：

> 帮助普通用户通过极小、可持续、低压力的行为改变，逐步建立健康饮食与身材管理习惯的 AI 执行助手。

核心设计原则基于福格行为模型：

```text
Behavior = Motivation × Ability × Prompt
行为发生 = 动机 × 能力 × 提示
```

产品设计重点不是提高用户自律，而是：

1. 降低行为难度；
2. 在正确时机提示用户；
3. 每次完成后立即给出正向反馈；
4. 通过微习惯让用户长期坚持。

---

# 1. 产品定位

## 1.1 一句话定位

轻减AI是一款基于行为设计的 AI 减脂习惯执行助手。

## 1.2 核心价值

用户不需要学习复杂减脂知识，只需要完成很小的动作：

- 拍一下食物；
- 看一下今日任务；
- 完成一个小习惯；
- 记录一次体重；
- 睡前看一次总结。

系统负责：

- 判断今天该做什么；
- 判断这顿怎么吃；
- 帮用户生成低难度任务；
- 在合适时间提醒；
- 用户失败时自动降低难度；
- 用户完成后立即鼓励。

## 1.3 产品不做什么

V1 阶段不要做：

- 社区；
- 排行榜；
- PK；
- 健身课程；
- 专业健美备赛；
- 复杂饮食方案市场；
- 生酮、DASH、地中海、IIFYM 等复杂方案；
- 大量专业营养数据前置展示；
- 体重焦虑型打卡系统。

---

# 2. 目标用户

## 2.1 核心用户：普通生活化减脂用户

用户画像：

- 想减肥，但不知道怎么开始；
- 没有规律运动；
- 对热量没有概念；
- 经常极端节食；
- 经常计划崩溃；
- 经常忘记自己吃了什么；
- 不愿意称重、计算、复杂记录；
- 需要被温和引导，而不是被监督。

核心问题：

```text
用户不是不知道减肥重要，而是无法持续执行。
```

## 2.2 次级用户：进阶减脂用户

用户画像：

- 有运动习惯；
- 了解热量和营养；
- 关注蛋白质、碳水、脂肪；
- 需要更精确的数据反馈。

---

# 3. 产品核心行为模型

## 3.1 行为设计公式

每个核心功能都必须满足：

```text
用户想做 + 用户做得到 + 系统及时提醒 = 行为发生
```

## 3.2 产品中的三类变量

### Motivation 动机

用户动机通常不稳定，所以产品不能依赖高动机。

设计要求：

- 不要求用户每天完美；
- 不用羞辱性文案；
- 不强调失败；
- 不把“连续断签”作为惩罚；
- 用户吃多后，提示“温和调整”，而不是“补偿性运动”。

### Ability 能力

产品要把所有行为拆到足够简单。

设计要求：

- 不要求称重；
- 不要求计算；
- 不要求每天记录三餐；
- 不要求每天运动；
- 默认只给 1-3 个小任务；
- 用户失败时自动降低任务难度。

### Prompt 提示

系统必须在正确时间提醒用户。

设计要求：

- 餐前提醒；
- 睡前提醒；
- 连续未记录提醒；
- 低活跃提醒；
- 聚餐/外卖/周末等场景提醒；
- 所有提醒文案温和，不催促、不批评。

---

# 4. App 信息架构

App 使用 5 个主 Tab。

```text
Today    今日执行中心
Scan     拍照分析
Habit    习惯系统
Progress 进展复盘
Me       我的
```

---

# 5. Tab 1：Today 今日执行中心

## 5.1 页面目标

Today 是用户每天打开 App 的第一屏。

只回答一个问题：

```text
今天我该做什么？
```

## 5.2 页面内容

首页首屏最多展示：

1. 今日状态文案；
2. 今日完成度；
3. 今日 1-3 个关键任务；
4. 拍照主按钮；
5. 温和鼓励反馈。

## 5.3 首页结构示例

```text
早上好，今天先完成一个小动作。

今日完成度
2 / 3

今日任务
✅ 午餐前拍一下
⬜ 晚餐主食少一点
⬜ 睡前看一次总结

[ 拍一下这餐 ]

不用完美，完成一点就算前进。
```

## 5.4 Today 不应出现

- 大量图表；
- 大量热量数字；
- 大量营养成分；
- 红色警告；
- 失败提示；
- 排行榜；
- 连续断签惩罚；
- 十几张卡片。

## 5.5 Today 页面组件建议

### SwiftUI 组件

```swift
TodayView
 ├── TodayHeaderView
 ├── DailyCompletionCard
 ├── TodayTaskListView
 ├── PrimaryScanButton
 └── GentleFeedbackView
```

---

# 6. Tab 2：Scan 拍照分析

## 6.1 页面目标

Scan 的目标不是单纯识别食物，而是回答：

```text
这顿怎么吃？
```

## 6.2 用户流程

```text
打开 Scan
↓
拍照 / 从相册选择
↓
AI 识别食物
↓
结合用户档案、今日任务、剩余额度
↓
输出吃法建议
↓
用户修正
↓
一键保存
↓
系统庆祝反馈
```

## 6.3 普通用户输出格式

默认不要展示大量专业数据。

示例：

```text
这顿可以吃。

建议：
1. 米饭留三分之一；
2. 肉和蔬菜正常吃；
3. 饮料换成无糖，或者少喝一点。

保存后，今天午餐任务就完成了。
```

## 6.4 进阶数据展示

用户点击“查看详细数据”后再展示：

```text
估算热量：约 650 kcal
蛋白质：32g
碳水：78g
脂肪：22g
```

## 6.5 Scan 页面组件建议

```swift
ScanView
 ├── CameraEntryView
 ├── FoodImagePreview
 ├── AnalysisLoadingView
 ├── FoodAdviceResultView
 ├── NutritionDetailDisclosureView
 ├── FoodCorrectionView
 └── SaveMealButton
```

---

# 7. Tab 3：Habit 习惯系统

## 7.1 页面目标

Habit 页面回答：

```text
我正在养成哪些减脂习惯？
```

## 7.2 微习惯结构

每个习惯必须包含：

```text
锚点 Anchor
行为 Tiny Behavior
庆祝 Celebration
```

## 7.3 习惯数据示例

```json
{
  "id": "habit_lunch_photo",
  "title": "午餐前拍一下",
  "anchor": "打开午餐或外卖包装后",
  "tinyBehavior": "拍一张食物照片",
  "celebration": "你完成了今天最关键的一步",
  "difficulty": 1,
  "frequency": "daily",
  "isActive": true
}
```

## 7.4 V1 默认习惯

新用户第一周最多 3 个习惯：

1. 午餐前拍一下；
2. 晚餐主食少一点；
3. 睡前看一次总结。

## 7.5 习惯难度自动调节

触发条件：

- 连续 2 天未完成；
- 连续 3 天未打开 App；
- 用户多次跳过同一任务；
- 用户反馈“太难”。

处理方式：

```text
不要批评用户。
把任务变得更简单。
```

示例：

```text
原任务：每天记录三餐
降低为：每天只拍一餐

原任务：每天走 8000 步
降低为：晚饭后走 5 分钟

原任务：晚餐不吃主食
降低为：晚餐主食少三分之一
```

## 7.6 Habit 页面组件建议

```swift
HabitView
 ├── HabitIntroCard
 ├── ActiveHabitListView
 ├── HabitCard
 ├── HabitDifficultyAdjustSheet
 └── HabitCompletionHistoryView
```

---

# 8. Tab 4：Progress 进展复盘

## 8.1 页面目标

Progress 页面回答：

```text
我是不是在变好？
```

不只看体重，而是看行为进步。

## 8.2 展示内容

优先展示：

- 本周完成的小任务数量；
- 连续记录天数；
- 任务完成率；
- 体重趋势；
- 最稳定的习惯；
- 最大阻碍场景；
- 下周一个重点。

## 8.3 周复盘结构

示例：

```text
本周你完成了 12 次小任务。

最稳定的习惯：
午餐前拍照。

最大阻碍：
晚餐后的零食。

下周只改一件事：
零食前先喝一杯水，然后等 5 分钟。
```

## 8.4 Progress 页面组件建议

```swift
ProgressView
 ├── WeeklySummaryCard
 ├── HabitCompletionChart
 ├── WeightTrendCard
 ├── KeyBehaviorInsightCard
 └── NextWeekFocusCard
```

---

# 9. Tab 5：Me 我的

## 9.1 页面内容

包含：

- 用户资料；
- 目标设置；
- 饮食偏好；
- 提醒设置；
- 账号；
- 订阅；
- 隐私；
- 数据导出；
- 删除账号。

## 9.2 Me 页面组件建议

```swift
MeView
 ├── ProfileSummaryCard
 ├── GoalSettingsEntry
 ├── PreferenceSettingsEntry
 ├── ReminderSettingsEntry
 ├── SubscriptionEntry
 ├── PrivacySettingsEntry
 └── AccountSettingsEntry
```

---

# 10. 首次使用流程 Onboarding

## 10.1 设计目标

不要使用复杂表单。

采用 AI 对话式建档。

## 10.2 建档流程

```text
选择语言
↓
游客模式进入
↓
AI 对话建档
↓
生成第一周计划
↓
进入 Today
```

## 10.3 AI 对话问题

AI 需要收集：

- 身高；
- 体重；
- 目标体重；
- 减脂目标；
- 饮食场景；
- 运动习惯；
- 作息；
- 最容易失败的场景；
- 是否接受提醒；
- 是否有健康风险。

## 10.4 建档输出

AI 输出：

```json
{
  "userProfile": {},
  "goal": {},
  "firstWeekFocus": "先稳定记录，不追求完美",
  "dailyTasks": [],
  "habits": [],
  "riskFlags": []
}
```

---

# 11. AI 功能设计

## 11.1 AI 能力分层

V1 包含四类 AI 能力：

```text
AI建档
AI拍照饮食建议
AI教练
AI周复盘
```

## 11.2 AI 建档

输入：

- 用户自然语言；
- 系统追问；
- 用户选择项。

输出：

- 用户档案；
- 减脂目标；
- 第一周任务；
- 微习惯；
- 风险提醒。

## 11.3 AI 拍照建议

输入：

- 食物图片；
- 当前时间；
- 用户档案；
- 今日任务；
- 今日已记录；
- 当前习惯；
- 目标热量；
- 用户偏好。

输出：

```json
{
  "summary": "这顿可以吃，但建议主食少一点。",
  "foodItems": [
    {
      "name": "米饭",
      "estimatedCalories": 260,
      "portion": "1碗",
      "confidence": 0.78
    }
  ],
  "totalCalories": 650,
  "macros": {
    "protein": 32,
    "carbs": 78,
    "fat": 22
  },
  "plainAdvice": [
    "米饭留三分之一",
    "肉和蔬菜正常吃",
    "饮料少喝一点"
  ],
  "taskCompletionImpact": "保存后完成午餐任务",
  "celebration": "你完成了今天最关键的一步",
  "riskFlags": []
}
```

## 11.4 AI 教练

AI 教练不是百科，而是行为支持。

支持问题：

- 今天吃多了怎么办；
- 没坚持住怎么办；
- 晚上想吃零食怎么办；
- 聚餐怎么办；
- 外卖怎么选；
- 明天任务能不能简单一点。

禁止输出：

- 极端节食；
- 催吐；
- 泻药；
- 惩罚性运动；
- 羞辱性语言；
- 医疗诊断；
- 快速瘦身承诺。

## 11.5 AI 周复盘

输入：

- 一周任务完成情况；
- 体重趋势；
- 饮食记录；
- 用户跳过任务情况；
- 最常失败场景。

输出：

- 本周完成了什么；
- 最有效行为；
- 最大阻碍；
- 下周只改一件事；
- 是否调整任务难度。

---

# 12. 数据模型设计

## 12.1 UserProfile

```swift
struct UserProfile: Identifiable, Codable {
    let id: UUID
    var gender: Gender?
    var birthYear: Int?
    var heightCm: Double?
    var currentWeightKg: Double?
    var targetWeightKg: Double?
    var activityLevel: ActivityLevel
    var dietScenes: [DietScene]
    var failureScenes: [FailureScene]
    var preferences: DietPreferences
    var createdAt: Date
    var updatedAt: Date
}
```

## 12.2 Goal

```swift
struct Goal: Identifiable, Codable {
    let id: UUID
    var type: GoalType
    var targetWeightKg: Double?
    var targetDate: Date?
    var weeklyPace: WeeklyPace
    var currentPhase: GoalPhase
}
```

## 12.3 Habit

```swift
struct Habit: Identifiable, Codable {
    let id: UUID
    var title: String
    var anchor: String
    var tinyBehavior: String
    var celebration: String
    var difficulty: Int
    var frequency: HabitFrequency
    var isActive: Bool
    var createdAt: Date
}
```

## 12.4 DailyTask

```swift
struct DailyTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var habitId: UUID?
    var taskType: DailyTaskType
    var status: TaskStatus
    var scheduledTime: Date?
    var completedAt: Date?
    var difficulty: Int
}
```

## 12.5 MealRecord

```swift
struct MealRecord: Identifiable, Codable {
    let id: UUID
    var mealType: MealType
    var imageURL: URL?
    var foodItems: [FoodItem]
    var estimatedCalories: Double
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var userCorrection: String?
    var createdAt: Date
}
```

## 12.6 WeeklyReview

```swift
struct WeeklyReview: Identifiable, Codable {
    let id: UUID
    var weekStartDate: Date
    var completedTaskCount: Int
    var taskCompletionRate: Double
    var strongestHabit: String?
    var biggestObstacle: String?
    var nextWeekFocus: String
    var aiSummary: String
}
```

---

# 13. 通知设计

## 13.1 通知原则

通知是行为提示，不是催促。

禁止文案：

```text
你还没打卡
今天又没记录
再不减就晚了
你已经落后了
```

推荐文案：

```text
午餐前拍一下就好。
今天只需要完成一个小动作。
睡前30秒，看一下今天完成了什么。
今晚可能有聚餐，要不要提前生成一个轻松策略？
```

## 13.2 通知类型

```swift
enum ReminderType {
    case mealBefore
    case sleepBefore
    case lowActivity
    case weeklyReview
    case sceneBased
}
```

---

# 14. UI 设计规范

## 14.1 视觉关键词

```text
克制
简约
高级
安静
清晰
温和
低压力
```

## 14.2 参考气质

接近：

- Apple Health 的清晰；
- Gentler Streak 的温和；
- Notion 的留白；
- 高级日记 App 的安静。

不要做成：

- 健身房风格；
- 小红书风格；
- 游戏化打卡风格；
- 红绿警告仪表盘；
- 复杂数据面板；
- 过度 Liquid Glass；
- 软糖风；
- 新拟态。

## 14.3 页面设计原则

每个页面只解决一个核心问题：

```text
Today：今天该做什么
Scan：这顿怎么吃
Habit：我正在养成什么习惯
Progress：我是否在变好
Me：我的设置和资料
```

## 14.4 信息密度

首页首屏最多展示：

- 一句话状态；
- 一个完成度；
- 三个任务；
- 一个主按钮；
- 一句温和反馈。

## 14.5 色彩规范

建议：

```text
主色：低饱和绿色
辅助色：暖灰、米白、浅蓝灰
风险色：柔和橙色
背景：接近 iOS 系统背景
```

禁止：

- 高饱和绿色；
- 高饱和蓝色；
- 高饱和红色；
- 大面积渐变；
- 大面积玻璃背景；
- 强警告色。

## 14.6 Liquid Glass 使用原则

只用于：

- Tab Bar；
- Floating Button；
- Bottom Sheet；
- Sheet 弹层。

不要用于：

- 正文长文本背景；
- 大面积数据区域；
- 图表背景；
- 任务卡片主体。

## 14.7 字体

使用系统字体：

```text
SF Pro
系统 Dynamic Type
```

要求：

- 大数字少量使用；
- 正文可读性优先；
- 按钮文字不截断；
- 中文和英文都要适配。

## 14.8 动效

要求：

- 快；
- 轻；
- 克制；
- 有反馈但不炫技；
- 支持 Reduce Motion。

---

# 15. 商业化设计

## 15.1 免费版

包含：

- AI 建档；
- 每日基础任务；
- 每日 3 次拍照分析；
- 基础记录；
- 基础趋势。

## 15.2 Pro 版

包含：

- 无限拍照分析；
- AI 教练；
- AI 周复盘；
- 个性化习惯调整；
- Apple Health 同步；
- 高级趋势分析；
- 多场景策略。

## 15.3 付费触发点

推荐触发：

- 免费拍照次数用完；
- 用户想查看 AI 周复盘；
- 用户想使用 AI 教练深度调整；
- 用户连续使用 3 天后；
- 用户完成首次建档后，但不要强拦截。

---

# 16. MVP 开发范围

## 16.1 必须开发

```text
1. iOS 原生基础架构
2. 5 Tab 主导航
3. 游客模式
4. AI 对话建档
5. Today 今日任务
6. Scan 拍照分析
7. Habit 微习惯系统
8. 基础记录
9. Progress 基础进展
10. AI 周复盘
11. Me 设置
12. 账号系统
13. 订阅系统
14. 通知系统
15. 隐私与删除数据
```

## 16.2 暂缓开发

```text
1. Apple Watch
2. Widget
3. 社区
4. 排行榜
5. 高级训练计划
6. 专业饮食方案库
7. 餐厅菜单 OCR
8. 社交分享
9. 家庭成员管理
```

---

# 17. 推荐开发顺序

## Phase 1：产品骨架

```text
1. SwiftUI 项目结构
2. 5 Tab 导航
3. 数据模型
4. 本地存储
5. Today 静态页面
6. Habit 静态页面
```

## Phase 2：核心闭环

```text
1. AI 建档
2. 生成每日任务
3. 完成任务
4. 任务庆祝反馈
5. 任务难度调整
```

## Phase 3：拍照记录

```text
1. 相机 / 相册
2. 图片上传
3. AI 食物分析
4. 展示建议
5. 用户修正
6. 保存记录
```

## Phase 4：复盘与商业化

```text
1. Progress 页面
2. 周复盘
3. 账号登录
4. 订阅
5. 通知
```

---

# 18. 验收标准

## 18.1 产品验收

```text
用户 3 分钟内完成建档
用户打开首页 3 秒内知道今天该做什么
用户 10 秒内进入拍照
用户拍照后可以一键保存
用户失败后系统可以降低任务难度
每个任务都有锚点、行为、庆祝
```

## 18.2 UI 验收

```text
首页无复杂图表
首页不超过 3 个任务
首页只有 1 个主操作按钮
无高饱和警告色
无羞辱性文案
留白充足
视觉克制
字体清晰
支持深色模式
支持 Dynamic Type
支持 Reduce Motion
```

## 18.3 AI 验收

```text
AI 输出必须结构化
AI 不输出极端节食建议
AI 不输出惩罚性运动建议
AI 不进行医疗诊断
AI 建议必须温和、具体、可执行
AI 建议必须结合用户当前任务和目标
```

---

# 19. Codex 执行要求

请按以下原则实现：

1. 优先实现产品核心闭环，不要先做复杂 UI 装饰；
2. 每个页面保持低信息密度；
3. 所有数据模型先本地可运行；
4. AI 接口可以先 Mock，后续替换为真实服务端；
5. Today 页面是最高优先级；
6. Scan 页面是核心增长功能；
7. Habit 页面是留存核心；
8. Progress 页面只做基础趋势，不做复杂分析；
9. UI 风格必须克制、简约、高级；
10. 所有文案必须温和，不制造焦虑。

---

# 20. 最小可运行 Demo 要求

第一个可运行版本至少包含：

```text
1. App 启动
2. 5 Tab 导航
3. Today 展示 3 个任务
4. 用户可以完成任务
5. 完成后出现庆祝反馈
6. Habit 页面展示习惯
7. Scan 页面支持选择图片并展示 Mock 分析结果
8. Progress 页面展示本周完成率
9. Me 页面展示用户资料入口
```

---

# 21. 总结

轻减AI V4.1 的核心不是“识别食物热量”，而是：

```text
用 AI + 微习惯 + 行为提示 + 正向反馈，帮助普通人真的坚持下去。
```

开发时请始终围绕这个核心闭环：

```text
AI 建档
↓
生成微习惯
↓
Today 给出今日任务
↓
用户完成一个小动作
↓
系统立即庆祝
↓
记录进入趋势
↓
AI 每周复盘
↓
系统降低或提高任务难度
↓
用户形成长期习惯
```
