# Run With — Native Capture Spine

The recorder from `RunWith_NativeCaptureSpine_BuildBrief.md`: start a run, track it, capture speed/distance/music, save it locally as a versioned Run object, export it. Nothing else. iOS-first, Swift/SwiftUI, phone-only sensors (GPS + step counter).

## Layout

```
RunWith/
  project.yml            XcodeGen definition → RunWith.xcodeproj
  RunCore/               Platform-agnostic Swift package (no UIKit/CoreLocation)
    Sources/RunCore/
      Run.swift          The Run object, schema_version 6, snake_case JSON, pace helpers
      MusicTracker.swift Music log v6: one entry per play, end reason, play time, sightings
      Sprint.swift       Line crossing, sprint splits and the history-gated sprint style call
      SpeedCleaner.swift GPS cleaning pipeline + RunBuilder (source arbitration, raw streams)
      GPX.swift          GPX 1.1 export and import
      Geo.swift          Haversine
    Tests/RunCoreTests/  Unit tests, run on macOS with `swift test`
  RunWithApp/            The iOS app
    Services/            LocationService, PedometerService, MusicLogger, RunRecorder, RunStore
    Views/               GearCheckView, RunningView, RunDetailView
  Companion/             Parked Haru Urara bust (glb + SceneKit views), not in the target
  Tools/                 Blender script and Mixamo sources for the companion asset, app icon drawing script
  Fixtures/              yoyogi_loop.gpx + yoyogi_waypoints.txt for simulator location replay
```

The split matters: everything that defines what a Run *is* and how speed is cleaned lives in `RunCore` and never touches SwiftUI or CoreLocation, so it is testable at the desk and portable to Android later (brief §2).

## Build

Requirements: Xcode 26 with the iOS platform component installed (Xcode > Settings > Components, or `xcodebuild -downloadPlatform iOS`). XcodeGen for regenerating the project after adding files: `brew install xcodegen`.

```bash
cd RunWith && xcodegen generate
```

```bash
cd RunWith/RunCore && swift test
```

```bash
cd RunWith && xcodebuild -project RunWith.xcodeproj -scheme RunWith -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

## Run on your phone (sideload)

1. Open `RunWith/RunWith.xcodeproj` in Xcode.
2. Xcode > Settings > Accounts: sign in with your Apple ID. A free account is enough for a personal dev build (it expires after 7 days and must be reinstalled; a paid account lasts a year).
3. Select the `RunWith` target > Signing & Capabilities > pick your Team. Xcode creates the provisioning profile. If the bundle id collides, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` and regenerate.
4. Plug in the phone, enable Developer Mode when iOS asks (Settings > Privacy & Security > Developer Mode), pick it as the run destination, press Run.
5. First launch: Settings > General > VPN & Device Management > trust your developer certificate.

## Test at the desk (simulator GPS replay)

The simulator has no GPS or step counter. Feed it a path instead:

```bash
xcrun simctl location booted start --speed=3.1 --interval=1 $(cat RunWith/Fixtures/yoyogi_waypoints.txt | tr '\n' ' ')
```

That walks a ~1.9 km loop of Yoyogi Park at 5:22/km. Stop with `xcrun simctl location booted clear`. The Steps row will say "Not available on this device" in the simulator, which is correct.

## Shoes-on acceptance test (brief §12)

1. Sideload, grant permissions in context, start music in Apple Music.
2. Pocket the phone. Tap Start (it only enables once GPS has a fix).
3. Run a route whose distance you roughly know. Second pass: a treadmill segment with Indoor mode on.
4. Tap End Run.

Pass: the saved Run shows a map trace that matches where you went (or a step-based distance indoors), a believable distance, a speed curve that looks like running, a music list of what actually played, every point tagged with `source` and `fidelity`, and it survives close/reopen and exports as GPX and JSON from the detail screen.

## What the recorder does and does not decide

