# Run With — Build Brief

*You are starting the native iOS app. This document is context and constraints, not a script. Where it states a fact, it was expensive to learn. Where it leaves a decision open, the decision is genuinely yours to make.*

---

## Why this exists

Run With channels the delight that lives behind screens — anime, games, fandom — into the body, as a reason to move. Not fitness rebranded.

The idea everything hangs from is the **embodiment gate**: you cannot reach the data, the voice, the reward, or the music without your body having actually done the work. When a feature proposal quietly removes that gate, it's usually wrong even when it's convenient. When you're unsure whether something belongs, ask whether it's the gate wearing a new costume.

The name is unfinished on purpose. You're always running *with* something; the reader finishes the sentence.

**Artifact vocabulary — use these words exactly, they are load-bearing:**

- **Route** — geofenced. Fixed ground, tied to real coordinates.
- **Run** — portable, person-shaped. Defined by *effort*, not place. The shareable atom.
- **Event** — a Route or a Run opened to other people inside a time window.

You author the first two. You activate the third.

The person you're building for is one developer with a treadmill, some friends, and no team. Everything should be something one person can carry.

---

## The outcome

An iOS app, native Swift and SwiftUI, that does two things on a shared foundation:

1. **Calibration.** A guided graded exertion test — stand, walk, leisurely jog, steady, hard, all-out sprint, cool down — that measures what *this particular person's* jog and sprint actually are, and persists that profile.
2. **Live effort readout.** A running screen showing cadence, pace, and a single-word effort state, driven by the same model the calibration uses.

**Done means:** it installs and runs on the developer's own iPhone, the effort model is a pure module with no platform imports and is covered by tests that replay recorded sensor traces, and a real calibration session produces a persisted profile that survives relaunch.

**Done does not mean TestFlight.** Apple Developer Program enrollment failed on a payment error and is being retried; assume no paid membership exists. Build to device-installable via free provisioning. Leave distribution alone.

The shared foundation matters more than either screen. Both features read the same effort state, and a third consumer — coached audio runs — is coming later. If the two screens end up with parallel implementations of the same concept, the architecture is wrong even if both screens work.

---

## What is already known

These were learned the hard way in web prototypes that live in this repo. They are not suggestions.

**Do not port the prototype's step detection.** `index.html` finds steps by thresholding raw accelerometer peaks. That exists only because browsers have nothing better. iOS has `CMPedometer`, which runs on the motion coprocessor and gives you what's needed directly: `currentCadence` in steps per second, `currentPace` in seconds per meter, plus distance and step count, with `queryPedometerData(from:to:)` for historical windows. It is more accurate and far cheaper on battery than anything hand-rolled. Both `currentCadence` and `currentPace` are optional and absent on some hardware — there must be a path that still works without them.

**Cadence alone probably cannot separate jogging from sprinting.** In synthetic calibration, cadence rose about 24% from jog to sprint while speed rose about 154%. Step length — speed divided by steps per second — separated them cleanly. Treat cadence as one input, not the input. This has not been confirmed on a real body yet; the calibration feature is partly how it gets confirmed.

**Effort classification needs hysteresis and sustain, or it oscillates.** The threshold to leave a state must differ from the threshold to enter it, and a candidate state must hold for a duration before it commits. Without both, normal stride variance makes the state flicker and everything downstream fires at random. The prototype used roughly 8 seconds for dropping, 5 for surging and steady, 4 for stopped, with a 6% delta band entering and 3% leaving. Those numbers are a starting point from synthetic data, not gospel.

**A stopped runner is not an interruption.** No pause dialog, no "are you still there," no nagging. The clock keeps running. Stopping to breathe is part of running and the app does not comment on it. This is a product decision.

**GPS is meaningless on a treadmill** and unreliable for the first several fixes outdoors. `CLLocation.speed` returns -1 when invalid. Indoors, the belt speed the user types in is the only ground truth available, and the calibration flow depends on being able to accept it.

**HealthKit's `HKWorkoutSession` is watchOS only.** On iOS, workouts are built with `HKWorkoutBuilder`. Plans that assume otherwise fail late.

**Your knowledge of Apple's APIs may be stale.** Check current Apple documentation for anything platform-specific rather than relying on recall — SwiftUI and the iOS frameworks move quickly, and a confidently wrong API shape costs more than a lookup.

---

## The data model

This outlives every client. Version it from the start and treat it as a public format — an Android client and other people's tooling will read it eventually.

