Hello,

Thank you for the review. All seven items are answered below, and the same information has been added to the Notes field of the App Review Information section. A screen recording captured on a physical iPhone 15 Pro running iOS 26.6 (23G71) is attached to this reply and to the version's Attachment field.

Two things up front that may save you time: StudyLapse has no accounts, no login and no paid content or subscriptions, so no demo credentials are needed. And the app makes no network connections at all - there are no third-party services or SDKs of any kind.

1. SCREEN RECORDING
Attached. It begins with launching the app from the Home Screen and shows, in order: the session list; starting a session while camera access is off, where the app runs as a timer only and offers "Open Settings"; granting Camera in iOS Settings; a live viewfinder; recording with the clock, frame count and size estimate updating; dimming the screen and restoring it; stopping; opening the finished session and playing the time lapse back; and changing the capture interval in Settings with the size estimate recalculating. Camera access is granted in iOS Settings rather than at the first-run alert because the device already had the app installed with access previously denied; that path also shows the timer-only fallback. The share button is visible on the session screen but is not tapped - it presents the standard iOS share sheet.

2. DEVICES AND OPERATING SYSTEMS TESTED
iPhone 15 Pro (iPhone16,1), iOS 26.6 (23G71) - physical device; all capture, timing, interruption and playback testing.
iPhone 16 Pro Max simulator, iOS 26.6 - layout and screenshots only; the simulator has no camera.
iPhone only, iOS 18.0 or later.

3. FUNCTION AND TARGET AUDIENCE
StudyLapse is a study timer that turns each session into a short time lapse. Students have no honest record of the hours they actually work. The app tracks elapsed time on a monotonic clock that survives screen locks, and at the same time captures one still frame every few seconds straight into a compact video. A two-hour session becomes a roughly 60-second, 26 MB clip, so the user ends with both a trustworthy number and something to watch. It is for students and anyone doing long focused desk work. Rated 4+. There is no shared user content, no social feature, no messaging, no ads and no in-app purchases.

4. SETUP AND ACCESS
No setup, credentials or sample files are required. Launch the app, tap "Start session", allow camera access, enter any subject and tap "Start session" again. Tap "Stop" to save, then tap the session to see the recap and play the lapse. The gear icon opens Settings.

5. EXTERNAL SERVICES
None. No backend, authentication, analytics, crash reporting, advertising, payment processor, AI service or data provider, and no third-party dependencies at all. Only Apple frameworks are used: SwiftUI, SwiftData and AVFoundation. Sessions are stored in a local database and videos in the app container, excluded from backup. Nothing is uploaded, which is why the privacy answer is "no data collected" and encryption is declared as none. The app works fully offline.

6. REGIONAL DIFFERENCES
None. The app behaves identically in every region. There is no server, no geofencing and no region-gated content. It is localised in English only.

7. REGULATED INDUSTRY OR PROTECTED THIRD-PARTY MATERIAL
Not applicable. This is not a health, medical, financial or gambling app, and it contains no licensed or third-party protected material. All code and artwork are original. The only media it handles is video the user records themselves, which never leaves their device.

One further note: this submission uses a new build, 1.0 (2). While preparing the recording we found and fixed a performance bug in which starting a session froze the app for about nine seconds. Build 2 contains that fix.

Thank you for your time.

Ross Toma
