# Run With — Engineering Context

*Handoff document. Written for a fresh chat with no history of this project. Read it fully before writing code.*

---

## 0. The one decision to confirm before scaffolding anything

**Do not generate a project skeleton until the human confirms the client stack.** The
recommendation below is considered, not arbitrary, but it's a one-way door and it's theirs to
walk through.

**Recommended: native Swift/SwiftUI for iOS first, with the backend and data format designed
so Android is a clean second client rather than a rewrite.**

Reasoning — the product thesis is *the body actually did the work*. Sensor fidelity and audio
timing are not implementation details here, they **are** the product. Those are precisely the
areas where React Native, Expo, and Flutter are weakest: background motion updates, audio
session category control, and sub-second scheduling all end up in custom native modules
anyway. If you're going to write native code for the hard 30%, write the whole thing native and
skip the bridge.

The cost is honest: Android becomes a second implementation, not a checkbox. The mitigation is
that the *durable* assets — the artifact JSON schema, the backend, the condition/effort model —
are platform-neutral by design (see §4, §6). A future Android client reimplements the sensor
and audio layer only.

**Alternatives worth naming if the human pushes back:**

- **Expo / React Native** — meaningfully faster to a TestFlight build, one codebase, good if
  reaching friends *this month* matters more than sensor quality. Expect to write native
  modules for background pedometer and audio ducking.
- **Kotlin Multiplatform** — share domain logic (effort model, artifact parsing, condition
  evaluation), keep UI and sensors native per platform. The best long-term shape if Android is
  a firm commitment rather than a maybe. Higher setup cost now.

Ask which they want. Don't assume.

---

## 1. What this is

A platform for channeling the delight that lives behind screens — anime, games, fandom — into
the body, as a reason to move. Not fitness rebranded.

**The idea that holds everything together: the embodiment gate.** You cannot access the data,
the voice, the reward, or the music without your body having actually done the work. It shows
up on four layers — viewing, authoring, reward, and the ghost's own gait. When a new feature is
proposed, check whether it's the gate wearing a new costume. If it is, protect it. If it
quietly removes the gate, it's probably wrong even when it's convenient.

The name is incomplete by design. You're always running *with* something; the sentence finishes
in the reader's head.

### Artifact taxonomy — this vocabulary is load-bearing, use it exactly

- **Route** — geofenced. Fixed ground, tethered to real coordinates.
- **Run** — portable, person-shaped. Defined by *effort*, not place. This is the shareable atom.
- **Event** — a Route or a Run opened to other people within a time window.

You author the first two. You activate the third.

### Why people use it — two stages, sequenced, not ranked

The **character** (the oshi, the fandom avatar) lowers the activation energy to start — it gets
the shoes on. The **authenticity** (a friend's real gasped voice, a clip that couldn't have been
recorded from a couch) is why anyone stays. Gateway and retention. The avatars are the door, not
decoration.

---

## 2. Where the project actually stands

Three standalone web prototypes exist in this repo. They are **research instruments**, not a
codebase to port. Each isolates exactly one unknown.

| File | Question it answers | Status |
|---|---|---|
| `calibrate.html` | Can a phone build a personal exertion profile — what *your* jog and *your* sprint are? | Built, verified synthetically. **Not yet run on a real body.** |
| `music.html` | Can a client recover what was genuinely playing during a run, without being told? | Built, PKCE verified against the RFC 7636 test vector. **Not yet run against a real account.** |
| `index.html` | Does an effort state machine track a body without flapping? | Built, verified against a synthetic trace. **Not yet run on a treadmill.** |

**Nothing here has been validated against a real human yet.** Treat every number in the
prototypes as a plausible default, not a finding. If the human reports real-world results,
those override anything in the code.

### The one real finding so far, and it's a warning

In synthetic calibration, cadence rose only **~24%** from jog to sprint while speed rose
**~154%**. If that holds on a real body, **cadence alone cannot distinguish jogging from
sprinting.** Step length (`speed ÷ steps-per-second`) separates them far better.

Consequence for the app: do not build effort zones on cadence alone. Design the effort model to
take cadence *and* pace, and degrade gracefully when pace is unavailable (treadmill, tunnel, no
GPS fix).

