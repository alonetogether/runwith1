# Ten Shapes the App Could Take

*Design reference, not a build instruction. First pass at information architecture — ten ways to organise the same set of surfaces. Superseded in places by [`ia-flat-and-round.md`](ia-flat-and-round.md), which narrows to a chosen direction; this document is kept for the comparison.*

Each option answers one question differently: what is the app *about* the moment you open it? The surfaces are identical in all ten — discovery, profile, store, calibration, the run itself. What changes is which one is the ground everything else sits on, and that choice quietly decides what feels easy and what feels buried.

Numbered for reference, not ranked.

---

## 01 — Map Ground
**Root: place.** Map fills the screen; a draggable sheet rides over it, collapsed to a handle, half for cards, full for a sorted list. Everything else opens as a layer on top.

- **Works:** Routes and Events are inherently spatial, and one gesture moves between browsing and reading. Tapping a friend flies the camera to them.
- **Costs:** Runs aren't spatial at all — they're portable and effort-shaped. Putting them on a map misrepresents the one artifact that has no place.
- **Verdict:** Best as a screen, not as the root. The hybrid is right; it belongs one level down inside discovery.

## 02 — Five-Tab Standard
**Root: category.** Discover · Library · Run · You · Shop, with the run button centred and raised.

- **Works:** Zero learning cost. Every surface has an obvious home, and a sixth thing later doesn't break the model.
- **Costs:** Says nothing about what the app *is*. Reads like a fitness app with anime skins rather than something new.
- **Verdict:** The safe floor. Ship it if the others feel risky; you'll never regret it and never be excited by it.

## 03 — Launch Pad
**Root: intent to run.** Opens on what you're about to run — last loaded Run, a friend's drop, your calibration if it's stale. One tap starts. Everything else is a swipe or tab away.

- **Works:** Matches the real moment of use — shoes on, standing in a doorway, thirty seconds of patience. Removes friction exactly where the activation-energy problem lives.
- **Costs:** Browsing and social get pushed down a level, so discovery has to be genuinely good or the library goes stale.
- **Verdict:** Fits the thesis. The character lowers the barrier to starting, so the home screen should be the starting line rather than a catalogue.

## 04 — The Feed
**Root: what's new.** A scrolling feed of friends' runs, creator drops, events opening. The map becomes a filter on the feed rather than a surface of its own.

- **Works:** Strongest retention loop of the ten. A friend's run at the top of a feed is a reason to open the app on a day you weren't going to run.
- **Costs:** Invites passive scrolling — the exact behaviour the product exists to counter. Easy to become a screen you consume instead of a reason to move.
- **Verdict:** Powerful and slightly dangerous. Works if the feed is short and finite, never infinite.

## 05 — The Shelf
**Root: what you own.** A game-library grid of Runs you own, were given, or downloaded. The store is a separate tab, the way Steam separates library from storefront.

- **Works:** Makes Runs feel like collectible objects, which suits creator content and paid artifacts. Offline state becomes first-class and visible.
- **Costs:** Emphasises accumulating over running. A shelf of unplayed Runs is a guilt object, not a motivator.
- **Verdict:** Right idea, wrong slot. The library needs to exist; it doesn't need to be the ground.

## 06 — The Circle
**Root: people.** A row of faces at the top; tapping one opens everything that person has left you — their runs, routes, voice. Browse by who, not what.

- **Works:** Honest about where the emotional weight sits. A friend's gasped voice is the retention mechanic, so organising around people is truthful.
- **Costs:** Falls apart with an empty circle. A new user sees a barren screen, and creator content has nowhere natural to sit.
- **Verdict:** Beautiful at scale, brutal on day one. Needs a populated fallback before it can lead.

## 07 — Train / Play
**Root: mode.** One hard switch at the top. *Train* is calibration, zones, pace, history — sober and numeric. *Play* is avatars, creators, events, friends.

- **Works:** Lets both audiences have their own app without either apologising. The serious runner never sees a cosmetic; the fandom user never sees a lactate curve.
- **Costs:** Splits the thesis in half. The whole point is that the character and the body are one experience, and a mode toggle says they're separate.
- **Verdict:** Solves a real tension the wrong way. Revisit only if research shows two genuinely disjoint audiences.

