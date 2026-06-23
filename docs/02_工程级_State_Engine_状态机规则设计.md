# 02 工程级文档：State Engine 状态机规则设计

版本：V2.0 Engineering  
适用对象：Codex / Claude Code / Cursor / iOS / 后端规则引擎  
产品：轻减AI / Qingjian AI / AI Body OS

---

## 0. 状态引擎目标

State Engine 是 AI Body OS 的核心底座。

它的职责不是展示数据，而是判断：

```text
用户今天处于什么身体状态？
用户今天适合执行什么策略？
哪些状态优先级最高？
是否需要覆盖原本训练或饮食计划？
```

---

## 1. 输入来源

State Engine 接收以下输入：

```text
User Profile
Goal
Cycle
Workout Record
Sleep Record
Recovery Score
Meal Record
Water Record
Supplement Record
Manual Event
HealthKit Data
AI Parsed Event
```

---

## 2. 状态分类

### 2.1 Goal State

```swift
enum GoalState {
    case fatLoss
    case maintenance
    case muscleGain
    case recovery
}
```

### 2.2 Training State

```swift
enum TrainingState {
    case normalTraining
    case restDay
    case deload
    case stopped
    case injured
    case returning
}
```

### 2.3 Life State

```swift
enum LifeState {
    case normal
    case travel
    case businessTrip
    case party
    case holiday
    case highStress
}
```

### 2.4 Recovery State

```swift
enum RecoveryState {
    case good
    case moderate
    case low
    case critical
}
```

### 2.5 User Mode

```swift
enum UserMode {
    case lifestyle
    case advanced
}
```

---

## 3. 状态优先级

当多个状态同时出现时，按以下优先级覆盖：

```text
1. Injury
2. Critical Recovery
3. Illness / Recovery
4. Travel / Business Trip
5. Party / Social Meal
6. High Expenditure Day
7. Planned Training Day
8. Planned Rest Day
9. Normal
```

示例：

用户今天本来是腿部训练日，但标记腿部受伤。

输出：

```text
TrainingState = injured
LifeState = normal
Strategy should ignore planned leg training
```

---

## 4. 状态输入事件

### 4.1 Manual Event

用户主动标记：

```json
{
  "eventType": "injury",
  "title": "膝盖不适",
  "durationDays": 7,
  "affectedBodyParts": ["knee", "leg"],
  "severity": "moderate"
}
```

### 4.2 Health Event

来自 Apple Health / Apple Watch：

```json
{
  "eventType": "high_expenditure",
  "activeEnergyBurned": 1800,
  "workoutDuration": 180
}
```

### 4.3 AI Parsed Event

用户对 AI 说：

```text
今天出差，晚上还有聚餐，没法训练。
```

AI 解析为：

```json
{
  "travelMode": true,
  "partyMode": true,
  "trainingStatus": "stopped",
  "duration": "today"
}
```

---

## 5. 状态机转移规则

### 5.1 Normal Training → Injured

触发：

- 用户手动标记受伤；
- AI 从对话识别受伤；
- 连续多次记录疼痛；
- 某部位训练后疲劳异常。

输出：

```json
{
  "trainingStatus": "injured",
  "injuryMode": true,
  "statePriority": 100
}
```

策略影响：

- 禁止推荐高强度训练；
- 保持蛋白质；
- 降低碳水；
- 热量从减脂缺口调整为温和缺口；
- 推荐恢复、睡眠、补剂、拉伸。

---

### 5.2 Injured → Returning

触发：

- 用户手动关闭受伤；
- 受伤预计持续时间结束；
- 用户连续 2 天无疼痛反馈。

输出：

```json
{
  "trainingStatus": "returning",
  "injuryMode": false,
  "statePriority": 70
}
```

策略影响：

- 不立即恢复原训练强度；
- 前 3 天采用 50%-70% 强度；
- 控制训练容量；
- 保持蛋白质。

---

### 5.3 Returning → Normal Training

触发：

- returning 状态持续 3-7 天；
- 用户无疼痛反馈；
- Recovery Score >= 70。

输出：

```json
{
  "trainingStatus": "normal_training",
  "statePriority": 10
}
```

---

### 5.4 Planned Training → Stopped

触发：

- 用户标记停训；
- 出差；
- 生病；
- 连续 3 天未完成训练；
- 用户手动设置“本周无法训练”。

策略影响：

- 降低碳水；
- 维持蛋白质；
- 减脂用户保持轻微缺口；
- 进阶用户避免过低热量导致肌肉流失。

