# Habits iOS — Getting Started Walkthrough

This is the step-by-step process for building the Habits iOS app, phase 1
(login + weight tracking + Apple HealthKit sync + push reminders). It is
written for a first-time iOS builder leaning on Claude Code for the Swift
code. Every step is tagged with **who** does it and **where**:

- **[You · Mac]** — something you personally click/type on your Mac
- **[You · iPhone]** — something you personally do on your phone
- **[You · Web]** — something on a website (Apple Developer portal, GitHub, App Store Connect)
- **[Claude Code]** — code Claude writes/edits for you
- **[Both]** — Claude drafts it, you review/approve before it's used

Companion doc: [SPEC.md](./SPEC.md) covers *what* to build. This covers *how the process works*.

---

## A note on GitHub pushes vs. App Store/TestFlight builds

These come up constantly starting in Phase 2, so it's worth being explicit
up front: they are three separate, independent actions. Nothing in this
repo automatically triggers one from another.

- **Commit** — saves a snapshot to your local git history, on your Mac only. Nobody else sees it.
- **Push to GitHub** — uploads those commits to GitHub so they're backed up and (via a PR) mergeable into `main`. This is purely a code-storage/collaboration step — it does **not** build, install, or ship anything anywhere.
- **A new App Store/TestFlight build** (Phase 7+) — a separate, manual step: archive the app in Xcode, upload to App Store Connect, so people *other than you*, or on a device *not cabled to your Mac*, can install it.

When you're testing by running the app on your phone over a USB cable
(Phase 3 onward), that's Xcode talking directly to your phone — GitHub
isn't involved at all, pushed or not. Only bother cutting a new
TestFlight/App Store build when you need one of the things only it
provides: a tester without a cable to your Mac, someone other than you
testing, or validating the release pipeline itself.

---

## Phase 0 — Create the repo (do this first, before anything else)

The rule of thumb: **create the GitHub repo before you create the Xcode
project**, so the Xcode project is born already inside a folder connected to
GitHub, instead of you creating it somewhere random and having to relocate it
later (which breaks file references and is a headache to fix).

1. **[You or Claude Code · Web+Mac]** Create a new, empty GitHub repo — e.g. `habits-ios` — private (recommended, since it'll contain your Supabase project URL/keys during early setup even though those get moved to a secure config later). This can be `gh repo create habits-ios --private --clone` from the terminal, or done on github.com.
2. **[You or Claude Code · Mac]** This also creates the local folder (via `--clone`, it clones straight to `~/projects/habits-ios` or wherever you run it). If you didn't use `--clone`, `git clone` it to `~/projects/habits-ios`.
3. That empty, cloned folder is where everything else in this walkthrough happens.

*Why a separate repo from the `workout-tracker` (Habits web) repo:* Xcode's
project files and build tooling are a different ecosystem than your JS/HTML
web app, and keeping them separate means your Netlify deploys and any future
Xcode/TestFlight automation don't trip over each other. The two repos share
the same Supabase backend (same database, same user accounts) — they just
don't share a git history. See SPEC.md for how that connection works.

---

## Phase 0.5 — Apple accounts (start this in parallel, it can take a few days)

Identity verification for a paid Apple Developer account can take a couple of
days, so kick this off now rather than waiting until you need it.

1. **[You · Web]** If you don't already have one tied to your name (separate from a
   family-shared Apple ID, if applicable), make sure you have an Apple ID you're
   comfortable using for development — the one on your iPhone today works fine.
2. **[You · Web]** Enroll in the **Apple Developer Program** at
   developer.apple.com/programs — $99/year. Do this now because:
   - Push notifications require a paid membership (a free "personal team" account cannot use the Push Notifications capability at all).
   - It also removes the 7-day-reinstall limit that free accounts have for apps installed directly on your phone.
   - TestFlight and any future App Store submission need it too.
3. While that's processing, continue to Phase 1 — nothing below is blocked on this finishing, except Phase 6 (push notifications).

---

## Phase 1 — Install and set up Xcode

