# Run With — Idea Capture (Sessions 1 & 2)

*A companion to the original Concept & Build Brief. That document holds the structural concept; this one holds the layer of mechanics and strategy that came out of working sessions. Written to be dropped into the same Claude project as shared context. Where the brief says "here is the thing," this says "here is **why** the thing keeps rhyming with itself."*

---

## 0. The spine (read this first — everything else hangs off it)

There is one idea under this entire product, and it shows up on **four** layers. Naming it explicitly so it doesn't get treated as four separate features when it's really one principle wearing four costumes.

**The embodiment gate (身体性ゲート — *shintaisei gēto*, the "you must be physically present" constraint): you cannot access the thing without your body actually doing the work.**

| Layer | What's gated | How |
|---|---|---|
| **Viewing** (original brief) | The deeper run data | You can't see real stats until you run the route yourself |
| **Authoring** (new) | Recording a voice clip | Mic only opens when your body is genuinely in-state (above baseline, final stretch) |
| **Reward** (new) | Unwrapping a celebration | The "dap" only opens when you cross the finish line |
| **Body** (new) | The ghost's naturalness | Gait responds to real race-state (effort), not to scripting |

**Design rule that follows:** when a new feature idea appears, check whether it's the gate in a new costume. If it is, it's probably load-bearing and you should protect it. The gate is the product's honesty mechanism — it makes things *structurally unfakeable* instead of asking the user to trust that they're real.

---

## 0.1 The thesis underneath everything

Daily life is layers of mediation over hyperreality. Direct exhortation ("just go run") bounces off because nothing unmediated lands anymore. The move is counterintuitive and correct: don't fight the mediation by stripping it away. **Add another layer of mediation — but one pointed *inward*, toward something real.** The legless Lightning McQueen is unreality used to smuggle a depressed person into something actually real: breathing hard, in a park, with a friend's real voice beside them. The paint, pointed inward.

**The product in one sentence:** A celebration of what your body can do, in spite of banal times, by bringing in the absurd, and the potential of human connection when technology is done right.

**The product in two words: Run With.**

---

## 0.2 The artifact taxonomy (settled — do not redesign)

Three distinct artifact types. They are not the same thing and should not be collapsed.

**Route** — geofenced, fixed ground. A specific piece of real geography someone walked through to define, or selected from a tested library. Tethered to coordinates. The Yoyogi loop. A track. A waterfront stretch. Margin of error matters here because the ground is the point.

**Run** — portable, person-shaped. Defined by duration and effort rather than place. The Arima Kinen *experience* you can run on a mountain. The sunset run your friend left across a time zone. The grief run. The beer run. The shape of effort, not the shape of ground. UGC lives here because UGC doesn't care where your feet are. **Runs are the most shareable artifact** — they travel, they broadcast, a VTuber can share one, a mommy ASMR creator can share one, it lands wherever the recipient is.

**Race/Event** — a Route or Run that's been *opened*. Public or invite-only, tethered to a time window, visible to other people. The opening is the act. The tethering to people — not just space — is what makes it a Race or Event rather than an artifact sitting quietly waiting.

The social architecture maps cleanly: Routes and Runs are content atoms. Events are activations of those atoms. You make a Route or Run first. Then optionally open it as a Race or Event. Two separate acts, two separate decisions.

---

## 1. Condition-gated voice clips — playback (非同期ボイス, *hikōki boisu*, async voice)

A recorded voice line **bound to a race-state condition, not a timestamp.** It fires when the *situation* matches — when you're ahead, behind, flagging on a climb, two seconds back with 200m to go — not at a fixed moment.

- The friend isn't recording a message. They're recording **a reaction to a future they can't see yet** — pre-loading themselves into a moment that hasn't happened. When it fires on real timing, it lands like they're actually there, even though the recording is dead.
- **The app contributes nothing except *when*.** The whole emotional payload is in the friend's actual voice and the relationship it carries.
- Register is the proof it works: "you got more, I know you" / the British "you fat fuck, do you want to lose 2kg or not" / a grudging やるじゃん / Haru Urara wired to gasp 負けないぞ. None of these can be synthesized; each carries a whole friendship. Absurdly high emotional payload, absurdly cheap mechanism.

**Plays spatially.** A neck-and-neck line must come from *beside* you — panned level, at the shoulder — because that's where the body reads "we're tied." Centered = information; at-the-shoulder = a presence drawing level with you.

**Anti-habituation is mandatory.** These lines are devastating *once* and an active irritant by the tenth play. Small bank per condition, rationed, rotated, weighted toward lines you haven't heard lately. Scarcity is load-bearing.

### Three authoring phases

**During the run** — condition-gated capture, embodiment-locked, the mic opens when your body earns it. Authentic but not deliberate. You're gasping, you're not curating.

**After the run (post-run editing)** — deliberate authoring against the race data. You see your pace curve, where you surged, where you flagged. You record clips *for specific conditions* — calmly, with full knowledge of what each moment feels like because you just ran it. The authenticity of knowing the moment from the inside, without the physiological constraint of being in it.

**Three anchor points for authoring:** start, mid-race in motion, finish. These map onto the three emotional beats of any race — anticipation, effort, completion. The mid-race anchor is the only one that's physiologically gated. The structure tells you what to make. Clean, simple, extensible.

**Condition categories for post-run authoring:** neck and neck (the pressure clip), falling behind (the one that either breaks you or saves you), up ahead (the generous or trap one — author decides). These are the premium authoring layer on top of the three anchors.

### Clip does not expire for slower runners

The finish line audio, the dap, the condition clips — these wait for whoever runs this, regardless of how long it takes them or how far behind the ghost they finish. A clip keyed to "neck and neck" has a gap condition by definition. Everything else is yours when your body earns it, not when your pace earns it. The slowest runner in an event gets the finish line moment. They earned it more honestly than the person who cruised through ahead.

---

## 2. Condition-gated voice clips — authoring (the better half)

The mic **only opens when the runner is genuinely in-state** — above baseline, in the final X% of the piece, actually gasping. The exhaustion in the recording is *real* because the gate decided when capture was possible.

- This is the embodiment gate applied to **authoring**. You can't fake the last-stretch clip any more than you can fake the run.
- A friend actually redlining, breath ragged, gasping a line out between real lungfuls — **that artifact cannot be performed.** The authenticity is *in the signal*.
- **Symmetry to protect:** playback is condition-triggered; authoring is now also condition-triggered. Author-state matches playback-state.
- **The friction IS the value.** Resist the urge to add "couch recording for convenience." The moment you allow comfortable recording, you've reintroduced the acted clip and lost the whole thing.

**Form follows the constraint.** Nobody redlining delivers a paragraph. Three or four ragged words. Design capture for one short gasped line.

### Capture hygiene
Recording while playback is live means your mic eats your own spatial mix — and **it compounds across generations of runners.** Handle エコーキャンセル (*ekō kyanseru*) at capture:
- Real-time light pass: RNNoise (open, small, phone-capable).
- Optional heavy pass in cooldown: Demucs-family source separation.
- Default = strip the engine's own audio, keep the world's ambient. Real-world park sound is texture; engine bleed is contamination.

---

## 3. Capture-automatic, publish-deliberate (the privacy/safety model)

The mic opens on a physiological trigger; **the human decides if the artifact lives.**

