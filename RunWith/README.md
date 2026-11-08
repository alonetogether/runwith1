# Run With — Native Capture Spine

The recorder from `RunWith_NativeCaptureSpine_BuildBrief.md`: start a run, track it, capture speed/distance/music, save it locally as a versioned Run object, export it. Nothing else. iOS-first, Swift/SwiftUI, phone-only sensors (GPS + step counter).

## Layout

```
RunWith/
  project.yml            XcodeGen definition → RunWith.xcodeproj
  RunCore/               Platform-agnostic Swift package (no UIKit/CoreLocation)
    Sources/RunCore/
      Run.swift          The Run object, schema_version 3, snake_case JSON, pace helpers
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
- **Music:** two connectors, deduplicated against the previous entry, each entry tagged with its `source`. Since schema v3 an entry also carries what the player said about the track, as explicit nulls when it said nothing: `album`, `isrc`, `track_id`, `genre`, `duration_ms`, `bpm`. Apple Music gives album, genre, store id, duration and a BPM only if the library tag is filled. Spotify gives album, ISRC, track id, duration, and the artist's first genre from one cached artist lookup; its audio-features endpoint is closed to apps created after November 2024, so BPM for Spotify tracks is a later enrichment (Deezer by ISRC). Purpose: relate songs, artists, genres and tempos to performance over time, per song and per window, which needs identity stored from day one. Schema v2 files still load. *Apple Music* reads the system player directly, no network. *Spotify* polls the Web API's currently-playing endpoint (every 10 s during a run) for whatever the account is playing on any device; it needs a one-time Spotify sign-in on the gear check. Other players (YouTube Music, SoundCloud) expose no playback and stay invisible on iOS (brief §5).

### Spotify setup (one time, per build)

1. Go to https://developer.spotify.com/dashboard, sign in with the Spotify account, Create app. Name and description are free text. Redirect URI: `runwith://spotify` (exact). API used: Web API.
2. Copy the app's Client ID into `SpotifyClientID` in `project.yml`, regenerate the project, rebuild.
3. On the gear check, tap Connect next to Spotify and sign in once. Tokens live in the keychain and refresh themselves.

The app stays in the dashboard's development mode, which is fine for personal use: the owning account works immediately, and up to 25 other Spotify accounts can be added under User Management. No client secret is involved (PKCE).
- **First launch vs. returning (diagnostic doc §6).** First launch shows a short welcome that asks for nothing, then a gear check that educates: every source as a row with what it adds and its own Enable button, primed in context. Once a run has been saved the gear check becomes a glance: a status strip (`GPS ✓ · Steps ✓ · Music ✓`), the capture line, Start. Tapping the strip expands the rows again for fixing a denied permission; it never re-explains. There is no diagnostic test on day one: the first easy run is the baseline, by design.
- **The diagnostic's first slice: the style call.** `StyleClassifier` (RunCore, deterministic, tested) is the single-run effort-distribution probe from the diagnostic doc §2.1. It trims 5% of distance at each end on runs of 8 min or more, splits the rest into four quarters by distance, measures each quarter as distance over moving time so a stop does not count as a slow quarter, grade-adjusts speeds with the Minetti energy-cost curve when elevation covers 80% of points, and names Front Runner / Pace Chaser / Late Surger / End Closer with the doc's starting thresholds (5% kick, 4% surge, 5% decline). It refuses, with a stated reason, when the run is under 4 min, when all quarters sit within 1.5% of average, when speed came only from the step counter (a belt set the pace), or when no distance accrued. The detail screen shows it under "This time" with the four quarter bars and the footer that one run is weak evidence. Thresholds are unvalidated starting points; tune them on real runs.
- **One post-run observation: the song line.** `RunInsights` (RunCore, deterministic, tested) ties the music log to the speed curve. It prefers a *pickup*: the minute after a song came on was at least 8% and 0.15 m/s faster than the minute before, never the first song, never after a stop, never when the after-minute descended 3 m more than the before-minute, and only for songs that played 90 s or more. Failing that it names the song playing during the best rolling minute. The detail screen shows it as an observation with a footer saying so, and tags it proxy when the speed came from steps. Nothing else interprets the run.
- **Indoor mode** is a user toggle that lets Start enable on the step source alone. The recorder tags those points `proxy`. What indoor speed *means* downstream (style classifier returns unclassified on a fixed belt, effort metrics consume the proxy) is the diagnostic's problem and remains the open call in the brief, not something this build resolves.

## Crash recovery

A run in progress is written to `Documents/in-progress-run.json` every 30 seconds and whenever the app goes to the background, then deleted once the finished run is saved. If the app is killed mid-run (a crash, a force-quit, iOS reclaiming memory), the next launch shows "A run didn't finish saving" on the gear check with three choices: continue the same run, save what was recorded, or discard (confirmed). Continuing restarts GPS on a fresh segment, so the time the app was closed is a hole in the trace rather than an invented straight line; the step counter, which counts from the run's own start, still covers it. Starting a new run with a leftover pending saves the leftover as its own run first. All writes go through one serial queue that End Run closes, so a late save cannot bring a finished run back.

## Known limits of this build

- Start requires "When In Use" location plus the `location` background mode. This is enough for pocketed tracking without asking for "Always".
- Switching from GPS to steps can double-count up to one step-counter interval (~2.5 s) of distance. Acceptable for v1; noted here so it is not mistaken for a sensor fault.
- Elevation is stored from GPS when vertical accuracy is ≤ 20 m; no barometer yet.
- The live map still draws a connecting line across a recovered gap; the saved distance does not include it.
- No HR, power or Bluetooth sensors. Those are the progressive-enhancement tiers (brief §6), not v1.

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
