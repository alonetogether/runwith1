# Run With — Native Capture Spine (build brief)

*The canonical spec for capturing the essential **Run** object on a native app. This supersedes `RunWith_RunCaptureSpine_BuildBrief.md` (the web/PWA version), which should be retired — its only surviving value is three stack-agnostic pieces carried forward here: the Run schema (§3), GPX export (§7), and the shoes-on acceptance test (§12).*

*Scope is deliberately narrow: the recorder. Start a run, track it, capture speed/distance/music, save it locally, export it. No ghost, no avatar, no spatial audio, no social, no stat interpretation. This is the data spine every downstream system hangs on — the diagnostic (`RunWith_Diagnostic_Design.md`) is a **downstream consumer** of the Run object this produces, not part of this build (see §9).*

---

## Epistemic status (read this — it tells you how much to trust each line)

This doc uses explicit tags so no agent hardens a maybe into a spec:

- **[DECIDED]** — settled in conversation; build to it.
- **[OPEN — Thomas's call]** — genuinely undecided; do not resolve by writing code. Flag and wait.
- **[VERIFY]** — a platform/API specific that is probably true but has a knowledge cutoff (Jan 2026) and an SDK that moves; confirm against the current iOS SDK before relying on it.
- **[PRINCIPLE]** — a durable design rule that governs choices below.

If this brief and the repo disagree on what's already built, the repo wins and this brief gets corrected — the build session can see the code; this doc is written partly blind to it.

---

## 0. The one deliverable

A native phone app that:
1. Starts and stops a run.
2. Tracks position on a live map.
3. Tracks speed and distance from the best available source — GPS outdoors, step-based indoors — cleaned of noise and **provenance-tagged** (§4).
4. Logs the song playing during the run, with timestamps (§5).
5. Saves the result locally as a versioned **Run** object, re-openable and exportable (§7).

**Pass condition:** a saved Run with a map trace that matches where you went, a believable distance, a speed curve that looks like running and not a seismograph, and a timestamped song list — survives app close/reopen, exports as GPX/JSON. That's the atom captured natively.

---

## 1. Why native (what it buys over the web build)

**[DECIDED]** The decisive reason is **background location.** A PWA can't track once the screen sleeps; the web brief had to demand "screen on, phone in hand, WakeLock." Native **CoreLocation with background location modes** lets you pocket the phone and run normally. That was the single biggest hole in the web capture brief, and it's the reason the web version is retired. **[VERIFY]** the current background-location authorization flow and the "Always"/"When In Use" + background-mode entitlement requirements.

Native also unlocks the things the rest of this brief depends on: CMPedometer as a real indoor source (§4), MusicKit as first-class music access (§5), and HealthKit / Core Bluetooth for the optional sensor tiers (§6). None of those are cleanly reachable from a browser.

**Honest cost:** "test today" is harder than the web build. Native means Xcode, a provisioning profile, and a dev build sideloaded to a real device — the friction moved from "deploy a static site" to Apple's signing ceremony. First run is today-or-tomorrow depending on whether that toolchain is already set up, not same-hour. (No TestFlight / App-Store-submission plan has been decided — don't assume one.)

---

## 2. Stack — **[DECIDED] Swift / SwiftUI, iOS-first**

Native, Swift/SwiftUI, iOS-first — chosen because it is the fastest path to a build Thomas can test, and the least friction between him and clean sensor data: CoreLocation, Core Motion, MusicKit, HealthKit, and Core Bluetooth are all first-party, no bridge. The whole point is to get the diagnostic on his feet soon, and Swift gets there quickest.

**Android is a deferred path, not an abandoned one.** [PRINCIPLE] The audience that needs this most is not all on iPhones, and ARCore makes Android a strong AR platform — so iOS-only is a first-build decision, not a permanent one. When Android matters, the move is React Native / Flutter (one codebase) or a parallel native Android build, decided then against how much iOS-native code has accrued. To keep that door cheap to open: hold the Run object (§3) and the cleaning layer (§4) as portable, platform-agnostic logic, not tangled into SwiftUI view code.

---

## 3. The Run object (the shared contract — the seam to everything downstream)

**[DECIDED]** Define/confirm this first; it is the integration point between the capture spine and every consumer (diagnostic, future ghost, export). Carried over from the web brief, extended with provenance.

