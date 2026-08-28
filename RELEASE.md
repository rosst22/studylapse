# Shipping StudyLapse 1.0

Build state: **archived, signed with Apple Distribution, ready to upload.**

```bash
xcodebuild -project StudyLapse.xcodeproj -scheme StudyLapse -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/StudyLapse.xcarchive \
  -allowProvisioningUpdates archive

xcodebuild -exportArchive -archivePath build/StudyLapse.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates
```

## Order of operations

The app record must exist in App Store Connect **before** a build can be uploaded,
otherwise the upload is rejected for having no matching app.

1. **Create the app** — appstoreconnect.apple.com → Apps → +
   - Platform: iOS · Bundle ID: `app.studylapse.StudyLapse` · SKU: `studylapse-001`
   - Primary language: English (Canada)
   - **If the name "StudyLapse" is taken you find out here.** Fallbacks worth
     holding in reserve: *StudyLapse: Focus Timer*, *Lapse Study*, *DeskLapse*.
2. **Upload the build** — Xcode → Window → Organizer → select the archive →
   Distribute App → App Store Connect. (Or give me an App Store Connect API key
   and I can upload from here with `xcrun altool`.)
3. **Fill in the listing** — copy below.
4. **Answer the questionnaires** — age rating and privacy, both below.
5. **Submit for review.**

## Listing copy

**Subtitle** (30 char max)
```
Time lapse your study sessions
```

**Promotional text** (170 max)
```
Start a session, prop your phone up, and get to work. StudyLapse tracks your time
and turns the session into a time lapse you can actually watch back.
```

**Description**
```
StudyLapse turns a study session into a time lapse.

Tap start, prop your phone up, and work. StudyLapse tracks how long you actually
studied and quietly builds a video of the session — so at the end you have both a
number and something to look at.

BUILT FOR LONG SESSIONS
Most apps that do this record continuous video, flatten your battery, and leave you
with a file too big to keep. StudyLapse captures a single frame every few seconds
and writes it straight to a compact video as it goes. A two-hour session becomes a
sixty-second clip of about 26 MB.

THE TIMER DOESN'T LIE
Lock your phone, take a call, or switch apps and the clock keeps running — because
you're still studying. iOS won't let any app use the camera in the background, so
when that happens StudyLapse tells you exactly when the video paused and why,
instead of pretending it didn't.

NOTHING LEAVES YOUR PHONE
No account. No sign-up. No server. Your sessions and videos are stored on your
device and are never uploaded. There are no ads, no analytics, and no tracking.

- Elapsed time that stays accurate through screen locks and interruptions
- 720p time lapses, roughly 26 MB for two hours
- Adjustable capture interval with a live size estimate
- Session history with duration, subject, and date
- Share any time lapse with the standard iOS share sheet
- Works fully offline
```

**Keywords** (100 char max, comma separated, no spaces)
```
study,timer,focus,timelapse,pomodoro,productivity,student,deep work,session,tracker
```

**URLs**
- Support: `https://rosst22.github.io/studylapse/support.html`
- Privacy: `https://rosst22.github.io/studylapse/privacy.html`
- Marketing: leave blank

## Age rating

All questions **None** / **No**. Result: 4+.
There is no user-generated content, no web access, no ads, and no data collection.

## App privacy

Select **"No, we do not collect data from this app."**

This is accurate for v1: no account, no network calls, no analytics SDK. The bundled
`PrivacyInfo.xcprivacy` declares the same, plus the system boot time API used by
`ContinuousClock` (reason `35F9.1`, measuring elapsed time between in-app events).

## Export compliance

`ITSAppUsesNonExemptEncryption` is `NO` in the Info.plist, so no form appears.
Correct for v1 — the app makes no network connections at all.

**This changes the moment accounts ship.** The `v2-accounts` branch talks HTTPS to
Supabase; that is exempt encryption, but the answer becomes "yes, and it's exempt"
rather than "no".

## Screenshots

Required: 6.9" display (1320 × 2868). Apple scales these down for smaller devices,
so one set is enough.

An iPhone 15 Pro produces 1179 × 2556, which is the wrong size for the required
slot. Capture on an iPhone 16 Pro Max — physical or simulator.

## Known reasons this could come back

Ranked by likelihood:

1. **Guideline 2.1 — screenshots don't match the app.** Show the real thing.
2. **Name collision.** Discovered at app-record creation, not at review.
3. **Guideline 5.1.1** — unlikely for v1, since there is no account at all. This
   becomes the main risk the moment the `v2-accounts` branch ships, and is exactly
   why v1 doesn't include it.

## After 1.0

- `v2-accounts` branch: optional Supabase account, backup, account deletion
- Consider CloudKit instead for plain backup — free with membership, no login UI,
  no account-deletion requirement, and the privacy policy stays "collects nothing"
- Video upload and the social feed both need a real backend
