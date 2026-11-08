# Run With — Coaching Run Prototype (Overnight Build)

*A single HTML file. No ghost, no gap, no avatar, no server. One runner, one authored coaching artifact, condition-triggered voice clips. Builds directly on the PoC 0a audio engine.*

*This is the "Noel coaching run" storyboard, made real.*

---

## What this is

A runner opens a page. Picks a coaching run. Starts running. Voice clips fire when their body does specific things — pace drops, pace surges, they enter the final stretch, they cross the finish. At the end, a message unlocks.

That's it. That's the whole prototype.

**The one question this answers:** does a voice arriving at exactly the right moment — triggered by what your body is actually doing, not by a timer — feel meaningfully different from a podcast?

---

## What this is NOT

Do not build these. They are explicitly out of scope:

- Any ghost, opponent, gap, or racing mechanic
- Spatial audio panning (the coaching voice is centered — she isn't beside you, she's *with* you)
- Avatars, visuals of any kind beyond the minimal UI
- GPS or geolocation
- Servers, accounts, networking, or persistence beyond `localStorage`
- Music integration
- The dap haptic interaction (a simple finish message stands in for it)
- Recording audio (clips are pre-supplied files)
- Unity, React, or any framework

**One HTML file. Vanilla JS. Web Audio API. DeviceMotion. That's the entire dependency list.**

---

## Architecture

```
DeviceMotion (accelerometer)
  → peak detector → cadence (SPM)
    → rolling baseline + effort state machine
      → condition evaluator (every 500ms)
        → clip scheduler (respects cooldowns, one-shots, priority)
          → Web Audio playback (centered, ducked over ambient)
```

Single state object. Single tick loop. No frameworks.

---

## Part 1 — Cadence detection

Reuse the 0a peak detector wholesale. Restated for completeness:

```javascript
window.addEventListener('devicemotion', (e) => {
  const y = e.accelerationIncludingGravity.y; // axis varies by orientation — expose a toggle
  detectPeak(y);
});
```

- **Threshold:** ~2–3 m/s² above rolling mean. Tunable via slider.
- **Refractory period:** 250ms minimum between peaks.
- **Cadence:** `60000 / mean(last 8 inter-peak intervals)` → steps per minute.
- **Typical range:** 140–190 SPM.

**Desktop fallback:** if no `devicemotion` events arrive within 3 seconds, switch to a simulated cadence driven by a slider so the whole system can be tested at a desk.

---

## Part 2 — Effort state (the thing conditions are evaluated against)

This is the core abstraction. Everything downstream reads from it.

```javascript
const effort = {
  cadence_spm: 0,           // current, smoothed
  baseline_spm: 0,          // established over first 90 seconds
  baseline_locked: false,
  delta_pct: 0,             // (cadence - baseline) / baseline
  state: 'warming',         // 'warming' | 'steady' | 'dropping' | 'surging' | 'stopped'
  elapsed_ms: 0,
  progress_pct: 0,          // elapsed / target_duration
  is_final_stretch: false,  // progress_pct > 0.80
  stopped_ms: 0             // how long cadence has been ~0
};
```

### Baseline establishment
First 90 seconds: collect cadence samples. At t=90s, `baseline_spm = median(samples)`, `baseline_locked = true`. Before that, `state` stays `'warming'` and no effort-relative clips can fire.

Median, not mean — a single stumble shouldn't skew it.

### State transitions
Evaluated every 500ms, but require **sustained** conditions to avoid flapping:

| State | Condition | Sustain requirement |
|---|---|---|
| `dropping` | `delta_pct < -0.06` | held 8 consecutive seconds |
| `surging` | `delta_pct > +0.06` | held 5 consecutive seconds |
| `steady` | `-0.06 ≤ delta_pct ≤ +0.06` | held 5 consecutive seconds |
| `stopped` | `cadence_spm < 20` | held 4 consecutive seconds |

**Hysteresis is mandatory.** Once in `dropping`, require `delta_pct > -0.03` (not -0.06) to exit. Without this the state machine will oscillate and clips will fire repeatedly. This is the same lesson as the phone-pitch hysteresis — get it right the first time.

### The stopped state
When `state === 'stopped'`, the run does **not** end. No pause dialog. No timer. No "are you still there?" prompt. The clock keeps running, `elapsed_ms` keeps incrementing, and no clips fire. When cadence resumes, the state machine picks up where it left off.

Stopping for breath is part of running. The app does not comment on it.

---

## Part 3 — Conditions

A coaching artifact is a list of clips, each bound to a condition. These are the conditions the prototype supports:

| Condition ID | Fires when | Type |
|---|---|---|
| `start` | Run begins | one-shot |
| `pace_dropping` | `state` enters `dropping` | repeatable, 4min cooldown |
| `pace_surging` | `state` enters `surging` | repeatable, 4min cooldown |
| `halfway` | `progress_pct` crosses 0.50 | one-shot |
| `final_stretch` | `progress_pct` crosses 0.80 | one-shot |
| `finish` | `progress_pct` reaches 1.0 OR user taps End | one-shot |

