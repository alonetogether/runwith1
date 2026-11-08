# Run With — working notes for Claude

## What this folder is

Five design documents at the root and one iOS prototype in `RunWith/`. The
docs are the spec; the README in `RunWith/` is the record of what was built
and why. Read the README before changing behaviour, and update it when you do.

Canonical doc per topic:
- Recorder scope, Run schema, cleaning: `RunWith_NativeCaptureSpine_BuildBrief.md`
- What may be claimed about a run, honesty rails, gear check, sensor tiers:
  `RunWith_Diagnostic_Design.md`
- Product intent, mascot, ghost runs, long-term ideas: `AR_Runner_Idea_Capture.md`

## Principles that are not negotiable

- Phone-only is always one tap from Start. Sensors are offered, never required.
- Every stored number carries `source` and `fidelity`. Nothing ships as false
  precision; an estimate says so.
- Capture wider than you interpret. Store identifiers and raw streams now;
  analyse later.
- Deterministic code computes; no language model does arithmetic on a series.
- Observations are phrased as observations ("this time", "an observation, not
  a cause") with their rails in code and in tests.
- The character asset stays on the user's side of the wall; nothing of it is
  redistributed.

## Build and test

- `cd RunWith && xcodegen generate` after adding files; `project.yml` is the
  project definition.
- `cd RunWith/RunCore && swift test` runs the pure logic tests on the Mac.
- Simulator and phone build/install commands are in `RunWith/README.md`.
- Thomas's phone is a personal-team sideload that expires every 7 days.

## Model split: when to call `/advisor`

This project is normally driven by Opus. Some decisions are better made with a
Fable review first. Offer `/advisor <question>` in one line, without waiting
to be asked, when:

- a change touches the Run schema or any stored format;
- a new insight or metric needs honesty rails decided (what it may claim,
  when it must refuse);
- the diagnostic maths is involved: curve fit, update rule, confidence,
  benchmark detection, grade adjustment;
- two docs could be read differently and the reading changes the build;
- a bug has survived two fixes, especially anything in the 3D pipeline
  (units, bind poses, bone conventions, Blender exports);
- a plan would touch more than about five files and has not been reviewed.

Everything else (views, connectors, plumbing, reinstalls, tests) proceeds
without it. The skill explains how the hand-off works.
