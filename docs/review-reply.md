# Reply to App Review — paste this into the reply box

Submission b5795aa1-b444-42ab-9ec7-249d9bebb22d · Guideline 2.1, 2026-08-28

Attach the screen recording to this same reply. Also paste the answers into
App Review Information → Notes before resubmitting, so they carry to future
versions (see `app-review-notes.md`).

---

Hello,

Thank you for the review. Answers to all seven items are below, and a screen
recording captured on a physical iPhone 15 Pro running iOS 26.6 is attached to
this message. I have also added this information to the Notes field of the App
Review Information section.

Two things that may save you time up front: StudyLapse has no accounts, no login,
and no paid content or subscriptions, so no demo credentials are needed — every
feature is available immediately on first launch. And the app makes no network
connections at all; it uses no third-party services or SDKs of any kind.

1. SCREEN RECORDING

A screen recording captured on a physical iPhone 15 Pro running iOS 26.6 is
attached to this reply. It begins with launching the app from the Home Screen and
walks through the full user flow: starting a session, granting camera access,
recording, stopping, playing back the resulting time lapse, sharing it, and
changing settings.

2. DEVICES AND OPERATING SYSTEMS TESTED

- iPhone 15 Pro (iPhone16,1), iOS 26.6 (23G71) — physical device. All camera
  capture, session timing, interruption handling, and playback testing was done
  here.
- iPhone 16 Pro Max simulator, iOS 26.6 — layout verification and App Store
  screenshot capture only. The iOS Simulator has no camera, so capture cannot be
  exercised there.

The app is iPhone-only (TARGETED_DEVICE_FAMILY = 1) and requires iOS 18.0 or later.

3. WHAT THE APP DOES, AND WHO IT IS FOR

StudyLapse is a study session timer that turns each session into a short time
lapse video.

The problem it solves: students who study for hours have no honest record of the
time they actually put in, and self-reported timers are easy to fool. StudyLapse
tracks elapsed time on a monotonic clock that keeps counting through screen locks
and interruptions, and simultaneously builds a visual record — it captures one
still frame every few seconds from the camera and writes those frames into a
compact video as the session runs. A two-hour session becomes a roughly
60-second, ~26 MB clip.

The value: at the end of a session the user has both a trustworthy number and
something to look at. It is a motivation and accountability tool.

Target audience: students and anyone doing long focused work at a desk. Rated 4+.
There is no user-generated content shared between users, no social feature, no
messaging, no ads, and no in-app purchases.

Design note that may look like a bug but is intentional: iOS revokes camera
access whenever an app is backgrounded or the screen locks. StudyLapse does not
use a background audio mode or any other workaround to defeat this. Instead, the
timer keeps running (the user is still studying) and the app records the
interruption and tells the user plainly when and why the video has a gap — for
example "Studied 1h 42m · lapse covers 1h 12m". The recording demonstrates this.

4. SETTING UP AND REACHING THE MAIN FEATURES

No setup, no credentials, no sample files are required. From a fresh install:

  1. Launch the app. The session list appears (empty on first launch).
  2. Tap "Start session" at the bottom.
  3. iOS shows the camera permission prompt. Tap "Allow". The camera is used
     solely to capture the still frames that make up the time lapse. If access is
     denied, the app still works as a timer — it offers a "Start timer only" mode
     and a shortcut to Settings.
  4. Type a subject (any text, for example "Chemistry") and tap "Start session".
     The viewfinder appears, then the session screen with a live elapsed clock,
     the frame count, and an estimated file size.
  5. Optionally tap "Dim screen". The app keeps the screen awake but dims it to
     near-black to save battery during a long session. Tap to restore it.
  6. Tap "Stop". The captured segments are joined and the finished session is
     saved to the list.
  7. Tap the session in the list to see the recap and play the time lapse back.
     The share button uses the standard iOS share sheet.
  8. The gear icon in the top-right opens Settings: capture interval (2–5
     seconds, with a live file size estimate), front or back camera, and the
     privacy summary.

5. EXTERNAL SERVICES, TOOLS, AND PLATFORMS

None. StudyLapse makes no network connections of any kind.

There is no backend, no authentication service, no analytics or crash-reporting
SDK, no advertising SDK, no payment processor, no AI or machine learning service,
and no third-party data provider. There are no third-party dependencies in the
project at all.

Everything is Apple first-party framework code: SwiftUI, SwiftData, and
AVFoundation. Study sessions are stored in a local SwiftData database and the
video files are written to the app's Application Support directory, excluded from
iCloud backup. Nothing is ever uploaded off the device. This is why the app's
privacy answer is "no data collected" and why ITSAppUsesNonExemptEncryption is NO.
The app functions fully offline, including in Airplane Mode.

6. REGIONAL DIFFERENCES

None. The app behaves identically in every region and on every carrier. There is
no server, no geofencing, no region-gated content, and no region-specific
feature. It ships localized in English only; durations and dates are formatted
using the system locale.

7. REGULATED INDUSTRY OR PROTECTED THIRD-PARTY MATERIAL

Not applicable. StudyLapse does not operate in a regulated industry — it is not a
health, medical, financial, gambling, or similarly regulated app. It contains no
licensed or third-party protected material. All code, the app icon, and all
artwork are original work by the developer. The only media the app handles is
video the user records themselves, which never leaves their device.

PERMISSIONS REQUESTED

Camera is the only permission the app requests. Purpose string:
"StudyLapse captures a single still frame every few seconds while a study session
is running, and turns those frames into a time lapse of your session. Video is
saved only on this device and is never uploaded."

The app does not request microphone, location, contacts, photo library, or App
Tracking Transparency access, and it captures no audio.

Please let me know if anything above needs expanding, or if there is a specific
flow you would like to see recorded in more detail. Thank you for your time.

Ross Toma
