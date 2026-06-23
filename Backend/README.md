# MealKind Backend

MealKind 后台原型，包含：

- iOS 兼容的食物分析 JSON 接口：`POST /api/ai/food-analysis`
- 图片智能分流接口：`POST /api/ai/smart-scan`
- App 客户端持久化：游客/账号会话、全量镜像同步、远端导出恢复、按集合增删改查
- 图片持久化：餐食/训练图片 base64 入库后转存为本地文件并返回 `imageUrl`
- 超管登录：`POST /api/auth/login`
- 超管管理接口：用户、方案、系统设置、AI 日志
- 用户账号管理：注册、禁用、恢复、注销
- 系统内置减脂方案、计算引擎参数、宏量营养规则配置
- App 订阅套餐、价格、产品 ID 和权益配置
- 项目内置 AI 模型、用途、温度、超时和启用状态配置
- 项目数据看板：用户、订阅、方案、AI、问题、通知等核心指标
- 日志、问题、通知公告查询与处理
- 超管 Web 页面：`/admin`

## 本地启动

```bash
cd Backend
python3 server.py
```

打开：

```text
http://127.0.0.1:8787/admin
```

默认超管账号：

```text
admin / mealkind-admin
```

可通过环境变量覆盖：

```bash
MEALKIND_ADMIN_USER=admin \
MEALKIND_ADMIN_PASSWORD='change-me' \
MEALKIND_PORT=8787 \
python3 server.py
```

## iOS 接口配置

iOS 端已有 `FoodAnalysisEndpoint` 和 `PersistenceEndpoint` 配置读取能力。开发时可将它们指向：

```text
http://127.0.0.1:8787/api/ai/food-analysis
http://127.0.0.1:8787/
```

真机调试时需要换成 Mac 局域网 IP，例如：

```text
http://192.168.1.10:8787/api/ai/food-analysis
http://192.168.1.10:8787/
```

## 说明

当前数据层使用 `Backend/data/store.json`，便于本地验证后台和超管页面。正式上线时建议替换为 Supabase/Postgres，并将 AI mock 替换为服务端模型编排。

客户端持久化集合：

```text
settings
habits
dailyTasks
mealRecords
workoutRecords
sleepRecords
waterRecords
weightRecords
supplementRecords
measurementRecords
dailyStrategies
weeklyReviews
trainingCycles
```

`POST /api/client/sync` 支持 `replaceAll: true`。iOS 端默认使用该模式上传 SwiftData 快照，后端会先清空当前用户的客户端集合，再写入本次记录，因此本地删除也会被镜像到远端。

App 首次完成本地 hydrate 后会调用 `GET /api/client/export`。如果远端已有用户记录且本地还没有用户记录，会把远端数据 upsert 回 SwiftData，再刷新 AppState；如果本地已有数据，则优先保留本地并继续向远端同步。

图片字段可随记录提交为 `imageBase64` 或 `imageData`。后端会把图片写入 `Backend/data/uploads/<userId>/<collection>/<recordId>.jpg`，记录中保留 `imageUrl`。

用户侧数据管理：

```text
POST /api/client/clear
```

清空当前客户端用户的持久化集合和上传图片，但保留会话账号。

```text
POST /api/client/delete-account
```

注销当前客户端用户，清空集合、上传图片和账号，并使后续同一 token 的请求失效。

## 主要接口

```text
GET    /api/admin/overview
GET    /api/admin/users
POST   /api/admin/users
PATCH  /api/admin/users/:id
DELETE /api/admin/users/:id

GET/POST /api/admin/plans
GET/POST /api/admin/subscriptions
GET/POST /api/admin/ai-models
GET/POST /api/admin/settings

GET    /api/admin/analysis-logs
GET    /api/admin/system-logs
GET    /api/admin/issues
POST   /api/admin/issues
PATCH  /api/admin/issues/:id
DELETE /api/admin/issues/:id

GET    /api/admin/notifications
POST   /api/admin/notifications
PATCH  /api/admin/notifications/:id
DELETE /api/admin/notifications/:id

POST   /api/client/session
GET    /api/client/me
POST   /api/client/sync
GET    /api/client/export
POST   /api/client/clear
POST   /api/client/delete-account
GET    /api/client/records/:collection
POST   /api/client/records/:collection
PATCH  /api/client/records/:collection/:id
DELETE /api/client/records/:collection/:id
```
