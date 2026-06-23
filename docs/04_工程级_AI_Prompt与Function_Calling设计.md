# 04 工程级文档：AI Prompt 与 Function Calling 设计

版本：V2.0 Engineering  
适用对象：Codex / Claude Code / Cursor / OpenAI Responses API / Claude Tool Use  
产品：轻减AI / Qingjian AI / AI Body OS

---

## 0. AI 职责边界

AI 在本系统中不是计算引擎。

AI 不负责：

- 计算 BMR/TDEE；
- 计算目标热量；
- 判断状态优先级；
- 生成最终策略规则；
- 给出医疗诊断；
- 推荐极端节食；
- 推荐惩罚性运动。

AI 负责：

- 对话建档；
- 解析用户自然语言事件；
- 食物图片识别；
- 将引擎结果翻译成用户能理解的建议；
- 生成温和、具体、低压力文案；
- 生成周复盘解释；
- 识别高风险表达并触发安全提醒。

---

## 1. AI 调用类型

```text
1. onboarding_profile_extraction
2. natural_language_event_parser
3. food_vision_analysis
4. strategy_explanation
5. weekly_review_generation
6. safety_classification
```

---

## 2. 通用 System Prompt

```text
你是轻减AI的身体管理助手。你必须遵循以下原则：

1. 不制造身材焦虑。
2. 不使用羞辱性语言。
3. 不鼓励极端节食、催吐、滥用泻药、惩罚性运动。
4. 不提供医疗诊断。
5. 对普通用户使用简单、温和、可执行的语言。
6. 对进阶用户可以提供宏量营养、训练、恢复相关建议，但必须基于系统提供的计算结果。
7. 你不负责重新计算热量和宏量营养，只能解释系统传入的数据。
8. 如果用户表达受伤、疾病、饮食障碍、自伤等高风险内容，应给出安全提醒，并建议寻求专业帮助。
9. 输出必须符合调用要求的 JSON Schema。
```

---

## 3. AI 建档 Prompt

### 3.1 目标

从自然语言对话中提取用户基础资料、目标、失败场景、饮食场景、用户模式。

### 3.2 输入

```json
{
  "messages": [
    {"role": "user", "content": "我想减肥，但是不想太麻烦，平时主要吃食堂。"}
  ]
}
```

### 3.3 输出 Schema

```json
{
  "type": "object",
  "required": ["profileDraft", "goalDraft", "userMode", "missingFields", "riskFlags"],
  "properties": {
    "profileDraft": {
      "type": "object",
      "properties": {
        "heightCm": {"type": ["number", "null"]},
        "currentWeightKg": {"type": ["number", "null"]},
        "targetWeightKg": {"type": ["number", "null"]},
        "activityLevel": {"type": ["string", "null"]},
        "dietScenes": {"type": "array", "items": {"type": "string"}},
        "failureScenes": {"type": "array", "items": {"type": "string"}}
      }
    },
    "goalDraft": {
      "type": "object",
      "properties": {
        "goalType": {"type": "string"},
        "targetPace": {"type": ["string", "null"]}
      }
    },
    "userMode": {
      "type": "string",
      "enum": ["lifestyle", "advanced"]
    },
    "missingFields": {
      "type": "array",
      "items": {"type": "string"}
    },
    "riskFlags": {
      "type": "array",
      "items": {"type": "string"}
    },
    "nextQuestion": {
      "type": "string"
    }
  }
}
```

### 3.4 Prompt Template

```text
请从用户对话中提取轻减AI建档信息。

不要编造用户没有提供的信息。
缺失字段放入 missingFields。
如果用户表达极端节食、催吐、过度运动、严重焦虑，写入 riskFlags。
判断用户模式：
- lifestyle：怕麻烦、不想学习、普通减脂、生活化减脂。
- advanced：规律训练、关注蛋白质/碳水/脂肪、周期训练、保肌减脂。

用户对话：
{{messages}}
```

---

## 4. 自然语言事件解析

### 4.1 目标

将用户输入转换为 State Engine 可识别事件。

用户示例：

```text
今天出差，晚上有聚餐，没法练了。
```

### 4.2 输出

```json
{
  "events": [
    {
      "eventType": "business_trip",
      "duration": "today",
      "confidence": 0.92
    },
    {
      "eventType": "party",
      "duration": "tonight",
      "confidence": 0.9
    },
    {
      "eventType": "training_stopped",
      "duration": "today",
      "confidence": 0.88
    }
  ],
  "statePatch": {
    "lifeStatus": "business_trip",
    "partyMode": true,
    "trainingStatus": "stopped"
  },
  "safetyFlags": []
}
```

### 4.3 支持事件类型

```text
injury
illness
business_trip
travel
party
holiday
training_stopped
high_expenditure
low_recovery
high_stress
sleep_debt
```

---

## 5. 食物图片识别 Prompt

### 5.1 AI 任务

识别食物、估算份量、估算热量和宏量营养。

但最终建议必须结合 Strategy Engine 传入结果。

### 5.2 输入

```json
{
  "image": "base64_or_url",
  "userMode": "lifestyle",
  "currentStrategy": {},
  "nutritionRemaining": {}
}
```

### 5.3 输出 Schema

