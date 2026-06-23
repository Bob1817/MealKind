# 03 工程级文档：Strategy Engine 决策树与算法规则

版本：V2.0 Engineering  
适用对象：Codex / Claude Code / Cursor / 后端规则引擎 / iOS  
产品：轻减AI / Qingjian AI / AI Body OS

---

## 0. Strategy Engine 目标

Strategy Engine 是 AI Body OS 的核心价值层。

它负责把用户当前状态转换为：

```text
今日饮食策略
今日训练策略
今日恢复策略
今日补剂策略
```

它不负责聊天，不负责生成花哨文案。  
它只负责稳定、可测试、可解释的规则决策。

AI Layer 只负责把策略翻译成人话。

---

## 1. 输入

```json
{
  "userMode": "lifestyle | advanced",
  "profile": {},
  "goal": {},
  "state": {},
  "cycle": {},
  "nutritionTarget": {},
  "dailySummary": {},
  "recoveryScore": {},
  "events": []
}
```

---

## 2. 输出

```json
{
  "localDate": "2026-06-17",
  "strategies": [
    {
      "type": "nutrition",
      "priority": 90,
      "title": "保持温和热量缺口",
      "actions": [
        {
          "code": "reduce_dinner_carbs",
          "label": "晚餐主食减少三分之一",
          "reason": "午餐热量偏高，需要保持今日缺口。"
        }
      ]
    }
  ]
}
```

---

## 3. 普通用户策略总原则

普通用户目标：

```text
持续保持热量缺口，但不制造焦虑，不要求完美。
```

### 普通用户策略优先级

```text
1. 安全
2. 不崩溃
3. 保持轻微热量缺口
4. 建立简单行为
5. 减少高热量误判
```

### 普通用户不要输出

- 具体 TDEE；
- 复杂宏量营养；
- 惩罚性运动；
- “你超标了”；
- “失败”；
- 大量专业术语。

---

## 4. 进阶用户策略总原则

进阶用户目标：

```text
减脂时尽量保留肌肉，不明显涨脂，维持训练表现与恢复。
```

### 进阶用户策略优先级

```text
1. 蛋白质达标
2. 控制总热量
3. 根据训练日动态调整碳水
4. 控制脂肪不过量
5. 保障睡眠与恢复
6. 补剂执行稳定
```

---

## 5. 热量目标算法

### 5.1 基础计算

```text
BMR = Mifflin-St Jeor
TDEE = BMR × ActivityFactor + ExerciseCalories
TargetCalories = TDEE - Deficit
```

### 5.2 普通用户缺口

```text
默认缺口：300-500 kcal
最大建议缺口：不超过 700 kcal
低恢复/出差/压力高：降低缺口到 200-300 kcal
```

### 5.3 进阶用户缺口

```text
训练日缺口：300-500 kcal
休息日缺口：400-600 kcal
高消耗日：缺口不超过 500 kcal
低恢复日：缺口不超过 300 kcal
停训期：缺口 300-500 kcal，蛋白保持
```

---

## 6. 宏量营养算法

### 6.1 蛋白质

```text
普通用户：1.2-1.6 g/kg
进阶用户减脂期：1.8-2.2 g/kg
进阶用户停训/受伤：保持 1.8-2.2 g/kg
```

### 6.2 脂肪

```text
普通用户：不前台展示，内部控制
进阶用户：0.6-0.9 g/kg
```

### 6.3 碳水

```text
Carbs = (TargetCalories - ProteinCalories - FatCalories) / 4
```

训练日：

```text
提高碳水
```

休息日：

```text
降低碳水
```

停训/受伤：

```text
降低碳水，维持蛋白
```

高消耗日：

```text
增加碳水，避免恢复受损
```

---

## 7. 决策树：普通用户

### 7.1 正常日

条件：

```text
lifeState = normal
trainingState != injured
recoveryState != critical
```

策略：

```json
[
  "拍一餐",
  "晚餐主食少一点",
  "避免含糖饮料"
]
```

### 7.2 聚餐日

条件：

```text
partyMode = true
```

策略：

聚餐前：

```text
不要空腹太久
先吃蛋白质
饮料尽量无糖
```

聚餐后：

```text
不补偿性节食
第二天恢复正常
未来两餐主食略少
```

### 7.3 出差日

条件：

```text
travelMode = true
```

策略：

```text
降低记录要求
优先记录一餐
优先蛋白质
主食不过量
```

### 7.4 高热量已发生

条件：

```text
caloriesIn > targetCalories + 300
```

策略：

```text
不要判定失败
后续一餐减少主食
明天恢复计划
```

### 7.5 连续未记录

条件：