## 08 — Three Artifacts
**Root: the taxonomy.** Runs, Routes, and Events as literal top-level segments, each with the presentation it deserves — list, map, calendar.

- **Works:** Teaches the vocabulary by using it. After a week nobody confuses a Run with a Route, because the app never blurred them.
- **Costs:** Organises around the internal model rather than user intent. Nobody wakes up wanting "a Route" — they want something to do this morning.
- **Verdict:** Great inside discovery, wrong as the whole app. This is the segmented control on option 01's sheet.

## 09 — The Calendar
**Root: time.** Today at the top, then what's coming — an Event at six, a friend's Run expiring tomorrow, a time-locked sunset route open for another hour.

- **Works:** Events are time-boxed by definition and time-locked Routes were always in the design. The only shape that makes scarcity legible.
- **Costs:** An empty calendar is bleaker than an empty anything else, and it turns a hobby into a schedule you can fail.
- **Verdict:** Hold for later. Comes into its own once Events exist and there's enough happening to fill a week.

## 10 — The Companion
**Root: character.** Your avatar owns the screen and greets you. Navigation happens through them — they hand you the run, mention the event, react to yesterday's pace.

- **Works:** Leans hardest into the actual thesis. No other option converts "I don't feel like running" into "she's waiting" as directly.
- **Costs:** Most expensive to build, and the only one that fails badly when the writing is weak. A companion with nothing good to say is worse than none.
- **Verdict:** Highest ceiling and highest floor. Wrong for a proof of concept, possibly right for the real thing.

---

## The structural opinion

The map-and-list hybrid is the right pattern, one level down. Google Maps is map-first because navigation *is* its product; here the product is the run and a map is how you find one. Making place the ground quietly demotes the Run — the only artifact with no place, and the one you most want people sharing.

**Option 03 as the root, with option 01 inside its discovery tab and option 08 as the segmented control on that sheet**, gets all three ideas without any of them fighting.

---

## Surfaces missing from the original plan

Two are load-bearing enough that the architecture can't be finished without them.

**The run itself — critical.** Every surface was described except the one people are actually here for. The active run screen has its own hard constraints: glanceable while moving, readable in sunlight, usable with sweat on the glass, and it must survive the screen locking. Where "start" lives is the single biggest IA decision.

**Finish and author — critical.** The ninety seconds after you stop. Summary, cadence signature, and the authoring moment — recording a voice clip, confirming the music that was playing. This is where the embodiment gate actually gets enforced, so it can't be an afterthought bolted to the run screen.

**Inbox.** Where a Run someone left you arrives, and where you'd feel their cadence before opening it. Distinct from a feed — this is addressed to you specifically, and it's what makes the app feel like a person reached out rather than a platform serving content.

**Offline and downloads.** People run where there's no signal. Audio, routes, and avatars must be resident before leaving the house, and the app has to make clear what's actually available offline.

**Privacy and location.** Geo-artifacts mean publishing where you ran, which for many people is near where they live. Needs start-point obscuring, a private-by-default posture, per-artifact visibility. Getting this wrong is the kind of mistake that ends a running product.

**Event states.** Upcoming, live now, and finished are three different experiences with different urgency. The live one is the only place synchronous social pressure exists.

**Onboarding.** Motion, location, and health permissions each need a reason attached, and calibration should be prompted here rather than discovered.

**Notifications.** An Event starting, a Run arriving, a time-locked route closing. The retention engine, and the thing most likely to become annoying — so it needs its own settings surface early.

**Creator tools.** If creators publish Runs and sell metric packages, they need somewhere to build and price them. Probably web rather than phone, but it must exist in the model before the store does.

**Real settings.** Units, connected accounts, data export, account deletion. Boring, non-negotiable, and the reason calibration shouldn't live there.

---

## Where calibration belongs

Not in Settings. Calibration is a *run you do*, not a preference you set — twelve minutes, you sweat, it produces a result. Burying it in a settings list frames it as configuration and almost guarantees people skip it.

Put the act of calibrating where runs live, and the *result* — your zones, your signature cadence, your jog and sprint — in the profile alongside the other metrics, where it reads as an achievement rather than a form. Settings gets one line: "Recalibrate", for when it's gone stale.