---

## 3. Sensor strategy — do NOT port the web prototype's peak detector

The web prototypes detect steps by thresholding raw accelerometer peaks. That exists **only**
because browsers have nothing better. Reimplementing it in Swift would be strictly worse.

**iOS — use `CMPedometer`.** It runs on the motion coprocessor: far more accurate, dramatically
cheaper on battery, and it exposes what we need directly:

- `CMPedometerData.currentCadence` — steps per second (multiply by 60 for SPM)
- `CMPedometerData.currentPace` — seconds per meter
- `distance`, `numberOfSteps`
- `queryPedometerData(from:to:)` for historical windows — useful for reconstructing a run after
  the fact, and for the music-correlation window

Note `currentCadence` and `currentPace` are optional and unavailable on some hardware — always
have a fallback path. Requires `NSMotionUsageDescription` in Info.plist.

**Android (later) — `TYPE_STEP_DETECTOR` / `TYPE_STEP_COUNTER`**, or Google's Recording API for
background step accumulation. Same shape, different plumbing.

**GPS pace** — `CLLocationManager` with `activityType = .fitness`. `CLLocation.speed` is in m/s
and is `-1` when invalid; check before using. Expect the first several fixes to be garbage.

**HealthKit** — worth integrating for workout attribution and richer data. Note: `HKWorkoutSession`
is **watchOS only**; on iOS you build workouts with `HKWorkoutBuilder`. Don't let a plan assume
otherwise. Requires usage descriptions and explicit user authorization.

---

## 4. The effort model — port this concept, not the code

The web state machine encodes real lessons. Carry the *design* over:

```
cadence + pace
  → rolling baseline (median of a settling window, not mean — one stumble shouldn't skew it)
    → delta vs baseline
      → state classifier with HYSTERESIS
        → sustain requirement before committing a transition
```

States: `warming` / `steady` / `dropping` / `surging` / `stopped`.

**Two rules that are not optional:**

1. **Hysteresis.** The threshold to *leave* a state must be different from the threshold to
   *enter* it. Without this the classifier oscillates on normal stride variance and every
   downstream consumer fires at random.
2. **Sustain windows.** A candidate state must hold for a duration before it commits (dropping
   ~8s, surging/steady ~5s, stopped ~4s in the prototype). Tune against real data.

**`stopped` never ends the run and never nags.** No pause dialog, no "are you still there?".
The clock keeps running, clips don't fire. Stopping for breath is part of running and the app
does not comment on it. This is a product decision, not an oversight.

This logic is platform-neutral. Put it in a pure, dependency-free module with no UIKit/SwiftUI
imports so it can be unit-tested against recorded traces and later shared or reimplemented.

**Build a trace replay harness early.** Record real sensor sessions to disk, replay them
through the effort model in tests. Tuning thresholds by going outside and running is a terrible
iteration loop.

---

## 5. Audio — the constraints that will bite

The coaching voice plays *over* the user's own music. On iOS:

- `AVAudioSession` category `.playback` with the `.duckOthers` option so Spotify/Apple Music
  ducks under the voice and comes back.
- Background mode **`audio`** in capabilities, or audio stops when the screen locks. This is
  also what keeps the process alive for continuous sensor updates.
- Preload clips into memory before the run starts. A clip that arrives 400ms late has missed its
  moment — the entire thesis is *she noticed*.
- Use `AVAudioEngine` when you need scheduling precision or spatialization later; `AVAudioPlayer`
  is fine for v1 one-shots.

**Latency budget: condition becomes true → audio starts in under 500ms.** Late is worse than
never.

**Firing rules from the coaching design — implement all of them:**

1. One-shot conditions never repeat.
2. Repeatable conditions respect a cooldown (~4 min default).
3. **Global minimum gap of 45s between any two clips.** Presence lives in the deltas.
   Wall-to-wall talking is a podcast.
4. Never fire while `stopped`.
5. Never fire before the baseline locks (except the `start` clip).
6. `final_stretch` and `finish` outrank everything queued.
7. Rotate within a condition's clip bank; never play the same line twice running. Scarcity is
   load-bearing — the line lands *because* it's rare.

