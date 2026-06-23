# 01 工程级文档：AI Body OS 数据库详细 ER 与 Supabase SQL 设计

版本：V2.0 Engineering  
适用对象：Codex / Claude Code / Cursor / Supabase / iOS 开发  
数据库：PostgreSQL + Supabase Auth + RLS  
产品：轻减AI / Qingjian AI / AI Body OS

---

## 0. 设计目标

本数据库用于支撑 AI Body OS 的核心闭环：

```text
User Profile
↓
Current State
↓
Cycle
↓
Nutrition Target
↓
Records
↓
Strategy
↓
AI Explanation
↓
Review
```

数据库必须支持两类用户：

1. 普通用户：减脂习惯、热量缺口、低压力执行。
2. 进阶用户：训练周期、宏量营养、睡眠、补剂、恢复、保肌减脂。

---

## 1. 核心设计原则

### 1.1 用户数据必须按 user_id 隔离

所有业务表必须包含：

```sql
user_id uuid not null references auth.users(id) on delete cascade
```

并开启 RLS。

### 1.2 所有日级数据必须包含 local_date

避免跨时区造成日记录混乱。

```sql
local_date date not null
timezone text not null default 'Asia/Shanghai'
```

### 1.3 计算结果与原始记录分离

例如：

- meal_records 是用户实际记录。
- daily_nutrition_summaries 是聚合结果。
- daily_strategies 是策略输出。

### 1.4 AI 输出必须结构化存储

不要只存 AI 文本。

必须同时保存：

- 输入快照
- 引擎计算结果
- AI 输出 JSON
- 展示文案

---

## 2. ER 总览

```text
auth.users
 └── user_profiles
 └── user_preferences
 └── goals
 └── body_states
 └── cycles
      └── cycle_days
 └── nutrition_targets
 └── meal_records
      └── meal_food_items
 └── workout_records
 └── sleep_records
 └── water_records
 └── supplement_plans
      └── supplement_records
 └── body_measurements
 └── daily_summaries
 └── recovery_scores
 └── daily_strategies
 └── strategy_events
 └── ai_interactions
 └── weekly_reviews
 └── subscription_entitlements
```

---

## 3. 枚举类型

```sql
create type user_mode as enum ('lifestyle', 'advanced');

create type goal_type as enum (
  'fat_loss',
  'maintain',
  'muscle_gain',
  'recovery'
);

create type cycle_type as enum (
  'fat_loss',
  'maintenance',
  'muscle_gain',
  'recovery'
);

create type training_status as enum (
  'normal_training',
  'rest_day',
  'deload',
  'stopped',
  'injured',
  'returning'
);

create type life_status as enum (
  'normal',
  'travel',
  'business_trip',
  'party',
  'holiday',
  'high_stress'
);

create type recovery_status as enum (
  'good',
  'moderate',
  'low',
  'critical'
);

create type meal_type as enum (
  'breakfast',
  'lunch',
  'dinner',
  'snack',
  'supplement',
  'unknown'
);

create type strategy_type as enum (
  'nutrition',
  'training',
  'recovery',
  'supplement',
  'habit'
);

create type subscription_tier as enum (
  'free',
  'pro',
  'pro_plus'
);
```

---

## 4. 用户基础表

### 4.1 user_profiles

```sql
create table public.user_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  display_name text,
  mode user_mode not null default 'lifestyle',
  gender text,
  birth_year int,
  height_cm numeric(5,2),
  current_weight_kg numeric(5,2),
  target_weight_kg numeric(5,2),
  timezone text not null default 'Asia/Shanghai',
  locale text not null default 'zh-Hans',
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_user_profiles_user_id on public.user_profiles(user_id);
```

### 4.2 user_preferences