- Capture is automatic. **Publishing is a deliberate, separate act.**
- The "keep this clip?" decision lives in the **cooldown phase** — post-run, walking it off — never mid-run. **The run captures; the walk curates.**

---

## 4. The dap — reward gate

An **asynchronous interactive celebration** that you can only "unwrap" by *actually finishing the race.*

- This is the embodiment gate applied to **reward** — the positive-valence counterpart to the competitive taunt.
- **Why it matters more than the taunt:** a product that only has taunts only speaks to people who respond to pressure. The dap speaks warmth. For the depressed person, the person who stopped wanting to move — they don't need "you're losing by two seconds." They need their friend's pre-loaded "you finished, you absolute legend" waiting at the line.

### Dap mechanics
- **Haptic interaction:** the phone gives you haptic feedback at the finish, you use your thumb to complete the gesture. The quality of the dap is slightly skill-based.
- **Two tiers only: good and great.** No fail state. Both feel like landing it. The delta is quality of contact, not success versus failure. Removing the bad tier was the right call — fumbling a handshake with your friend after a hard run sours the finish line.
- **Notification to sender:** good dap sends a notification. Great dap sends one with a different haptic texture on the sender's end. "She finished. The dap was clean — she had something left." That tells your friend more about the run than any split time.
- **One-time, non-retryable.** The imperfect dap is preserved. It carries the run in it.

### The jump
At the finish line, anyone can jump as high as they can with phone in hand. The accelerometer detects the zero-G zenith. The people who jumped highest are recorded on a leaderboard. It has nothing to do with how fast you ran — the slowest runner might have the biggest jump because they had the most joy left. That's not a bug. That's the whole point. The finish line isn't just a crossing. It's a shout.

---

## 5. Gateway vs. retention — a sequence, not a ranking

The **character lowers the activation energy (活性化エネルギー)** to start at all. "Go run with your oshi" routes around the wall that "go run" can't. The costume gets the shoes on.

The **authenticity layer** — real friend's gasped voice, real exertion, the dap, the gap that's genuinely losable — is why they stay.

**Two stages of the same person's journey, not competing priorities.** The avatar pipeline is not decoration to bolt on later. It's the entrance. Build it close to the trigger system.

**Low fidelity is not a compromise.** A stumpy low-poly Haru Urara gasping 負けないぞ at your shoulder doesn't need to look like a Cygames render. It needs to look enough like Haru Urara that your brain fires the right circuit. Low poly in the right context isn't a downgrade — it's the vernacular of the whole space. The lovability isn't *despite* the low fidelity. It's *because* of it. The absurdity is visible and embraced. Play is the gateway. High fidelity would have killed that. This is also confirmed by the Ugandan Knuckles precedent.

---

## 6. VTuber ghost-broadcast — cold-start skip + mass distribution

A VTuber records a Race and shares it = **one-to-many ghost broadcast.** Cold start isn't solved incrementally — it's skipped. One person with sensors seeds a ghost that infinite phone-only people can race.

The condition-gated authoring produces, for free, the single most valuable content type a parasocial economy has: **the performer's voice under real physical load**, unfakeable. A machine that manufactures authenticity for people whose whole job is mediation.

**The intimate and the mass use case are the same product.** The machine that gets one depressed person moving is the same machine that pulls 10,000 sedentary fans into real cardio because their oshi left a ghost in a park. Meaning and distribution are the same mechanism.

### IP line (relocated and scaled up)
- **Clean:** the VTuber broadcasts the ghost — pace curve + their own authored clips. Indisputably theirs.
- **Dangerous:** users rigging/redistributing the VTuber's avatar model — often agency-owned IP. Keep the model UGC, user-side of the wall, never in your repo.

---

## 7. Platform & monetization — the Discord model

**Free forever, untouchable:** the run, the ghost, the friend's voice, the cardio. Never gate the social core.

**Sell flair + authoring capacity:** more/richer clip authoring, custom profiles, cosmetics, emote rights.

**Geolocation course purchase:** buy an AR course, leave a temporary banner in the space before a race. Sells scarcity tied to real place. Continuous pricing ladder from $3 personal banner → seasonal brand sponsorship. One mechanism, whole revenue ladder.

**The wall:** sell the pickaxe, only take a cut of gold the seller owns. Revenue share on content only on original or properly-licensed work. Never take a cut of creator transactions — this is both a values statement and a statutory condition for safe harbor.

**Open source from the start.** AGPL for the engine. The community you need shows up for open source. You can't manufacture that energy after the fact. The authorship subscription coexists with open source because you're charging for the *hosted platform* — the place where the community already is, the infrastructure, the discovery layer — not the code. Anyone can self-host. Most won't. You charge for convenience and the service, not the commons.

**No premium tier until users ask for things that don't exist yet.** Free authorship tools in the beginning. When active users hit a threshold and start requesting sophisticated features, develop and release a premium tier of authorship and profile customization tools. The threshold isn't a number — it's a signal. Unsolicited feature requests clustering around the same missing capability from people who are clearly already invested.

### B2B surface (year two)
- **Brands with adjacency:** sponsored Events, geolocation course ownership. Post-exertion brand recall is measurably higher. That's the pitch.
- **Health insurance / 健康保険組合:** slow procurement cycle (18 months). Talk to them early; close later. Design the analytics layer now.
- **Tourism operators / 観光協会:** Routes as de facto tours. City governments seeding neighborhoods.
- **Mental health organizations:** the most honest application. Exercise as a behavioral health intervention, delivered through parasocial attachment. Complicated, evidence-required, year three.

### Robux parallel
Soft currency earned by running, spent on authorship boosts and course visibility. Earns while running = the embodiment gate applied to the economy. Nobody resents that mechanic because the earning mechanism is the product itself. Do not copy the obscured-pricing psychology of V-Bucks. Copy the float mechanic and the creator-economy application.

---

## 8. Audio is the primary channel, not the fallback

Reframe: the audio layer was written as a safety net. **It's the floor the whole thing stands on.**

Phone-up AR = fidelity, rare, a gesture + risk. Audio = presence, continuous and free. **Presence is what's being sold.**

**This resolves the 2026 eyewear problem.** Audio glasses people already own deliver the primary experience completely. Visual AR eyewear only delivers the garnish. The dependency was backwards.

**Hardware: open-ear AIR conduction, NOT bone conduction.** Bone conduction bypasses the pinna — throws away exactly the structure the binaural illusion depends on. Open-ear air conduction gives you the L/R axis cleanly, keeps the canal open for traffic safety, and renders binaural cues correctly. Recommended: Shokz OpenRun Pro 2 (running standard), Bose Ultra Open Earbuds (better fidelity, higher price).

**Presence lives in the deltas.** Steady-state audio habituates to wallpaper within a kilometer. Footsteps louder + pan as the gap closes, breathing roughens on a climb, voice clips fire on events. Information in the *change*, not the steady state.

### Haptic feedback layer
Haptic gives you a presence channel that works without headphones — always on regardless of what's in the runner's ears. Specific patterns:
- Steady pulse at the ghost's cadence felt through armband or pocket. Ambient, subliminal.
- Gap closing = pulse gets stronger and faster. Body knows before the brain reads anything.
- Building rhythm as the final stretch approaches, peaking at the line.
- **Accessibility note:** haptic-primary mode gives Deaf/HoH runners the full presence experience. Nobody in fitness tech thinks about this. The architecture supports it for free.