```json
{
  "id": "uuid",
  "schema_version": 2,
  "started_at": "ISO-8601",
  "ended_at": "ISO-8601",
  "duration_ms": 0,
  "points": [
    {
      "t": 0,                 // ms since started_at
      "lat": 0.0,             // null when indoor / no GPS fix
      "lng": 0.0,             // null when indoor / no GPS fix
      "accuracy_m": 0.0,      // GPS horizontal accuracy; gates junk
      "raw_speed_mps": null,  // source's raw speed if present
      "speed_mps": 0.0,       // cleaned/derived — THE stored truth
      "distance_m": 0.0,      // cumulative, from accepted samples
      "cadence_spm": null,    // steps/min (Core Motion), when available
      "elevation_m": null,
      "source": "gps",        // "gps" | "pedometer" | "fused" — PROVENANCE
      "fidelity": "measured"  // "measured" | "proxy" | "estimated"
    }
  ],
  "music": [
    { "t": 0, "title": "", "artist": "", "source": "apple_music" }
    // v3 adds identity/attributes (album, isrc, track_id, genre, duration_ms, bpm);
    // v6 adds how it played: started_t, ended_t, played_ms, end, timing_fidelity,
    // timing_method, sightings[], artwork_url, album_id, artist_id.
    // The current shape and its rules are recorded in RunWith/README.md (Music).
  ],
  "summary": {
    "distance_m": 0.0,
    "avg_speed_mps": 0.0,
    "max_speed_mps": 0.0,
    "moving_time_ms": 0
  },
  "raw_streams": {}           // see §11 — wider than v1 interprets, opt-in, provenance-tagged
}
```

Design rules baked in:
- **Speed is stored truth; pace is derived.** Pace (min/km) is a display transform, never a stored field.
- `raw_speed_mps` kept beside `speed_mps` so the cleaning is inspectable.
- **Every point carries `source` + `fidelity`.** [PRINCIPLE] The epistemic-honesty rule applied to the data layer — a number must say whether it was measured or approximated, because downstream systems and the user both deserve to know.
- GPX-adjacent and versioned (`schema_version`) so it exports to a real standard day one (§7).

---

## 4. Capture sources & the indoor reconciliation

**[PRINCIPLE]** "Speed" and "distance" are **source-abstracted** fields fed by the best available input, not "GPS speed." The cleaning layer produces one clean `speed_mps` / `distance_m` series and tags where each sample came from.

- **Outdoors → GPS** (CoreLocation). Accuracy-gate junk fixes, prefer the source's own speed when sane else derive from haversine/dt, smooth, accumulate distance from accepted points only, exclude stopped segments from moving time. (This is the one real cleaning algorithm; it's part of capture, not a separate agent's job — see §9.)
- **Indoors / treadmill → CMPedometer** (Core Motion): cadence + step-length-derived distance/pace. **[DECIDED]** GPS is meaningless on a treadmill; the step-based source is primary indoors. Provenance-tag it `source: "pedometer"`, `fidelity: "proxy"` (step-length estimation is noisier than GPS). **[VERIFY]** current CMPedometer fields and whether live pace/distance are exposed or must be derived from cadence.

**[OPEN — Thomas's call] The one reconciliation to settle:** what "speed" *means* indoors, end to end. Two parts, two answers (already worked out in the diagnostic doc's §2.1):
1. For the **style classifier**: a constant-belt treadmill dictates pace externally, so `UNCLASSIFIED` on a fixed belt is *correct by design*, not a failure — make it an explained outcome.
2. For the **effort metrics** (sustainable pace, decay, N-curve): they consume the CMPedometer-derived speed, provenance-tagged.
The recorder just needs to produce a clean, tagged `speed_mps` from whichever source is live. The *interpretation* of that indoor signal is the diagnostic's problem — but the recorder must not throw away the distinction. Confirm the handoff shape before building.

---

## 5. Music

