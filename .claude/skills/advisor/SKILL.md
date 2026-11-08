---
name: advisor
description: Get a second opinion from Claude Fable on a design call, a tangled debugging session, or a plan before a large build. Use when the docs have to be interpreted rather than followed, when two fixes have failed, or when a decision crosses the Run schema, the diagnostic maths, or the 3D pipeline. Invoke with /advisor <question>, or offer it when a trigger in CLAUDE.md fires.
---

# /advisor — consult Fable without leaving the session

You are the builder. Fable is the reviewer. Keep it that way: the advisor
returns a recommendation and its reasoning; you decide and implement.

## When to call it

Call it, or offer it in one line, when any of these is true:

- The question is "what should this be", not "how do I write this": schema
  changes to the Run object, the diagnostic's curve fit / update rule /
  confidence, honesty rails on a new insight, what a metric may claim.
- Two or more of the five design docs bear on the decision and they could be
  read differently.
- A bug has survived two attempted fixes, or the failure involves units,
  coordinate conventions, skinning, or anything in the Blender → glb → SceneKit
  pipeline.
- You are about to start a build that touches more than ~5 files or changes a
  stored format, and the plan has not been reviewed.

Do not call it for plumbing, UI polish, reinstalls, or anything a test can
settle in one run.

## How to call it

1. Write a brief, in your own words, that stands alone. Fable gets nothing
   else. Include:
   - The decision or failure in two sentences.
   - What you have already ruled out, with evidence (test output, screenshot
     findings, numbers).
   - The exact files and doc sections to read, as paths. Point, don't paste.
   - The constraint that matters most (honesty rails, phone-only, no LLM
     arithmetic on the series, IP posture, capture-now).
   - The shape of answer you want: a recommendation with reasoning, or a
     ranked list of hypotheses to test, never a code dump.
2. Launch it:

   Agent with `subagent_type: "general-purpose"`, `model: "fable"`,
   `description: "Advisor: <topic>"`, and the brief as `prompt`. Let it read
   the files itself. Run it in the foreground if the answer blocks you;
   otherwise keep working on what does not depend on it.
3. Relay the answer to the user in a few sentences, say what you will do with
   it, and only then proceed. If you disagree with the advice, say so and why;
   the user decides.
4. If the advice turns out wrong or right in a way worth remembering, add a
   line to the relevant memory file.

## Project pointers for the brief

- Docs: `RunWith_NativeCaptureSpine_BuildBrief.md` (what the recorder is and
  is not), `RunWith_Diagnostic_Design.md` (what may be claimed and how),
  `AR_Runner_Idea_Capture.md` (product intent), the coaching and competitive
  docs for context.
- Code: `RunWith/RunCore/Sources/RunCore/` is the contract (Run schema,
  cleaning, insights, classifier) and has the tests; `RunWith/RunWithApp/`
  is the iOS app; `RunWith/Companion/` is the parked 3D companion;
  `RunWith/Tools/` holds the Blender pipeline.
- The README in `RunWith/` records every design decision taken so far.