```sql
create table public.user_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  diet_scenes jsonb not null default '[]',
  failure_scenes jsonb not null default '[]',
  food_preferences jsonb not null default '{}',
  allergies jsonb not null default '[]',
  disliked_foods jsonb not null default '[]',
  accepted_adjustments jsonb not null default '[]',
  notification_preferences jsonb not null default '{}',
  ai_memory_enabled boolean not null default true,
  image_storage_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

---

## 5. 目标与周期

### 5.1 goals

```sql
create table public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  goal_type goal_type not null,
  start_weight_kg numeric(5,2),
  target_weight_kg numeric(5,2),
  target_body_fat_percent numeric(5,2),
  start_date date not null,
  target_date date,
  weekly_weight_change_target_kg numeric(4,2),
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_goals_user_active on public.goals(user_id, is_active);
```

### 5.2 cycles

```sql
create table public.cycles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  goal_id uuid references public.goals(id) on delete set null,
  cycle_type cycle_type not null,
  title text not null,
  start_date date not null,
  end_date date,
  current_week int not null default 1,
  current_day int not null default 1,
  template_code text,
  is_active boolean not null default true,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_cycles_user_active on public.cycles(user_id, is_active);
```

### 5.3 cycle_days

用于描述练三休一、PPL、Upper/Lower 等周期模板。

```sql
create table public.cycle_days (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references public.cycles(id) on delete cascade,
  day_index int not null,
  title text not null,
  training_status training_status not null,
  muscle_groups jsonb not null default '[]',
  target_intensity text,
  calorie_adjustment numeric(6,2) default 0,
  carb_adjustment numeric(6,2) default 0,
  notes text,
  unique(cycle_id, day_index)
);
```

---

## 6. 状态引擎表

### 6.1 body_states

保存每日状态快照。

```sql
create table public.body_states (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  timezone text not null default 'Asia/Shanghai',

  goal_type goal_type not null,
  cycle_id uuid references public.cycles(id) on delete set null,
  cycle_day_id uuid references public.cycle_days(id) on delete set null,

  training_status training_status not null default 'normal_training',
  life_status life_status not null default 'normal',
  recovery_status recovery_status not null default 'moderate',

  injury_mode boolean not null default false,
  travel_mode boolean not null default false,
  party_mode boolean not null default false,
  high_expenditure_mode boolean not null default false,

  subjective_fatigue int check (subjective_fatigue between 1 and 10),
  injury_note text,
  state_source text not null default 'system',
  state_priority int not null default 0,

  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique(user_id, local_date)
);

create index idx_body_states_user_date on public.body_states(user_id, local_date desc);
```

---

## 7. 营养目标与饮食记录

### 7.1 nutrition_targets

```sql
create table public.nutrition_targets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  timezone text not null default 'Asia/Shanghai',

  target_calories numeric(7,2) not null,
  target_protein_g numeric(6,2),
  target_carbs_g numeric(6,2),
  target_fat_g numeric(6,2),
  target_fiber_g numeric(6,2),
  target_water_ml numeric(7,2),

  deficit_target numeric(7,2),
  calculation_version text not null default 'v2.0',
  input_snapshot jsonb not null default '{}',
  reason text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique(user_id, local_date)
);

create index idx_nutrition_targets_user_date on public.nutrition_targets(user_id, local_date desc);
```

### 7.2 meal_records

```sql
create table public.meal_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  timezone text not null default 'Asia/Shanghai',

  meal_type meal_type not null default 'unknown',
  title text,
  image_url text,
  input_method text not null default 'manual',

  estimated_calories numeric(7,2) not null default 0,
  protein_g numeric(6,2) default 0,
  carbs_g numeric(6,2) default 0,
  fat_g numeric(6,2) default 0,
  fiber_g numeric(6,2) default 0,

  ai_confidence numeric(4,3),
  user_corrected boolean not null default false,
  correction_note text,
  raw_ai_result jsonb not null default '{}',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_meal_records_user_date on public.meal_records(user_id, local_date desc);
