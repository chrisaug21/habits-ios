# Habits iOS — Phase 1 Spec

Companion doc: [GETTING_STARTED.md](./GETTING_STARTED.md) covers *how* to build this, step by step. This covers *what* to build.

## Naming: this product is being renamed to Ondoloop

The iOS app's public name is now **Ondoloop** (App Store subtitle: "Ondoloop:
The Habits App"), replacing the earlier working name "Habitude Loop." This
is a name change only, not a rescope — everything else in this spec still
applies.

Internal identifiers (Xcode target name, bundle ID `com.chrisaug.Habits`,
this repo's name `habits-ios`) are staying "Habits" — those are technical,
nobody-but-you-sees-them identifiers, unrelated to the public-facing name.

What's done so far: the iOS app's `CFBundleDisplayName`, in-app title text,
and HealthKit usage-description strings now say "Ondoloop."

What's **not** done, and may need to follow depending on how far this rename
goes:
- The **web app** (this doc's "Habits (web)" references below) is still
  branded "Habits" — its UI copy, page titles, and metadata haven't changed.
- The web app currently lives at **habits.chrisaug.com**. A rename would
  mean deciding whether that subdomain moves to the new **ondoloop.com**
  domain (not yet purchased) or stays as a redirect target.
- **ondoloop.com** needs to be purchased, and DNS/redirect behavior decided
  (e.g. does habits.chrisaug.com 301-redirect to ondoloop.com, or do both
  stay live pointing at the same app?).
- The logo assets in `Habits logo design/` (wordmark, lockups, app icon) all
  say "Habits" and need to be redone. The monogram specifically was designed
  around the letter H and no longer fits an "Ondoloop" identity — it needs a
  new direction, not just a re-label.
- Any other "Habits" references outside this repo (App Store Connect
  listing copy, TestFlight metadata, marketing pages, etc.) once they exist.

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
- **In-app account deletion** — users must be able to delete their account from within the app, not just by emailing you. Note: the client SDK's anon/publishable key can't delete a Supabase Auth user — this needs a server-side Edge Function using the service-role key, not a client-only change.
- **Privacy policy URL** — required for submission; scrutiny is higher for apps requesting HealthKit access (health data can't be used for ads/tracking, purpose must be clearly disclosed in both the policy and the permission prompt copy).
- App icon, screenshots, App Store description/metadata.

## Phase 8 — Today Screen (spec addendum, decided 2026-09-11)

The first of the phase 8 native screens (see GETTING_STARTED.md Phase 8).
Brings the web app's most-used screen — `today.js` — natively, as three
cards in one view.

**In scope:**

- **Workout rotation card**: shows the next-up workout (name, icon, "last
  done X days ago"), a "Done ✓" button, and a "Log other activity…" flow
  that can (a) log a *different* workout from the active list, (b) mark a
  rest day with an optional freeform reason — remembered as quick-tap chips
  for next time, or (c) log a free-text "other" activity — also remembered
  as chips. Includes "Undo" for the most recent action taken today or
  yesterday (matches web behavior, covers logging after midnight).
- **Journal card**: intention / gratitude / one-thing fields, one entry per
  day, edit-in-place. Includes the "you wrote something similar last week"
  gratitude nudge before saving.
- **Weight card**: the existing weight-entry functionality shown as a
  compact card (today's value, or a "Log Weight" button) rather than its
  own full screen — [WeightView.swift](Habits/Habits/WeightView.swift) stays
  as-is for the calendar/history view Log will need later.
- Respect the existing per-user `show_workout_card` / `show_journal_card` /
  `show_weight_card` toggles (read-only here — the settings UI to change
  them is a separate, not-yet-speced screen).
- Read the active workout rotation from `workout_library` / `user_rotation`
  if the user has customized it; otherwise fall back to the same default
  5-workout list/rotation the web app hardcodes in `app.js`.

**Data model** — new read/write access, all existing Supabase tables shared
with the web app, no schema changes:

```
history        (id, user_id, type, date, advanced, note, sequence)
state          (id, user_id, rotation_index, action_date)
journal        (date, intention, gratitude, one_thing, user_id)
                 -- unique on (date, user_id)
workout_library (id, name, category, icon, is_global, created_by)
user_rotation   (id, position, workout_id, user_id)
```

**Explicitly out of scope for this pass:**

- Editing the workout rotation/library itself (add/remove/reorder
  workouts) — that's a settings screen, not part of Today.
- Log, Stats, and Journal-as-its-own-history-view — the remaining phase 8
  steps, each gets its own spec addition when we get there.

**Decided (2026-09-11):**

1. **Undo window**: matches web behavior — an entry logged today or
   yesterday can be undone (covers logging after midnight).
2. **Rotation fallback**: mirrors the web app's hardcoded 5-workout default
   list/rotation (`app.js`'s `WORKOUTS`/`ROTATION`) when the user has no
   custom rotation in `user_rotation`.

## Later phases (not speced yet)

Log, Stats, and Journal-as-its-own-screen remain as additive native
screens after Today — working toward full feature parity with the web app,
at which point retiring the web app becomes a real option rather than a
plan. Each gets its own short spec addition when you get there, same
pattern as Today above.