1. **[You · Mac]** Install **Xcode** from the Mac App Store (it's large, budget 30–60+ min depending on connection).
2. **[You · Mac]** Open Xcode once, accept the license agreement, and let it install additional components when prompted.
3. **[You · Mac]** Xcode → Settings → Accounts → add your Apple ID (the same one from Phase 0.5). This is what lets Xcode sign apps for your device.

---

## Phase 2 — Scaffold the Xcode project (one-time GUI step)

This is the one part of the process that has to happen through Xcode's own
interface rather than through Claude Code — Xcode project files have a
complex internal format that's meant to be generated by Xcode itself, not
hand-written. Once this scaffold exists, everything after this is normal
text-file editing Claude Code can do directly.

1. **[You · Mac]** Xcode → File → New → Project → iOS → **App**. Interface: **SwiftUI**. Language: **Swift**. Name it `Habits` (or similar).
2. **[You · Mac]** When Xcode asks where to save it, choose your cloned `habits-ios` folder from Phase 0 — this puts the project directly inside the git repo instead of somewhere you'd have to move later.
3. **[You · Mac]** Xcode generates the starter files. Commit this as-is:
   ```bash
   git add -A
   git commit -m "Scaffold Habits iOS app from Xcode template"
   git push
   ```
4. From here on, it's your normal flow: Claude edits files in this folder, you review the diff, commit, push, PR, merge — same as your web repos.

---

## Phase 3 — "Hello World" on your actual phone

This confirms the whole signing/install pipeline works before any real
feature code goes in — you want to hit this friction on the smallest
possible app.

1. **[You · Mac]** In Xcode, select your project in the file navigator → Signing & Capabilities tab → set **Team** to your Apple ID/Developer account. Xcode auto-generates a provisioning profile.
2. **[You · iPhone + Mac]** Plug your iPhone into your Mac with a cable (or same Wi-Fi network for wireless). On the phone, tap "Trust This Computer" if prompted.
3. **[You · Mac]** In Xcode's device dropdown (top toolbar), select your physical iPhone instead of a Simulator. Click **Run** (▶).
4. **[You · iPhone]** First install will fail to open with an "Untrusted Developer" warning. Go to **Settings → General → VPN & Device Management**, tap your Apple ID/developer profile, tap **Trust**. This is a one-time step per Apple ID per device.
5. **[You · iPhone]** Open the app from your home screen — you should see Xcode's default "Hello, world!" SwiftUI screen. That's milestone 1.

---

## Phase 4 — Connect Supabase + login screen

1. **[You · Mac]** In Xcode: File → Add Package Dependencies → paste `https://github.com/supabase/supabase-swift` → add the package. (This is Xcode's equivalent of `npm install`.)
2. **[Claude Code]** Writes the Swift code for a login screen using the **same Supabase project URL and anon key** your Habits web app already uses (from `workout-tracker`'s environment variables) — so you log in with the exact account you already have, no new signup flow needed.
3. **[Both]** You'll need to tell Claude Code (once) the Supabase URL and anon key so it can wire them in — treat the anon key the same way you already do in the web app (it's the public client key, not a secret).
4. **[You · iPhone]** Run the app, log in with your existing Habits account, confirm it authenticates. Milestone 2.

---

## Phase 5 — HealthKit weight read + sync to Supabase

1. **[You · Mac]** Xcode → Signing & Capabilities → **+ Capability** → add **HealthKit**.
2. **[Claude Code]** Adds the required `NSHealthShareUsageDescription` text to the project's Info settings (the sentence iOS shows you when it asks permission — you should read/approve the actual wording since it's user-facing).
3. **[Claude Code]** Writes the Swift code that:
   - Requests read permission for body mass (weight) from HealthKit
   - Reads the latest sample(s)
   - Writes them into the same `weight` table your web app already uses (`date`, `value_lbs`, `user_id`), the same way the web app does (see SPEC.md for the upsert/conflict behavior)
4. **[You · iPhone]** Grant the HealthKit permission prompt when it appears.
5. **[You · iPhone]** Confirm: log/sync a weight in the Health app (or let your smart scale sync one in), open the Habits iOS app, confirm it appears — then check the **web app** shows the same value. Milestone 3.

---

## Phase 6 — Local push reminders

Starting with **local notifications** (scheduled entirely on-device) rather
than true remote push — no server-side piece needed, and it's sufficient for
"remind me daily at 8pm to log my weight."

1. **[Claude Code]** Writes the Swift code for: a permission-request prompt, a reminder toggle + time picker in the Weight screen, and scheduling a local notification via `UNUserNotificationCenter`. No Xcode capability step needed here — that's only required for true remote push (APNs); local, on-device notifications just need the runtime permission prompt below.
2. **[You · iPhone]** Toggle the reminder on, grant the notification permission prompt, confirm a time, background the app, and confirm the notification fires at that time (default 8:00 PM, adjustable immediately). Milestone 4.

---

## Phase 7 — TestFlight soft launch

This is the "share it with just yourself, no App Review" step you said you're comfortable with.

**Before you start:** unlike every phase so far, this one needs a real app
icon — Apple's upload validation checks for one, where Xcode's Run/Debug
never did. Any 1024×1024 square PNG technically satisfies it; it doesn't
need to be polished, you can swap it for something real later, before ever
going public.

1. **[You · Mac]** Get a 1024×1024 PNG (anything square works for now — even a plain color). In Xcode, open `Assets.xcassets` → click **AppIcon** → drag your PNG into the single icon slot.
2. **[You · Web]** Go to appstoreconnect.apple.com → **My Apps** → **+** → **New App**. Fill in: Platform **iOS**; **Name** (must be globally unique across the entire App Store — plain "Habits" may already be taken by someone else's app; have a backup like "Habits – Chris" ready); Primary language; **Bundle ID** (pick `com.chrisaug.Habits` from the dropdown — it should already be listed, since Xcode registered it with your Developer account back in Phase 2); **SKU** (any unique string you make up, e.g. `habits-ios-001` — internal only, users never see it).
3. **[You · Mac]** Back in Xcode: Product → **Archive**. Builds a release version and opens the Organizer window when done.
4. **[You · Mac]** In Organizer, select the archive → **Distribute App** → **App Store Connect** → **Upload**. Defaults are fine through the rest of the prompts. (Requires the paid Developer account from Phase 0.5.)
5. **[You · Web]** Back in App Store Connect, wait for the build to finish processing — usually 10-30 min, sometimes longer the first time. You'll get an email, or just refresh the TestFlight tab on your app's page.
6. **[You · Web]** App Store Connect → your app → **TestFlight** tab → add yourself as an **internal tester** (your own Apple ID/email).
7. **[You · iPhone]** Install the **TestFlight** app from the App Store if you don't have it, accept the invite (email or notification), install your build from there.
8. No Apple review happens for internal testers — this is your fastest "real device, real distribution mechanism" loop short of a cable.

---

## Phase 8 — Full feature parity (Today, Log, Stats, Journal)

Per the decision to eventually replace the web app rather than run both
long-term, each remaining web feature becomes its own native screen.
Rather than building all four at once, treat each like phase 1 was treated:
scope it briefly, build it, test on your device, commit — one at a time.

Suggested order (roughly matches how central each feature is to daily use):

1. **Today** — the daily workout/journal/weight home screen. Reference: `today.js` in the `habits` (web) repo.
2. **Log** — calendar view + backfill. Reference: `log.js`.
3. **Stats** — streaks, consistency, weight trend chart. Reference: `stats.js`.
4. **Journal** — intention/gratitude entries. Reference: the journal-related code in `data.js`/`today.js`.

For each: **[Both]** write a short spec addition first — a paragraph added
to SPEC.md is enough, it doesn't need its own document — before writing any
code. Scope creep is the main risk once you're not following a pre-written
plan the way phase 1 was.

Once all four are live natively and you've used the iOS app as your daily
driver for a while with no regressions, that's your real signal to retire
the web app — not a fixed date.

---

## Phase 9 — Branding consistency (before going public)

- **[You + Claude Design]** Redo the icon/wordmark artwork to say
  "Habitude Loop" (or whatever name you land on), replacing the placeholder
  PNG from Phase 7.
- No Xcode-side renaming needed beyond the icon image itself — the internal
  product name, bundle ID (`com.chrisaug.Habits`), and target name can all
  stay "Habits" forever. Those are technical identifiers nobody but you
  ever sees; they're unrelated to the public-facing name.
- **[You · Mac]** Swap the new icon into `Assets.xcassets` → AppIcon the
  same way you did the placeholder in Phase 7.

---

## Phase 10 — Public App Store submission

This is the phase SPEC.md's "Before public App Store submission" section
previewed. Apple's exact requirements shift over time and App Store
Connect will walk you through whatever's current at submission time, but
here's what to expect:

1. **[Claude Code]** Add **Sign in with Apple** as a login option alongside
   email/password — required by Apple review whenever an app offers other
   account-creation methods. This is another Xcode capability (like
   HealthKit) plus Swift code; treat it as its own mini-phase when you get
   here.
2. **[Both]** Add in-app account deletion. Real gotcha worth knowing now:
   deleting a Supabase Auth user typically can't be done from the client
   SDK — the anon/publishable key doesn't have permission — it needs a
   small server-side Supabase Edge Function using the service-role key,
   similar to the Edge Functions your other apps already use for
   privileged operations. This isn't a client-only Swift change.
3. **[You]** Write and host a privacy policy — a simple static page works;
   any of your existing Netlify sites can host it. Needs specific language
   about HealthKit data given Apple's extra scrutiny there (no ads/tracking
   use, clearly disclosed purpose).
4. **[You · Mac]** Prepare App Store screenshots on whatever device sizes
   Apple currently requires — Xcode's Simulator can generate these, no need
   to screenshot your physical phone.
5. **[You · Web]** Fill in App Store Connect's listing metadata:
   description, keywords, support URL, age rating questionnaire, export
   compliance questionnaire (usually "No" for an app not implementing
   custom encryption beyond standard HTTPS — confirm this is still true for
   your build before answering).
6. **[You · Web]** Submit for review. Typical turnaround is 24-48 hours; a
   rejection just means fixing the flagged issue and resubmitting, not
   starting over.
