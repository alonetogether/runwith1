# Run With — Diagnostic Design (the measurement foundation)

*Brief for the algorithm agent (Fable / Astra, whichever is assigned). This defines WHAT a running diagnostic must extract and the fundamental ways to elicit it. It is deliberately explicit about epistemic status: what is established exercise science, what is a field proxy, what is product-design reasoning, and what the agent must VERIFY against the literature rather than take from this document. Do not treat the specific numeric parameters here as validated — they are starting points to confirm and tune.*

---

## 0. Why the diagnostic is the foundation

Every downstream system consumes the diagnostic's output:
- **The N+1 tuned pacer** needs the runner's sustainable-effort curve (the "N").
- **脚質 classification** needs their natural effort-distribution tendency.
- **Guts / durability** needs their behavior under accumulating fatigue.
- **The grade / benchmark** needs an absolute capability anchor.

So the diagnostic is not a feature — it's the sensor that calibrates the whole product. Get it wrong and everything built on it inherits the error.

---

## 1. What the diagnostic must extract (the output spec)

Six characteristics. Not all require a dedicated test; some can be inferred from ordinary runs over time (see §4).

1. **Top-end speed** — the anaerobic/sprint ceiling. How fast at all, briefly.
2. **Sustainable pace** — the aerobic/threshold-ish pace held for a sustained period without blowing up. The heart of the N baseline.
3. **The speed–duration relationship** — the curve, not a point. The single most valuable output (see §3).
4. **Fatigue resistance / durability** — how much sustainable pace decays over time; the Guts substrate.
5. **Recovery** — how fast the system recovers after an effort.
6. **Effort-distribution tendency** — front-load, even, or back-load (the 脚質 axis).

---

## 2. The fundamental measurable axes and how to elicit each

