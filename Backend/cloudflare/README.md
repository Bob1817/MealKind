# MealKind Cloudflare Backend

Cloudflare Workers 版本的 MealKind API 后端。接口保持和 `Backend/server.py` 一致，结构化数据使用 Cloudflare KV，图片优先存入阿里云 OSS。未配置 OSS 时，图片会临时回退到 KV，便于本地开发。

## 准备

```bash
cd Backend/cloudflare
npm install
npx wrangler login
npx wrangler kv namespace create MEALKIND_STORE
```

把 KV 命令返回的 `id` 填入 `wrangler.toml` 的 `kv_namespaces[0].id`。

生产环境请修改超管密码：

```bash
npx wrangler secret put MEALKIND_ADMIN_PASSWORD
```

## 阿里云 OSS 图片存储

在 `wrangler.toml` 的 `[vars]` 中配置公开参数：

```toml
OSS_BUCKET = "mealkind"
OSS_ENDPOINT = "oss-cn-hangzhou.aliyuncs.com"
```

`OSS_ENDPOINT` 不需要带 bucket，也不需要 `https://`。例如杭州地域使用 `oss-cn-hangzhou.aliyuncs.com`。

AccessKey 必须用 Cloudflare Secret，不要写入仓库：

```bash
npx wrangler secret put OSS_ACCESS_KEY_ID
npx wrangler secret put OSS_ACCESS_KEY_SECRET
```

RAM 用户至少需要对目标 bucket 的 `oss:PutObject` 和 `oss:GetObject` 权限。Worker 会通过 `/data/uploads/<userId>/<collection>/<recordId>.jpg` 代理读取 OSS 图片，bucket 可以保持私有。

## 本地运行

```bash
npm run dev
```

## 部署

```bash
npm run deploy
```

当前已部署地址：

```text
https://mefitai.fit
```

部署后将 iOS 配置改成 Worker 地址：

```text
FoodAnalysisEndpoint = https://mefitai.fit/api/ai/food-analysis
PersistenceEndpoint = https://mefitai.fit/
```

线上 `MEALKIND_ADMIN_PASSWORD` 已通过 Cloudflare Secret 覆盖，仓库中的默认密码不会用于生产登录。需要重设后台密码时运行：

```bash
npx wrangler secret put MEALKIND_ADMIN_PASSWORD
```
