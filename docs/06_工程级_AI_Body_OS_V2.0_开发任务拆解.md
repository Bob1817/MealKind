# 06 工程级文档：AI Body OS V2.0 开发任务拆解

版本：V2.0 Engineering  
适用对象：Codex / Claude Code / Cursor / iOS / Backend / Supabase / AI Gateway  
产品：轻减AI / Qingjian AI / AI Body OS

---

## 0. 升级目标

将当前 MealKind 原型从“拍照识别 + 计划建议 + 本地记录”升级为 `AI Body OS`：

- 普通用户：低压力减脂习惯助手。
- 进阶用户：训练、营养、恢复、周期管理系统。

核心闭环：

```text
User Profile
-> Current State
-> Cycle
-> Nutrition Target
-> Records
-> Strategy
-> AI Explanation
-> Review
```

---

## 1. 里程碑规划

### M0：工程基线与规则落地

目标：让后续开发全部受 Body OS 架构边界约束。

- [x] 建立 `.cursor/rules` 工程规则。
- [ ] 将 V2.0 文档加入开发入口索引。
- [ ] 确认 App 当前 Tab 与 V2.0 Tab 映射关系。
- [ ] 定义 V2.0 开发分支、构建命令、验收命令。
- [ ] 清理旧原型任务中与 V2.0 冲突的表述。

验收标准：

- 新增功能能明确归属到 State、Cycle、Nutrition、Recovery、Strategy、AI Layer 或 Feature UI。
- 开发任务均可映射到本任务拆解中的任务编号。

---

## 2. M1：Core Models 与 Engine 协议

目标：先定义 Body OS 的稳定领域模型与引擎接口，避免 UI 先行导致规则散落。

### V2-M1-01：用户模式与目标模型

- [x] 新增或统一 `UserMode`：`lifestyle`、`advanced`。
- [x] 新增或统一 `GoalType`：`fatLoss`、`maintain`、`muscleGain`、`recovery`。
- [x] 增加用户资料字段：身高、体重、目标体重、活动水平、时区、语言、训练经验。
- [x] 增加普通用户与进阶用户展示能力开关。

验收标准：

- 普通用户不默认展示 BMR、TDEE、复杂宏量营养。
- 进阶用户可展示宏量营养、周期、恢复、训练数据。

### V2-M1-02：State Engine 模型与协议

- [x] 定义 `GoalState`、`TrainingState`、`LifeState`、`RecoveryState`。
- [x] 定义 `StateInput`、`BodyState`、`StateEvent`。
- [x] 实现 `StateEngineProtocol.resolve(input:)`。
- [x] 实现状态优先级覆盖规则。

验收标准：

- 受伤覆盖训练计划。
- Critical Recovery 覆盖普通训练建议。
- 出差、旅行、聚餐能影响当天策略。
- 单元测试覆盖状态优先级。

### V2-M1-03：Cycle Engine 模型与协议

- [x] 定义 `CycleType`：减脂、维持、增肌、恢复。
- [x] 定义训练模板：练三休一、Push Pull Legs、Upper Lower、自定义。
- [x] 定义 `CycleDay` 与当前周期日解析。
- [x] 实现 `CycleEngineProtocol`。

验收标准：

- 能返回当前周期、当前训练日、是否休息日。
- 停训、受伤、恢复期不直接删除原周期，而是由 State/Strategy 覆盖执行建议。

### V2-M1-04：Nutrition Engine 模型与协议

- [x] 定义 `NutritionInput`、`NutritionTarget`。
- [x] 实现热量、蛋白质、碳水、脂肪目标计算。
- [x] 支持普通用户与进阶用户不同规则。
- [x] 支持训练日、休息日、停训、受伤、高消耗、低恢复动态调整。

验收标准：

- 普通用户缺口默认 300-500 kcal。
- 低恢复/出差/高压力时缺口降低到 200-300 kcal。
- 进阶用户停训/受伤仍保持蛋白质。

### V2-M1-05：Recovery Engine 模型与协议

- [x] 定义睡眠、HRV、静息心率、饮水、疲劳评分输入。
- [x] 定义 `RecoveryScore` 与 `RecoveryState`。
- [x] 实现基础恢复评分算法。

