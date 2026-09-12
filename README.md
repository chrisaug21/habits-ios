# Habits iOS

Native iOS companion to [Habits](https://habits.chrisaug.com) (the
`workout-tracker` repo). Reuses the existing Supabase backend, tables, and
user accounts as-is — this is a second client, not a second system. See
[SPEC.md](./SPEC.md) for exact scope and [GETTING_STARTED.md](./GETTING_STARTED.md)
for the build process, step by step.

**Status:** Phase 1 (login, weight, HealthKit sync, local reminders) is
done. Phase 8 (native Today/Log/Stats/Journal screens, working toward full
feature parity with the web app) is in progress — Today, Log, and Stats are
live; Journal is the remaining step. See SPEC.md for what each screen
covers and GETTING_STARTED.md's Phase 8 section for the plan.

## Why a separate repo from `workout-tracker`

Same Supabase backend (same project, same tables, same user accounts) as
the web app — this is a second client, not a second system. Kept in its own
repo because Xcode's project tooling doesn't mix well with the web app's
JS/Netlify tooling, and the two have independent build/release pipelines
(App Store Connect vs. Netlify).

## Stack

- Swift, SwiftUI, Xcode
- Supabase (`supabase-swift` package) — same project as the web app
- Swift Charts (first-party, ships with iOS) — used by the Stats screen
- No custom backend/API layer

## Credentials

Uses the same Supabase project URL and publishable (anon) key as
`workout-tracker`'s `SUPABASE_URL` / `SUPABASE_KEY` (documented in that
repo's README), configured in [SupabaseConfig.swift](./Habits/Habits/SupabaseConfig.swift).
The anon key is meant to be public by Supabase's design — it already ships
inside the web app's public JS bundle — so it doesn't need the same secrecy
treatment a true secret would.

## File structure

All app code lives under `Habits/Habits/`:

- `HabitsApp.swift` — app entry point
- `ContentView.swift` — root view; routes to login or the signed-in tab bar
- `SupabaseConfig.swift` / `SupabaseManager.swift` — Supabase client setup
- `AuthViewModel.swift` / `LoginView.swift` — email/password auth
- `Theme.swift` — shared colors, button styles, card/pill/sheet modifiers,
  the version footer — mirrors the web app's dark theme
- **Today tab:** `TodayView.swift`, `TodayViewModel.swift`, `TodayModels.swift`
  (workout rotation, journal, weight card)
- **Log tab:** `LogView.swift` (calendar/list/schedule sub-views, backfill —
  reuses `TodayViewModel`, since it's the same rotation/history domain)
- **Stats tab:** `StatsView.swift`, `StatsViewModel.swift` (streaks,
  consistency, workouts-by-type, weight trend chart)
- **Settings tab:** `SettingsView.swift` (HealthKit sync, reminder toggle,
  sign out — a stub until Settings gets its own spec pass)
- `WeightViewModel.swift` — shared weight read/write logic used by Today,
  Log's backfill sheet, and Settings' HealthKit sync
- `HealthKitManager.swift` / `ReminderManager.swift` / `ReminderViewModel.swift`
  — HealthKit read access and local notification scheduling

## Versioning

See CLAUDE.md/AGENTS.md's Versioning section for the build number /
Marketing Version bump rules — both live in the `Habits` target's
**General → Identity** tab in Xcode.