Patterns must survive movement noise — footfalls, arm swing, general chaos of a body in motion. Simple or strong. Nuanced patterns don't survive contact with a real run.

### Hands-free voice UI (Beemo)
During a run, your hands are busy and your eyes should be on the path. A voice command layer costs nothing cognitively if designed well.

**Custom wake word:** on first setup, the user names their companion with speech. The app confirms it heard correctly. From that moment it responds to that name. "Hey Beemo" or "Hey Leon Kennedy" or whatever they chose. The custom name changes the relationship with the device — it's not corporate infrastructure, it's a companion. The naming ritual creates a before and after.

**Mid-run commands only:** record voice clip / stop recording / tag this moment. Not "open settings." Not "show pace history." Only what you'd actually need while moving and gasping.

**Tag this moment** = marks a timestamp + queries what's currently playing on Spotify/Apple Music via their APIs. Post-run editing session shows tagged moments with the song already identified. "You tagged this at 4:23 into your run. You were listening to ユメヲカケル. Attach it to this Run?" Song metadata attaches to the Run artifact. The actual audio never lives on your servers. BYO-local playback.

**Raise to speak:** the phone knows when you raise it toward your face (accelerometer + proximity sensor). Natural trigger for "I want to say something" without a wake word. Raise → mic opens → speak → lower → closes.

**Wake word latency must be under 300-400ms** or the interaction feels broken. This is a real-time audio processing requirement, not a polish item.

**On-device processing:** Apple Neural Engine handles wake word detection, cadence classification, voice transcription — all local, no network call, no data leaving the device. The companion that processes your voice, physiological data, and race state entirely on-device is a fundamentally different trust proposition. "We don't see your data. We can't. It never leaves your phone." Worth saying explicitly and building toward deliberately.

### Companion as UGC avatar
The named companion — Beemo, whoever — can be skinned as a VRM avatar. Not just a voice. A presence with a face, a gait, a character. It's the persistent entity you've named and run with across every session. The avatar that greets you at the start, breathes next to you, says the thing at the right moment. Reactive AI voice for the companion makes sense because authenticity isn't the point — presence and responsiveness are. Pre-canned clips for friend ghosts (authenticity matters). Reactive AI for the companion (variation and novelty matter). Different tools for different emotional jobs.

### Physiological awareness
Cycle tracking (e.g. Love in Deep Space tracks periods), HRV if sensors present, recent session recovery — all readable from Apple Health on-device, none of it touching your servers. A companion that quietly sets a gentler pacer on low-energy days without announcing it is expressing care through the product. Design for this layer eventually. Handle disclosure and consent carefully — physiological cycle data is sensitive in a way pace curves aren't.

---

## 9. Gait capture — naturalness comes from the loop, not the capture

**Tech:** markerless motion capture. MediaPipe (free, phone, real-time) or Move.ai / DeepMotion for SMPL-body fitting → FBX.

**Treadmill is optimal for capture** — constant scale, dead-center, static background, infinite strides. BUT the belt steals push-off and forward lean. Flattens the kick gait specifically.

**Split:** treadmill for cruise + climb base loops; one overground capture for the kick.

**The real craft is the loop, not the capture.** Loop-conditioning (matching pose + velocity at the seam) is what separates "lurching mannequin" from "a person." Budget it as its own task.

**Three gaits, blended by race-state:** cruise / climb / kick. A ghost running one identical loop = a sprite. A ghost whose stride visibly strains when it's working = alive.

---

## 10. Safety

**The real safety mechanism is the audio-first hierarchy.** Not arm fatigue.

**Route-gating:** AR avatar only phases in on a registered course. Open street → audio + glance HUD only.

**Phone-pitch hysteresis:** bake in threshold + hysteresis from the start or the mode strobes.

**The run keeps going if someone stops for breath.** Stopping is part of running. The ghost runs ahead, the gap widens honestly, no UI acknowledges the stop with judgment. No "you paused" notification. No timer counting how long you've been stopped. The app waits. When the runner is ready, they run. The completed Run with pauses is a completed Run.

---

## 11. HUD layout — sequenced, not either/or

**Side-on (gap)** for the cold-start product — the emotional payload is gap.
**Top-down (lateral position)** arrives with the track-meet overlay, once there are bodies beside you.

---

## 12. The geo-artifact — inhabited place

Someone enters a geo-bounded area. The space *already has someone in it*, waiting. Their course, their distance, their difficulty rating, their music if you want it, their voice if you want it.

This is **async inhabitation of physical space.** Someone was here. They left. They left *themselves* here, to whatever degree you want to receive them.

### The consent dial
The artifact has layers, each opt-in:
- Course — yes by default. Just the route.
- Distance reduction — a safety valve. Acknowledges the seeder might be fitter. Not discouragement — the course becomes something you grow into.
- Difficulty rating — someone's honest assessment. Not a static star. **Dynamic difficulty relative to your rolling recent pace history** (60-90 day window, weighted toward recent). "This final stretch runs at a pace you've hit twice in the last month" versus "a pace you've never sustained." Same course, completely different meaning to two different runners. Two reading depths: headline number for quick decisions, expandable shape breakdown for serious runners.
- Music — optional, their soundtrack for this space.
- Voice — the deepest layer, the most personal, choose when you're ready.

This gradient is the gateway-to-authenticity sequence expressed as a **consent dial on a physical artifact.**

### Time-locking
A sunset run isn't just geo-bounded — it's time-bounded. The artifact is *of* that moment and lives *in* that moment. Meeting it requires inhabiting the same moment. GPS-calculated civil twilight by location — the window shifts as seasons change, tracking the real sun. The author defines the window; the platform calculates actual times by coordinate.

Other temporal contexts: dawn runs, New Year's runs, birthday routes that open once a year. The gift doesn't expire. It just has a window.

### The train ride
Taking a train to somewhere your friend runs and leaving a run there for them to find on their usual Tuesday. Not just leaving a run — making a pilgrimage to a place that matters to your friend so that when they show up, they find you already there, in ghost form, having been there before them. That's friendship expressed as geography.

This is the use case that makes the train ride *part of the product.* The platform grows because people make pilgrimages. The growth mechanic is people going somewhere for someone.

### Collaborative spatial mapping (later)
The "open the map" gesture: someone arrives at a location, the app says this area hasn't been mapped yet, do you want to scan. They spend 60 seconds doing a slow camera pan. The area becomes better for everyone who comes after — AR anchors more stable, geo-emotes stop drifting, discovery view feels more real. The map's quality is a direct function of community investment.

Scanning an area could unlock the ability to leave content there. You can't leave a geo-emote somewhere you haven't mapped. Embodiment gate plus spatial contribution gate.

---

## 13. Public events — emergent density, not scheduled moments

A track meet is just the ghost-broadcast format called many times, all anchored to the same geofence, all played back simultaneously when you enter. No new system. Events are activations of artifacts. The event *emerges* when enough artifacts accumulate in one place.

**Nobody has to schedule anything.** The VTuber seeds her ghost on a Tuesday. Her fans run it across the following three weeks. The track meet isn't a moment in time. It's a density of presence that builds up in a location until it feels like a crowd even though everyone ran alone.