### Firing rules — implement all of these

1. **One-shots never repeat.** Track fired state per condition.
2. **Repeatables respect a cooldown.** Default 4 minutes. Configurable per condition.
3. **Global minimum gap between any two clips: 45 seconds.** Two clips must never overlap or stack back to back. Presence lives in the deltas; wall-to-wall talking is a podcast.
4. **Never fire while `state === 'stopped'`.** She's not going to encourage you while you're standing still with your hands on your knees.
5. **Never fire before `baseline_locked`.** Except the `start` clip, which fires immediately.
6. **`final_stretch` and `finish` outrank everything.** If a `pace_dropping` clip is queued and `final_stretch` triggers, the final stretch clip wins and the queued one is dropped.
7. **Rotation.** If a condition has multiple clips in its bank, cycle through them; never play the same clip twice in a row. Scarcity is load-bearing — the line lands because it's rare.

---

## Part 4 — The coaching artifact format

This is a draft of the Run artifact from PoC 1, scoped down. Keep it clean JSON — it's the beginning of an open format.

```javascript
{
  "id": "noel-danchou-5k",
  "title": "Run with your Danchou",
  "author": "白銀ノエル",
  "mode": "coaching",
  "target_duration_ms": 1800000,
  "description": "I'll be running beside you, order member. Don't embarrass the guild.",
  "clips": [
    {
      "id": "clip_start",
      "condition": "start",
      "audio": "audio/noel_start.mp3",
      "transcript": "Alright — let's go. I'll be with you the whole way.",
      "duration_ms": 4200
    },
    {
      "id": "clip_drop_1",
      "condition": "pace_dropping",
      "audio": "audio/noel_drop_1.mp3",
      "transcript": "Ha— your pace dropped. That's okay. Even knights rest. Keep moving.",
      "duration_ms": 5100
    },
    {
      "id": "clip_drop_2",
      "condition": "pace_dropping",
      "audio": "audio/noel_drop_2.mp3",
      "transcript": "Hey. Breathe. You're still going, that's what counts.",
      "duration_ms": 4400
    },
    {
      "id": "clip_surge_1",
      "condition": "pace_surging",
      "audio": "audio/noel_surge_1.mp3",
      "transcript": "Oh? Someone's feeling strong today. Good.",
      "duration_ms": 3800
    },
    {
      "id": "clip_final",
      "condition": "final_stretch",
      "audio": "audio/noel_final.mp3",
      "transcript": "Last part. Don't slow down now. I can't lose to you, understand? Go.",
      "duration_ms": 5600
    },
    {
      "id": "clip_finish",
      "condition": "finish",
      "audio": "audio/noel_finish.mp3",
      "transcript": "You made it. Good work, Order member.",
      "duration_ms": 4000
    }
  ]
}
```

**Ship two artifacts** so the prototype can demonstrate that the same engine holds different emotional registers:

1. **`noel-danchou-5k`** — warm, slightly competitive, older-sister energy. As above.
2. **`kiryu-debt-run`** — sparse, low, unencouraging. Clips are two to six words. `pace_dropping` fires *"...slowing down already? Hmph."* then *"Get up."* `finish` is *"...not bad."* Same engine, opposite register. This is the demonstration that the format is neutral and the author supplies the meaning.

---

## Part 5 — Audio playback

```
AudioBufferSourceNode (clip)
  → GainNode (clip gain, 1.0)
    → destination

AudioBufferSourceNode (ambient bed, looping, optional)
  → GainNode (ambient gain, ducks to 0.15 during clips)
    → destination
```

- **No PannerNode.** The coaching voice is centered. She isn't beside you as a body — she's *with* you as a presence. Panning her would make her a ghost, and this isn't ghost mode.
- **Duck the ambient bed** to ~15% during clip playback, ramp back over 800ms after. Use `linearRampToValueAtTime`, never abrupt gain changes.
- **Preload every clip** into `AudioBuffer` on run start. A clip that arrives 400ms late has missed its moment.
- **iOS:** `AudioContext` requires a user gesture. Everything starts on the Start button.

### Optional ambient bed
A very quiet loop — wind, distant traffic, nothing musical. Gives the clips something to emerge from and return to. If it feels like it's adding nothing, cut it. Test with and without.

---

## Part 6 — UI

Minimal. Dark. Readable at a glance while moving. The user's eyes should be on the path.

### Screen 1 — Select
Two cards: the two artifacts. Title, author, description, target duration. Tap to select.

### Screen 2 — Pre-run
- Selected artifact title
- Target duration (editable — default 30 min)
- **Start** button (this is the user gesture that unlocks audio + requests `DeviceMotionEvent.requestPermission()` on iOS 13+)

