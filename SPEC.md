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
  own full screen. *(Updated by the Log addendum below: the standalone
  Weight tab this card's logic originally lived in has since become
  [SettingsView.swift](Habits/Habits/SettingsView.swift); weight history
  moved to Log's calendar.)*
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

## Phase 8 — Log Screen (spec addendum, decided 2026-09-12)

The second phase 8 native screen. Brings the web app's `log.js` natively —
calendar with backfill, plus its List and Schedule sub-views — as a new
third tab.

**In scope:**

- **Tab bar change**: adds `LogView` as a third tab (Today, Log, Settings).
  The old standalone Weight tab is retired — see "Weight tab retirement"
  below.
- **Calendar sub-view**: month grid, prev/next navigation. Past/today days
  with a logged entry show its icon (workout/rest/other); future (and
  not-yet-logged today) days show the *projected* rotation workout at
  reduced opacity, computed the same way as the web app's
  `buildProjectionMap` — walk forward from today assigning the next
  rotation workout to every day without a history entry, without mutating
  the stored rotation index. Small dots mark days with a journal entry or a
  weight entry. Tapping a **past** day (not today, not future) opens the
  backfill sheet.
- **List sub-view**: all history entries, reverse chronological. Read-only,
  no tap-to-backfill — matches the web app (only calendar cells are
  interactive there).
- **Schedule sub-view**: next 14 days' projected rotation workouts, read-only.
- **Backfill sheet**: for a selected past date —
  - Read-only summary: current exercise entry (or "No exercise logged"),
    current weight (or "No weight logged"), and journal fields if any exist
    for that date (**read-only** — no journal editing here, matches Today's
    journal scope of "today only").
  - "Add/Edit Exercise" switches to an option list (active rotation
    workouts + Rest Day + Other Activity, single flat list matching the web
    app's `getBackfillOptions()`) with an optional note field (reusing the
    same recent-chips store as Today's skip/other flows) and Save/Cancel.
  - "Add/Edit Weight" switches to a numeric entry field and Save/Cancel,
    upserting `weight` for that specific date (`date,user_id` unique
    constraint already handles edit-vs-insert).
  - Saving an exercise re-runs the same rotation-advance/rewind math as the
    web app's `confirmBackfill` (see `TodayViewModel.backfillLogEntry`):
    only advances the rotation index if this is the most recent
    rotation-relevant entry, and adjusts the index when editing a past
    entry changes whether it was rotation-advancing.

**Weight tab retirement (decided 2026-09-12):** now that weight history is
visible in Log's calendar and daily weight entry lives on Today's weight
card, the old Weight tab's "Recent" list and "Add Weight Manually" button
are removed outright (no replacement in this pass — they return, in a
different form, when Stats is built next). What's left of that tab
(HealthKit sync, the daily reminder toggle, Sign Out) becomes a stubbed-out
**Settings** tab (`SettingsView.swift`) — a placeholder until Settings gets
its own real spec pass.

**Data model** — same tables as Today, no schema changes:

```
history        (id, user_id, type, date, advanced, note, sequence)
state          (id, user_id, rotation_index, action_date)
journal        (date, intention, gratitude, one_thing, user_id)
workout_library (id, name, category, icon, is_global, created_by)
user_rotation   (id, position, workout_id, user_id)
weight          (date, value_lbs, user_id) -- unique on (date, user_id)
```

**Explicitly out of scope for this pass:**

- Editing journal entries from the backfill sheet (display only).
- A real Settings screen (notifications preferences beyond the one
  reminder toggle, account management, etc.) — today's Settings tab is
  intentionally a stub.
- Stats and Journal-as-its-own-history-view — the remaining phase 8 steps.

**Known limitation carried over from Today:** Log and Today each own an
independent `TodayViewModel`/`WeightViewModel` instance (same pattern as
the old Today/Weight split) — a backfill edit made in Log won't be visible
in Today until Today's tab is reloaded (pull-to-refresh, or relaunch).
Fixing this would mean sharing state across tabs, which is a bigger
architectural change than this pass — worth revisiting if it's annoying in
daily use.

## Phase 8 — Stats Screen (spec addendum, decided 2026-09-12)

The third phase 8 native screen. Brings the web app's `stats.js` natively
as a new fourth tab, read-only (no writes at all in this pass).

**In scope:**

- **Tab bar change**: adds `StatsView` as a new tab, inserted between Log
  and Settings (Today, Log, Stats, Settings).
- **Range toggle**: Last 7 Days / Last 30 Days / All Time, defaults to 30
  days — matches the web app's default.
- **Total Workouts card**: count of history entries in the selected range,
  excluding rest days (`type == "off"`).
- **Streaks card**: current streak and longest streak, both computed over
  *all* history regardless of the range toggle — matches the web app
  (`computeCurrentStreak`/`computeLongestStreak` in `stats.js` don't take
  the range into account, only the Total Workouts / by-type breakdown do).
- **Consistency card**: distinct workout days ÷ days-in-range, as a
  percentage. For "All Time", the denominator is days since the first-ever
  history entry (inclusive) rather than a fixed number.
- **Workouts by Type card**: a bar per active rotation workout (name, icon,
  "last done" pill using the same color rules as Today/Log, count/bar
  scaled to the largest bar), plus an expandable "Other" row listing
  one-off activities (date + note) for anything outside the active
  rotation — matches the web app's collapsible `#stats-other-row`.
- **Weight trend chart**: raw weight points, a 7-day rolling average line,
  and a smoothed trend line (a rolling average of the rolling average) —
  same math as `computeRollingSeries` in `app.js`, filtered to the selected
  range. Built with Apple's native Swift Charts framework (`import Charts`)
  — first-party, ships with iOS, not a new third-party dependency. Shows an
  empty state below 2 data points, matching the web app.
- Reads the active workout rotation the same way Today/Log do:
  `user_rotation`/`workout_library` if customized, otherwise the hardcoded
  default 5-workout list.

**Data model** — read-only, same tables as Today/Log, no schema changes,
no new writes:

```
history        (id, user_id, type, date, advanced, note, sequence)
workout_library (id, name, category, icon, is_global, created_by)
user_rotation   (id, position, workout_id, user_id)
weight          (date, value_lbs, user_id)
```

**Explicitly out of scope for this pass:**

- Any editing — Stats is purely a read-only summary view.
- Journal-as-its-own-history-view — the remaining phase 8 step.

**Known limitation carried over from Today/Log:** Stats owns its own
independent data fetch (same pattern as Today/Log/Settings each owning
their own `TodayViewModel`/`WeightViewModel` instance) — a backfill made in
Log won't be reflected in Stats until Stats is reloaded (pull-to-refresh,
or switching tabs back).

## Phase 8 — Settings Screen (spec addendum, decided 2026-09-12)

Builds out the rest of `SettingsView.swift`, which since the Log addendum
has only been a stub (HealthKit sync, the reminder toggle, Sign Out).
Brings the web app's `settings.js` natively. Unlike Today/Log/Stats, this
is big enough to span **three passes** rather than one PR, because one
piece (onboarding) structurally depends on another (the rotation builder)
that hasn't been built yet:

1. **Pass 1** (below, done — PR #6): Account, Today Tab toggles, Feedback,
   Account deletion — none of these depend on anything not already built.
2. **Pass 2** (see addendum below, done — PR #7): Workout Sequence builder —
   reorder/add/remove workouts, custom workouts, reset to a starter program.
   The biggest single piece of `settings.js`; fully self-contained.
3. **Pass 3** (not yet built): Onboarding/FTUX replay ("Tutorial") — in the
   web app this reuses the same program-picker/rotation-builder screens
   (`renderOnboardingStep`, `openCustomBuilderFromFtux`), so it's built
   after pass 2 exists rather than duplicating that UI ahead of it.

**In scope for this pass:**

- **Account section**: signed-in email (read-only, from the session),
  editable first/last name, and change password. Name and password are
  Supabase Auth user metadata/credentials (`auth.updateUser`), **not** a
  database table — matches the web app exactly, no schema involved.
  Simplification from web: iOS uses always-editable fields with a single
  Save button rather than the web's separate view/edit-mode toggle
  (`settingsProfileEditing`) — standard native Settings-form pattern,
  same end result.
- **Today Tab toggles**: show/hide the Workout, Journal, and Weight cards
  on Today — read-write here, backed by the existing `user_preferences`
  table and the `UserPreferencesRow`/`UserPreferencesUpsertPayload` models
  already defined in `TodayModels.swift` for Today's read-only display.
- **Feedback**: web's version posts to a Netlify form, which is
  Netlify-specific infra with no iOS equivalent. Replaced with a `mailto:`
  link (pre-filled subject/body) rather than porting form-submission
  infrastructure for what is, for a single-user app, just a note to
  yourself.
- **Account deletion**: mirrors what the web app *actually* does today,
  not the theoretical ideal — the client's publishable key can't call
  `auth.admin.deleteUser`, so the web app already falls back to: delete
  the user's rows from `history`, `journal`, `weight`, `state`, and
  `user_preferences`, then flag the account via `auth.updateUser` metadata
  (`deletion_requested_at`/`_email`/`_name`), then sign out. Same fallback
  here — a true Auth-user delete via Edge Function is still the
  before-App-Store-submission item noted above, unchanged.
- Existing HealthKit sync, reminder toggle, and Sign Out stay as-is.

**Explicitly out of scope for this pass:**

- Workout Sequence builder and Onboarding/FTUX (passes 2 and 3 above).
- Web's "Sync" button (`syncAllData`) — that's cache-invalidation for the
  web app's local storage cache, which the iOS app doesn't have (each
  screen's view model fetches fresh from Supabase); no native equivalent
  needed.
- Real (non-fallback) account deletion — needs the server-side Edge
  Function already flagged under "Before public App Store submission".

**Data model** — no schema changes; reuses `user_preferences` (already
modeled) plus Supabase Auth's built-in user metadata/password, and
deletes rows (no new tables) from `history`/`journal`/`weight`/`state`/
`user_preferences` on account deletion:

```
user_preferences (user_id, show_workout_card, show_journal_card, show_weight_card)
-- + Supabase Auth: user.email, user.user_metadata.{first_name,last_name}, password
```

## Phase 8 — Settings Screen, pass 2: Workout Sequence builder (spec addendum, decided 2026-09-13)

Pass 2 of the Settings addendum above. Brings the web app's rotation-builder
and program-picker (`settings.js`) natively.

**In scope:**

- Read-only summary card on Settings showing the current sequence (custom
  `user_rotation`, or the hardcoded default list if none saved yet), with
  "Customize My Sequence"/"Edit Sequence" and "Reset to a Program" actions.
- **Builder sheet**: reorder (drag), add from the workout library (grouped
  "Global" vs "Your Workouts"), remove (down to a 2-workout minimum), and add
  a custom workout (name + category) — saved to `workout_library` and
  appended to the sequence in one step, matching the web app's "Add your
  own" flow. Saves the whole sequence in one shot via the same
  `save_user_rotation` RPC the web app calls (atomic replace of the user's
  `user_rotation` rows), then resets rotation progress
  (`state.rotation_index` back to 0) so "next up" starts from the top of the
  new sequence.
- **Program reset sheet**: pick from the shared `programs` table's starter
  programs (global or user-created) to replace the current sequence
  wholesale, behind a destructive-action confirmation ("this cannot be
  undone"); or hand off to the builder sheet to build one from scratch
  instead.
- The hardcoded default rotation's ids (`"peloton"`, `"upper_push"`, etc., in
  `DefaultWorkouts`) predate `workout_library` and were never real rows
  there — the builder resolves each one against its matching global
  `workout_library` row by name before staging it, rather than staging an
  id nothing can look up.

**Data model** — new read/write access to two tables the web app already
has, no schema changes:

```
programs         (id, name, description, is_global, created_by)
program_workouts (id, program_id, workout_id, position)
```
Reuses `workout_library`/`user_rotation` (already modeled above) and the
existing `save_user_rotation` Postgres RPC.

**Explicitly out of scope for this pass:**

- Onboarding/FTUX replay (pass 3 above) — still pending; reuses this
  builder's UI once built.
- A single-transaction replace-and-reset RPC. The sequence-save and
  progress-reset are two separate writes, ordered so a failure between them
  leaves progress reset against the *still-current* sequence rather than
  paired with the new one — a real gap, but a narrow one, and closing it
  fully means changing a function the web app also calls. Deferred rather
  than done unilaterally.

## Later phases (not speced yet)

Journal-as-its-own-screen remains as an additive native screen after
Stats and Settings — working toward full feature parity with the web app,
at which point retiring the web app becomes a real option rather than a
plan. Gets its own short spec addition when you get there, same pattern
as Today, Log, Stats, and Settings above.
