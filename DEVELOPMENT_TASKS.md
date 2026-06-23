# MealKind iOS Native Development Tasks

Last updated: 2026-06-17

## V2.0 Body OS Progress (Today Center)

- Implemented Body OS Cycle Engine with three-on-one-off, push pull legs, upper lower, and custom training patterns.
- Connected the full Today chain inside `AppState`: profile, cycle, recovery score, body state, nutrition target, today strategy.
- Today tab now surfaces three Body OS cards above the strategy:
  - Current State card with mode badge, goal/training/life/recovery chips, and an override summary line.
  - Energy & Nutrition Summary card with remaining kcal, calorie progress bar, and advanced macro tiles (protein/carbs/fat).
  - Existing Body OS Strategy card driven by `StrategyEngine`.

## V2.0 Profile UI (Onboarding + Me)

- Onboarding "AI 需要先了解你" / scene card now exposes Activity Level and Training Experience pickers; both values flow into `UserEnergyProfile` and the Body OS chain.
- Me → Profile editor sheet shows the same two pickers in the Lifestyle section, alongside existing work environment and weekly workout inputs.
- Build + 40 tests still pass.

## V2.0 Profile Model Completion (V2-M1-01)

- Added `TrainingExperience` enum (`none`, `beginner`, `intermediate`, `advanced`) with bilingual labels.
- Added `ActivityLevel.localizedName(language:)` so the existing enum is UI-ready.
- Extended `UserEnergyProfile` with `activityLevel`, `trainingExperience`, and a `derivedActivityLevel` heuristic from `workEnvironment` + `weeklyWorkoutCount`.
- Persisted the new fields in `StoredUserSettings` (`activityLevelRawValue`, `trainingExperienceRawValue`).
- Extended `BodyOSProfile` with `targetWeightKilograms`, `activityLevel`, `trainingExperience`, `language`, and a `timezone` default of `TimeZone.current.identifier`.
- `AppState.bodyOSProfile` now flows the unified fields and the live device timezone into the Body OS chain.
- Added unit tests `testBodyOSProfileCarriesProfileFields` and `testDerivedActivityLevelReflectsWorkoutFrequency`; the full suite is at 40 tests, all passing.

## V2.0 Navigation Upgrade (V2-M3-01 / minimum M3-03)

- Renamed main `habit` tab to `bodyLog`, mapping to a new `BodyLogView`.
- Main navigation now matches the V2.0 spec: Today, Scan, BodyLog, Progress, Me.
- New `BodyLogView` adapts to user mode:
  - Lifestyle: weight, water, steps (placeholder until HealthKit), today meals.
  - Advanced: today energy, macro breakdown, workouts, sleep placeholder, water, supplement placeholder, measurements, recent meals.
- Plan capabilities continue to be reachable through the goal settings sheet inside Me.
- All 38 unit tests still pass after the navigation and BodyLog additions.

## Completed In Current Prototype

- Created native SwiftUI iOS project with XcodeGen.
- Added shared `AppState` for plan, budget, meals, water, and profile state.
- Built simplified Liquid Glass-inspired design foundation with iOS 26+ `glassEffect` fallback support.
- Implemented onboarding start flow with plan selection.
- Implemented Today tab:
  - remaining / over-budget kcal status
  - plan-based next move
  - scan, log, water, weight actions
  - collapsed calorie calculation details
- Implemented Scan tab:
  - camera capture entry
  - photo picker entry
  - captured image preview in scan result
  - simplified result sheet
  - advanced nutrition details collapsed by default
- Added SwiftData local persistence:
  - user settings and onboarding completion
  - selected plan, energy profile, water, weight
  - meal records with optional externally stored image data