```

### 7.3 meal_food_items

```sql
create table public.meal_food_items (
  id uuid primary key default gen_random_uuid(),
  meal_record_id uuid not null references public.meal_records(id) on delete cascade,
  name text not null,
  portion_text text,
  quantity numeric(8,2),
  unit text,
  calories numeric(7,2) default 0,
  protein_g numeric(6,2) default 0,
  carbs_g numeric(6,2) default 0,
  fat_g numeric(6,2) default 0,
  fiber_g numeric(6,2) default 0,
  confidence numeric(4,3),
  metadata jsonb not null default '{}'
);
```

---

## 8. 训练、睡眠、饮水、补剂

### 8.1 workout_records

```sql
create table public.workout_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  timezone text not null default 'Asia/Shanghai',

  workout_type text not null,
  title text,
  duration_minutes int,
  estimated_calories numeric(7,2),
  intensity text,
  muscle_groups jsonb not null default '[]',
  source text not null default 'manual',
  healthkit_workout_id text,
  notes text,

  created_at timestamptz not null default now()
);

create index idx_workout_user_date on public.workout_records(user_id, local_date desc);
```

### 8.2 sleep_records

```sql
create table public.sleep_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  timezone text not null default 'Asia/Shanghai',

  total_sleep_minutes int,
  deep_sleep_minutes int,
  rem_sleep_minutes int,
  awake_minutes int,
  sleep_score numeric(5,2),
  source text not null default 'manual',
  raw_healthkit_payload jsonb not null default '{}',

  created_at timestamptz not null default now(),
  unique(user_id, local_date)
);
```

### 8.3 water_records

```sql
create table public.water_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  timezone text not null default 'Asia/Shanghai',
  amount_ml numeric(7,2) not null,
  source text not null default 'manual',
  created_at timestamptz not null default now()
);
```

### 8.4 supplement_plans

```sql
create table public.supplement_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  dosage_text text,
  timing text,
  frequency jsonb not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
```

### 8.5 supplement_records

```sql
create table public.supplement_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  supplement_plan_id uuid references public.supplement_plans(id) on delete set null,
  local_date date not null,
  timezone text not null default 'Asia/Shanghai',
  name text not null,
  dosage_text text,
  completed boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create index idx_supplement_records_user_date on public.supplement_records(user_id, local_date desc);
```

---

## 9. 身体测量与恢复指数

### 9.1 body_measurements

```sql
create table public.body_measurements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  timezone text not null default 'Asia/Shanghai',

  weight_kg numeric(5,2),
  body_fat_percent numeric(5,2),
  waist_cm numeric(5,2),
  chest_cm numeric(5,2),
  hip_cm numeric(5,2),
  arm_cm numeric(5,2),
  thigh_cm numeric(5,2),

  source text not null default 'manual',
  created_at timestamptz not null default now()
);
```

### 9.2 recovery_scores

```sql
create table public.recovery_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  timezone text not null default 'Asia/Shanghai',

  score int not null check (score between 0 and 100),
  status recovery_status not null,
  sleep_component numeric(5,2),
  fatigue_component numeric(5,2),
  workout_load_component numeric(5,2),
  hydration_component numeric(5,2),
  hrv_component numeric(5,2),
  input_snapshot jsonb not null default '{}',
  created_at timestamptz not null default now(),

  unique(user_id, local_date)
);
```

---

## 10. 汇总与策略

### 10.1 daily_summaries

```sql
create table public.daily_summaries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  timezone text not null default 'Asia/Shanghai',

  calories_in numeric(7,2) default 0,
  calories_out_exercise numeric(7,2) default 0,
  protein_g numeric(6,2) default 0,
  carbs_g numeric(6,2) default 0,
  fat_g numeric(6,2) default 0,
  water_ml numeric(7,2) default 0,

  completed_tasks int default 0,
  total_tasks int default 0,
  adherence_score numeric(5,2),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique(user_id, local_date)
);
```

### 10.2 daily_strategies

```sql
create table public.daily_strategies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  timezone text not null default 'Asia/Shanghai',

  strategy_type strategy_type not null,
  title text not null,
  summary text not null,
  actions jsonb not null default '[]',
  priority int not null default 0,
  source_engine text not null default 'strategy_engine',
  input_snapshot jsonb not null default '{}',
  ai_explanation text,
  status text not null default 'active',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_daily_strategies_user_date on public.daily_strategies(user_id, local_date desc);