**Curation layer on playback:** at scale, fifty thousand ghosts is a blizzard, not a meet. The platform surfaces the ten nearest to your current pace, or the most recent, or the ones whose 脚質 matches yours. Each answer produces a completely different emotional experience. The 脚質 classifier isn't just identity — it's a matchmaking engine for the crowd you run with.

**Post-race Twitch-style chat log:** visible in spectator view. Someone finishing their run from Wednesday gets applauded on Saturday. The timeline collapses. Nobody expected to feel something about this and here we are.

**Spectator view — virtual replay:** two friends race; someone watches them race in a generic 3D course later on their phone or PC in a browser. Or the race is wired to look like it took place in a UGC recreation — a lore-accurate 2500m Arima Kinen mapped to a real 1600m run. Same pace curve data. The fictional course is the stage set. The runner's effort is the truth underneath. Pin the climaxes to course position, rubber-band the connective tissue, steal it from adaptive game audio. Author-defined beat mapping: "this section is the back straight, this percentage of elapsed effort is the final corner."

---

## 14. Dark Souls discovery layer (later)

Walking around a park in discovery view, pointing your camera at space, seeing what people left behind.

**Geo-emotes:** a silhouette doing a motion at a real-world coordinate, visible in discovery mode. Someone with sensors can leave a real captured motion. Someone without can play a pre-canned emote. The ghost is slightly translucent, renders as residual image (残像 — *zanzō*). Designed to look impermanent. The AR rendering should feel like a memory of someone who was there.

**Geo-messages:** short authored text at real coordinates. Not free text — a combinatorial system with a curated word pool, same as Dark Souls message construction. Prevents moderation catastrophe. You must have run the route to leave a message on it. The world only accumulates traces of people who actually showed up.

**AR chat bubble / marketplace:** images and GIFs displayable in AR as a chat bubble above an avatar's head, or as ephemeral Counter-Strike-style sprays at real-world coordinates at actual Events. Manual content approval in early days to set the tone. Automated moderation (hash-matching + ML classifier + community flagging) eventually.

**Discovery view is late-stage.** It requires: spatial mapping infrastructure, enough seeded content to make wandering worthwhile, drift problem solved with accumulated scan data. Don't build it before Yoyogi has enough ghosts to be worth wandering through. The geofenced start zone — a circle on a map, walk into it, ghost activates — is the MVP version of the same idea. Ten-meter radius absorbs GPS error and still feels intentional.

---

## 15. Run types and community

The platform doesn't editorialize about why people run. The format holds everything.

**A partial taxonomy, illustrative not exhaustive:**

*Relational:* "Run with me" (midpoint track between two people, expiration date, dap and recorded audio at finish, sender gets notification when you go through). Friend across the world, golden hour, Nujabes/Uyama Hiroto triggering at sunset. The date run — showing someone what your neighborhood looks like at a certain hour because you can't bring them there.

*Fandom:* Beat Biwa Hayahide as Tokai Teio, UGC course, audio from the anime, positional data at a glance. Hajime no Ippo training run with dynamic music. Uma Musume meet at Inokashira — UGC track, dynamic commentary that parses which Uma avatars are present. "Tokai Teio! Tokai Teio! Sakura Bakushin O!!" All-stars meet, spectator view, Twitch-style chat log.

*Community:* Pilgrimages. 初詣 run on New Year's morning. Oshi birthday run, once a year, the spectator view at midnight shows everyone who showed up. The commute run — someone's ordinary Tuesday preserved, available to anyone who runs the same path. If that person later moves or changes jobs, the ghost still runs that commute.

*Emotional:* The grief run. Someone ran because they didn't know what else to do with their body that day. The pace curve tells you everything if you know how to read it. The Sunday scaries run — サザエさん症候群 — specifically for the 6pm Sunday feeling. People who showed up because the couch was getting dangerous.

*Absurd:* The beer run. Accelerometer detects the sip gesture (lift, tilt, hold, return). Back Tap or dedicated button triggers. Burp and hiccup audio at X sips. Spectator view showing which avatar drank the most and at which kilometer. The boobs vs ass run. This is going to happen. The platform doesn't editorialize.

*Civic:* 49ers winning run. Dodgers winning run. Japan losing the World Cup mourning run — the spectator view at midnight accumulates all the people who ran that night into something that looks like a vigil. Nobody coordinated it. The format just held it.

*Inclusion:* IBS run — mapped routes with accessible bathrooms, voice clips that are just "you're okay, keep going, there's one at kilometer two." Neurodivergent runs — sensory-friendly routes, low traffic, predictable terrain, time-of-day locking for when crowds are minimal. Pride runs — the ghost of the parade, available year-round. People who couldn't be there physically that day finding the route later.

*Music curator:* A geo-scored run. The author scores the experience — what plays on the climb, what drops at the final stretch, what fades in when the route opens onto a view. That's a DJ set mapped to geography. The run is the set. The route is the venue. Deserves its own authorship tier and its own discovery category. "Runs curated by —" the same way a playlist is attributed.

**The thesis underneath the taxonomy:** you're not building courses. You're building a format that any fandom, community, or human condition can pour its mythology into.

---

## 16. Position-locked music sync

Condition-triggered music is the same engine as condition-triggered voice clips, scaled up. The difference is duration and timing precision. A song's climax must land on the physical climax.

**Pin climaxes to course position, not time.** The song isn't a fixed timeline — break it into chunks keyed to course milestones. Time-stretch or cross-fade the connective bits to absorb the runner being early or late. The drop always lands on the final stretch. The elastic is hidden in the low-information sections.

**BYO-local file for music.** Identify via Spotify/Apple Music API (Shazam-adjacent fingerprinting or reading the active playback state). Attach metadata — title, artist, timestamp — to the Run artifact. When someone else runs it, the app prompts them to play it from their own library. You never host audio. You pass a recommendation.

**"Tag this moment" mid-run** marks the timestamp and queries what's playing. Post-run editing attaches the song. Author chooses: play from beginning, or play from the tagged timestamp. Songs are meant to be heard whole — most will choose from beginning. Some will choose the timestamp because that specific moment in the song is the point. Both are valid.

---

## 17. Profile metrics

The profile should read like a small autobiography of how someone moves through the world. Not a fitness dashboard.

**脚質 classification** — earned, not self-selected. Classified from actual run data, potentially shifting over time. One word says more about how someone runs than a pace chart ever could. History of style changes is a narrative.

**Runs left for others vs runs received** — two numbers that say completely different things about who you are in the community. Display without judgment.

**Ghost completion rate** — of all the runs you seeded, what percentage of people finished. A metric about the quality of what you leave, not what you endure.

**Perfect daps given and received** — separately. Different achievements.

**Sunrise and sunset runs** — separately. 5:47am and 6:23pm are different commitments.

**Routes mapped** — how much of your city you've physically defined as a course. Map visualization. Your city gradually filled in with ground you've handed to the platform. 縄張り (*nawabari*).

**Total distance as journey, not number.** Not "1,247 km total." "Tokyo to Sapporo and halfway back." Everyone understands distance as a journey.

**Streak: longest only, not current.** A broken current streak confirms "I knew I couldn't do this" for exactly the wrong user. The longest streak is historical and permanent. You always ran 47 days once. That doesn't go away.

---

## 18. Competitive landscape