### Screen 3 — Running
Large, low-information, glanceable:

- **Elapsed time** (biggest element)
- **Current cadence** (SPM, updating live)
- **Effort state** as a single word: `warming` / `steady` / `dropping` / `surging` / `paused`
- A thin **progress bar** toward target duration
- **End Run** button (bottom, requires a deliberate second tap to confirm)

**Nothing else.** No clip history, no "next clip in 2:34", no encouragement text on screen. The voice is the interface.

### Screen 4 — Finish
- Duration, average cadence, baseline
- The finish clip plays automatically
- Transcript of every clip that fired, with the timestamp it fired at and the state that triggered it

That last item is the most important debugging surface in the entire build. It tells you whether the conditions fired where they should have.

### Dev panel (collapsible, top corner, hidden by default)
Essential for tuning on a treadmill without stopping:

- Live cadence, baseline, `delta_pct`, current state
- Peak threshold slider
- Simulated cadence slider (desktop mode)
- **Force-fire** buttons for each condition
- Sustain-duration overrides
- Toggle: ambient bed on/off

---

## Part 7 — Persistence

`localStorage` only. Store completed runs as:

```javascript
{
  artifact_id: string,
  completed_at: timestamp,
  duration_ms: number,
  baseline_spm: number,
  avg_cadence_spm: number,
  clips_fired: [{ clip_id, fired_at_ms, triggering_state }]
}
```

Show the last five on the select screen. That's the whole persistence layer.

---

## Part 8 — Audio assets

Do not block on production voice acting. Use placeholder recordings — the developer reading the transcripts is completely fine, and arguably better for testing, because it isolates *timing* from *performance*. If a badly-read line arriving at the right moment still lands, the mechanic is real.

Directory: `audio/`. Format: MP3, mono, 128kbps. Naming: matches the `audio` field in the artifact JSON.

If a clip file is missing, log a warning and use the browser's `SpeechSynthesis` API to read the `transcript` field instead. This means the prototype runs with zero audio assets on first launch, which is the right default for an overnight build.

---

## Latency requirements

| Path | Budget |
|---|---|
| Condition becomes true → clip audio starts | < 500ms |
| DeviceMotion event → cadence updated | < 50ms |
| Clip end → ambient ramps back | 800ms ramp |

The condition-to-audio path is the one that matters. A clip that fires two seconds after your pace dropped is a clip that fired for no reason. The whole thesis is *she noticed*. Late is worse than never.

---

## Error handling

- **No DeviceMotion:** simulated cadence slider, warning banner, everything else works.
- **Permission denied (iOS):** explain why it's needed, offer simulated mode.
- **Missing audio file:** `SpeechSynthesis` fallback, log warning.
- **AudioContext suspended (backgrounded tab):** resume on `visibilitychange`.
- **Screen sleeps mid-run:** request a `WakeLock` on run start; if unavailable, warn the user.

---

## What success looks like

Put it on a treadmill. Sealed headphones. Run for twenty minutes at a comfortable pace. Around minute eight, deliberately let your pace sag.

**Pass:** the clip arrives, and for a moment it feels like someone *noticed*. Not like a timer went off. Like attention was being paid.

**Partial pass:** the clip arrives but late, or too often, or at a moment that doesn't feel like a real pace drop. → tune the sustain durations and the `delta_pct` thresholds first. Then the cooldowns. The mechanic is probably fine; the numbers are wrong.

**Fail:** clips arrive and feel like a podcast playing in the background. Nothing about them feels responsive. → check that clips aren't firing on timers, verify the condition log on the finish screen shows the right triggering states, and confirm the latency budget is being met.

Before concluding the mechanic doesn't work: **check the finish screen's clip log.** If the clips fired at the wrong moments, you tested the wrong thing.

---

## Build order

1. Cadence detector + effort state machine + dev panel. Verify state transitions on a treadmill *with no audio at all*. Watch the state word change. This is the foundation and it's the thing most likely to be subtly wrong.
2. Condition evaluator + firing rules. Log to console. Still no audio.
3. Audio playback + ducking + `SpeechSynthesis` fallback.
4. Screens 1–4.
5. `localStorage`.
6. The Kiryu artifact — proves the format is neutral.

**Do not build steps 3 onward until the state machine is provably correct.** A beautiful audio layer sitting on top of a flapping state machine will fire clips at random and you will incorrectly conclude the concept is dead.

---

## Note on scope discipline

Every one of the following will feel like an obvious improvement at 2am and every one of them is out of scope:

- Adding a ghost
- Adding spatial panning to the coach's voice
- Adding music
- Adding GPS
- Adding a way to record your own clips
- Adding a second runner

**Build the thing in this document. Nothing else.** The value of this prototype is that it isolates exactly one variable: does condition-triggered voice feel like attention. Every added feature contaminates that measurement.