- Added UIKit camera bridge for real meal photo capture.
- Replaced hardcoded scan mock with server-ready JSON parsing:
  - `ServerFoodAnalysisService` posts image + plan context as JSON
  - food vision requests now use a typed AI function envelope (`food_vision_analysis`, schema `food_vision_analysis.v1`)
  - response decoding accepts both the typed envelope and the earlier bare PRD JSON shape
  - PRD-style response JSON maps into `FoodAnalysisResult`
  - local fallback keeps the app usable when endpoint is not configured
- Added in-app language switching:
  - English / Simplified Chinese setting in Me
  - language stored with SwiftData user settings
  - key onboarding, tab, Today, Scan, and Me strings localized
- Implemented Plan tab:
  - current plan
  - daily target and deficit
  - guardrails
  - advanced details collapsed by default
- Implemented Insights tab:
  - weekly balance
  - gentle weekly review
  - simple stat summaries
- Implemented Me tab:
  - profile summary
  - subscription entry
  - privacy, language, health, terms rows
- Added domain tests for calorie budget and mock food analysis service.
- Added local backend prototype under `Backend/`:
  - Python standard-library HTTP server
  - iOS-compatible `POST /api/ai/food-analysis`
  - smart scan classifier endpoint
  - super admin login and protected admin APIs
  - JSON file persistence for users, plans, settings, and AI logs
  - glass-style web super admin console at `/admin`

## V2.0 Body OS Upgrade Direction

The V2.0 upgrade changes the product from a scan-first diet prototype into AI Body OS:

- Lifestyle users: low-pressure fat-loss habit assistant.
- Advanced users: training, nutrition, recovery, cycle management system.
- Core loop: Profile -> State -> Cycle -> Nutrition Target -> Records -> Strategy -> AI Explanation -> Review.

Primary V2.0 task source:

- `v2.0/06_工程级_AI_Body_OS_V2.0_开发任务拆解.md`

## Next V2.0 Product Tasks

- Upgrade main navigation to Today, Scan, BodyLog, Progress, Me.
- Convert current Plan functionality into Goal/Cycle management instead of a standalone primary tab.
- Upgrade Today into the Body OS daily command center:
  - current state
  - nutrition summary
  - today strategy
  - quick scan
  - lifestyle/advanced display modes
- Build BodyLog:
  - lifestyle: weight, water, steps, meal records
  - advanced: nutrition, macros, workouts, sleep, water, supplements, measurements
- Build Progress:
  - lifestyle weekly completion, trend, stable behavior, next focus
  - advanced calories, protein, training, recovery, sleep, body trend
- Add Pro Plus feature gates for cycle management, recovery analysis, sleep analysis, AI training suggestions, and AI nutrition suggestions.

## Next V2.0 Technical Tasks

- Add Body OS Core models and protocols:
  - State Engine
  - Cycle Engine
  - Nutrition Engine
  - Recovery Engine
  - Strategy Engine
- Implement deterministic State/Nutrition/Strategy minimum viable engines before expanding UI.
- Add SwiftData models for V2.0 local persistence with `localDate` and `timezone`.
- Replace backend JSON persistence with Supabase/Postgres and RLS.
- Add Repository layer so SwiftUI views do not directly own storage or sync details.
- Split AI calls into typed JSON-schema functions:
  - onboarding profile extraction
  - natural language event parser
  - food vision analysis (request envelope implemented; schema-ready typed payload)
  - strategy explanation
  - weekly review generation
  - safety classification
- Configure real AI Gateway and keep AI as interpretation layer, not calculation engine.
- Add HealthKit integration for steps, active energy, sleep, heart rate, HRV, and workouts.
- Add StoreKit 2 subscription flow and entitlement sync.
- Expand tests for Body OS engines, API decoding, RLS, and main UI flows.

## Design Principles To Preserve

- Default UI is for ordinary lifestyle fat-loss users.
- Show one clear answer first, details only after expansion.
- Every recommendation must come from the current plan and calorie context.
- Avoid shame, punishment, and professional nutrition clutter.
- Use Liquid Glass for hierarchy and interaction, not as decoration over long text.
