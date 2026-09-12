# AGENTS.md — Habits iOS (project-specific overrides)

> Global instructions live in ~/.codex/AGENTS.md. This file adds
> habits-ios-specific context only.

## Project overview
Native iOS companion to the Habits PWA (repo: `workout-tracker`, live at
https://habits.chrisaug.com). Phase 1 scope: login, weight display/entry,
Apple HealthKit weight sync, local push reminders. Full requirements live in
SPEC.md; the build process is in GETTING_STARTED.md — read both before
making scope decisions.

## Stack
- Swift, SwiftUI, Xcode
- Supabase (backend + auth) via `supabase-swift` — same Supabase project as
  the web app, same tables, same user accounts
- Swift Charts (first-party, ships with iOS — not a new dependency) for the
  Stats screen's weight trend chart
- No custom backend/API layer, same as the web app

## Architecture rules
- Supabase is the source of truth for all writes
- The `weight` table (`date`, `value_lbs`, `user_id`, unique on `date,user_id`)
  is shared with the web app — a schema change here affects `workout-tracker`'s
  `today.js` too
- No destructive schema changes without explicit instruction
- Explain SQL migrations clearly before running
- Preserve RLS policies after any auth-related changes
- If Supabase is unreachable, show a clear error state — no offline writes
- HealthKit access is read-only in phase 1 — no write-back to Apple Health
  without explicit instruction
- Reminders are local notifications only in phase 1 — no remote/push
  server without explicit instruction
- Do not add dependencies beyond `supabase-swift` without explicit approval

## File structure
TBD — populate once the Xcode project is scaffolded (GETTING_STARTED.md Phase 2).

## Versioning
Two fields, both in the `Habits` target → General tab → Identity section:

- Build number (`CURRENT_PROJECT_VERSION`, currently `10`) — bump by 1
  before every push that changes app behavior. Always increment, no
  judgment call, same discipline as the web app's `VERSION` constant. Apple
  also requires a unique build number per TestFlight/App Store upload.
- Marketing Version (`MARKETING_VERSION`, currently `1.1`) — the
  user-facing version. Bump at real milestones (a Phase 8 screen shipping,
  a real TestFlight/App Store build) — not on every GitHub push, since a
  push alone doesn't ship anything (see GETTING_STARTED.md's GitHub-vs-App
  Store note).

### On-screen version footer
Every screen shows a small `v{MARKETING_VERSION}.{BUILD}` readout at the
bottom (e.g. `v1.0.8`), via `HabitsVersionFooter` in `Theme.swift`. Mirrors
the web app's x.x.x look while staying tied to the two Xcode fields above
instead of a third, separately-maintained version string: the first two
components are `MARKETING_VERSION` as-is, the third is the build number.
It's a live readout of `Bundle.main.infoDictionary`, not a hardcoded
string — nothing to update by hand beyond the two bump rules above. Add
`HabitsVersionFooter()` to any new screen's content (pass `color:
.secondary` on a screen that hasn't opted into the app's dark theme, like
Settings currently hasn't).

## Pre-push checklist
1. Bump Marketing Version / Build number in Xcode (once applicable)
2. Confirm the app builds and runs on device or simulator
3. Update SPEC.md if scope or requirements changed
4. Update README.md if setup steps or features changed
5. Update AGENTS.md if new patterns or gotchas were discovered