---

### 5.5 Normal → Travel

触发：

- 用户手动开启出差模式；
- AI 解析用户输入；
- 地理位置/时区大幅变化。

策略影响：

普通用户：

```text
保持记录最低要求。
不强制完美饮食。
只保证热量缺口不失控。
```

进阶用户：

```text
蛋白质优先。
碳水按活动量动态调整。
训练缺失时降低训练日碳水。
```

---

### 5.6 Normal → Party

触发：

- 用户标记聚餐；
- AI 解析“今晚聚餐/火锅/烧烤/酒局”。

策略影响：

普通用户：

```text
聚餐前不要饿太久。
聚餐时优先蛋白质和蔬菜。
第二天温和调整，不惩罚性节食。
```

进阶用户：

```text
聚餐前预留热量。
优先保证蛋白。
控制脂肪与酒精。
第二天恢复原计划。
```

---

### 5.7 Recovery Good → Recovery Low

触发：

- 睡眠 < 6 小时；
- Recovery Score < 60；
- 疲劳评分 >= 8；
- 连续训练 >= 4 天；
- 静息心率明显升高。

策略影响：

- 降低训练强度；
- 增加恢复任务；
- 不建议继续扩大热量缺口；
- 保证蛋白质与水分。

---

## 6. 状态计算伪代码

```swift
func resolveBodyState(input: StateInput) -> BodyState {
    var state = BodyState.default()

    state.goalState = input.activeGoal.type
    state.trainingState = input.cycle.todayTrainingState
    state.lifeState = .normal

    if input.manualEvents.contains(.injury) {
        state.trainingState = .injured
        state.injuryMode = true
        state.priority = 100
        return state
    }

    if input.recoveryScore < 40 {
        state.recoveryState = .critical
        state.priority = 90
        return state
    }

    if input.manualEvents.contains(.travel) {
        state.lifeState = .travel
        state.priority = max(state.priority, 70)
    }

    if input.manualEvents.contains(.party) {
        state.lifeState = .party
        state.partyMode = true
        state.priority = max(state.priority, 60)
    }

    if input.exerciseCalories > 1200 {
        state.highExpenditureMode = true
        state.priority = max(state.priority, 55)
    }

    if input.recoveryScore < 60 {
        state.recoveryState = .low
        state.priority = max(state.priority, 50)
    }

    return state
}
```

---

## 7. 普通用户与进阶用户差异

### 7.1 普通用户

状态输出要翻译成低压力语言：

```text
今天属于外出日，目标不是完美控制，只要避免明显超标。
```

不要展示：

- 复杂状态机；
- recovery score 细节；
- 碳水调整公式。

### 7.2 进阶用户

状态输出要精确：

```text
当前：减脂期第4周 / 训练日 / 恢复指数82 / 今日碳水目标220g
```

可展示：

- 训练状态；
- 恢复状态；
- 宏量营养目标；
- 周期信息；
- 今日策略原因。

---

## 8. 状态冲突处理

### 8.1 Injury + Training Day

受伤优先。

输出 injured。

### 8.2 Travel + Party

合并为 travel_with_party。

策略：

```text
降低记录要求，重点控制聚餐热量与蛋白质。
```

### 8.3 High Expenditure + Fat Loss

不要继续压低热量。

策略：

```text
补充碳水和蛋白，保持合理缺口。
```

### 8.4 Low Recovery + Training Day

恢复优先。

策略：

```text
降低训练强度或改为休息。
```

---

## 9. State Engine 输出 JSON

```json
{
  "userMode": "advanced",
  "localDate": "2026-06-17",
  "goalState": "fat_loss",
  "trainingState": "normal_training",
  "lifeState": "normal",
  "recoveryState": "good",
  "injuryMode": false,
  "travelMode": false,
  "partyMode": false,
  "highExpenditureMode": false,
  "priority": 10,
  "stateSummary": "减脂期第4周，正常训练日，恢复状态良好。",
  "strategyHints": [
    "maintain_protein",
    "training_day_carbs",
    "normal_deficit"
  ]
}
```

---

## 10. 单元测试要求

必须覆盖：

1. 训练日 + 受伤 → injured。
2. 训练日 + 低恢复 → low recovery strategy。
3. 出差 + 聚餐 → travel party combined。
4. 高消耗日 → 增加碳水建议。
5. 停训 → 降低碳水，维持蛋白。
6. 普通用户状态文案低压力。
7. 进阶用户状态文案精确。