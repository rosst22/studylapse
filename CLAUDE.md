# CLAUDE.md — StudyLapse

Native iOS app. SwiftUI + SwiftData + AVFoundation. iOS 18.0+, iPhone only.
Ross has never written Swift — explain iOS-specific mechanics when you touch them.

## Commands

```
xcodebuild -project StudyLapse.xcodeproj -scheme StudyLapse \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```
The project uses an Xcode 16+ **synchronized root group**: any file added under
`StudyLapse/` is compiled automatically. Never hand-edit `project.pbxproj` to add
sources.

The simulator has no camera. Capture changes must be tested on a device.

## Architecture

| Layer | File | Job |
|---|---|---|
| Config | `Capture/CaptureConfiguration.swift` | Interval, bitrate, encoder settings, size math |
| Camera | `Capture/CaptureController.swift` | AVCaptureSession, sensor slowdown, decimation, interruption notifications |
| Encode | `Capture/TimeLapseSegmentWriter.swift` | One AVAssetWriter per segment |
| Segments | `Capture/SegmentPipeline.swift` | Owns the open writer + finished segment list |
| Join | `Capture/SegmentStitcher.swift` | Passthrough concat at Stop |
| Orchestrate | `Session/TimeLapseRecorder.swift` | @MainActor @Observable; the only thing views talk to |
| Time | `Session/SessionClock.swift` | ContinuousClock elapsed time |

## Invariants — do not break these

1. **One serial queue** (`CaptureController.captureQueue`) owns the sample-buffer
   delegate *and* the asset writer. No locks anywhere. Anything touching the
   writer must be on that queue.
2. **Never retain a CVPixelBuffer past the delegate call.** It comes from a finite
   camera pool; holding one starves capture. Append synchronously, then let go.
3. **Never append with the capture timestamp.** Frame N is stamped `N/30 s`.
   That rewrite *is* the time lapse.
4. **The clock does not pause on interruption.** Only an explicit user pause stops it.
5. **Store filenames, not URLs**, in SwiftData. Container paths change across app
   updates and restores.
6. Videos go in Application Support, excluded from backup. Never `Caches` — iOS
   purges it and sessions would vanish.

## Hard rules for App Store review

- **No `audio` background mode**, no silent-audio-loop trick to keep the camera
  alive in the background. Instant 2.5.4 rejection, and it doesn't work anyway.
- Never draw over or disguise the green recording indicator.
- Don't put "Strava" in the app name, description, or screenshots.
