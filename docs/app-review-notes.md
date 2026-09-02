# App Review Information — Notes field

**Status: this exact text is saved live in App Store Connect** (StudyLapse → iOS App
1.0 → App Review Information → Notes), verified after reload on 2026-09-02.
It was NOT resubmitted — "Update Review" is deliberately untouched until the demo
video is attached.

The field caps at 4,000 characters; this is 3,706. Keep it under the cap and update
the device/OS line (item 2) each release. If the `v2-accounts` branch ever ships,
items 5 and the privacy/encryption claims stop being true.

The previous notes (790 chars) were not blank — they described the test flow and the
two intentional behaviours, both of which are preserved below. What they lacked was
the demo video and Apple's items 2, 3, 5, 6 and 7.

---

No demo account needed: StudyLapse has no accounts, no login, and no paid content or subscriptions. Every feature is available on first launch.

1. SCREEN RECORDING
Attached to this submission, captured on a physical iPhone 15 Pro running iOS 26.6. It starts with the app launching and covers the full flow: start a session, grant camera access, record, stop, play the time lapse back, share it, and change settings.

2. DEVICES AND OS TESTED
iPhone 15 Pro (iPhone16,1), iOS 26.6 (23G71) - physical device, all capture, timing, interruption and playback testing.
iPhone 16 Pro Max simulator, iOS 26.6 - layout and screenshots only; the simulator has no camera.
iPhone only, iOS 18.0 or later.

3. WHAT IT DOES AND WHO IT IS FOR
StudyLapse is a study timer that turns each session into a short time lapse. Students have no honest record of hours actually worked. StudyLapse tracks elapsed time on a monotonic clock that survives screen locks, and at the same time captures one still frame every few seconds and writes it into a compact video as the session runs. A 2-hour session becomes a ~60-second, ~26 MB clip, so the user ends with both a trustworthy number and something to watch. For students and anyone doing long focused desk work. Rated 4+. No shared user content, no social features, no messaging, no ads, no in-app purchases.

4. HOW TO REACH THE MAIN FEATURES
No setup, credentials, or sample files.
1) Launch. The session list appears, empty on first run.
2) Tap "Start session".
3) Allow camera access at the prompt. The camera supplies only the frames that make up the time lapse. If access is denied the app still works: it offers "Start timer only" plus a shortcut to Settings.
4) Enter any subject and tap "Start session". A live clock, frame count, and size estimate appear.
5) Optional: "Dim screen" keeps the display awake but near-black to save battery. Tap to restore.
6) Tap "Stop" to save the session to the list.
7) Tap the session to see the recap and play the time lapse. Sharing uses the standard iOS share sheet.
8) The gear icon opens Settings: capture interval (2-5 s with a live size estimate), front/back camera, privacy summary.

5. EXTERNAL SERVICES
None. The app makes no network connections of any kind. No backend, authentication, analytics, crash reporting, advertising, payment processor, AI service, or data provider, and no third-party dependencies at all. Only Apple frameworks: SwiftUI, SwiftData, AVFoundation. Sessions are stored in a local database and videos in the app container, excluded from backup. Nothing is uploaded. This is why the privacy answer is "no data collected" and encryption is declared as none. The app works fully offline.

6. REGIONAL DIFFERENCES
None. Identical behaviour in every region; no server, no geofencing, no region-gated content. English only.

7. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
Not applicable. Not a health, medical, financial, or gambling app. No licensed or third-party protected material. All code and artwork are original. The only media handled is video the user records themselves, which never leaves the device.

TWO INTENTIONAL BEHAVIOURS THAT MAY LOOK UNUSUAL
1) iOS revokes camera access when an app is backgrounded or the screen locks. The app uses no workaround for this. The study timer deliberately keeps running, the video pauses, and the app states exactly when and why. The recap lists each interruption.
2) Declining camera access is fully supported. The session runs as a plain timer and the recap explains why there is no video. No functionality is gated behind the permission.

PERMISSIONS
Camera only. No microphone, location, contacts, photo library, or tracking, and no audio is captured.