---

## 6. Data model — the durable contract

This outlives every client. Version it from day one; treat it as a public format.

```jsonc
{
  "schema": "runwith.run.v1",
  "id": "uuid",
  "type": "run",              // "run" | "route" | "event"
  "title": "string",
  "author": { "id": "uuid", "display_name": "string" },
  "target_duration_ms": 1800000,
  "clips": [
    {
      "id": "string",
      "condition": "start|pace_dropping|pace_surging|halfway|final_stretch|finish",
      "audio_url": "string",
      "transcript": "string",
      "duration_ms": 4200,
      "authored_under": {          // the embodiment gate, made auditable
        "cadence_spm": 172,
        "effort_state": "surging",
        "elapsed_ms": 1420000
      }
    }
  ],
  "music": {                        // only if it was GENUINELY playing (§7)
    "provider": "spotify",
    "verified": true,
    "tracks": [{ "id": "string", "name": "string", "artists": ["string"], "played_at": "iso8601" }]
  }
}
```

Calibration output already has a shipped schema — `runwith.calibration.v1`, see `calibrate.html`.
Keep it compatible; the human may arrive with real logs in that format.

**`authored_under` is the point.** It's what makes the embodiment gate real rather than
asserted. Persist it, and design so the server can eventually verify it.

---

## 7. Music provenance

Attach music **only if it was genuinely playing during the run.** Someone on a couch must not be
able to curate a perfect emotional arc after the fact. The accident is the artifact.

**Spotify Web API + Authorization Code with PKCE.** Already proven in `music.html`; the PKCE
implementation there is verified against the RFC 7636 test vector. Same approach works on iOS
(`ASWebAuthenticationSession`) and later on Android — a genuine cross-platform win, so prefer it
over the Spotify iOS SDK, which is oriented at playback control rather than history.

Scopes: `user-read-recently-played`, `user-read-currently-playing`, `user-read-playback-state`.

**Constraints that shape the product — do not design around wishful thinking:**

- Recently-played is capped at the most recent **50 tracks** and won't page meaningfully further back.
- Offline playback never appears.
- Podcasts are excluded.
- A long run, or a busy listening day afterwards, can push a run's soundtrack permanently out of reach.

Implication: **capture the soundtrack live during the run** (poll currently-playing) rather than
reconstructing it afterwards. Reconstruction is the fallback, not the plan.

**Apple Music / MusicKit** — requires a paid Apple Developer membership and a signed developer
token. On iOS 15+ the `MusicKit` Swift framework exposes recently-played. Higher friction, worth
it only once the paid membership exists anyway for TestFlight (it will).

**SoundCloud is not viable.** Their public API has been closed to new app registrations for
years. Don't build a provider that can't be authorized.

---

## 8. Backend

Scale for now is *a handful of friends on TestFlight*. Optimize for zero ops, not throughput.

**Recommended: Supabase.** Postgres + auth + object storage + row-level security in one, generous
free tier, and it's just Postgres underneath so migration later isn't a trap. Object storage
handles the voice clips.

Alternative if they'd rather own the stack: Cloudflare Workers + D1 + R2 — cheaper at scale,
more assembly required.

**What the backend must do for v1, and nothing more:**

- Identity (Sign in with Apple is cleanest on iOS; note it requires the paid dev program)
- Store and fetch Run artifacts
- Store and serve audio clips
- Share a Run with a friend (a share link is sufficient — a full social graph is not v1)

**Design for, but do not build yet:** server-side verification of `authored_under`. The moment
runs are shared publicly, a client-asserted "I really ran this" becomes a thing people will lie
about. Keep the data shape ready for it.

**Never gate the social core.** Free forever to run, race, receive, finish. Monetization, when it
comes, is authoring tools, self-expression, and geolocated course ownership. Intended license
posture is open-core, AGPL on the engine — the community builds costumes, we build the stage.
**Never host the characters**; the architecture makes the non-association real rather than merely
asserted.

---

## 9. TestFlight path, and what only the human can do

