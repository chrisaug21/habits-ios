# CLAUDE.md — Habits iOS (project-specific overrides)

> Global instructions live in ~/.claude/CLAUDE.md. This file adds
> habits-ios-specific context only.

## Project overview
Native iOS companion to the Habits PWA (repo: `workout-tracker`, live at
https://habits.chrisaug.com). Phase 1 scope: login, weight display/entry,
Apple HealthKit weight sync, local push reminders. Full requirements live in
[SPEC.md](./SPEC.md); the build process is in [GETTING_STARTED.md](./GETTING_STARTED.md) —
read both before making scope decisions.

## Stack
- Swift, SwiftUI, Xcode
- Supabase (backend + auth) via the `supabase-swift` package — same
  Supabase project as the web app, same tables, same user accounts
- No custom backend/API layer, same as the web app

## Architecture rules
- Supabase is the source of truth for all writes — same rule as the web app
- The `weight` table (`date`, `value_lbs`, `user_id`, unique on `date,user_id`)
  is shared with the web app — do not change its shape without also
  considering the web app's `today.js`, which reads/writes the same table
- No destructive schema changes without explicit instruction — a schema
  change here affects the web app too
- Explain SQL migrations clearly before running them
- Preserve RLS policies after any auth-related changes
- If Supabase is unreachable, show a clear error state — no offline writes
  (matches the web app's behavior; phase 1 has no offline queueing)
- HealthKit access is **read-only** in phase 1 — do not add write-back to
  Apple Health without explicit instruction
- Reminders are **local notifications only** in phase 1 — no remote/push
  server infrastructure without explicit instruction
- Do not add third-party frameworks/dependencies beyond `supabase-swift`
  without explicit approval — same "stay simple" philosophy as the web app

## File structure
TBD — populate this once the Xcode project is scaffolded (GETTING_STARTED.md
Phase 2). Update this section then so future sessions don't have to
rediscover the layout.

## Versioning
TBD — once the Xcode project exists, this section should specify: bump the
Marketing Version / Build number in Xcode's target settings before every
push that changes app behavior, mirroring the same discipline the web app
applies to its `VERSION` constant (see the global CLAUDE.md's version
discipline rule, which still applies here).

## Pre-push checklist
1. Bump Marketing Version / Build number in Xcode (once applicable — see Versioning above)
2. Confirm the app builds and runs on device or simulator
3. Update SPEC.md if scope or requirements changed
4. Update README.md if setup steps or features changed
5. Update AGENTS.md if new patterns or gotchas were discovered