- **Speed is stored truth, pace is derived.** `speed_mps` on every point; min/km only on screen.
- **Provenance on every point.** `source: gps|pedometer`, `fidelity: measured|proxy`. GPS is the live source while fixes keep arriving; after 5 s without an accepted fix the step counter takes over for speed and distance. Cadence from the step counter is attached to GPS points too.
- **Cleaning (GPS):** reject fixes with horizontal accuracy > 30 m, reject implausible jumps (> 12.5 m/s), prefer the chip's own speed when sane else derive from haversine/dt, exponential smoothing with a 3 s time constant, no distance or moving time below 0.5 m/s. Raw speed is kept beside cleaned speed. Every raw fix, including rejected ones, is kept in `raw_streams.gps_fixes`.
- **Music:** two connectors, one entry per play, each entry tagged with its `source`. Since schema v3 an entry also carries what the player said about the track, as explicit nulls when it said nothing: `album`, `isrc`, `track_id`, `genre`, `duration_ms`, `bpm`. Apple Music gives album, genre, store id, duration and a BPM only if the library tag is filled. Spotify gives album, ISRC, track id, duration, and the artist's first genre from one cached artist lookup; its audio-features endpoint is closed to apps created after November 2024, so BPM for Spotify tracks is a later enrichment (Deezer by ISRC). Purpose: relate songs, artists, genres and tempos to performance over time, per song and per window, which needs identity stored from day one. Schema v2 files still load. *Apple Music* reads the system player directly, no network. *Spotify* polls the Web API's currently-playing endpoint (every 10 s during a run) for whatever the account is playing on any device; it needs a one-time Spotify sign-in on the gear check. Other players (YouTube Music, SoundCloud) expose no playback and stay invisible on iOS (brief §5). A track becomes an entry the first time it is actually playing during the run, so one paused at Start and played later is logged when it starts. On End, Spotify gets one final poll (bounded to 3 s) before the run is saved, so a final-spurt track that came on since the last 10 s poll is kept. Before 2026-11-08 both cases were silently dropped.
- **Music log v6: what was played, for how long, and how it ended** (advisor-reviewed, 2026-11-08). Connectors no longer decide what to log; they report every look at the player (Spotify every poll, Apple Music on every change plus a 2 s sample) and `RunBuilder.observeMusic` keeps one open entry per source. Each entry now stores:
  - `sightings`: raw `{t, progress_ms, playing}` looks at the player. Everything below is derived from these and can be recomputed if the estimator changes. They also map run time to song position through seeks (see the tabled drop idea, Idea Capture §32).
  - `started_t`: estimated run time the track began, `t − progress at first sight`; negative when it was already playing at Start. `t` keeps its old meaning, first sight, so old and new runs compare.
  - `ended_t`: when it stopped being current or the run ended. For Spotify a change is timed from the next track's position (seen 4 s in means it changed 4 s ago), never earlier than the last sighting, which pins most ends to about a second instead of the 10 s poll.
  - `played_ms`: time audibly playing inside the run, from position advances clamped to wall time, so pauses do not count.
  - `end`: `completed` (position reached the end within 15 s, allowing crossfade), `skipped` (replaced before the end), `stopped` (paused or stopped and never resumed), `run_ended` (still playing at Stop: the final-spurt song), `lost` (an ad, a private session or a recording gap).
  - `timing_fidelity` and `timing_method`: Spotify `estimated` / `spotify_poll_10s_progress`; Apple Music `measured` / `system_player_notifications_2s_sampling`. One pair per entry, since all its times share one connector.
  - `artwork_url` (Spotify cover link, the ~300 px size), `album_id`, `artist_id`.
  All optional: v2–v5 files and pre-v6 crash checkpoints decode with them null, and null means unknown, never zero. A replayed song (same track, position back more than 5 s) is a new entry; the old title+artist dedupe merged replays into one.
  - **No listened verdict is stored.** Whether a play counts as "listened" is a later, tested filter over `played_ms`, `duration_ms` and `end`. The advisor's starting rule, not yet built: listened if played ≥ 90 s, or ≥ 50% of the track, or it completed or was cut off by Stop after ≥ 30 s; skipped if `end = skipped` and played < max(30 s, 25%); otherwise partial; and Spotify values within ±10 s of a threshold count as partial.
  - **The run screen** shows each song's cover, the run time it began, and its play time as a fact ("Played ~2:10 of 3:40", `~` for Spotify estimates), never a listened or skipped label. Spotify covers load from `artwork_url` at display time; Apple Music hands over an image instead of a link, so it is cached on the phone (Caches/artwork, one file per album, keyed by `album_id`) and never written into the Run. Storing a link rather than the image fits Spotify's developer terms as recalled during review (no permanent copies of content beyond metadata, cover art shown unmodified); check the current wording before anyone but Thomas uses the app.
  - **The song line** now uses `started_t`/`ended_t` for each song's span and `played_ms` for the 90 s floor when present, which also corrects Spotify pickup windows that were up to 10 s late.