**Ghost Pacer** — the most direct predecessor. AR glasses projecting a holographic running partner. Kickstarted $151k from 700+ backers, proved the demand, died on supply chain issues before shipping at scale, project cancelled 2022, patents acquired by Peloton. One generic humanoid avatar, no character customization, no UGC, no community layer, no voice, no dap, no geo-artifact. Monocular 30° FOV projection. The hardware-first bet is exactly what killed them and exactly the bet Run With doesn't make. Their failure is a proof-by-counterexample of why phone-first, audio-primary architecture is correct.

**Uma Racing on Roblox** — 1.45 million community members. Fan-made, openly credits Cygames as IP owner, still running. Implements 脚質 as gameplay mechanics. Synchronous, screen-bound, completely disconnected from real bodies in real space. Proof of demand. The platform Run With is building is what Uma Racing users graduate to when they want to take it outside. The pipeline is: Roblox game → Run With. Not the reverse.

**BUPT student project** — Beijing University of Posts and Telecommunications students independently designed a campus running app with AR, AI voice synthesis, community voice packs, leaderboards, Uma Musume theming. Never shipped beyond campus. Their version uses AI-generated encouragement; Run With captures *real* physiological states. The demand was real enough to generate independent invention across a language barrier. The idea didn't fail. The student team ran out of runway.

**Independent invention across three points of evidence** (Uma Roblox, BUPT, Ghost Pacer) means the concept was inevitable. What isn't inevitable is which version of the thing actually works and why. That's Run With's to hold.

---

## 19. Open source + IP posture

**AGPL for the engine.** Anyone who deploys a modified version as a network service must open-source their modifications. Competitor can't quietly fork-and-close.

**512(c) hosting safe harbor.** You can host user content. Stay blind to what it is copyright-wise. Take no cut of infringing transactions. Remove expeditiously on valid notice. The architecture makes the non-association real, not just asserted. Registered DMCA agent + real intake + real removal (not archive-but-still-usable) required before any public launch.

**Uma Musume:** mechanic (脚質 taxonomy) free to use. Avatar you distribute: no. Cygames is the most legally aggressive IP holder in this space. The horse names are licensed from real racehorse owners. Keep Uma on the user's side of the wall permanently. The 1.45M Roblox community exists under enforcement tolerance, not enforcement permission. The moment your platform has meaningful visibility, the temperature changes.

**Western launch first.** Lower enforcement temperature, natural beachhead, same community that already loves the IP. Japan arrives when the product earns it, same pattern as VRChat. Document everything in English first — the open-source contributor community that will extend the protocol lives on GitHub and reads English READMEs.

**BYO everything.** Users bring their own VRM avatars, their own music files. You distribute the tech, never the characters. The architecture makes the non-association a fact about your infrastructure, not a claim.

---

## 20. Why this exists (do not lose this under the spec)

The person who stopped wanting to move cannot be reached by "just go run." They can be reached by something they already love, rendered beside them, asking nothing except that they show up.

The character gets the shoes on. The authenticity keeps them running.

The train ride to your friend's neighborhood. Leaving a run for them to find on their usual Tuesday. They round the corner and hear your footsteps and don't know why their eyes are stinging, and they run faster than they meant to.

**You were here. They'll know.**

---

## 21. Metric / profile packs — the UGC interpretation layer

**The key architectural move: separate the data from its interpretation.**

The backend collects raw, neutral metrics — cadence, pace variance, elevation handling, recovery-after-drop, split distribution, completion rates, cardiac drift (if HR sensor present). These are *facts*. They are not "Speed" or "Guts" — they are numbers.

A **profile pack** is a UGC interpretation layer that maps those raw metrics onto a presentation a community finds meaningful. Same numbers underneath, radically different self-image on top.

- The Uma Musume pack maps recovery-after-depletion onto "Guts."
- A Dragon Ball pack maps top-end pace onto "Power Level" with the scouter aesthetic.
- A keiba-purist pack maps splits onto the 脚質 framework with racing-form presentation.
- A minimalist data-viz pack for people who hate all of that.

**Why this is a strong UGC surface:**
- **Low IP risk.** A pack is a presentation template — colors, stat names, layout, thresholds, aesthetic. It contains no character models, no audio. Stat names (Speed/Power/Guts/Wit/Stamina) are generic RPG vocabulary, not ownable. Much thinner wall than avatars.
- **Infinite content from finite data.** You collect metrics once. The community builds a thousand ways to look at them. Every fandom re-skins the same numbers into their own language. Enormous content leverage for zero additional data collection.
- **Clean monetization.** Pure self-expression — the Discord-Nitro category. Free tier gets basic stat display. Premium/creator packs are cosmetic reinterpretation. Nobody's gated out of *knowing* their stats — they choose how they *look and feel.*

**The load-bearing discipline: the backend metrics must be a stable, documented, version-controlled API.** If a pack maps "Guts" to a recovery metric and you later change how that metric is calculated, every pack that used it silently breaks or lies. The metrics are an API that UGC builds on top of — same discipline as the ghost format being an open standard. Document each raw value, exactly what it measures, its stable name. Packs build against that contract.

### The Uma Musume stat mapping (the primary example)

Maps onto real backend metrics with surprisingly little forcing — a sign the pack reveals a relationship the framework already intuited, rather than fabricating one.

- **Speed** — top sustained pace. Cleanest mapping, directly measurable.
- **Power** — acceleration capacity + elevation handling. How quickly cadence ramps from standstill; how well pace holds on inclines (GPS elevation or accelerometer pitch). Muscling through resistance.
- **Guts** — performance under depletion (see §22). The most interesting one.
- **Wit / Wisdom** — pacing intelligence. Even splits vs reckless front-loading that collapses. Measured from split variance.
- **Stamina** — distance capacity + pace decay rate over duration.

### "Rainbow training" — the aesthetic feedback layer
In Uma Musume, rainbow training is the visual celebration when conditions align for maximum gain. A pack could bring that presentation language in — a run that hits multiple stat thresholds simultaneously renders as a "rainbow" run, celebrated visually the way the game celebrates it. Not new data — the *feedback aesthetic* the community already has an emotional relationship with, applied to real effort.

### IP fits for the profile/metric framework
The best fits are IPs where **the fandom already quantifies the self** — a native measurement culture the framework satisfies rather than imposes.

- **JoJo** — Stand stat blocks (Power/Speed/Range/Durability/Precision/Potential, graded A–E). The single most natural fit — the source material hands you the grading system fully formed.
- **Dragon Ball** — the scouter, numeric power levels, "over 9000" as a literal breakpoint. Community has measured itself in power levels as a joke for 30 years.
- **Jujutsu Kaisen** — Grade 4 up to Special Grade, maps near-identically to a letter-grade scale.
- **My Hero Academia** — hero rankings, "Plus Ultra" as the go-beyond-your-limit breakpoint (maps onto Guts).
- **Solo Leveling** — the entire IP is a stat screen; E–S hunter ranks; literal "you have leveled up" notifications.
- **Persona** — social stats *including a literal Guts stat*; beloved stat-up jingle aesthetic.
- **Pokémon** — the stat hexagon, read fluently by the fandom; excellent for a five-trait distribution.
- **Blue Lock / Haikyuu / Hajime no Ippo / Kaze ga Tsuyoku Fuiteiru** — sports IPs already about athletic growth and the underdog outworking the prodigy. Thematically identical to what the app *is.*
- **One Piece** — rising bounty number as a progression metaphor.

