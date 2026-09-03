# App Review Information — Notes field

**Live in App Store Connect** (StudyLapse -> iOS App 1.0 -> App Review Information ->
Notes), 3,994 characters, saved and verified 2026-09-03.

The field caps at **4,000 characters**, and the counter beneath it shows characters
REMAINING, not used. Update the device/OS line (item 2) each release. If the
`v2-accounts` branch ever ships, item 5 and the privacy/encryption claims stop being
true.

Item 1 describes the demo video precisely, including the two things it does not show
(the first-run permission alert, and the share sheet being opened). Keep it that way —
a claim the video does not support is worse than a gap you name yourself.

---

No demo account needed: StudyLapse has no accounts, login, or paid content. Every feature is available on first launch.

1. SCREEN RECORDING
Attached, captured on a physical iPhone 15 Pro on iOS 26.6 (23G71). It begins with launching the app from the Home Screen and shows, in order: the session list; starting a session while camera access is off, where the app runs as a timer only and offers "Open Settings"; granting Camera in iOS Settings; a live viewfinder; recording with the clock, frame count and size estimate updating; dimming the screen and restoring it; stopping; opening the finished session and playing the time lapse back; and changing the capture interval in Settings with the size estimate recalculating.

So nothing looks missing: camera access is granted in iOS Settings rather than at the first-run alert, because the app was already installed with access previously denied; that path also shows the timer-only fallback. The share button is visible on the session screen but not tapped - it presents the standard iOS share sheet.

2. DEVICES AND OS TESTED
iPhone 15 Pro (iPhone16,1), iOS 26.6 (23G71) - physical device; all capture, timing, interruption, playback testing.
iPhone 16 Pro Max simulator, iOS 26.6 - layout and screenshots only; the simulator has no camera.
iPhone only, iOS 18.0+.

3. WHAT IT DOES AND WHO IT IS FOR
StudyLapse is a study timer that turns each session into a short time lapse. Students have no honest record of hours actually worked. It tracks elapsed time on a monotonic clock that survives screen locks, while capturing one still frame every few seconds straight into a compact video. A 2-hour session becomes a ~60-second, ~26 MB clip, so the user ends with both a trustworthy number and something to watch. For students and anyone doing long desk work. Rated 4+. No shared user content, no social features, ads, or in-app purchases.

4. HOW TO REACH THE MAIN FEATURES
No setup, credentials or sample files.
1) Launch. The session list appears, empty on first run.
2) Tap "Start session" and allow camera access. The camera supplies only the frames that make up the lapse. If denied, the app still works as a timer.
3) Enter any subject and tap "Start session". A live clock, frame count and size estimate appear. "Dim screen" keeps the display awake but near-black; tap to restore.
4) Tap "Stop" to save the session.
5) Tap the session for the recap and to play the lapse. Sharing uses the standard iOS share sheet.
6) The gear icon opens Settings: capture interval (2-5 s, live size estimate), front/back camera, privacy summary.

5. EXTERNAL SERVICES
None. The app makes no network connections of any kind. No backend, authentication, analytics, crash reporting, advertising, payment processor, AI service or data provider, and no third-party dependencies at all. Only Apple frameworks: SwiftUI, SwiftData, AVFoundation. Sessions live in a local database and videos in the app container, excluded from backup. Nothing is uploaded, which is why the privacy answer is "no data collected" and encryption is declared as none. Works fully offline.

6. REGIONAL DIFFERENCES
None. Identical behaviour in every region; no server, no geofencing, no region-gated content. English only.

7. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
Not applicable. Not a health, medical, financial or gambling app. No licensed or third-party protected material; all code and artwork are original. The only media handled is video the user records themselves, which never leaves the device.

INTENTIONAL BEHAVIOUR THAT MAY LOOK UNUSUAL
iOS revokes camera access when an app is backgrounded or the screen locks. The app uses no workaround for this. The timer deliberately keeps running, the video pauses, and the app states exactly when and why; the recap lists each interruption. Declining camera access is likewise fully supported, as the recording shows.

PERMISSIONS
Camera only. No microphone, location, contacts, photo library or tracking; no audio is captured.