**These are blocking and cannot be delegated to a coding session. Surface them early rather than
building up to a wall:**

1. **Apple Developer Program enrollment — $99/yr.** Gates TestFlight, Sign in with Apple,
   MusicKit, and push. Nothing ships without it.
2. **App Store Connect setup** — bundle ID, app record, signing.
3. **Spotify developer app registration** — free, but they must accept the terms and copy the
   Client ID themselves. Never ask for or handle a client secret; PKCE doesn't need one and it
   must never be embedded in a client.

**TestFlight shape for friends:**

- **Internal testers** — up to 100, must be App Store Connect users, **no beta review**, builds
  available in minutes. This is the right channel for a handful of friends.
- **External testers** — up to 10,000 via public link, but the first build needs Beta App Review.
  Only worth it once the circle outgrows internal.

Practical notes: builds expire after 90 days; bump the build number every upload; TestFlight
requires an uploaded build to have a valid `Info.plist` with all usage descriptions filled in or
the upload is rejected — motion, location, HealthKit, and microphone strings all need real
human-readable text.

---

## 10. Phase plan

Each phase ends in something testable on a real body. Do not skip ahead — the prototypes exist
precisely because untested assumptions stack up invisibly.

**Phase 0 — Confirm stack (§0), enroll in the Developer Program, empty app to TestFlight.**
Prove the pipeline end-to-end with a build that does nothing. Signing and distribution problems
are much cheaper to solve against a trivial app.

**Phase 1 — Sensors + effort model.** `CMPedometer` cadence/pace, effort model as a pure module,
trace recording to disk, replay harness in tests. On-screen diagnostic readout only, no audio.
Ship to TestFlight; the human runs with it and confirms the state machine tracks a real body.

**Phase 2 — Calibration.** Port the graded exertion protocol from `calibrate.html` natively.
This is where the cadence-vs-step-length question (§2) finally gets a real answer. Persist the
profile.

**Phase 3 — Coaching runs.** Artifact loading, condition evaluator, audio playback with ducking
and the full firing rules (§5). Ship two artifacts in deliberately different emotional registers
— one warm, one sparse and unencouraging — to prove the format is neutral and the *author*
supplies the meaning.

**Phase 4 — Backend + sharing.** Auth, artifact storage, clip upload, share links. Friends can
receive each other's runs.

**Phase 5 — Authoring.** Recording voice clips, with the mid-race authoring gate: the mic only
opens above baseline effort, in motion, in the final stretch. **The couch-recording option must
not exist.** The friction is the value.

---

## 11. Explicitly out of scope for now

Ghost / opponent / gap / racing mechanics · spatial audio panning · avatars and 3D · the dap
haptic · geo-artifacts and time-locking · Events · Android · Apple Watch.

Every one of these will feel like an obvious improvement at 2am. Each one contaminates a
measurement that hasn't been taken yet. They're in the vision, they're not in the next build.

---

## 12. Working conventions

- **Report honestly.** If something is untested, say untested. This project's entire method is
  refusing to confuse "built" with "verified" — a plausible-looking result that hasn't touched a
  real body is worth nothing here.
- **The human does the physical validation.** Your job is to make the instrument trustworthy and
  the failure modes visible. Build the diagnostic surface *before* the feature that depends on it.
- **Prefer pure, testable modules** for anything numeric. Sensor input at the edges, logic in the
  middle, and tests that replay recorded traces.
- **Don't couple the prototypes.** Their value is that each one fails independently and tells you
  *which* assumption was wrong.
- Existing web prototypes are served for local testing with:
  `python -m http.server 8765 --bind 127.0.0.1` — loopback IP, not `localhost`, because Spotify
  rejects `localhost` in redirect URIs.

---

## 13. Open questions for the human

1. Native Swift, or cross-platform? (§0 — blocking)
2. Is Android a firm commitment or a maybe? Changes whether Kotlin Multiplatform is worth the setup.
3. Do they already have an Apple Developer Program membership?
4. How many friends in the first TestFlight circle? Under 100 keeps it internal-only, no review.
5. Have any of the three web prototypes been run on a real body yet, and what happened?
   **Real results override every default in this document.**