**Principle:** the framework doesn't impose measurement on a fandom that doesn't want it. It satisfies a measurement impulse the fandom already expresses through jokes, tier lists, and fan-made stat blocks. You're making the joke real — giving people the actual version of something they were already doing with made-up numbers. That's why it spreads.

---

## 22. Fatigue measurement & the Guts philosophy

### The physiological substrate — decoupling / cardiac drift
"Guts" has a real measurable basis. At steady effort, heart rate drifts upward over time even at constant pace — cardiac drift, caused by accumulating fatigue. The honest measure of fatigue isn't HR alone; it's the **relationship between HR and output over time.**

**Decoupling** = the ratio of that relationship. Early run: a given HR produces a given pace/cadence. Later: is the same output costing more heartbeats? If HR climbs but pace holds, the runner is *paying more to produce the same thing* — fatigue made visible. The widening gap between the two curves is a genuine fitness signal serious runners already track (under ~5% decoupling = well-trained aerobic fitness).

**What Guts actually measures: as the cost of running rises, does output hold?** Someone whose cadence stays locked while HR climbs into the red is demonstrating exactly the trait — output sustained *in spite of* mounting cost. Not a forced metaphor; literally what the numbers show.

### Measurement tiers (by hardware)
- **Cadence stability under duration** — phone only. Does cadence hold or decay over the run? Free-tier version, already meaningful.
- **Pace decay vs first-half baseline** — phone + GPS. Negative vs positive splits.
- **Cardiac drift / decoupling** — requires HR (chest strap / watch). The real thing. This is where the sensor affiliate tier earns its place honestly — the metric genuinely improves with the hardware.
- **Second-wind detection** — output drops, HR elevated, then output *comes back* rather than continuing to decay. The purest expression of Guts.

### Stamina vs Guts — where the line is
There is no clean separation in the source material either (in-game, Guts functions as virtual stamina in the home stretch). The distinction worth encoding:

**Stamina is a capacity. Guts is a behavior under depletion.**
- Stamina = how much you have and how slowly it drains. Measured across the *whole* run.
- Guts = what you do when the tank is nearly empty. Measured *only* in the final depleted portion (last 15–20%), relative to how depleted you are at that point. A runner who finishes fresh can't demonstrate Guts — they were never tested.

You draw the line at **depletion state.** Before depletion: measuring Stamina. After the point where Stamina should have failed, everything you produce is Guts. They share plumbing — Guts is essentially "virtual stamina that only exists when real stamina is gone."

### The humane property (this is the emotional core of the whole stat system)
Guts is **not correlated with overall fitness — possibly inversely correlated at the low end.** A fit runner rarely reaches depletion in a normal run, so has *no opportunity* to demonstrate Guts. The novice — unfit, HR spiking early, genuinely suffering, refusing to walk — lives in the depleted zone the whole run. Every run is a Guts exam and they keep passing.

So **a G-rank runner in the absolute sense can be an S-rank Guts legend simultaneously, and it's true, not a rigged kindness.** The person who stopped moving, who dreads every run and does it anyway, is in the truest measurable sense more of a fighter than the natural athlete who finds it easy. The app should see that and say it back — not "you're slow but good effort" (condescending), but "your Guts is elite, genuinely higher than people who finish twice as fast, because you fight through depletion they never even reach." That's a fact that reframes someone's relationship with their own body.

**Narrative property:** two runners with identical finish times can have opposite stat sheets. One cruised (decent speed, untested guts, never suffered). One clawed through (lower speed, elite guts, fought the whole way). The system tells them apart. The person who finds running hard gets to be legibly, provably the more tenacious.

**Honesty check:** this only works if Guts is *real*, not gamed to flatter beginners. The kindness must come from the reality of the measurement, not from softening it. Fudge it and everyone senses it and it becomes worthless. Keep it true and it's the most motivating number in the app.

**The Guts arc (bittersweet, design for it):** as a Guts legend gets fitter, their Guts score may *drop* — they stopped reaching depletion, it got easier. Frame this as graduation, not regression. "Your Guts was forged when running was hard. It got easier because you got stronger. That fight is why." Let people look back on the version of themselves that had to fight hardest, and honor it. The person you were when it was hardest deserves to be remembered by the system that watched them do it.

---

## 23. Absolute grading vs progressive framing

The most consequential decision in the stat system.