### Spotify setup (one time, per build)

1. Go to https://developer.spotify.com/dashboard, sign in with the Spotify account, Create app. Name and description are free text. Redirect URI: `runwith://spotify` (exact). API used: Web API.
2. Copy the app's Client ID into `SpotifyClientID` in `project.yml`, regenerate the project, rebuild.
3. On the gear check, tap Connect next to Spotify and sign in once. Tokens live in the keychain and refresh themselves.

The app stays in the dashboard's development mode, which is fine for personal use: the owning account works immediately, and up to 25 other Spotify accounts can be added under User Management. No client secret is involved (PKCE).
- **First launch vs. returning (diagnostic doc §6).** First launch shows a short welcome that asks for nothing, then a gear check that educates: every source as a row with what it adds and its own Enable button, primed in context. Once a run has been saved the gear check becomes a glance: a status strip (`GPS ✓ · Steps ✓ · Music ✓`), the capture line, Start. Tapping the strip expands the rows again for fixing a denied permission; it never re-explains. Music is one item, not one per service: it is ready as soon as any service is connected ("Logging from Spotify"), the unused service stays out of sight behind "Add another source", and with none connected it reads "Music not logged" as optional rather than as a fault. Most people use one player, so the strip can go all green without both. There is no diagnostic test on day one: the first easy run is the baseline, by design.
- **The diagnostic's first slice: the style call.** `StyleClassifier` (RunCore, deterministic, tested) is the single-run effort-distribution probe from the diagnostic doc §2.1. It trims 5% of distance at each end on runs of 8 min or more, splits the rest into four quarters by distance, measures each quarter as distance over moving time so a stop does not count as a slow quarter, grade-adjusts speeds with the Minetti energy-cost curve when elevation covers 80% of points, and names Front Runner / Pace Chaser / Late Surger / End Closer with the doc's starting thresholds (5% kick, 4% surge, 5% decline). It refuses, with a stated reason, when the run is under 4 min, when all quarters sit within 1.5% of average, when speed came only from the step counter (a belt set the pace), or when no distance accrued. The detail screen shows it under "This time" with the four quarter bars and the footer that one run is weak evidence. Thresholds are unvalidated starting points; tune them on real runs.
- **One post-run observation: the song line.** `RunInsights` (RunCore, deterministic, tested) ties the music log to the speed curve. It prefers a *pickup*: the minute after a song came on was at least 8% and 0.15 m/s faster than the minute before, never the first song, never after a stop, never when the after-minute descended 3 m more than the before-minute, and only for songs that played 90 s or more. Failing that it names the song playing during the best rolling minute. The detail screen shows it as an observation with a footer saying so, and tags it proxy when the speed came from steps. Nothing else interprets the run.
- **Indoor mode** is a user toggle that lets Start enable on the step source alone. The recorder tags those points `proxy`. What indoor speed *means* downstream (style classifier returns unclassified on a fixed belt, effort metrics consume the proxy) is the diagnostic's problem and remains the open call in the brief, not something this build resolves.

## Starting, ending and the finish (shared base for all flow variants)

Reviewed by the Fable advisor before building; see the commit history for the plan.

