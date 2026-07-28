# Run With

*You're always running **with** something. The sentence never finishes — you finish it.*

A platform for channeling the delight that lives behind screens into a reason to move the body.

## Three prototypes, tested separately

Each file is standalone, dependency-free, and isolates **one** unknown. They are deliberately
not wired together — if you bolt them into one app, a failure tells you "something broke"
instead of telling you *which assumption was wrong*.

| File | The one question it answers | Status |
|---|---|---|
| [`calibrate.html`](calibrate.html) | Can a phone build a personal exertion profile — what *your* jog and *your* sprint actually are? | ready to test |
| [`music.html`](music.html) | Can a web page recover what was genuinely playing during a run, without being told? | ready to test |
| [`index.html`](index.html) | Does an effort state machine track a real body without flapping? (Step 1 of the coaching run) | verified synthetically |

## Run them

No build step, no framework, no Node. Serve the folder over the **loopback IP** — not
`localhost`, because Spotify no longer accepts it in redirect URIs:

```bash
python -m http.server 8765 --bind 127.0.0.1
```

Then open `http://127.0.0.1:8765/calibrate.html` (or `music.html`, `index.html`).

---

## 1 — Calibration (`calibrate.html`)

A guided graded exertion test: stand → walk → leisurely jog → steady → hard → all-out
sprint → cool down. It measures cadence throughout, asks for RPE (perceived exertion, 1–10)
after each stage, and captures speed. Then it derives your zones.

**Two environments, one log schema** — so the runs are comparable afterwards:

- **Treadmill** — you type the belt speed per stage. Exact ground truth; GPS is meaningless indoors.
- **Outdoors** — GPS reads pace live (`coords.speed`, falling back to haversine between fixes). Real conditions, noisier.

It discards the first 35% of each stage before sampling, so you're measuring the pace you
settled into rather than the ramp-up.

**The metric that matters is step length** (`speed ÷ steps-per-second`). In a synthetic run,
cadence rose only ~24% from jog to sprint while speed rose ~154% — cadence *alone* is a weak
way to tell jogging from sprinting, and step length is what actually separates them. The
results screen calls this out explicitly if your own spread comes back narrow.

Exports portable JSON (`runwith.calibration.v1`) and keeps the last 20 runs in `localStorage`.

## 2 — Music provenance (`music.html`)

Spotify Web API via **Authorization Code + PKCE** — no client secret, nothing leaves the
browser, token stays in `localStorage`. Give it a time window; it tells you which tracks were
genuinely playing then.

**One-time setup is yours to do:** register a free app at the
[Spotify Developer Dashboard](https://developer.spotify.com/dashboard), add
`http://127.0.0.1:8765/music.html` as the redirect URI (character-for-character), tick Web API,
and copy the **Client ID**. You never need the client secret — never paste one into a web page.

Scopes: `user-read-recently-played`, `user-read-currently-playing`, `user-read-playback-state`.

**Constraints this test is designed to expose,** because they shape the product:
Spotify caps recently-played at the most recent **50 tracks**, won't page meaningfully further
back, excludes offline playback, and excludes podcasts. A long run — or a busy listening day
afterwards — can push a run's soundtrack permanently out of reach. Better to learn that now
than after building the packaging layer on top of it.

**SoundCloud** is not implemented. Their public API has been closed to new app registrations
for years; a button that always fails is worse than no button. The provider logic is isolated
enough to add one later if access reopens.

## 3 — Coaching effort engine (`index.html`)

Step 1 of the coaching-run prototype: accelerometer peak detection → cadence → a 90-second
median baseline → an effort state machine (`warming` / `steady` / `dropping` / `surging` /
`stopped`) with sustained transitions and hysteresis so it doesn't oscillate. Dev panel for
tuning without stopping; the finish screen logs every transition — that log *is* the experiment.

`stopped` never ends the run and never nags. Stopping for breath is part of running.

**No audio, no clips, no ghost, no GPS** — by design. Audio only gets built once the state
machine is provably stable, because a beautiful audio layer on a flapping state machine fires
clips at random and you'd wrongly conclude the whole concept is dead.

Verified headlessly against a synthetic trace: correct transition sequence, correct baseline,
and a single-tick dip injected mid-steady was **absorbed, not committed** — no flapping.

---

## What is deliberately NOT built yet

Ghost / opponent / gap / racing · spatial audio panning · avatars · servers or accounts ·
the dap haptic · audio recording · any coupling between the three prototypes above.

Each would contaminate a measurement that hasn't been taken yet.