```jsonc
{
  "schema": "runwith.run.v1",
  "id": "uuid",
  "type": "run",
  "title": "string",
  "author": { "id": "uuid", "display_name": "string" },
  "target_duration_ms": 1800000,
  "clips": [
    {
      "id": "string",
      "condition": "start | pace_dropping | pace_surging | halfway | final_stretch | finish",
      "audio_url": "string",
      "transcript": "string",
      "duration_ms": 4200,
      "authored_under": {
        "cadence_spm": 172,
        "effort_state": "surging",
        "elapsed_ms": 1420000
      }
    }
  ],
  "music": {
    "provider": "spotify",
    "verified": true,
    "tracks": [{ "id": "string", "name": "string", "artists": ["string"], "played_at": "iso8601" }]
  }
}
```

The `type` field takes `run`, `route`, or `event`.

`authored_under` is what makes the embodiment gate auditable rather than merely asserted. It is not decoration.

Calibration already has a shipped schema, `runwith.calibration.v1` — see `calibrate.html`. Real logs in that format may arrive from the web prototype, so stay compatible with it.

---

## Where the real judgment calls are

These are open, and they are the reason this task is worth your time rather than a cheaper model's.

- How the domain core is separated from platform edges, such that an Android client later reimplements only sensors and UI. The effort model, the artifact format, and the calibration protocol should not know what platform they're on.
- How the sensor source is abstracted so that live `CMPedometer` data, a recorded trace being replayed in tests, and a manually-entered treadmill speed all feed the same model without special cases leaking into it.
- What the effort model's inputs actually are, given the cadence-versus-step-length finding.
- How a recorded trace is captured and replayed. Tuning thresholds by going outside and running is a terrible iteration loop; recorded sessions replayed in tests are how this stays workable. Build this early — it's the instrument that makes everything after it verifiable.
- How the calibration profile is persisted and how the live readout consumes it.

---

## How to work on this

**Verify, don't assume.** Before reporting progress, audit each claim against a tool result from this session. Report only work you can point to evidence for; if something isn't verified, say so. If tests fail, say so with the output. If a step was skipped, say that. When something is done and verified, state it plainly without hedging.

**Establish a way to check your own work as you build, and use it at intervals rather than only at the end.** Fresh-context verifier subagents tend to catch more than self-critique does. Delegate independent subtasks and keep working while they run.

**Keep notes for future sessions.** Store one lesson per file with a one-line summary at the top, in `notes/`. Record corrections and confirmed approaches alike, including why they mattered. Don't record what the repo or git history already says. Update an existing note rather than duplicating it; delete notes that turn out wrong.

**Don't build past the task.** No features, refactors, or abstractions beyond what's needed. Don't design for hypothetical future requirements; do the simplest thing that works well. Don't add error handling for scenarios that cannot happen — validate at system boundaries such as user input and external APIs, and trust internal code. No feature flags or compatibility shims when you can just change the code.

**Pause only when you genuinely need the developer:** a destructive or irreversible action, a real scope change, or input only they can provide. If you hit one, ask and end the turn rather than ending on a promise.

**Nothing in this project has been validated on a real body yet.** Every number here comes from synthetic traces. If the developer reports real-world results, those override anything written here.

---

## Not in this build

Ghost, opponent, gap, and racing mechanics. Spatial audio panning. Avatars and 3D. Coached audio playback and voice clips. The dap haptic. Geo-artifacts and time-locking. Events. Backend, accounts, and sharing. Android. Apple Watch. TestFlight distribution.

Several of these are close enough to touch and will feel like obvious additions. Each one contaminates a measurement that hasn't been taken yet.

---

## Context you may want

The repo contains three web prototypes, each isolating one question. They are research instruments, not code to port.

- `calibrate.html` — the graded exertion protocol, in both treadmill and outdoor forms, writing one shared log schema. The native calibration feature is this idea done properly.
- `index.html` — the effort state machine, including the hysteresis and sustain logic described above.
- `music.html` — Spotify history retrieval over OAuth PKCE. Relevant later, not now.

**One open external question:** Spotify's recently-played endpoint caps at the most recent 50 tracks, excludes offline playback, and won't page far back. If that proves limiting in practice, soundtracks must be captured live during a run rather than reconstructed afterward — which is a different architecture. The developer is testing this separately. It does not block this build, but don't design as though after-the-fact reconstruction is guaranteed to work.
