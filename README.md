# Run With

*You're always running **with** something. The sentence never finishes — you finish it.*

A platform for channeling the delight that lives behind screens into a reason to move the body. This repo starts with the smallest honest slice of it.

## Where this is right now — Step 1 of the coaching-run prototype

`index.html` is a **single, dependency-free file**: cadence detection, an effort state
machine, a dev panel, and a state-transition log. **No audio, no clips, no ghost, no GPS.**

It exists to answer one question before anything else gets built:

> Does the effort state machine track a real body correctly — and *without flapping*?

Audio does not get built until the answer is yes. That's the build order, and it's
deliberate: a beautiful audio layer on a flapping state machine fires clips at random,
and you'd wrongly conclude the whole concept is dead.

### The effort state
Everything downstream reads from one object: `cadence_spm`, `baseline_spm`, `delta_pct`,
`state` (`warming` / `steady` / `dropping` / `surging` / `stopped`), `progress_pct`,
`is_final_stretch`. Baseline is the median of your first 90 seconds. State transitions
require **sustained** conditions (dropping 8s, surging/steady 5s, stopped 4s) and carry
**hysteresis** so they don't oscillate at the boundary. `stopped` never ends the run and
never nags — stopping for breath is part of running.

## Run it

No build step, no framework. Node isn't required. Serve the folder and open it:

```bash
python -m http.server 8765
```

Then open `http://localhost:8765/` on the device. On a phone, tap **Start** (grant motion
access on iOS). At a desk with no motion sensor, it falls back to a **simulated cadence
slider** in the dev panel (⚙, top-right) so the whole machine is testable without moving.

## The treadmill test (the actual point of Step 1)

Put it on a treadmill, run ~5+ min so the baseline locks, then deliberately let your pace
sag. Open the dev panel and **watch the state word change.** At the end, the summary screen
shows every transition with its timestamp and triggering cadence/delta — that log *is* the
experiment. If a transition fired at the wrong moment, tune the peak `threshold`, then the
`sustain` durations, then the `delta` thresholds — in that order.

## Verified so far

The state machine was exercised headlessly against a synthetic cadence trace
(warm-up → drop → recover → surge → stop → resume): correct transition sequence, correct
baseline, and a single-tick dip injected mid-steady was **absorbed, not committed** — no
flapping. `classify()` passes threshold + hysteresis checks in both directions.

## Explicitly NOT in this prototype

Ghost / opponent / gap / racing · spatial audio panning · avatars · GPS · servers /
accounts · music · the dap haptic · audio recording. Each one contaminates the single
variable Step 1 isolates. They come later, in order.

## Build order

1. **Cadence + effort state machine + dev panel — done, verified.** ← you are here
2. Condition evaluator + firing rules (console-logged, still no audio)
3. Audio playback + ducking + `SpeechSynthesis` fallback
4. Screens (select / finish) + clip log surface
5. `localStorage` persistence
6. Second artifact (the sparse register) — proves the format is neutral
