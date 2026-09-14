# Flat World, Round World

*Design reference, not a build instruction. Second pass at information architecture, narrowing from the ten options in [`ia-ten-shapes.md`](ia-ten-shapes.md) to a named fork and six sketches. Read [`companion-and-retention.md`](companion-and-retention.md) alongside it — the companion model there is the current one.*

There aren't variations of one app here. There are two: a conventional one made of screens, and a spatial one you inhabit. Both honour the same three commitments. Naming the fork is the useful part; the sketches just show what each side looks like.

---

## What both sides must have

**Go means go.** One tap, cold app to running, choosing nothing. Defaults to a free run with your companion along. Picking a specific Run is a deliberate detour, never a toll gate.

**Someone's already here.** The companion covers the cold start, when the friend graph is empty. Ships with defaults, accepts your own, present on the landing surface rather than buried in customisation.

**Runs are objects.** A Run arrives as a thing with weight and art, sealed until opened — not a row in a list. Held rather than browsed.

---

## The fork

This is the real decision. Engine, asset pipeline, team, and timeline all follow from it.

### Family one — Flat

Screens, sheets, and lists. The companion is a rendered portrait rather than a body in a space. The map is Google-shaped: overhead, pannable, with a card sheet riding over it.

Objects are tangible through art, physics, and haptics — a cube you flick and it tumbles — but they sit on a surface, not in a world.

*SwiftUI · weeks · one person can build it.*

### Family two — Round

You boot into a place. A small room you can scurry around, the companion standing in it, cubes as objects on actual shelves. Step out the door and the map is a perspective overworld — Pokémon Go rather than Google Maps — with friends' avatars standing where they are.

Viewing a friend's run means *taking their camera* while their character runs it.

*RealityKit or SceneKit · months · needs an art pipeline.*

### You don't have to choose yet — but you do have to capture

Flat can ship first and grow into round **if the data model doesn't forget**. A spatial replay needs route geometry, per-second cadence and effort state, clip trigger times, and music timestamps. The Run artifact already carries all of it.

So the near-term rule is simple: let the flat UI decide what you *render*, never what you *record*. Capture at spatial fidelity from day one and the round world stays reachable. Capture at list fidelity and you've closed the door without noticing.

*This rule is now in `CLAUDE.md` as a build constraint.*

---

## The object

One good face is enough to feel real. More faces are worth exploring, not required.

- **Front** — cover art and who it's from. This alone, done well, carries the whole idea: a chunky object with weight, a little tumble physics, a soft landing sound.
- **Pulse** — their cadence signature, felt as haptic taps while you hold it. You feel their footfall before reading a word. The strongest argument for objects over rows.
- **More, optionally** — voice clip count, the music that was playing, route line, effort shape. A six-sided information puzzle is a worse toy than a lovely single face.

**States:** sealed (arrived, unopened) · opened (contents known) · resident (downloaded, safe to leave the house) · run (you've done it) · closing (time-locked, expiring).

Sealed is a real state, not a badge. An unopened cube should feel like an unopened package — holdable, its cadence felt through the glass, contents still unknown. Opening it is a moment worth designing, and it's the cheapest emotional beat in the whole app.

---

## Flat — three layouts

### F1 · The Doorway
Companion full-bleed, one Go button beneath, everything else in a sheet you drag up over them — shelf, inbox, map, profile, store. Cubes appear as a row on the first drag, one gesture away without competing with Go.

*Purest read of the brief. Ruthless about the doorway moment. Risk is that everything else feels hidden and discovery quietly dies.*

### F2 · Shelf and Door
Companion and Go on top, cubes scrolling along the bottom, a thin tab row beneath. Two things visible at once, both in thumb reach. A sealed cube from a friend nudging into view is the strongest re-engagement moment that isn't a notification.

*The balanced one. Least likely to be wrong, least likely to be remarkable.*

### F3 · Go Core
A large Go occupies the middle; small entry points surround it — inbox and shelf above, find and profile below. Tap runs free, hold chooses an artifact first. The companion is reduced to a reactive strip.

*Cheapest to build, easiest to test. The honest proof-of-concept shape — proves the Go instinct without betting on art you haven't made.*

---

## Round — three layouts

### R1 · The Room
Boot into a small room you can move around. Everything is furniture — a mail slot for arrivals, shelves holding cubes, a mirror for your profile, a window onto the map, a door you leave through. Navigation stops feeling like navigation; new surfaces arrive as new objects rather than new tabs.

*Highest fondness, highest cost. Nothing else builds attachment like a place you keep returning to, and nothing else collapses as badly if the art is weak.*

### R2 · The Overworld
No room — you're always on a tilted perspective map of the real world with your avatar standing on it. Routes drawn on the ground, friends' avatars where they last ran, events visible as gatherings forming. Going somewhere is the same gesture as browsing.

*Strongest single idea for Routes and Events. Weakest for Runs, which have no place and would have to live in a menu, fighting the metaphor.*

### R3 · Room and Overworld
Two connected spaces. The room is home — companion, shelf, inbox, mirror. Stepping through the door transitions to the overworld, where Routes, Events, and friends live. Portable Runs live indoors on the shelf; placed Routes live outdoors on the ground.

*The one that actually resolves the artifact model. Runs are things you own, Routes are places you go, and the architecture says so without a single label.*

**Note:** the roster model in `companion-and-retention.md` strengthens the case for this family. Rotation works flat, but *encounter* — running into a different character in a different part of the space — needs somewhere to be.

---

## The mechanic worth protecting, in either family

Taking a friend's perspective while their character runs their route is the strongest idea in this whole thread. It's the embodiment gate rendered as a camera — you don't watch their run, you occupy it. Their voice clips fire where they fired, their cadence drives the footfall, their music plays.

It works natively in the round family. It also works flat, as a replay scrubber over a map with haptics and audio — less magic, a fraction of the cost, and it proves whether the emotional beat lands before anyone builds a 3D engine to deliver it.

---

## Where everything lives

One canonical map. Entries marked *(new)* were missing from the original plan; *(round)* exists only in the spatial family.

**Home — room or screen**
companion · Go · resume last run *(new)* · recalibrate nudge *(new)* · sealed arrivals peek *(new)* · free movement *(round)* · friend avatars visiting *(round)*

**The run — and the ninety seconds after**
active run *(new)* · effort readout *(new)* · lock-screen surface *(new)* · finish summary *(new)* · cadence signature *(new)* · voice authoring *(new)* · music confirm *(new)* · save or discard *(new)*

**Shelf**
your Runs · your Routes · inbox, sealed *(new)* · downloads and offline *(new)* · history *(new)* · expiring soon *(new)* · physical shelf objects *(round)*

**Find**
map and list hybrid · Runs / Routes / Events · friends · event upcoming *(new)* · event live now *(new)* · event results *(new)* · perspective overworld *(round)* · friend perspective replay *(round)*

**You**
name and socials · 3D avatar · stock metrics · custom metric packages · zones and calibration result *(new)* · running style *(new)*

**Store**
companions and avatars · creator Runs · metric packages · subscriptions · creator tools *(new)* · room furniture and skins *(round)*

**Quiet but non-negotiable**
onboarding and permissions *(new)* · calibration flow *(new)* · privacy and start-point obscuring *(new)* · notification controls *(new)* · connected accounts *(new)* · units, export, delete *(new)*

---

## Two assumptions baked into all six

**Calibration is a run, not a setting.** The act sits with the other running; only the result lives in the profile, where it reads as something earned. Settings gets a single "recalibrate" line.

**Sealed is a real state.** See the object section above — opening a package is a moment, and it's nearly free to design well.