```

### 10.3 strategy_events

记录特殊事件，例如聚餐、受伤、出差、骑行高消耗。

```sql
create table public.strategy_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date not null,
  event_type text not null,
  title text,
  description text,
  impact_payload jsonb not null default '{}',
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);
```

---

## 11. AI 交互与周复盘

### 11.1 ai_interactions

```sql
create table public.ai_interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  local_date date,
  interaction_type text not null,
  model_name text,
  prompt_version text,
  request_payload jsonb not null default '{}',
  response_payload jsonb not null default '{}',
  safety_flags jsonb not null default '[]',
  latency_ms int,
  cost_estimate numeric(10,6),
  created_at timestamptz not null default now()
);
```

### 11.2 weekly_reviews

```sql
create table public.weekly_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start_date date not null,
  week_end_date date not null,

  completed_task_count int default 0,
  task_completion_rate numeric(5,2),
  weight_change_kg numeric(5,2),
  protein_adherence_rate numeric(5,2),
  calorie_adherence_rate numeric(5,2),
  strongest_behavior text,
  biggest_obstacle text,
  next_week_focus text,
  ai_summary text,
  input_snapshot jsonb not null default '{}',

  created_at timestamptz not null default now(),
  unique(user_id, week_start_date)
);
```

---

## 12. 订阅权限

```sql
create table public.subscription_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  tier subscription_tier not null default 'free',
  store text,
  original_transaction_id text,
  expires_at timestamptz,
  is_active boolean not null default true,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

---

## 13. RLS 策略模板

所有用户业务表使用以下模板。

```sql
alter table public.user_profiles enable row level security;

create policy "Users can read own profile"
on public.user_profiles for select
using (auth.uid() = user_id);

create policy "Users can insert own profile"
on public.user_profiles for insert
with check (auth.uid() = user_id);

create policy "Users can update own profile"
on public.user_profiles for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete own profile"
on public.user_profiles for delete
using (auth.uid() = user_id);
```

Codex 执行要求：

为所有包含 user_id 的表创建同样 RLS 策略。

---

## 14. 必须创建的 View

### 14.1 today_dashboard_view

聚合 Today 所需数据。

```sql
create view public.today_dashboard_view as
select
  bs.user_id,
  bs.local_date,
  bs.goal_type,
  bs.training_status,
  bs.life_status,
  bs.recovery_status,
  nt.target_calories,
  nt.target_protein_g,
  nt.target_carbs_g,
  nt.target_fat_g,
  ds.calories_in,
  ds.protein_g,
  ds.carbs_g,
  ds.fat_g,
  rs.score as recovery_score
from public.body_states bs
left join public.nutrition_targets nt
  on nt.user_id = bs.user_id and nt.local_date = bs.local_date
left join public.daily_summaries ds
  on ds.user_id = bs.user_id and ds.local_date = bs.local_date
left join public.recovery_scores rs
  on rs.user_id = bs.user_id and rs.local_date = bs.local_date;
```

---

## 15. 开发验收标准

1. 所有表可在 Supabase SQL Editor 一次性执行创建。
2. 所有业务表开启 RLS。
3. 所有日级表支持 user_id + local_date 查询。
4. meal_records、workout_records、sleep_records、supplement_records 可独立写入。
5. daily_summaries 可由服务端任务或客户端计算更新。
6. daily_strategies 可保存规则引擎与 AI 解释结果。
7. ai_interactions 可追踪 AI 调用成本、模型、输入、输出。