- **Arm to start.** Start works as soon as Location is allowed. Without a fix it arms: location switches to run mode at the tap so a pocketed phone keeps receiving fixes, and recording begins on the first fix within ±30 m, which becomes point 0. The tap time is stored as `armed_at`; fixes while waiting go to the raw stream only, with negative `t_ms`. The arming screen shows elapsed time and current accuracy, and after 90 s offers "Start on steps now", with GPS joining when it finds you (not Indoor, which would tag an outdoor run as proxy). A haptic and the system record sound mark the start. `ArmingPolicy` in RunCore makes the decision and is unit-tested.
- **Hold to end.** A 1.2 s press-and-hold replaces the confirmation sheet, because the screen stays awake during a run and is live in a pocket. VoiceOver gets an "End run" action with a confirmation.
- **Finish first.** The run screen leads with distance, time and pace, then the style call, the song line and "How did that feel?", then map and music; capture stats, time waited for GPS, exports and delete fold under Details.
- **Self-reports (schema v4).** Feel (1–5) and intent (walk, easy, push) are stored under `annotations` as append-only records with `source: "user"`, `fidelity: "reported"` and `recorded_at`. Stored runs change only through `Run.annotated` / `RunStore.annotate`, which cannot touch measured data. "Push" is a declaration, not a benchmark flag; a declared walk makes the style call decline but keeps the song line.
- **Returning home.** After the first saved run the gear check is one invitation: a descriptive last-run line, a Run | Sprint toggle, a large action button and one live readiness line that opens the full rows. First launch keeps the educating rows. The toggle is the real choice on the card and opens on Run every time, so a phone-only run stays one tap from Start. Under Run sit the feel chips (Walk, Easy, Push), labelled "How should it feel? Optional" and styled as a note rather than a mode, because they change nothing about recording. Under Sprint sit the distance and a "Set up sprint" button. An earlier version showed Sprint as one orange row beside orange chips, which read as if Sprint were the only selectable thing.
- **No blanket refresh timer.** `LocationService` publishes `hasFix` and flips it only when GPS is gained or goes stale, so screens no longer rebuild every two seconds; that rebuild was swallowing button taps.

## Sprint mode (line-to-line efforts)

Built to recreate short races, such as a one-minute Japanese sprint, on a straight or a proper track. Design reviewed by the Fable advisor; the noise tests then tightened it.

- **Setup.** Choosing Sprint on the gear check's toggle and tapping Set up sprint opens setup: a distance (100 to 1200 m), the start line marked by standing on it, and a finish that is either the same line (a lap), a separately marked line, or a manual tap. GPS distance on a track is off by 5 to 10% in published tests, so the finish is a marked line, never accumulated distance. Sprints need GPS: no Indoor, no start-on-steps fallback.
- **The race.** Ready starts recording at the line, then a spoken three, two, one, go. Gun time is the moment of "go". The recorder integrates Doppler speed for an approximate "to go" and a "one hundred to go" cue, finishes on crossing the marked line (interpolated between fixes) or on a Finish tap, and keeps recording a cool-down until hold to end.
- **Stored as an `effort` record (schema v5).** Target (reported), gate (app-measured), finish (estimated, with its method), the marked lines, GPS and Doppler distances, a first-movement estimate, and the events `gate_open`, `to_go_100` and `finish` for future Moments. Raw GPS fixes now carry `speed_accuracy_mps` and `course_deg`. The same record is meant to feed the speed-duration fit and re-benchmarking later.
- **Analysis (`SprintAnalysis`).** Interpolated 100 m splits from integrated Doppler speed, scaled to the marked distance; top speed; fade as the last split against the fastest split; opening as time to 90% of top speed (stored, not classified, ±1 s). Under 200 m it is a top-speed measurement only. It refuses on GPS gaps over 2 s, fewer than 20 fixes, or no valid Doppler speed. The simulator reports no speed accuracy, so simulator sprints show that refusal; a real iPhone does report it.
- **Style (`SprintStyle`).** Judged only against the runner's own sprints at the same distance, once there are three: in 400 m research the fittest runners fade most, so a population norm would label fitness. Front Runner means faded more than usual; End Closer means closed harder than usual; Late Surger needs a second-half split at least 4% faster than the best first-half split; otherwise Pace Chaser. δ is 5% or the runner's own spread, whichever is wider. Measured noise: ±0.3 m/s Doppler moves the fade by about 2 to 3 points, so calls near the threshold are not reliable.
- **The regular style call refuses any run holding a sprint**, so a sprint plus a cool-down jog does not read as a Front Runner.