验收标准：

- Recovery Score 能分为 good、moderate、low、critical。
- critical 会驱动 State 与 Strategy 降低训练强度和热量缺口。

### V2-M1-06：Strategy Engine 模型与协议

- [x] 定义 `StrategyInput`、`TodayStrategy`、`StrategyItem`、`StrategyAction`。
- [x] 实现饮食、训练、恢复、补剂四类策略输出。
- [x] 输出包含 `type`、`priority`、`title`、`actions`、`reason`。

验收标准：

- 策略输出稳定、可测试、可解释。
- AI Layer 只解释策略，不生成最终策略。

---

## 3. M2：本地数据与 Supabase 数据结构

目标：让 V2.0 数据可同步、可隔离、可追溯。

### V2-M2-01：SwiftData 本地模型升级

- 新增或扩展本地模型：Profile、Goal、Cycle、BodyState、MealRecord、WorkoutRecord、SleepRecord、WaterRecord、SupplementRecord、RecoveryScore、DailyStrategy。
- 所有日级模型包含 `localDate` 与 `timezone`。
- 区分原始记录与计算结果。

验收标准：

- App 可离线查看今天的状态、目标、记录、策略。
- 本地模型具备迁移策略。

### V2-M2-02：Supabase Schema 与 RLS

- 基于 `01_工程级_AI_Body_OS_数据库ER与Supabase_SQL设计.md` 建立迁移 SQL。
- 为业务表添加 `user_id`、索引、RLS 策略。
- 建立 `daily_strategies`、`ai_interactions`、`weekly_reviews`。

验收标准：

- 所有业务表按用户隔离。
- 日级表按 `user_id + local_date` 可查询。
- AI 输出结构化保存。

### V2-M2-03：Repository 层

- 新增 Profile、Goal、Cycle、Record、Strategy、Review Repository。
- Repository 负责本地与远端同步，不在 View 中直接读写底层存储。
- 定义离线草稿、同步中、同步失败状态。

验收标准：

- ViewModel 不直接依赖 Supabase 或 SwiftData 细节。
- 同步失败不会丢失本地记录。

---

## 4. M3：iOS V2.0 信息架构升级

目标：把当前 Tab 升级为 V2.0 信息架构。

### V2-M3-01：Tab 映射

- [x] 当前 `Today` 保留并升级为 Body OS 今日中枢。
- [x] 当前 `Scan` 保留为拍照入口。
- [x] 当前 `Record` 升级为 `BodyLog`。
- [x] 当前 `Insights` 升级为 `Progress`。
- [x] 当前 `Plan` 能力迁移到 Cycle/Goal 管理（Me 中保留入口）。
- [x] 当前 `Me` 保留并加入模式、订阅、隐私、HealthKit 入口。

验收标准：

- 主导航符合 Today、Scan、BodyLog、Progress、Me。
- 旧 Plan 页面不再作为独立主 Tab 阻断 V2.0 架构。

### V2-M3-02：Today 页面升级

- [x] 新增 Current State 卡片。
- [x] 新增 Energy/Nutrition Summary 卡片。
- [x] 新增 Today Strategy 卡片。
- [x] 保留 Quick Scan。
- [x] 普通用户展示简单行动，进阶用户展示宏量营养与恢复指数。

验收标准：

- 普通用户看到“今天完成两个小动作即可”类型体验。
- 进阶用户可看到周期、训练日、恢复指数、Calories/Protein/Carbs/Fat。

### V2-M3-03：BodyLog 页面

- [x] 普通用户展示体重、饮水、步数（占位）、饮食记录。
- [x] 进阶用户展示饮食、宏量营养、训练、睡眠（占位）、饮水、补剂（占位）、体重、体脂、围度（占位）。
- [ ] 接入 HealthKit / Supplement / Measurement 真实数据写入。

验收标准：

- 同一页面根据 `UserMode` 渐进展示复杂度。

### V2-M3-04：Progress 页面

- 普通用户展示本周完成项、体重趋势、最稳定行为、下周一个重点。
- 进阶用户展示周热量趋势、蛋白达标率、训练完成率、恢复趋势、睡眠趋势、体重/体脂趋势。

