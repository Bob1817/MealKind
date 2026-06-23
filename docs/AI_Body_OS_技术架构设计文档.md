# AI Body OS 技术架构设计文档

## 总体架构

Client
↓
API Gateway
↓
Body OS Core
├─ State Engine
├─ Cycle Engine
├─ Nutrition Engine
├─ Recovery Engine
├─ Strategy Engine
└─ AI Layer
↓
Database

---

## State Engine

职责：
维护用户实时身体状态。

状态来源：
- 用户输入
- Apple Health
- Apple Watch
- AI分析

输出：
- 当前状态
- 当前目标
- 当前风险

---

## Cycle Engine

职责：
管理训练周期与身体周期。

支持：
- 减脂期
- 增肌期
- 维持期
- 恢复期

支持周期模板。

---

## Nutrition Engine

职责：
计算动态营养目标。

输出：
- Calories
- Protein
- Carbs
- Fat

动态受以下影响：
- 周期
- 训练
- 恢复
- 出差
- 停训

---

## Recovery Engine

输入：
- 睡眠
- HRV
- 静息心率
- 饮水
- 疲劳评分

输出：
Recovery Score

---

## Supplement Engine

管理：
- 补剂模板
- 每日打卡
- 连续统计

---

## Strategy Engine

输入：
State
Cycle
Nutrition
Recovery

输出：
Today Strategy

包括：
- 饮食建议
- 训练建议
- 恢复建议
- 补剂建议

---

## AI Layer

AI 不负责计算。

AI 负责解释。

例如：

系统：
剩余蛋白40g

AI：
建议补充200g鸡胸肉。

---

## 核心数据库

users
goals
cycles
states
meal_records
workout_records
sleep_records
water_records
supplement_records
recovery_scores
strategies
weekly_reviews

---

## iOS 模块

Features
- Today
- Scan
- BodyLog
- Progress
- Me

Core
- StateEngine
- CycleEngine
- NutritionEngine
- RecoveryEngine
- StrategyEngine

Services
- AIService
- HealthKitService
- SubscriptionService

---

## 长期路线

V2.1 Apple Watch

V2.2 Widget

V2.3 Siri

V3.0 AI Coach

最终目标：

AI Body OS

普通用户：减脂助手

进阶用户：训练、营养、恢复与周期管理系统