## Crash recovery

A run in progress is written to `Documents/in-progress-run.json` every 30 seconds and whenever the app goes to the background, then deleted once the finished run is saved. If the app is killed mid-run (a crash, a force-quit, iOS reclaiming memory), the next launch shows "A run didn't finish saving" on the gear check with three choices: continue the same run, save what was recorded, or discard (confirmed). Continuing restarts GPS on a fresh segment, so the time the app was closed is a hole in the trace rather than an invented straight line; the step counter, which counts from the run's own start, still covers it. Starting a new run with a leftover pending saves the leftover as its own run first. All writes go through one serial queue that End Run closes, so a late save cannot bring a finished run back.

## Known limits of this build

- Start requires "When In Use" location plus the `location` background mode. This is enough for pocketed tracking without asking for "Always".
- Switching from GPS to steps can double-count up to one step-counter interval (~2.5 s) of distance. Acceptable for v1; noted here so it is not mistaken for a sensor fault.
- Elevation is stored from GPS when vertical accuracy is ≤ 20 m; no barometer yet.
- The live map still draws a connecting line across a recovered gap; the saved distance does not include it.
- No HR, power or Bluetooth sensors. Those are the progressive-enhancement tiers (brief §6), not v1.
- Spotify is polled every 10 s: a track that plays for less than about 10 s between polls may never be seen. A Spotify change followed by silence (nothing playing, an ad) can only be bounded between two polls; the entry's `end` and method say so.
- The music-log v6 capture (play time, end reasons, Apple Music sampling) is tested in RunCore and on synthetic data in the simulator, which cannot play music. It has not yet been checked on a real run.

## Companion (parked)

The Haru Urara bust is out of the prototype for now while her animation source is settled. Everything needed to bring her back sits in `Companion/`, outside the app target: `HaruUrara.glb`, a skinned glTF with three clips, plus `HaruCompanion.swift` and `HaruUraraView.swift`, which load it with [GLTFKit2](https://github.com/warrenm/GLTFKit2) (MIT) and play it through SceneKit animation players. `idle` (Mixamo "Happy Idle") loops, a head tap plays `hide` once (Mixamo "Ducking", hands over her head), then `cower`, a short shiver derived from the end of `hide`, holds until the next tap, and the camera eases down with her head while she hides.

To restore her: uncomment the GLTFKit2 package and dependency in `project.yml`, add `Companion` as a source path and `Companion/HaruUrara.glb` as a resource, regenerate, and overlay `HaruUraraView()` on the gear check (bottom-leading, about 232×316 pt, offset past the corner, with the Recent runs rows inset to her right).

The sources live in `Tools/mixamo/`: the character FBX Mixamo returned in T-pose (uploaded as `HaruUrara_mixamo.zip`, FBX plus textures), the two clips downloaded "without skin" at 30 fps, and the textures. Rebuild the asset with Blender 4.0:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --python Tools/mixamo_to_glb.py -- Tools/mixamo/HaruUrara_mixamo.fbx Companion/HaruUrara.glb Tools/mixamo "idle=Tools/mixamo/Happy Idle.fbx" hide=Tools/mixamo/Ducking.fbx
```

The script merges each clip's action onto the character armature as an NLA track, derives `cower` from the last six frames of `hide`, relinks textures, drops the facial shape keys (30 MB otherwise), and exports one 1.8 MB `.glb`. To try other clips, download them for the same uploaded character and pass them under the same names.

## Credits

The companion on the gear-check screen is based on "ハルウララ [Haru Urara] | Umamusume" (https://sketchfab.com/3d-models/haru-urara-umamusume-7129d6ead4334a9a81bf654a0e18d2ee) by MMSkecthfab (https://sketchfab.com/MMDSKETCH), licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/). Her clips come from Adobe Mixamo under its standard licence. Per the project's IP posture, this is a personal dev build; the character asset stays on the user's side of the wall and is not redistributed.
