# Companions, Retention, and the Shape of Engagement

*Product design, not a build instruction. Nothing here is needed for the current milestone. It exists so that decisions made now don't quietly foreclose it — and so the reasoning survives the conversation it came from.*

---

## The engine we're borrowing

Not fitness apps. Visual novels, raising sims, and character games — the thing that has held otaku attention for forty years. Accumulating bonds, content gated behind thresholds, characters who remember you, a roster you encounter around a space.

Those genres solved retention long ago and almost nobody in fitness has looked at them once.

**The inversion that makes it ours:** in a raising sim, *you* train the character and the numbers are fictional. Here, *she* trains you and the stat sheet is real — speed, stamina, guts, all derived from sensor data. A visual novel structurally cannot do this, because it has no sensor. A fitness app has no reason to. We're the only place both halves exist, and the stat sheet becomes the shared object the relationship is actually about: something true for her to react to, refreshing itself without anyone authoring new content, because the body keeps producing it.

---

## The test every mechanic has to pass

**Does it still work on a bad week?**

The person this is for isn't an athlete. They're the one who needs a little unreality to get out the door. So the engine has to survive the weeks where they're slower, heavier, sadder, and ran twice instead of five times — because that's exactly when most fitness products turn into a source of shame and get deleted.

Run the standard mechanics through it:

| Mechanic | Verdict | Why |
|---|---|---|
| Streaks | **Fails** | A broken streak is the single most common quit trigger in habit apps, and running needs rest days anyway. If ever used: "three times a week", and forgiving. |
| Progression / numbers | **Fails** | Strava's engine. Works until the graph turns down, then regression becomes shame at the worst moment. |
| Scarcity / time-locking | **Fails** | Thrilling on form, one more failure off it. Seasoning, never structure. |
| Social obligation | **Mixed** | "She left you a run and it expires Sunday" is enormously motivating — and becomes "I'm letting people down" on a bad week. Also useless at cold start. |
| Collection | **Neutral** | Doesn't punish, doesn't drive. Watch for the Steam-library problem: a shelf of runs you own and never do becomes a guilt object. |
| Companion | **Passes** | Unconditional affection is structurally immune to a bad week. Works at N=1, before any social graph exists. |
| Narrative | **Passes** | A story continues regardless of pace. Almost nobody in fitness does episodic well. |
| Creator drops | **Passes** | New content arrives regardless of your performance, and it borrows an existing fandom's engine instead of building one. |

**The stack:** companion and narrative as the spine, creator drops as the content supply, social as an amplifier once the graph populates. Keep the numbers — show them in the profile — just never make them the reason to come back.

**The ladder.** The engine should change as someone's situation does. Week one, no friends: the companion carries everything. Weeks two through six: creator content. Month two onward, if the graph populated: social obligation takes over and the companion recedes to ambient. Three different engines in sequence, and the app should know which phase a person is in.

**The handoff is solved by not having one.** The companion doesn't compete with social — she *delivers* it. She's the one who tells you someone left you a run, hands it over, mentions your friend was suffering on the back half. Social growth then makes her more relevant rather than less, and nobody ends up paying for a character they now ignore.

---

## What a Companion is

**A bundle, not an artifact.** A Companion can contain Runs, dialogue banks, a voice set, an avatar, home-screen behavior, and unlock rules. Everything optional except identity. Barebones is a name, a portrait, and twenty lines; elaborate is that plus eight Runs, a seasonal arc, and custom classifiers. Same format, wildly different fill.

Runs reference companions. Companions package runs. The Companion is the unit of purchase.

**Two halves of content, authored differently:**

- *Ambient* — greetings, idle lines, reactions to being tapped. Short, contextual, tied to place and time.
- *Run* — condition-triggered, effort-driven, fired mid-effort.

A creator may be excellent at one and hopeless at the other. Price and package accordingly.

### The roster

Freshness comes from *who showed up today*, not from new lines. Eight characters with thirty lines each doesn't feel like 240 lines; it feels like "oh, she's at the door this morning." A greeting heard in one voice is fresh again in another.

This also aligns with how creators behave. Creators want to make *new characters*. They don't want to maintain a subscription to an old one forever. The roster model asks for the thing they already want to do — and one creator going quiet out of eight is barely perceptible, where one going quiet out of one is fatal.

**Casting is its own system:** who greets you at launch, who stands where, who comes running. That configuration layer is the expression loop, and it's monetizable without touching the social core — people buy breadth, never company.

**But the roster needs a primary.** If everyone rotates, nobody accumulates history, and content gated on "ten runs together" never unlocks. Breadth gives novelty; depth gives the reason to lace up when you don't feel like it. So: ambient roster rotates freely, the running slot changes rarely and accrues the bond.

### Cold start

A roster of one is just a companion, so day-one needs four to six characters minimum. The plan:

1. Commission a few originals — they ship prepackaged.
2. Recruit community creators ahead of launch so there's third-party work available from day one.
3. During onboarding, send the user to the marketplace to *pick* their companion — which conveniently already has one or two compelling community pieces on the shelf.

That third step does double duty. Choosing is a commitment moment, so people arrive already invested, and the store opens with activity instead of an empty room.