```text
no meal records for >= 2 days
```

策略：

```text
任务降低为：今天只拍一餐
```

---

## 8. 决策树：进阶用户

### 8.1 正常训练日

条件：

```text
userMode = advanced
trainingState = normal_training
```

策略：

```text
蛋白质必须达标
训练前后碳水优先
脂肪不要占用过多热量
补剂按计划执行
睡眠目标 >= 7h
```

输出示例：

```json
{
  "type": "nutrition",
  "title": "训练日营养策略",
  "actions": [
    "蛋白质达到 160g",
    "训练后补充 60-80g 碳水",
    "脂肪控制在 55g 内"
  ]
}
```

### 8.2 休息日

条件：

```text
trainingState = rest_day
```

策略：

```text
蛋白保持
碳水下调
脂肪可略高但不超过目标
保持饮水
```

### 8.3 停训

条件：

```text
trainingState = stopped
```

策略：

```text
维持蛋白
降低碳水
保持轻微缺口
不建议极端节食
```

### 8.4 受伤

条件：

```text
trainingState = injured
```

策略：

```text
暂停相关部位训练
蛋白保持
热量缺口降低
睡眠和恢复优先
补剂保持
```

### 8.5 高消耗日

条件：

```text
exerciseCalories > 1000
```

策略：

```text
增加碳水
保证蛋白
补水和电解质
避免过大热量缺口
```

### 8.6 低恢复

条件：

```text
recoveryScore < 60
```

策略：

```text
降低训练强度
不扩大热量缺口
优先睡眠
减少高强度有氧
```

---

## 9. 特殊事件算法

### 9.1 聚餐补偿算法

禁止：

```text
第二天极端节食
额外惩罚性运动
```

允许：

```text
未来 2-3 餐每餐减少 100-200 kcal
优先减少主食/油脂
蛋白质保持
```

### 9.2 停训算法

```text
NewCalories = OriginalCalories - TrainingDayCarbCalories
Protein unchanged
Fat moderate
Carbs reduced
```

### 9.3 高消耗算法

```text
If ExerciseCalories > 1000:
  AddBackCalories = min(ExerciseCalories * 0.4, 800)
  Prefer carbs
  Maintain deficit <= 500
```

### 9.4 低恢复算法

```text
If RecoveryScore < 60:
  Deficit = min(Deficit, 300)
  TrainingIntensity = reduce
  Add recovery task
```

---

## 10. Strategy Engine 伪代码

```swift
func generateTodayStrategy(input: StrategyInput) -> TodayStrategy {
    var strategies: [Strategy] = []

    if input.state.trainingState == .injured {
        strategies.append(injuryNutritionStrategy(input))
        strategies.append(injuryRecoveryStrategy(input))
        return TodayStrategy(strategies: strategies)
    }

    if input.state.recoveryState == .critical {
        strategies.append(criticalRecoveryStrategy(input))
        return TodayStrategy(strategies: strategies)
    }

    if input.userMode == .lifestyle {
        strategies += generateLifestyleStrategies(input)
    } else {
        strategies += generateAdvancedStrategies(input)
    }

    if input.state.partyMode {
        strategies.append(partyStrategy(input))
    }

    if input.state.highExpenditureMode {
        strategies.append(highExpenditureStrategy(input))
    }

    return TodayStrategy(strategies: strategies.sortedByPriority())
}
```

---

## 11. AI 解释层输入

Strategy Engine 输出给 AI：

```json
{
  "userMode": "advanced",
  "currentStateSummary": "减脂期第4周，训练日，恢复良好",
  "calculatedTargets": {
    "calories": 2200,
    "protein": 160,
    "carbs": 220,
    "fat": 55
  },
  "currentProgress": {
    "calories": 1650,
    "protein": 120,
    "carbs": 150,
    "fat": 45
  },
  "strategyCodes": [
    "maintain_protein",
    "add_post_workout_carbs",
    "control_fat"
  ]
}
```

AI 输出：

```text
今天还差 40g 蛋白质，可以睡前补一份乳清或 200g 鸡胸肉。碳水还可以补一根香蕉或一小碗米饭，脂肪已经接近目标，晚餐尽量少油。
```

---

## 12. 单元测试要求

必须覆盖：

1. 普通用户正常日策略。
2. 普通用户聚餐策略。
3. 普通用户超标后温和调整。
4. 进阶用户训练日宏量建议。
5. 进阶用户休息日碳水下调。
6. 进阶用户停训维持蛋白。
7. 进阶用户受伤优先恢复。
8. 高消耗日增加碳水。
9. 低恢复日降低训练强度。
10. AI 输入 JSON 不包含未计算字段。