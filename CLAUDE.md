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
- Swift Charts (first-party, ships with iOS — not a new dependency) for the
  Stats screen's weight trend chart
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
The Xcode project has two version fields, both in the `Habits` target →
**General** tab → **Identity** section:

- **Build number** (`CURRENT_PROJECT_VERSION`, currently `11`) — bump by 1
  before every push that changes app behavior. No judgment call needed:
  always increment, same discipline as the web app's `VERSION` constant
  (global CLAUDE.md's version discipline rule). Apple also requires every
  TestFlight/App Store upload to have a unique build number, so an
  always-incrementing counter avoids surprises there too.
- **Marketing Version** (`MARKETING_VERSION`, currently `1.1`) — the
  user-facing version. Bump deliberately at real milestones (finishing a
  Phase 8 screen, cutting a real TestFlight/App Store build) rather than on
  every push — pushing to GitHub alone never requires a Marketing Version
  bump, since it doesn't ship anything (see the GitHub-vs-App-Store note in
  [GETTING_STARTED.md](./GETTING_STARTED.md)).

### On-screen version footer
Every screen shows a small `v{MARKETING_VERSION}.{BUILD}` readout at the
bottom (e.g. `v1.0.8`), via `HabitsVersionFooter` in
[Theme.swift](./Habits/Habits/Theme.swift). This mirrors the web app's x.x.x
look while staying tied to the two Xcode fields above instead of a third,
separately-maintained version string:
- The first two components are `MARKETING_VERSION` as-is (already
  major.minor, e.g. `1.0`).
- The third component is the build number (`CURRENT_PROJECT_VERSION`).

It's a live readout of `Bundle.main.infoDictionary` (`CFBundleShortVersionString`
/ `CFBundleVersion`), not a hardcoded string — so it stays in sync with those
two fields automatically, with nothing to update by hand beyond following
the two bump rules above. Add `HabitsVersionFooter()` to the bottom of any new screen's
content (pass `color: .secondary` on a screen that hasn't opted into the
app's dark theme, like Settings currently hasn't).

## Pre-push checklist
1. Bump Marketing Version / Build number in Xcode (once applicable — see Versioning above)
2. Confirm the app builds and runs on device or simulator
3. Update SPEC.md if scope or requirements changed
4. Update README.md if setup steps or features changed
5. Update AGENTS.md if new patterns or gotchas were discovered
