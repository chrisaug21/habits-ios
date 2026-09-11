# Habits iOS — Phase 1 Spec

Companion doc: [GETTING_STARTED.md](./GETTING_STARTED.md) covers *how* to build this, step by step. This covers *what* to build.

## Goal

A native iOS app for the existing Habits product that does three things a
PWA cannot do on iOS: read weight from Apple HealthKit automatically, send
real local push reminders, and give a genuinely native feel. It is **not** a
rebuild of the whole app — it reuses the existing Supabase backend and
existing user accounts as-is.

## Background / why this scope

Full context: Habits (web) is a solo-built PWA at habits.chrisaug.com,
backend is Supabase (Postgres + Auth), no separate API layer — the web app
talks to Supabase directly, and this iOS app will do the same, using the
**same Supabase project, same tables, same user accounts**. This is phase 1
of a longer-term plan: if it goes well, later phases add native
Today/Log/Stats/Journal screens working toward full feature parity, at which
point the web app could eventually be retired. Phase 1 deliberately stays
narrow because it's the first native iOS app being built here, and the goal
is to get through unfamiliar territory (Xcode, code signing, App Store
tooling) on the smallest possible surface before adding feature complexity.

## In scope (Phase 1)

1. **Login** — email/password against the existing Supabase Auth, same
   accounts as the web app. No new signup flow; if you don't already have an
   account, create one via the web app first.
2. **Weight display** — show recent weight entries (reuse the existing
   `weight` table: `date`, `value_lbs`, `user_id`).
3. **Manual weight entry** — same as web app today, in case HealthKit isn't
   available/connected on a given day.
4. **HealthKit weight sync** — read the latest body-mass sample(s) from
   Apple Health and write them into the same `weight` table the web app
   reads, so a value logged by your smart scale shows up in both the iOS
   app and the web app.
5. **Local push reminders** — a settable daily reminder ("log your weight"),
   scheduled entirely on-device (no server-side push infrastructure in
   phase 1).

## Explicitly out of scope (Phase 1)

- Today tab (workout/journal cards), Log (calendar/backfill), Stats
  (streaks, consistency, trend charts), Journal entries, workout rotations,
  workout programs. These stay on the web app for now — see "Later phases"
  below.
- New account signup flow (use the existing web signup).
- Remote/server-triggered push notifications (only local, device-scheduled
  reminders in phase 1).
- Any change to the web app itself.
- Public App Store submission (see "Before public App Store submission"
  below — deliberately deferred).

## Data model

No new tables required for weight sync — reuse exactly what exists:

```
weight (
  date       date,
  value_lbs  numeric,
  user_id    uuid references auth.users
)
-- unique/upsert key: (date, user_id) — matches the web app's existing
-- .upsert(..., { onConflict: 'date,user_id' }) behavior in today.js
```

**Decided (2026-09-11):** the reminder time is stored locally on-device via
`UserDefaults`, not in Supabase — no schema change needed. It only controls
a local notification firing on this device, so there's no cross-device sync
requirement for it.

## Open questions (need your decision before/while building)

1. **HealthKit vs. manual-entry conflict**: if a day already has a
   manually-entered weight (from the web app) and HealthKit also has a
   sample for that day, what wins?
   - *Option A*: HealthKit always overwrites manual entries for that day (simplest, matches "the scale is the source of truth").
   - *Option B*: Manual entries are never overwritten by HealthKit; HealthKit only fills in days with no existing entry.
   - *Option C*: Ask ("we found a Health value that differs from your logged value — use which?") — most correct, most engineering effort.
   - **Recommendation**: Option A for phase 1 (simplest, matches your stated use case of the smart scale being authoritative), revisit if it causes surprises.
2. **Multiple HealthKit samples per day** (e.g. weighed twice): use the
   most recent sample of the day, or an average? **Recommendation**: most recent.
3. **Sync trigger**: pull from HealthKit every time the app opens, or also
   sync in the background periodically (needs a HealthKit background
   delivery entitlement, more setup)? **Recommendation**: on-app-open only for phase 1; background sync is a fast follow if the foreground version feels laggy in practice.
4. **Reminder time default**: pick a sensible default (e.g. 8:00 PM) or
   require the user to set one before reminders activate? **Decided:** reminders start off; toggling on pre-fills 8:00 PM as a starting point, adjustable immediately via the time picker — no silent default-on.

## Non-functional requirements

- **Minimum iOS version**: target a recent-but-not-bleeding-edge floor (e.g. iOS 17) unless you have an older device to support.
- **Offline behavior**: match the existing web app rule — Supabase is the source of truth, no offline writes; show an error state if Supabase is unreachable rather than silently queuing (mirrors the "no destructive schema changes" / "no offline writes" rules already in the web app's CLAUDE.md).
- **HealthKit permission denied**: app must still function for manual entry and login; HealthKit sync silently becomes unavailable with a clear in-app indicator, not a crash or blocking error.
- **Notification permission denied**: reminder settings UI should show the disabled state clearly and link to iOS Settings rather than failing silently.

## Before public App Store submission (not needed for TestFlight-only use)

Flagging now so these don't surprise you later, but none of this blocks
phase 1 if you're staying on direct-install or TestFlight-internal:

- **Sign in with Apple** must be offered as a login option alongside email/password (Apple App Review requirement whenever third-party/standard account creation exists).
- **In-app account deletion** — users must be able to delete their account from within the app, not just by emailing you.
- **Privacy policy URL** — required for submission; scrutiny is higher for apps requesting HealthKit access (health data can't be used for ads/tracking, purpose must be clearly disclosed in both the policy and the permission prompt copy).
- App icon, screenshots, App Store description/metadata.

## Later phases (not speced yet)

If phase 1 goes well: Today, Log, Stats, and Journal as additive native
screens, working toward full feature parity with the web app — at which
point retiring the web app becomes a real option rather than a plan. Each
of these would get its own short spec when you get there, same pattern as
this one.