```json
{
  "type": "object",
  "required": ["foods", "total", "confidence", "plainAdvice", "recordDraft", "safetyFlags"],
  "properties": {
    "foods": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["name", "portion", "calories", "protein", "carbs", "fat", "confidence"],
        "properties": {
          "name": {"type": "string"},
          "portion": {"type": "string"},
          "calories": {"type": "number"},
          "protein": {"type": "number"},
          "carbs": {"type": "number"},
          "fat": {"type": "number"},
          "confidence": {"type": "number"}
        }
      }
    },
    "total": {
      "type": "object",
      "properties": {
        "calories": {"type": "number"},
        "protein": {"type": "number"},
        "carbs": {"type": "number"},
        "fat": {"type": "number"}
      }
    },
    "confidence": {"type": "number"},
    "plainAdvice": {"type": "array", "items": {"type": "string"}},
    "advancedAdvice": {"type": "array", "items": {"type": "string"}},
    "recordDraft": {"type": "object"},
    "safetyFlags": {"type": "array", "items": {"type": "string"}}
  }
}
```

### 5.4 普通用户输出风格

```text
这顿可以吃。
建议米饭留三分之一，肉和蔬菜正常吃，饮料少喝一点。
```

### 5.5 进阶用户输出风格

```text
估算约 650 kcal，蛋白 32g，碳水 78g，脂肪 22g。
当前脂肪接近上限，晚餐建议少油，优先补蛋白。
```

---

## 6. 策略解释 Prompt

### 6.1 输入

来自 Strategy Engine 的结构化结果。

```json
{
  "userMode": "advanced",
  "currentStateSummary": "减脂期第4周，胸背训练日，恢复良好",
  "targets": {
    "calories": 2200,
    "protein": 160,
    "carbs": 220,
    "fat": 55
  },
  "progress": {
    "calories": 1650,
    "protein": 120,
    "carbs": 150,
    "fat": 45
  },
  "strategyActions": [
    {
      "code": "protein_remaining",
      "value": 40,
      "unit": "g"
    },
    {
      "code": "fat_near_limit"
    }
  ]
}
```

### 6.2 输出

```json
{
  "summary": "今天是训练日，蛋白质还差 40g，脂肪已经接近目标。",
  "actions": [
    "睡前可以补一份乳清或 200g 鸡胸肉。",
    "碳水还可以补一根香蕉或一小碗米饭。",
    "晚餐尽量少油。"
  ],
  "tone": "calm",
  "safetyFlags": []
}
```

### 6.3 Prompt Template

```text
请根据系统传入的策略结果生成用户可理解的建议。

要求：
- 不重新计算。
- 不修改系统目标。
- 不夸大。
- 不制造焦虑。
- 普通用户用简单语言。
- 进阶用户可以使用蛋白质、碳水、脂肪等术语。
- 输出 JSON。

输入：
{{strategy_engine_output}}
```

---

## 7. 周复盘 Prompt

### 7.1 输入

```json
{
  "userMode": "lifestyle",
  "weekSummary": {
    "completedTaskCount": 12,
    "completionRate": 0.72,
    "weightChangeKg": -0.4,
    "strongestBehavior": "午餐前拍照",
    "biggestObstacle": "晚餐后零食"
  }
}
```

### 7.2 输出

```json
{
  "summary": "这周你完成了12次小任务，整体已经在往好的方向走。",
  "wins": ["午餐前拍照完成得最好。"],
  "obstacles": ["晚餐后零食是最容易失控的场景。"],
  "nextWeekFocus": "下周只做一件事：吃零食前先喝一杯水，等5分钟。",
  "tone": "encouraging"
}
```

---

## 8. Safety Classification

### 8.1 高风险表达

识别：

```text
极端节食
催吐
滥用泻药
过度运动
饮食障碍
严重身材焦虑
自伤
疾病诊断
```

### 8.2 输出

```json
{
  "riskLevel": "low | medium | high",
  "riskFlags": [],
  "shouldBlockWeightLossAdvice": false,
  "safeResponse": "..."
}
```

### 8.3 高风险处理

如果 high：

- 不继续提供减重技巧；
- 不提供热量压低建议；
- 给出温和安全提醒；
- 建议咨询专业人士。

---

## 9. Function Calling 设计

### 9.1 可用工具

```json
[
  {
    "name": "get_current_state",
    "description": "获取用户当前身体状态"
  },
  {
    "name": "get_today_targets",
    "description": "获取今日营养目标"
  },
  {
    "name": "get_today_progress",
    "description": "获取今日已记录数据"
  },
  {
    "name": "create_strategy_event",
    "description": "创建特殊事件，例如出差、聚餐、受伤"
  },
  {
    "name": "save_meal_record",
    "description": "保存饮食记录"
  },
  {
    "name": "generate_today_strategy",
    "description": "调用 Strategy Engine 生成今日策略"
  }
]
```

### 9.2 AI 对话流程

```text
用户说：今天出差晚上聚餐，没法练。

AI:
1. parse event
2. create_strategy_event
3. get_current_state
4. generate_today_strategy
5. strategy_explanation
```

---

## 10. 开发验收

1. 所有 AI 输出必须可 JSON parse。
2. AI 不得覆盖 Strategy Engine 的计算值。
3. 所有 AI 请求保存到 ai_interactions。
4. 高风险内容必须进入 safetyFlags。
5. 普通用户和进阶用户文案风格不同。
6. 食物识别结果必须允许用户修正。
7. AI 建议必须可以追溯到输入快照。