**[DECIDED]** **Apple MusicKit is the primary path; Spotify is a secondary plugin.**
- MusicKit (iOS) is first-party, native, no OAuth dance, cleaner than the Spotify Web API. Spotify tightened extended API access in 2025 (25-user dev-mode cap) — a real dependency risk, so it's secondary. **[VERIFY]** current MusicKit now-playing access and Spotify API terms.
- **System-wide audio capture is impossible.** [DECIDED] iOS does not let an app read arbitrary system audio (whatever's playing in another app) — that's private-API territory and an App Store rejection. So music is **per-source connectors**, not universal: clean now-playing from Apple Music; Spotify via its API if connected; everything else, nothing.
- [PRINCIPLE] Music is **metadata only** (title/artist/timestamp), never hosted or redistributed, and **embodiment-gated** — a track attaches to a Run only if it was genuinely playing during the run.
- [BUILT, schema v6] Each play is one entry with raw position sightings and derived start, end, play time and end reason (completed / skipped / stopped / run_ended / lost). No "listened" verdict is stored; that is a later, tested filter. Cover art is stored as a link (Spotify) or cached on device (Apple Music), never as image bytes in the Run.

---

## 6. Sensors (progressive enhancement — v1 is phone-only)

**[PRINCIPLE] Progressive enhancement around a complete phone-only core. Sensors sharpen and enrich; they NEVER gate.** No one ever hears "you need a pod for a real baseline." This is also what keeps any future sensor-affiliate model honest: a sensor is recommended because it genuinely improves a named axis, never to paywall the floor.

v1 builds **phone-only** (GPS + CMPedometer). The tiers below are the **enhancement path**, not this build — but see §11: the capture layer should be *designed* so these slot in without a rewrite, and should store their streams wide once present.

- **+ Wrist HR** (HealthKit / Apple Watch): unlocks the internal-load axis — decoupling, HR recovery, HR zones, a VO2max *estimate* (proxy, label it). The substrate for Guts.
- **+ Chest strap** (Core Bluetooth): no new category, just makes HR trustworthy at the hard end.
- **+ Foot/leg pod** (Core Bluetooth; Stryd canonical): **running power** upgrades the N baseline from a terrain-confounded speed proxy to a true, terrain-independent critical-power curve — the highest-value accuracy upgrade in the stack. **Running dynamics** (ground contact time, vertical oscillation, leg-spring stiffness, L/R asymmetry) open a form/economy/durability axis. [VERIFY] running power is less standardized than cycling power — devices compute it differently and aren't directly comparable.
- [PRINCIPLE] **Recommend by dimension, not by cart:** tie any sensor suggestion to the axis the person wants to sharpen (Guts → HR; accurate baseline on hills/treadmill → power; form/asymmetry → dynamics). Never "buy everything."

Everything degrades cleanly: HR fields `null` without HR, power/dynamics `null` without a pod, provenance tag says which.

---

## 7. Storage & export

- **Local persistence** on-device (the native equivalent of the web build's IndexedDB — framework-dependent; pick per §2). Save on stop; list saved runs; re-open and render map + song list.
- **Export, day one:**
  - **JSON** — the raw Run object.
  - **GPX** — [PRINCIPLE] forces the Run object to validate against a real standard immediately, and is the honest first step toward the Run being a portable, open format instead of a proprietary blob. Low effort, disproportionate payoff. The things people care most about should belong to them, not the infrastructure.

---

## 8. Setup / distribution friction (do first, or you can't test)

1. Xcode + a provisioning profile; dev build sideloaded to the test device. (Apple Developer account specifics not decided — confirm what's already in place.)
2. Grant Location ("Always" or background-capable), Motion (CMPedometer), and Apple Music / HealthKit permissions **in context, primed one at a time at the moment each is needed** — never cold-fire all dialogs on launch (that trains reflexive denial; a denied grant is painful to recover). This is the pre-run gear-check UX (`RunWith_Diagnostic_Design.md` §6) in miniature.
3. **Confirm capture is live before Start:** GPS fix acquired / step source active / music connected, shown honestly. Don't enable Start until location is ready. This prevents the silent-failure run (finishing and discovering nothing tracked — a documented Zombies, Run! complaint).

---

## 9. Ownership & the seam (so nobody builds the same thing twice)

**[PRINCIPLE] Read wide, write narrow. One owner per buildable artifact; one source of truth per fact.**

- **The capture spine — including the GPS/step cleaning pipeline — is owned by the build session.** It's one coherent native module against one data model; splitting the cleaning to a separate agent just adds coordination for no benefit.
- **The diagnostic is downstream.** It *consumes* the Run object (§3) via the schema contract — it does not re-capture or re-clean. The capture brief's job is to produce clean, tagged traces and stop; stat interpretation (N-curve fit, 脚質 classifier, decay, confidence) lives in `RunWith_Diagnostic_Design.md` and is explicitly out of scope here (§10).
- **One open ownership question remains for the diagnostic itself** (not this brief): does the repo's effort-model scope already include the curve fit + classifier, or does it stop at capture? If it stops at capture, the diagnostic is net-new analysis and can go to another agent; if it already fits the curve, it stays with the build session. Resolve that against the repo before assigning the diagnostic — but it does not block this capture build.

---

## 10. Explicitly OUT of scope for this build

Each of these contaminates the "did capture work" test:
- Ghost, pacer, avatar, spatial audio, any Moment/Display.
- Social, accounts, servers, sharing.
- Arbitrary system audio / non-connector music sources.
- 脚質 classification, Guts, N-curve, any stat interpretation — that's the diagnostic, a later pass over clean data.
- LLM / persona anything (narration is deferred — idea-capture §31).

---

## 11. FOUNDATION FOR LATER — what we must not foreclose

**[PRINCIPLE]** A capture brief isn't only "what we build now" — it's "what we must not make *impossible* later." Storing wider than you interpret is cheap at capture time and impossible to backfill: if v1 only stores what v1 computes, every richer stream is gone and the plugin author two years out has nothing to mine. **Honest-wide, not hoard-everything:** opt-in, provenance-tagged, nothing sensitive you can't justify holding. The `raw_streams` field (§3) exists for exactly this.

These are **not built now.** They are named so the recorder is *designed around them* — each lists what must be captured today to keep the door open.

1. **Gait / posture → ghost body-fidelity (the seed).** The original want (filming a side profile of yourself running to extract a repeatable, natural gait "so the ghost feels real — like how VRChat lets you wave your arms"), grown to: capture data that could later drive how a 3D model moves through a race — posture, body language, kick vs cruise. *Capture-now:* preserve the raw IMU/accelerometer stream (and, where offered, foot-pod running-dynamics channels) rather than only derived cadence. The later markerless-mocap pipeline (MediaPipe/SMPL-class) needs those streams; derived numbers alone can't reconstruct gait. Multi-view video capture and a cruise/climb/kick gait set are the *upgrade path*, not v1.

2. **Richer sensor streams for future plugins / metric-packs.** Sensors have three consumers, not one: diagnostic accuracy, quantified-self pleasure (the delight Strava sells), and the plugin canvas. A ground-contact-time stream the core app ignores today is exactly what a future form-coaching pack or a character "technique" pack mines tomorrow. *Capture-now:* store sensor streams wider than v1 interprets, provenance-tagged, behind a stable metric API that packs can read.

3. **The Run/ghost format as an open standard.** The versioned JSON + GPX export (§3, §7) are the first bricks. The eventual goal is a human-readable format other developers implement against, and that stays open enough to *receive* community-authored assets (e.g. a fan-built lore-accurate course). *Capture-now:* version the schema and ship export from the first build (already in scope).

4. **Embodiment gate applied to game feedback.** "You cast your own ability" — the homestretch-haste animation + iconic soundbyte firing only when your real body hits a speed threshold at the final corner. Nobody has built a power-up you can't trigger by tapping a button. *Capture-now:* nothing extra beyond a clean, timestamped speed series with segment position — which this brief already produces. Hold onto the idea.

5. **Physiological-awareness companion.** HealthKit exposes permission-gated, on-device data (including cycle data) that could let a companion quietly adjust pacing on low-energy days. *Capture-now:* nothing — but the permission-gated, on-device, provenance-tagged trust posture this brief establishes is the groundwork. Do not capture any such data in v1.

6. **Temporal / conditional gated experiences.** Rain runs wired to live weather, a New Year's run once a year, a birthday route that reopens annually, a dawn run. *Capture-now:* timestamp everything (already done) and keep the Run/Route schema open to condition metadata. Weather-triggering is the harder, later piece.

7. **Narration / persona companion (LLM).** Deferred (idea-capture §31). [PRINCIPLE, load-bearing] the LLM never analyzes the data — the math analyzes, the LLM narrates the analysis. Synthetic-companion side only. *Capture-now:* nothing; just don't let tokens near the raw series when it does arrive.

*(Other deferred items live in the idea-capture doc and are not capture-layer concerns: visual world-locked AR as the later hardware upgrade, top-down/track-meet views arriving with the crowd, discovery view, arbitrary condition-triggered authoring granularity, and the Arima Kinen re-embodiment flagship. Listed here only so the build session knows they exist and are sequenced later.)*

---

## 12. Acceptance test (the shoes-on test)

1. Sideload the dev build; grant permissions in context; start music through Apple Music.
2. Pocket the phone (this is the native payoff — no screen-on requirement). Tap Start.
3. Run a route whose rough distance you know. For a second pass, do a treadmill segment to exercise the CMPedometer path.
4. Tap Stop.

**Pass =** a saved Run showing a map trace matching where you went (or a clean step-based distance indoors), a believable `distance_m`, a speed curve that looks like running, a `music[]` list of what actually played with plausible timestamps, every point provenance-tagged — and it survives close/reopen and exports as GPX/JSON.

That's the atom, captured natively. Everything else in Run With is downstream of this object existing and being trustworthy.
