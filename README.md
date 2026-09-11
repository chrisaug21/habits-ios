# Habits iOS

Native iOS companion to [Habits](https://habits.chrisaug.com) (the
`workout-tracker` repo). Phase 1: login, weight display/entry, Apple
HealthKit weight sync, and local push reminders — capabilities the existing
PWA can't offer on iOS. Not a rebuild of the whole app; see
[SPEC.md](./SPEC.md) for exact scope and [GETTING_STARTED.md](./GETTING_STARTED.md)
for the build process, step by step.

**Status:** pre-Xcode-scaffold — see GETTING_STARTED.md Phase 2. No app
exists yet; this repo currently holds planning docs only.

## Why a separate repo from `workout-tracker`

Same Supabase backend (same project, same tables, same user accounts) as
the web app — this is a second client, not a second system. Kept in its own
repo because Xcode's project tooling doesn't mix well with the web app's
JS/Netlify tooling, and the two have independent build/release pipelines
(App Store Connect vs. Netlify).

## Stack (planned)

- Swift, SwiftUI, Xcode
- Supabase (`supabase-swift` package) — same project as the web app
- No custom backend/API layer

## Credentials

Not yet wired in — see SPEC.md Phase 4. Will use the same Supabase project
URL and publishable (anon) key as `workout-tracker`'s `SUPABASE_URL` /
`SUPABASE_KEY` (documented in that repo's README). The anon key is meant to
be public by Supabase's design — it already ships inside the web app's
public JS bundle — so it doesn't need the same secrecy treatment a true
secret would.

## File structure

TBD — populate once the Xcode project is scaffolded.