### Top-end speed
- **Elicit:** a short all-out effort (order of ~10–20s / ~100m).
- **Measure:** peak sustained velocity (GPS, smoothed — raw GPS speed is noisy, see the capture brief's cleaning pipeline).
- **Status:** straightforward. No physiology model needed.

### Sustainable pace (threshold proxy)
- **Elicit:** a sustained maximal-but-holdable effort (order of several minutes).
- **Measure:** average pace held.
- **Status:** this is a *field proxy* for lactate threshold / critical speed. **Established concepts** (lactate threshold, critical speed) but the app is NOT measuring them in a lab — it's approximating. Say so in any UI. Do not claim "your lactate threshold is X."

### The speed–duration curve (THE prize)
This is where the real algorithm work lives.
- **Established science:** the **critical-power / critical-speed model** (originating with Monod & Scherrer's critical-power concept; critical speed is the running analog). The relationship between maximal sustainable intensity and duration is modelable — with a few maximal efforts of *different durations*, you can fit a curve that predicts sustainable speed at any duration. **That fitted curve IS the "N" baseline.** Not a single pace — a function.
- **Elicit:** multiple maximal efforts across a spread of durations (e.g. one short, one medium, one longer), adequately rested between.
- **VERIFY — do not trust this document's parameters:** there are established field protocols for this. The agent should ground the design in them rather than my recollection:
  - The **3-minute all-out test** (3MT) for critical power/speed — I believe this exists (cycling origin, running adaptations exist) but **confirm the running protocol, validity, and what it yields** before building on it.
  - The **multiple time-trial / multiple-distance method** — plot distance vs. time across 2–3 maximal trials; the slope estimates critical speed. This is the classic method; **confirm the recommended durations/distances and the fit math.**
  - I do **not** know the optimal field durations, rest intervals, or fit coefficients with confidence. Those are empirical. Verify against the literature and plan to tune against real collected data.
- **Status:** model established; exact field protocol = verify; app output = proxy, labeled as such.

### Fatigue resistance / durability (Guts substrate)
- **Elicit:** a sustained effort long enough for fatigue to show; or observed across the back half of longer runs.
- **Measure:**
  - **Pace decay** — how much pace falls across a sustained maximal effort (phone-only, works without HR).
  - **Decoupling / cardiac drift** — the ratio of heart-rate-to-output early vs. late in a sustained effort. **Established concept.** Requires HR (see §5). Low decoupling = durable aerobic fitness.
- **Status:** pace decay = direct measure; decoupling = established concept, HR-dependent, app computes a field version.

### Recovery
- **Elicit:** the rest periods between diagnostic efforts.
- **Measure:** heart-rate recovery (HRR) — how fast HR drops after an effort. **Established concept**, HR-dependent.
- **Status:** HR-dependent; skip gracefully if no HR.

### Effort-distribution tendency (脚質)
- **Elicit:** a *self-paced* piece where the runner is NOT told how to pace — observe the natural shape. Or (better, see §4) infer from accumulated real runs rather than a single test.
- **Measure:** where in the piece their fastest segments fall — front (逃げ/先行), even, or late surge (差し/追込).
- **Status:** classification from pace-curve shape; already specced as a quartile-split heuristic in the idea-capture doc. Refine here — and see §2.1 for the concrete, build-today version.

---

## 2.1 Testing-grade style classifier (build this FIRST — the one diagnostic output shippable today)

Goal: from a single self-paced run, output one of four labels — **Front Runner (逃げ)**, **Pace Chaser (先行)**, **Late Surger (差し)**, **End Closer (追込)** — or `UNCLASSIFIED`. Needs only the capture spine's cleaned speed + cumulative distance. No HR, no curve fit, no literature. This is the cheap, testable slice.

The four labels are the user-facing English names for the same 脚質 taxonomy: Front Runner = 逃げ nige · Pace Chaser = 先行 senkō · Late Surger = 差し sashi · End Closer = 追込 oikomi. (English names are likely the better default for the Western beachhead.)

### Algorithm
```
Input: cleaned speed series + cumulative distance (from the capture spine).

1. Trim warmup/cooldown: drop first & last ~5% of distance if the run is long
   enough; otherwise use the whole active portion.
2. Split the active portion into 4 quarters BY DISTANCE (not time — distance is
   the honest axis for "where in the piece").
3. For each quarter q: s_q = mean cleaned speed in q.
   m = mean speed over the whole active portion.
   r_q = s_q / m          # ~1.0 = that quarter was at the runner's own average

4. Guard: if the run is too short (e.g. < ~4 min or too few clean points), OR the
   cross-quarter variance is below a noise floor with no clear peak,
   → return UNCLASSIFIED ("not enough signal yet"). Do NOT force a label.

5. Derived shape:
   peak      = argmax(r_q)
   decline   = r_1 - r_4
   late_kick = r_4 - max(r_1, r_2, r_3)
   mid_surge = r_3 - mean(r_1, r_2)

6. Classify (first match wins):
   End Closer (追込)   : peak == Q4 AND late_kick > KICK_THRESH   # sharp final-quarter jump
   Late Surger (差し)  : (peak == Q3 OR mid_surge > SURGE_THRESH) AND not End Closer
   Front Runner (逃げ) : peak == Q1 AND decline > DECLINE_THRESH  # fades through the run
   Pace Chaser (先行)  : else                                     # even / no dominant spike or fade

7. Confidence: LOW for any single run. Rises only as the SAME label recurs across
   runs (the real classifier aggregates; this one is the single-run probe).
```

**Thresholds are illustrative starting points, NOT validated — tune against real data:** `KICK_THRESH ≈ 0.05`, `SURGE_THRESH ≈ 0.04`, `DECLINE_THRESH ≈ 0.05` (i.e. ~4–5% deviations relative to the runner's own average). Do not ship these as truth; they're where tuning starts.

### Honesty rails (the label lies without these)
- **Terrain confound (the one that will fool you):** a downhill final quarter makes *everyone* an End Closer — you'd be classifying the course, not the runner. If elevation is available, classify on **grade-adjusted pace**; if not, accept the noise and keep confidence low. Power (terrain-normalized) is the real fix later (§5).
- **One run is weak evidence:** output as provisional — "you ran like a ___ *this time*" — never a verdict. A true 脚質 is a tendency across many runs (§4 progressive refinement).
- **Self-paced only:** meaningful only if the runner chose their own pacing. A prescribed-pace run measures compliance, not tendency.
- **Quarters are coarse** for the Late-Surger / End-Closer distinction (Q3 vs Q4 surge). Fine for testing; finer segmentation (deciles) sharpens surge-timing later.
- **Fallback to `UNCLASSIFIED`** over forcing a label on thin or flat data. Honesty over output.
- **Indoor / treadmill — reconcile with the recorder's input model (and split the fix in two):** the project's capture layer treats CMPedometer cadence × step-length as the primary indoor signal (GPS is meaningless on a treadmill). That creates two *separate* questions, with two *different* answers:
  1. **For this style classifier:** a constant-belt treadmill dictates pace externally, which violates the self-paced precondition above. So returning `UNCLASSIFIED` on a fixed-belt run is **correct behavior, by design** — not a GPS failure. Make it an *explained* outcome ("style needs a run where you set your own pace"), never a silent null. (Interval / variable-belt runs *can* be classified, from the pace changes.)
  2. **For the OTHER diagnostic outputs** (sustainable pace, decay, the N curve): these genuinely need an indoor speed source → CMPedometer, provenance-tagged at lower fidelity (§5). This is real plumbing, distinct from the style call.
  Net: the style call declines honestly indoors; the effort metrics switch source. Final reconciliation with the recorder's actual input model is a **product decision to confirm**, not an agent's to assume. Do not let a build consume this doc as GPS-only.

---

## 3. The output object (what the diagnostic produces)

```json
{
  "diagnostic_version": 1,
  "measured_at": "ISO-8601",
  "confidence": 0.0,            // how much data backs this (low after 1 run, rises over time)
  "top_speed_mps": 0.0,
  "critical_speed_mps": 0.0,    // the fitted N — sustainable-speed anchor
  "speed_duration_curve": {},   // the fitted function params, not just a point
  "decay_rate": 0.0,            // pace decay under sustained effort
  "decoupling_pct": null,       // HR-dependent; null if no HR
  "hr_recovery": null,          // HR-dependent; null if no HR
  "kyakushitsu": "senko",       // effort-distribution class
  "grade_anchor": {}            // absolute capability (e.g. 5k-equivalent) for §23 grading
}
```

`confidence` is load-bearing — it lets the product show a soft early estimate and sharpen it over time (see §4) rather than pretending one run is definitive.

---

## 4. The diagnostic is NOT a one-time gate (product-design reasoning — mine, not science)

A full maximal multi-effort field test is **brutal**, and inflicting it on day one contradicts the entire gentle-on-ramp thesis (the depressed/beginner/"just put my shoes on" user will not do a sprint-ladder, and shouldn't have to). Resolution — three tiers, not one test:

1. **Light first-touch.** One easy, self-paced run → a rough first N at low `confidence`. No maximal efforts demanded. Gets them a baseline without suffering.
2. **Progressive refinement (the honest default).** The system keeps updating the speed–duration curve from *real runs over time* — every hard-ish effort is data. `confidence` rises; N sharpens. This is the gentle path and it should be the default. The agent needs to define the **update rule** (how a new run revises the fitted curve — e.g. only maximal/near-maximal segments inform the curve; a run where they jogged easily shouldn't drag the estimate down).
3. **Optional deliberate benchmark.** For runners who *want* a sharp measurement — the re-benchmark ceremony (idea-capture §27). This is where a real multi-effort protocol (§2, verified) belongs. Opt-in, not imposed. Mascot "trending up" reaction fires off improvements between benchmarks.

This maps onto the embodiment gate cleanly: the baseline is *earned through real running*, light at first, sharper as the body does more. Nobody is gated behind a dreaded test.

---

## 5. Sensor tiers (progressive enhancement — richness AND accuracy track sensors)

**Core principle: progressive enhancement around a stable phone-only core. Sensors sharpen and enrich; they NEVER gate.** The phone-only diagnostic must be genuinely complete and honest on its own — no one ever hears "you need a pod for a real baseline." This is what keeps the sensor-affiliate model honest: a sensor is recommended because it *genuinely* improves a metric, not to paywall the floor.

Two different kinds of upgrade, worth keeping distinct:
- **HR makes the diagnostic *richer*** (adds an axis that was invisible).
- **Power makes the diagnostic *truer*** (upgrades the fidelity of an axis you already had — the N curve itself).

### The tiers and what each unlocks

**Tier 0 — Phone only** (pocket / armband / hand)
- GPS (speed, distance, elevation), accelerometer/gyro (cadence, rough vertical oscillation, impact).
- Diagnostic gets: top speed, sustainable pace, speed–duration curve, pace decay, effort distribution, grade anchor, cadence. The full **external-load** picture. Complete and shippable on its own.

**Tier 1 — + Wrist HR (Apple Watch / Garmin etc.)**
- Unlocks the **internal-load axis**: decoupling, HR recovery, HR zones, HRV, a VO2max *estimate* (a proxy, not a measurement — label as such). The true substrate for Guts.
- Fidelity caveat: wrist optical HR is noticeably noisier at high intensity and during rapid change (motion artifact, lag). Fine for steady-state decoupling; unreliable for sprint intervals.

**Tier 2 — + Chest-strap HR** (e.g. Polar H10)
- No new category — it makes the Tier-1 HR metrics *trustworthy at the hard end* (accurate even at high intensity; true R-R-interval HRV). The upgrade is fidelity of decoupling/HRV during hard efforts, exactly where wrist falls down.

**Tier 3 — + Foot / leg / ankle pod (running power + running dynamics)** — the one Thomas flagged ("on my legs/ankles")
- **Running power** (Stryd is the canonical example): the *qualitative* upgrade. The critical-power model was originally a POWER model; fitting N from GPS speed is confounded by hills, wind, and surface, whereas power normalizes all of it, is instantaneous (not GPS-lagged), and works where GPS fails (treadmill, tunnel, tree cover). **Upgrades the N baseline from a terrain-confounded speed proxy to a true, terrain-independent critical-power curve.** Highest-value *accuracy* upgrade in the stack.
- **Running dynamics** (ground contact time, vertical oscillation, leg-spring stiffness, L/R asymmetry): opens a **form / economy / durability / asymmetry** axis nothing else sees, plus an injury-risk-adjacent asymmetry signal. Note: the *measurements* are solid; their *interpretation* (economy, injury risk) is less settled — present carefully, not as verdicts.

### Provenance tagging (epistemic honesty, applied to the data layer)
Every diagnostic output stores not just the value but its **source/fidelity** — e.g. `critical_speed` from a power meter (terrain-normalized, high fidelity) vs. phone GPS (proxy). Downstream systems and the user both deserve to know whether a number is measured or estimated. Add a `source` + `fidelity` field to each output in §3.

### Recommend by dimension, not by cart (honest affiliate logic)
Tie any sensor suggestion to the axis the person wants to sharpen:
- Care about the Guts/fatigue story → **heart rate.**
- Want an accurate baseline on hilly terrain or the treadmill → **power pod.**
- Worried about form or asymmetry → **running dynamics.**
Never "buy everything." Each recommendation must be *true* for that person's goal.

### Crossover — leg/ankle IMUs serve TWO systems
The same leg/ankle sensor that sharpens the critical-power curve also captures gait data that enriches **the ghost's gait fidelity** (the markerless-mocap / gait pipeline elsewhere in the project). One sensor investment, two payoffs — a sharper diagnostic *and* a more convincing left-behind ghost. This is the original brief's sensor-asymmetry growth loop, doubled: the person who straps on pods both measures themselves better and leaves a richer ghost for phone-only chasers.

### Richer sensor data serves THREE consumers (not just accuracy)
Sensors are optional — always — but when present they pay off three ways, and this changes what you *capture*, not just what you compute:
1. **Diagnostic accuracy/richness** — sharper N, real Guts (the §5 tiers above).
2. **Quantified-self enjoyment** — some people simply love rich data about their own body; a stream can be worth surfacing for the pleasure of it even when no stat depends on it (the Strava/quantified-self delight). Legitimate on its own.
3. **Future plugins / metric-packs** — richer stored streams = a wider canvas for later pack authors. A ground-contact-time stream the core app ignores today is exactly what a form-coaching pack or a character "technique" pack mines tomorrow.

**Architectural instruction that follows: capture more than you currently interpret.** When a sensor offers a richer stream, *store it* even if v1 does nothing with it, so plugins later have material — bounded by the project's privacy/storage honesty (sensitive data, opt-in, provenance-tagged; don't hoard what you can't justify). The diagnostic consumes a slice; the stored stream is deliberately wider than the slice.

### Graceful degradation
Everything above degrades cleanly: HR-dependent fields → `null` without HR; power/dynamics fields → `null` without a pod. Nothing breaks; the picture is just less rich or less true, and the provenance tag says which.

**VERIFY (do not trust this doc's device specifics):** the device market moves and this document's knowledge has a cutoff. Confirm the current sensor landscape independently. Note especially that **running power is less standardized than cycling power** — different devices compute it differently and are not directly comparable, which matters if sources are ever mixed.

---

## 6. The pre-run gear check (the user-facing front of the sensor tiers)

Where §5's "optional, progressive enhancement" meets the actual user: a pre-run device-prep step. Before a run — especially a diagnostic — the app helps the user ready whatever sensors they have ("if you have an Apple Watch / HR-capable smartwatch, put it on now"), and the connection + permission prompts live *here*, in context. This screen determines (and provenance-stamps, per §5) the capture tier for the run.

**Design disciplines (all serving: optional must FEEL optional, and no silent failures):**

1. **Phone-only is always one tap to Start.** The gear check *offers* sensors; it never requires them. Zero pairing friction on the default path, or the floor you promised not to gate is gated.
2. **Prime permissions in context, never cold.** Location, HealthKit, Bluetooth, notifications, Spotify — explain *why* right before each OS dialog fires, one capability at a time, at the moment it's needed. Never cold-fire all permission dialogs on launch; that trains reflexive denial (and a denied HealthKit grant is painful to recover).
3. **Confirm sensors are LIVE before Start — the most important one.** Show real status: `GPS: fix acquired ✓`, `HR: streaming ✓`, `music: connected ✓`. Do not enable Start until GPS has a fix. This prevents the *silent-failure run* — finishing and discovering the watch never connected and there's no HR data (a documented Zombies, Run! complaint: tracking that failed quietly mid-run). The gear check's real job is to **guarantee the capture will work before the person spends a run on it.**
4. **State honestly what THIS run will capture.** "This run: pace, route, heart rate." / "Phone-only this time — pace and route. Add your Watch for heart rate and Guts." The recommend-by-dimension nudge (§5) at the one honest moment, not a repeated upsell.
5. **First-run educates; every run after is a glance.** First time: explain briefly, show what each optional device adds, offer pairing, skip = phone-only. Returning: remembered devices auto-reconnect; a status strip (`Watch ✓ · GPS ✓ · Spotify ✓`) + Start, one tap. Never re-explain, never re-nag — the gear check gets *lighter* every time.
6. **Fail soft.** BT pairing (chest strap, pod) is genuinely finicky and a common failure point. A sensor that won't connect drops cleanly to phone-only with a one-line note + retry. Never trap someone in a pairing loop while they're warmed up and ready to run.

**Flow — first-run (diagnostic onboarding):**
welcome → gear check ("here's what you've got; phone-only is fine") → contextual permission priming → OS prompts → live readiness confirm (GPS fix, HR streaming, music) → "you're set — this run captures X" → Start (enabled on GPS fix).

**Flow — returning:**
auto-reconnect remembered devices → status strip + what-this-captures → Start (one tap).

---

## 7. What the algorithm agent owns (the handoff)

1. **Verify the field protocols** (3-min all-out test, multiple-TT critical-speed method) against the literature. Confirm durations, validity, fit math. Do not inherit this doc's numbers as truth.
2. **Define the speed–duration curve fit** — model, inputs (which run segments qualify as maximal), output params.
3. **Define the progressive-refinement update rule** (§4.2) — how ordinary runs revise N without being corrupted by easy days.
4. **Define decay and decoupling computation** (reuse the capture brief's GPS-cleaning output as input).
5. **Define the `confidence` function** — how much data yields how much certainty.
6. **Refine the 脚質 classifier** beyond the quartile heuristic.
7. Everything numeric stays deterministic code. (Per the idea-capture §31 note: no LLM arithmetic on the series. The model narrates the diagnostic later; it never computes it.)

---

## 8. Epistemic summary (so nothing ships as false precision)

- **Established science (confident at concept level):** lactate threshold, critical speed/power model, cardiac drift/decoupling, heart-rate recovery, effort-distribution analysis.
- **Field proxies (label as such in UI):** everything the app measures is a consumer-sensor approximation, not a lab value. Never present a proxy as a clinical measurement.
- **Needs verification (do not trust this doc):** exact protocol parameters — durations, rest, number of efforts, fit coefficients. Ground in the literature, then tune against real data.
- **Product-design reasoning (mine, not science):** the three-tier "not a one-time gate" structure (§4), the `confidence`-driven progressive refinement, the hardware-scaling framing.