验收标准：

- 周复盘基于记录和策略，不依赖自由 AI 文本。

---

## 5. M4：AI Gateway 与 Function Calling

目标：把 AI 从“直接给建议”改为“解析与解释层”。

### V2-M4-01：AI 调用类型拆分

- `onboarding_profile_extraction`
- `natural_language_event_parser`
- `food_vision_analysis`
- `strategy_explanation`
- `weekly_review_generation`
- `safety_classification`

验收标准：

- 每类调用都有独立输入、输出 JSON Schema。
- 后端不把自由文本当业务事实来源。

### V2-M4-02：自然语言事件解析

- 将“今天出差，晚上聚餐，没法练了”解析为 State Event。
- 输出 `statePatch` 供 State Engine 使用。
- 增加置信度与安全标记。

验收标准：

- AI 解析事件不会直接改写最终策略。
- State Engine 仍是状态优先级唯一来源。

### V2-M4-03：策略解释

- 输入 Strategy Engine 结果与用户模式。
- 输出普通用户/进阶用户不同文案。
- 禁止羞辱、失败、惩罚性运动、极端节食。

验收标准：

- 同一策略可以生成温和中文文案。
- 高风险场景触发安全提醒。

---

## 6. M5：HealthKit、补剂与恢复

目标：补齐 Body OS 进阶能力。

### V2-M5-01：HealthKit 接入

- 接入步数、活动能量、睡眠、心率、HRV、训练记录。
- 增加权限说明与可撤销入口。

验收标准：

- HealthKit 数据能参与 State/Recovery/Nutrition，但用户可关闭。

### V2-M5-02：Supplement System

- 支持肌酸、鱼油、D3、镁、电解质、自定义补剂。
- 支持每日打卡、连续统计、策略提醒。

验收标准：

- 进阶用户可管理补剂计划。
- 普通用户不被复杂补剂管理打扰。

### V2-M5-03：Recovery 分析

- 展示睡眠、饮水、疲劳评分、恢复指数。
- 恢复低时自动调整训练与热量缺口建议。

验收标准：

- Recovery Score 能影响今日策略。

---

## 7. M6：订阅与商业化

目标：建立 Free / Pro / Pro Plus 能力边界。

### V2-M6-01：订阅能力定义

- Free：基础拍照、基础今日建议、基础记录。
- Pro：更多饮食分析、基础趋势、更多记录能力。
- Pro Plus：周期管理、恢复分析、睡眠分析、AI 训练建议、AI 营养建议。

验收标准：

- 功能入口按订阅状态展示锁定、试用、升级。

### V2-M6-02：StoreKit 2

- 接入 StoreKit 2 产品、购买、恢复购买、订阅状态监听。
- 本地与后端保存 entitlement。

验收标准：

- App 可区分 Free、Pro、Pro Plus。

---

## 8. M7：测试与验收

目标：保证 Body OS 核心规则可靠。

### V2-M7-01：Domain Tests

- State Engine 状态优先级。
- Nutrition Engine 缺口和宏量营养边界。
- Recovery Engine 分数分段。
- Strategy Engine 普通/进阶、聚餐、出差、受伤、低恢复、高热量场景。

### V2-M7-02：API Tests

- AI JSON Schema 解码。
- 低置信度食物识别。
- 安全分类。
- Supabase RLS 与用户隔离。

### V2-M7-03：UI Tests

- Onboarding 建档。
- Scan 保存餐食。
- Today 策略刷新。
- BodyLog 新增记录。
- 模式切换后信息显示变化。

验收标准：

- 核心引擎测试覆盖 V2.0 关键状态。
- App 可在模拟器完成普通用户和进阶用户主路径。

---

## 9. 优先级建议

第一阶段优先做：

1. Core Models 与 Engine 协议。
2. State Engine + Nutrition Engine + Strategy Engine 的最小可用实现。
3. Today 页面接入 Today Strategy。
4. AI Gateway 输出 JSON Schema 调整。
5. Supabase Schema 与 Repository 层。

原因：这五项决定 Body OS 是否真正成立。补剂、HealthKit、订阅可以在核心闭环跑通后逐步上线。