**The free default must be genuinely good.** If the appealing companion is paywalled, the cold start is gated at exactly the moment someone has no friends and no reason to stay. Charge for *choice* — a specific character, a particular voice. Never charge for having someone there at all.

---

## The launch sequence

Opening the app should put you in a mood. The reference is a PlayStation 2 booting: that sequence works *because it never changes*. Nostalgia accrues on repetition, not variety.

Most apps race to get out of your way. This one should make a small ceremony of arriving — a default "shall we go for a run together?", a custom "run with me!", whatever the companion's author wrote.

**Resolving it against frictionless Go:** the sequence plays over the load, and Go is live the instant it's tappable. You cut through by acting, not by hunting a skip button. Someone in a hurry taps and the greeting truncates gracefully; someone savouring it lets it finish.

Mechanically it's just an event with `condition: app_launch`. Vary it by time of day, days since the last run, weather, and who's rostered — that's the cycling variety, and it costs nothing new.

---

## Two ways to start

**JUST RUN.** One tap. The app quietly tracks route, speed, distance, cadence, and what music was playing. No decisions, no configuration, no artifact selection. This is the default and the thing the home screen is built around.

**Prep a run.** Pick a Run, set parameters, adjust settings. The deliberate path, for when someone wants it — and while they're in the UI, the companion is stretching in the background.

Both produce the same data. Only the ceremony differs.

---

## Events, conditions, and serendipity

The condition system built for voice clips is a **general event system**. Same triggers, different payload — a line, a full scene, or both. Nothing new needs building to get visual-novel events; the payload type just has to widen before creators author against the schema.

### Trigger categories

- **Earned** — a personal record, a milestone count, a first (first rain run, first negative split).
- **Contextual** — weather, time of day, season, a new place or a returned-to route.
- **Relational** — running a friend's artifact, running where they ran, returning after an absence.
- **Random** — the raffle. The hot-spring-afternoon moment.

### The absence trigger deserves the most authored content in the product

More than the personal-record celebration. A record happens when someone is already winning; they don't need help that day. The return-after-three-weeks happens at the precise moment a person is most likely to delete the app forever, and whatever is on screen decides it.

Almost everything gets this wrong — dead streaks, wilted plants, "we missed you" shaped like guilt. The correct version is unconditional gladness with zero reproach. Which is simply *her*: the most beloved runner in the genre lost a hundred and thirteen races and has no standing to scold anyone.

Get that one scene right and it outperforms fifty pieces of content anywhere else.

### Rules for randomness

The gacha toolkit isn't uniformly predatory. The harm concentrates in two couplings, and both are separable:

**Randomness plus money** is the slot machine. Here the currency is *effort* — the event fires because someone ran, not because they paid. Variable reward for exercise is a nice surprise, not exploitation. **The raffle is never purchasable.** If a paid roll ever exists, the whole thing becomes a casino with a treadmill attached.

**Reward plus absence-punishment** is already excluded by the bad-week test.

Strip those two and roughly ninety percent of the engine survives with nothing left to defend.

Three refinements:

- **Shuffle, not lottery.** Randomness decides *when* and *in what order* good things arrive, never *whether*. Everything reaches everyone eventually. Otherwise the person who never rolls the sentimental scene feels cheated and the person chasing it is being worked.
- **Invisible pity timer**, and it must be **global across everything the user has active**, not per-pack. Creators set rarity on their own events; a creator who marks everything ultra-rare would otherwise starve their subscribers with no way for the system to rescue them. Rarity is a creator knob; "you will see *something* eventually" is a platform guarantee.
- **Weight luck toward people having a hard time.** Someone running less, slower, or returning from a gap gets a higher event probability. Someone on a tear needs the lift less. That's the inverse of commercial gacha weighting, which hunts whales — and it's invisible from outside, impossible to feel manipulated by, because it only ever errs generous.

### Bond never decays

It goes up, or it goes up more slowly. Never down.

A Tamagotchi that resents you for a bad week is the cruelest mechanic available for the person this exists for. This single rule keeps all of the accumulation and none of the guilt, and it's most of what separates this from an app someone deletes in March because it made them feel bad about February.

---

## Running style

Real running already has the vocabulary — front-runners, kickers, sit-and-kick, wire-to-wire — and the categories are genuinely classifiable from an effort curve we're already recording. Someone who consistently negative-splits is a late surger.

Ship defaults, let creators register their own classifiers. That folds into the custom metric packages planned for the store: a pack can bring its own way of reading you.

**Unvalidated.** Whether real effort curves separate cleanly into these categories is an open question. Check against actual data before promising it in an interface.

---

## Open risks

- **Creator supply, not creator churn.** The roster makes any single abandonment survivable. The real exposure is the pipeline of *new* characters drying up — which makes creator tooling more load-bearing than it looks.
- **Cold-start content cost.** Four to six first-party companions before any platform effect exists. That's real commissioning spend up front.
- **Dilution versus depth.** Rotation gives novelty, the primary gives bond. Where that balance sits is guesswork until real users exist.
- **Nothing validated on a body.** Every threshold, every claim about what motivates, is currently synthetic or borrowed.

## Deliberately not doing

Streaks. Decaying meters. Login bonuses. Limited-time banners. Paid raffle rolls. Progression as the retention spine.

Each of these works. Each of them fails the bad-week test, which means each of them would hurt the exact person this is being built for.
