# StudyLapse

**A study session tracker for iOS that turns each session into a time lapse.**
Start a session, prop your phone up, work. The app tracks elapsed time and quietly
builds a video of the session — one frame every few seconds, encoded straight to
disk, without recording continuous video.

Native iOS. SwiftUI · SwiftData · AVFoundation. iOS 18+, iPhone.

---

## Why it's interesting

The naive version of this app records video for two hours and speeds it up
afterwards. That produces a multi-gigabyte file, flattens the battery, and stalls
for minutes on export. This one never holds more than a single frame in memory and
writes a finished, playable file continuously.

Three constraints drove every design decision:

| Constraint | Approach |
|---|---|
| **Battery** — a session can run 4+ hours | Sensor pinned to its slowest supported rate (~1 fps) rather than dropping frames from a 30 fps stream. Rate rises to 30 fps only while the viewfinder is actually on screen. |
| **Storage** — must stay small enough to keep | 720p HEVC, one frame per 4 s, ~26 MB for a 2-hour session. Frames stream into `AVAssetWriter` as they arrive; nothing accumulates. |
| **iOS revokes the camera** when the app backgrounds or the screen locks | Session survives it. The clock keeps running, footage is finalised per-stretch, and the user is told exactly why the video has a jump. |

## The size math

Storage tracks the **output** video length, not the session length:
`bytes = bitrate × output_duration ÷ 8`.

For a 2-hour session (7200 s) at 30 fps playback:

| Interval | Frames | Output | Speed-up | Bitrate to hit 30 MB |
|---|---|---|---|---|
| 2 s | 3600 | 120 s | 60× | 2.0 Mbps |
| 3 s | 2400 | 80 s | 90× | 3.0 Mbps |
| **4 s** | **1800** | **60 s** | **120×** | **4.0 Mbps** |
| 5 s | 1440 | 48 s | 150× | 5.0 Mbps |

Shipping default: **4 s / 30 fps / 720p HEVC / 3.5 Mbps → ~26 MB per 2 hours**,
about 15 KB per frame. A time lapse is effectively all jump cuts, so inter-frame
prediction is weak; the encoder is given a keyframe every output second rather
than being left to guess.

## Pipeline

```
AVCaptureSession  (sensor pinned to ~1 fps while dimmed)
  └─ AVCaptureVideoDataOutput ── delegate on captureQueue
       └─ decimate to 1 frame / 4 s          CaptureController
            └─ ingest, synchronously          SegmentPipeline
                 └─ AVAssetWriterInputPixelBufferAdaptor
                      └─ segment-N.mov        720p HEVC

  Stop ─→ SegmentStitcher (passthrough concat) ─→ <uuid>.mov ─→ SwiftData
```

Three decisions worth calling out:

**Timestamp rewriting is the time lapse.** Frames arrive stamped with real capture
time. Appending that produces a 2-hour video containing 1800 frames. Instead frame
_N_ is stamped at _N_/30 s, so the same frames become a 60-second video. No
post-processing pass, no re-encode.

**One serial queue owns both the sample-buffer delegate and the asset writer.**
No locks anywhere, and no way to append to a writer that is being torn down. The
`CVPixelBuffer` handed to the delegate comes from a small fixed camera pool, so it
is appended synchronously and never retained — holding one starves capture.

**Segments, not one long file.** `AVAssetWriter` only produces a playable file
after `finishWriting()`. Every contiguous stretch of capture is its own file,
finalised under a `beginBackgroundTask` assertion when the app backgrounds. At Stop
they are concatenated with `AVAssetExportPresetPassthrough` — a container rewrite,
no re-encode, no quality loss, sub-second. A crash costs one segment, not a session.

## Surviving interruptions

iOS revokes camera access the instant an app backgrounds or the screen locks.
No entitlement changes this, and the workarounds that claim to (declaring a
background audio mode and playing silence) are an App Store rejection.

- **The clock is `ContinuousClock`** — monotonic *and* it keeps counting while the
  device sleeps. `Date()` jumps when the time zone changes; `SuspendingClock` and
  `ProcessInfo.systemUptime` stop while asleep, so a locked phone would under-count.
- **Every interruption is recorded** with a reason and surfaced to the user, live
  and in the recap: *"Studied 1h 42m · lapse covers 1h 12m."*
- **Killed sessions are recoverable.** A heartbeated JSON record ties orphaned
  segments back to a subject and duration; the next launch offers to rebuild them.
  The heartbeat matters — wall clock alone would count hours in a pocket as study time.
- **Prevention beats recovery:** the session keeps the screen awake and dims itself
  to near-black, so the common case never interrupts at all.

## Measured, not assumed

Startup was instrumented rather than guessed at, on an iPhone 15 Pro:

```
[launch]   31.6 ms  App.init
[launch]   94.2 ms  RootView appeared — app usable
[trace]    55.0 ms  capture session configured
[trace]   271.2 ms  startRunning() returned
[trace]   565.1 ms  first frame — preview live
```

## Running it

```bash
cp Local.xcconfig.example Local.xcconfig   # add your Apple Team ID
open StudyLapse.xcodeproj
```

Select a physical device and ⌘R. **The simulator has no camera**, so capture is a
no-op there; the timer, storage, and UI all work.

## Layout

| Path | Role |
|---|---|
| `Capture/CaptureConfiguration.swift` | Interval, bitrate, encoder settings, size math |
| `Capture/CaptureController.swift` | Capture session, sensor rate, decimation, interruptions |
| `Capture/TimeLapseSegmentWriter.swift` | One `AVAssetWriter` per segment |
| `Capture/SegmentPipeline.swift` | Open writer + finished segment list |
| `Capture/SegmentStitcher.swift` | Passthrough concatenation |
| `Session/TimeLapseRecorder.swift` | `@MainActor @Observable` — the only type the views touch |
| `Session/SessionClock.swift` | Elapsed time across sleep and interruption |
| `Session/SessionRecovery.swift` | Rebuilding a session the app died during |

## Status

v1 is local-only: no accounts, no backend, sessions in SwiftData, videos in the app
container excluded from iCloud backup. Friends, feed, and streaks are planned for v2.

## License

MIT — see [LICENSE](LICENSE).
