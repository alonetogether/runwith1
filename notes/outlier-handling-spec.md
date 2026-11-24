# Outlier handling: reject impossible samples, trim forgotten runs — never interrupt

One-line summary: real phone traces (runwith-data, 2026-11) show two distinct outlier classes — physically impossible pedometer deltas and forgotten-run tails — each needs its own fix, and neither may violate the no-nagging rule.

## Where this comes from

Analyzed the five traces in `runwith-data/phone-runs` on the Windows machine (2026-11-24). Method: consecutive pedometer-report deltas (dt 0.5–30 s), cadence = Δsteps/Δt, speed = Δdist/Δt, step length = Δdist/Δsteps. All numbers below are from these real recordings, not synthetic data.

## Finding 1 — impossible single samples (cleaner logic, uncontroversial)

Two single-sample cadence spikes: **259 spm** (D42F5836) and **518 spm** (E3029360). Both are isolated pedometer report-boundary artifacts inside otherwise ~94 spm walks. Fix in the sample cleaner (SpeedCleaner or a sibling):

- Reject deltas with cadence > **240 spm** (generous physiological cap; owner's measured ceiling is ~165).
- Reject negative Δsteps or Δdistance (none observed, but same class).
- Reject deltas with dt < 0.5 s (quantization noise dominates).
- Rejected samples stay in `raw_streams` untouched — rejection is a derived-layer decision, versioned like any algorithm.

## Finding 2 — forgotten runs (product-sensitive; trim, don't interrupt)

E3029360: a 4.2 h recording, intent "walk", 11,877 GPS fixes but only 404 pedometer reports — a session left running through an afternoon. D42F5836 (17 min walk) is legitimate by contrast.

Constraint that must survive any fix (CLAUDE.md product law): **a stopped runner is not an interruption — no pause dialogs, no "are you still there", clock keeps running.** So no runtime auto-stop, no prompts.

Recommended shape: **trailing trim at save time.** Keep recording everything; when the session ends, mark where sustained effort last occurred and let the summary/stats reflect [start … last-effort], while `raw_streams` keeps the full tail. A `trimmed_at` / `effort_ended_at` derived field keeps it auditable and reversible. Where exactly "effort ended" sits (e.g., N minutes below walking cadence with no intent annotations) is an open design call for the owner — do not pick silently.

## Calibration numbers from the same analysis (this body only)

- Cadence ceiling ~**165 spm**, reached almost immediately at running effort; jog→fast cadence +10–17% while speed +78–90%.
- Step length is the effort axis above ~3 m/s: walk ~0.77 m, jog ~1.1, run ~1.48, fast 1.66–1.91.
- CMPedometer-derived cadence is coarse/quantized (recurring values 94.2 / 117.8 / 141.3 / 153.1 / 164.8) — prefer longer windows or cross-check `currentCadence`.

## Fixtures

Use the five real traces as regression fixtures for both fixes: 6E219791 (2.7 s accidental), 10B1827E (push interval), 9B9A38CF (easy run), D42F5836 (legit walk — must NOT be trimmed), E3029360 (forgotten run — must be trimmed, spike must be rejected).