**The tension:** an absolute scale gives achievement *meaning* (a sub-30 5k really is a C; a rank has to correspond to something true or it's participation-trophy noise). But an absolute scale, by definition, tells most people they're near the bottom — and the bottom is exactly the depressed / just-started user whose fragile motivation you're protecting. "You ran your first 5k" and "you are rank G" are both true simultaneously; showing the second can kill what the first started.

**The resolution: absolute scale, but the visible surface is built around progression, not position.**

- **The absolute grade exists** and is anchored to real capability breakpoints (sub-30 5k = C, sub-25 = another, first 10k = another). Crossing into a grade triggers genuine celebration (rainbow aesthetic, rank-up moment). The grade is a *door you walk through*, not a verdict on your worth — and there's always a next door.
- **Show the climb, not the floor.** The dominant visual is trajectory over time — the line going up. Beginners improve *fastest* (improvement is easiest from the bottom), so progression framing structurally rewards exactly the people absolute framing punishes. Let them see the speed of their improvement, not the lowness of their position.
- **Never lead with a low grade for a new user.** Consider not surfacing the absolute grade at all until there's a trajectory to contextualize it. Let them earn a climb first, then reveal where they sit, framed by how far they've come.
- **The multi-stat distribution softens the absolute speed grade.** Speed might be a C, but Guts might be elite. The profile isn't one damning number — it's a distribution that lets a slow runner be legibly excellent at something. The difference between "you're bad" and "you're this specific kind of runner." The second is survivable; the first isn't.
- **No visible ceiling.** The Uma scale continuing up into UG/UF/UE/etc. means even an S-rank has somewhere to climb. Everyone at every level is mid-climb. The elite runner and the beginner are doing the same thing — moving up a scale with no top — just at different points. Nobody's arrived. That dissolves some of the hierarchy.

**The philosophy in one line:** an absolute scale measures the runner, but the runner should experience the app measuring their *becoming.* Position is what you are; trajectory is who you're turning into. Show people who they're turning into. Absolute truth, progressive framing — the number is honest, the experience is kind. Not in conflict if you're deliberate about which one you put in front of someone's face.

---

## 24. Finish-line emote wheel

A radial/wheel UI for selecting a finish-line pose. Inspired by Meccha Chameleon's radial pose selection.

**Why a wheel is right (physical, not aesthetic):** you've just finished a run — hands unsteady, fine motor control degraded, breathing hard. A wheel is the most forgiving input for that state: thumb sweeps toward a *region*, releases to commit. Coarse directional input under stress, same reason weapon wheels work mid-fight.

**Design considerations:**
- **Four to six poses max.** Large angular slices = a sloppy sweep still lands. Cram in twelve and you reintroduce the precision problem. Four poses at 90° each is nearly impossible to miss.
- **Preview the pose, not just the name.** As the thumb hovers a slice, the avatar previews that pose (quick loop / held frame). Selection becomes recognition, not recall — faster and more reliable when winded.
- **Pre-run default + in-the-moment override.** Pre-select a default before the run (no required decision when spent); the wheel is for *overriding* it if the run made you feel something specific. Gives both — no forced decision, but expression available. (Resolves the tension with "don't put decisions in front of exhausted people" — the finish line is the one place a decision feels earned rather than intrusive.)
- **Consistent layout = muscle memory.** Never reshuffle between sessions. "Victory pose is up-left" becomes a flick without looking — the same fluency-reward property as the dap.
- **Coexists with the jump.** The jump is a physical gesture (phone in hand, launch). The wheel is a screen gesture (thumb pose). Sequential, or the wheel selection determines what the avatar does when you jump. Open question worth deciding.

**Category note:** the emote wheel is the first UI pattern in the whole system about *expression* rather than information or effort-gating. Everything else conveys data or gates access behind the body. The wheel is purely about letting someone say something with their avatar at the moment they most want to. This is the same design space as profile customization and the self-expression monetization layer — "who I am" gets expressed here, and self-expression is what people pay for.

---

## 25. The Walk — a fourth artifact type (register, not reduction)

A **Walk** is not a Run with the effort removed — it's a different *register*, which is why it earns its own object. A Run is about what your body **did** (effort, pace, Guts). A Walk is about where you **were** (place, route, presence). Dropping the pace demand shifts the whole center of gravity from effort to place.

**Why it matters: accessibility.** The moment you stop gating on pace, the platform opens to everyone the effort layer quietly excludes — the recovery case, the elderly, the depressed person on a day a run is too much but a walk isn't, anyone who physically can't run. Not a footnote; it roughly doubles the addressable population.

**Object definition:**
- **Distance and route** — the core. A Walk is route-first.
- **Pace** — tracked quietly, *optional to offer.* The person doesn't have to expose it. (Embodiment gate still holds — you were there, you moved through space — but the competitive/effort layer relaxes.)
- **Playlist** — a *first-class* field, not an afterthought. A Walk is a vessel for music in a way a hard run isn't: you curate a walk *around* a playlist, not the reverse.

**What's worth tracking on a Walk (different from a Run — pick the things that fit the register):**
- Elevation as a **journey** ("you climbed the equivalent of a 14-story building"), not a performance stat.
- **Novelty / exploration — the sleeper metric.** How much *new* ground vs. ground already walked. "You've now set foot on 23% of your neighborhood." A Walk rewards exploration; a Run never bothers. Genuinely fun, genuinely sticky, and it feeds §26.
- **Places passed** — the geo-artifact discovery layer *lives* in Walk, because walkers stop and look.
- **Photos** along the route.
- **Consistency / cadence of showing up** rather than performance.

**Register:** Walk is **companion-register by default** — the ASMR-companion layer, the music-curator layer, and the geo-discovery layer all belong here more naturally than anywhere else.

*Taxonomy note: this makes four content atoms — Route, Run, Walk — plus Race/Event as the activation of any of them.*

---

## 26. GPS route art — drawing on the map with your body, composable across sessions

Tracing pictures with your GPS track exists in the wild ("Strava art" / GPS art / GPS drawing). **The novel addition: composition across multiple sessions.** Nearly all existing GPS art is one heroic single outing. Letting someone **overlay specific Walks and Runs to build one drawing over days** is both more forgiving (you don't have to draw the whole thing in one go) and more poetic — the body making a slow mark on the city over time.

- Pure **self-expression surface** — inherently visual, inherently shareable (GPS art spreads on social media by nature).
- Natural home is the **Walk** object (GPS art is slow, deliberate, usually walked).
- On-thesis: *you draw on the map with your feet, across your life.* The body making a mark on real geography. Ties into the exploration/novelty metric (§25) and the territory/geo layer.
- Mechanic: select and overlay chosen tracks → the system renders the composite line-art → optional share/export.

### Fog-of-war walk packs (the % explored, visualized)
A community-authored Walk pack where unexplored map is hidden under fog that clears as you physically cover ground (e.g. a StarCraft-probe "scout the enemy base" theme).

- **Not ambitious — it's the §25 exploration metric *rendered dramatically.*** The same covered-ground data you already track, shown as a reveal mask instead of a percentage. The mechanic is solved and *crowded*: shipped apps include Fog of World, Fogwalk, FOG: Fog of War Walking Map, FogWalker, FowIRL, and open-source implementations. Buildable, not research.
- **Map API:** for a custom fog mask you need to composite/punch holes in an overlay → use **MapLibre + OpenStreetMap (free, open)** or **Mapbox (generous free tier, best custom styling).** *Not* Google Maps (pricier, historically stricter on heavy custom overlays).
- **IP wall holds:** fog-of-war-as-mechanic is unownable (the *concept* of scouting/fog). The StarCraft probe *sprite* and sound cues are Blizzard's → a probe pack is a community **Companion** (user brings the skin + voice bytes; platform provides the fog engine). Same partition as everything else.
- Architecturally: a fog-of-war walk is a **Walk** + the **map-fog Display** (§30) + a themed **Companion** firing **Moments** (§28). Not a new system — a composition of existing ones.

---

## 27. Re-benchmarking and the mascot "trending up" slot

The diagnostic/baseline race from the original brief (the N+1 measurement) becomes a **repeatable ceremony**, not a one-time setup. "Test me again."

- **Why:** improvement must be *legible* (see §23, absolute-vs-progressive framing). The most legible form is a deliberate, ceremonial re-measurement where you watch your own curve move — the Uma Musume "check your stats" moment made real.
- **Mascot / Companion "trending up" slot:** a reaction that fires when the system detects *sustained* improvement across benchmarks. This is the companion **noticing you got better** — the single most emotionally potent thing the app can do, because being *seen improving* is the thing almost nobody in a struggling person's life actually does for them. Expose it as an explicit authorable slot (it's a Moment — see §28 — with trigger `benchmark_improved` / `trending_up`).

---

## 28. Moments — the unifying creator-tools primitive

**The architectural clarification:** a **Moment** is a **trigger + a payload**, and it is the single atomic primitive of the entire creator-tools system. Everything designed across the whole project — condition-gated voice clips, music drops, the dap, announcer callouts, ability-casts — was never a set of separate features. They are all *the same mechanism*: something that listens for a condition and fires a response. (This is the same collapse-into-one-primitive move as the embodiment gate and the ghost format. When the same thing keeps reappearing in costumes, name it once.)

**The creator tool is a Moment editor.** Depth comes from the richness of **two composable vocabularies**:

**Trigger vocabulary** (anything the sensors/state can see):
- Race-state: ahead, behind, neck-and-neck, final stretch, halfway, start, finish, pace dropping, pace surging.
- Thresholds: speed above X at the final corner, cadence, elevation, heart-rate zone.
- Progress / position: distance milestones, geo-entry (geofence), lap.
- Meta: `benchmark_improved` / `trending_up`, completion, personal record, time-of-day / light.

**Payload vocabulary:**
- **Short repeatable soundbyte** (cheap, reusable — the connective tissue).
- **Full voice-acted line** (expensive, rationed — the devastating ones).
- Text message.
- Music drop (position-locked).
- Sprite / visual.
- **Ability-cast animation + iconic sound cue.**
- Dap, emote.

### The soundbyte tier (the thing that makes the economy work)
Uma Musume (and gacha dialogue generally) doesn't fully voice every line — it layers short canned reaction bytes (へぇ？ / なんでやねん / なんや) over text. **This is the correct architecture, not a shortcut.** Full VA for every Moment is unaffordable and doesn't scale; a bank of 20–30 short character-reaction soundbytes, recorded once, triggerable across infinite Moments, creates the *felt presence* of a voiced companion at a fraction of the cost.

So the payload vocabulary is **deliberately tiered**:
- **Short repeatable soundbytes** — cheap, reusable, fill the space between big beats.
- **Full voice-acted lines** — expensive, rationed (the anti-habituation rule applies — scarcity is load-bearing; the full line lands *because* it's rare).

Creator tools must expose **both as slots.** A companion feels alive without bankrupting whoever authored it.

### Companions (meta-object)
A **Companion** is a named entity — avatar + voice + personality — that **contains slots for Moments**: a bundle of triggerable reactions tied to a character. Packageable and distributable. (IP wall holds: official Companions on the agency-controlled side; community Companions UGC-side, BYO — same partition as everything else.)

### Packaged Runs
A **packaged Run** is a Run artifact with a dense set of Moments, soundbytes, and sprite references baked in — a complete authored experience someone can obtain and run. (Same for packaged Walks, packaged Companions.)

---

## 29. The Arima Kinen target experience — Moments at full density (north-star / existence proof)

The community-authored "taste the Arima Kinen" experience is **a Run** (portable, effort-defined, re-mappable to any ~2.5km of real ground), packed with **Moments**, cast with opponent **Companions**. Optionally tied to a real **Route** if someone maps it to an actual track for the authentic version — but fundamentally a Run densely authored with Moments.

Composition:
- **Starting soundbytes** — the gate, the announcer intro (Moments on trigger `start`).
- **Sprites** — opponent avatars (Companions).
- **Announcer soundbytes** — play-by-play calling your position (a Moment *track* keyed to race position).
- **Opponents casting abilities** — Companion-Moments firing visual + sound on race-position triggers.
- **You casting your own ability** — homestretch-haste animation + the iconic game sound cue, firing when you hit a real speed threshold at the final corner.

### The gate, extended — a NEW layer worth promoting into §0
**You cannot trigger your own ability-cast by tapping a button. You trigger it only by actually, physically accelerating at the final corner.** The game's most satisfying feedback — the power-up animation, the screen flash, the iconic sound cue, the feeling of *being* Tokai Teio — is locked behind your real body doing the real thing.

This is **the embodiment gate applied to game feedback**, and it may be the most elegant layer yet: it turns the entire vocabulary of game-feel (power-ups, screen effects, iconic cues) into rewards that are **structurally unfakeable**. The dopamine of the ability-cast is *paid for in real acceleration.* Nobody has done this. It is a candidate fifth row for the spine table in §0:

| Layer | What's gated | How |
|---|---|---|
| **Game feedback** (new) | Your own ability-cast / power-up animation + iconic sound | Only fires when your body actually hits the physical threshold (e.g. real acceleration at the final corner) |

---

## 30. Displays — the second creator surface (the persistent view layer)

**Moments (§28) are only half of creator agency.** A Moment is a *triggered event* — it happens at a point in time, then goes quiet. But a creator also needs agency over what is **persistently on screen** — at the start, and continuously during the activity. That is a different authoring surface and deserves its own name: **Displays** (the HUD / the broadcast-graphics layer).

**The clean frame is a sports broadcast, which keeps these two layers distinct and never confuses them:**
- The **announcer** (play-by-play, fires on events, quiet between) = **Moments.**
- The **on-screen graphics package** (position chart, gaps, clock, leaderboard — *always there*, continuously updating, never "fires") = **Displays.**

So the full creator-tools surface is **two authoring tools**:
- **Moments** — discrete, triggered: *what happens and when.*
- **Displays** — persistent, configured: *what you see the whole time.*

**Display options (creator picks + tunes per experience):**
- **Keiba numbered-dots** — side-on, runners strung left-to-right, gap-focused. The horse-racing position chart. Ships with an Arima Kinen Run.
- **Top-down lanes** — lateral position, bodies beside you. Ships with a track-meet Event.
- **Map + markings** — map API render, POI markers, route trace, **fog of war** (§26). Ships with a Walk pack / probe-scout experience.
- **Minimal / none** — audio purist.

### This resolves the oldest open question in the project
The original brief (and §11) left **top-down vs side-on HUD** as a pending global decision. **The answer: you don't decide — the creator does, per experience.** It was never a product-level choice; it's a Display configuration. Different experiences want different graphics packages, exactly as a horse-race broadcast and a marathon broadcast use different on-screen graphics. **Open question killed — it was a Display setting all along.**

### Hard guardrail — the one place creative freedom can hurt someone
**The Display layer is bounded by the safety hierarchy (§10).** Half-second glance reads, eyes back on the path, audio stays primary. Creators get real agency over the graphics package, but *within the envelope* — no one may author a HUD so dense it becomes a screen you must stare at while running. Creative freedom over presentation, **hard-capped by glanceability.** Both the Moment editor and the Display editor ship with this constraint baked in, not bolted on later. (Note: this, plus the expanding Moment vocabulary, is why the 健全性 review pipeline and the authoring tools must grow up *together*, not two years apart — a richer authoring surface is a larger surface to moderate.)

---

## 31. LLM tokens — capability note (deferred, not an architecture yet)

*Flagged, not committed. Cart before the horse — none of this is needed to prove the core. Recorded only so the capability isn't forgotten.*

We have Claude/LLM tokens available. Where they plausibly belong, when the time comes:

- **Personalized, persona-driven dialogue for the *assistant/companion*** — the synthetic side only (Beemo, the tuned pacer, the mascot). NOT the friend-ghost or VTuber-ghost, where the whole value is that it's really them. Same wall as reactive AI voice (§8-ish / companion sections): generated language for synthetic companions, real capture for authentic ones.
- **Narrate, don't compute.** The LLM never does arithmetic on the time series — metrics (decoupling, 脚質, split variance, benchmark deltas, the diagnostic/re-benchmark curve) stay deterministic code. The model takes the *computed* packet and turns it into readable, in-character language. Compute with code, narrate with Claude.
- **Diagnostics debrief** is the natural first fit: code computes the benchmark curve, the companion reads it back in persona ("you're trending up"). Grounds the mascot "trending up" slot (§27) in real numbers instead of a canned line.
- **Three hard caveats for when this is actually built:** (1) *Grounding* — feed only computed numbers, forbid the model from emitting a figure of its own, or it fabricates stats. (2) *Latency* — no live mid-run calls; the sub-500ms Moment budget forbids a round-trip. LLM is cooldown-phase / pre-computed only. (3) *Privacy* — location + physiology is sensitive and cloud calls cut against the "never leaves your phone" story; decide the fork (on-device small model vs. opt-in cloud vs. anonymized) deliberately, not by default.
- **Cheap near-term PoC if ever wanted:** a post-run debrief generator — feed a GPS/HR file, code computes the packet, Claude writes the persona readback. Buildable in a day, good demo, needs none of the real-time engine.

---

## Appendix — moderation note
UGC avatar platforms live and die on the 健全性 (*kenzensei*) moderation layer. "Our most enthusiastic early contributor is also our first moderation headache" is a sentence every one of these platforms has written. Budget for it. Daru is a person *and* a category.
