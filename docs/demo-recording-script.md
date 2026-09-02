# Demo video shot list

Apple wants: physical device, latest OS, starts with the app launching, walks the
typical flow through the core features, and shows every permission prompt.

Target length **2–3 minutes**. Under 5 minutes.

## Before you hit record

- [ ] **Delete StudyLapse from the phone, then reinstall the release build.**
      This is the important one. Camera permission is granted once and never asked
      again — a fresh install is the only way the prompt appears on camera, and
      Apple explicitly asked to see it.
- [ ] Phone is the iPhone 15 Pro on iOS 26.6.
- [ ] Do Not Disturb on, so no notification banners land in the recording.
- [ ] Prop the phone where the camera sees an actual desk with books or a laptop.
      The reviewer should see the time lapse capture something recognisable.
- [ ] Control Center → Screen Recording. **Long-press it and make sure Microphone
      is OFF.** No narration; Apple doesn't need it.

## The shots

| # | Action | Why it's in there |
|---|---|---|
| 1 | Start on the Home Screen. Tap the StudyLapse icon. | Apple requires the recording to begin with the launch. |
| 2 | Let the session list sit for ~2 s. | Shows the real first screen, not a splash. |
| 3 | Tap **Start session**. | |
| 4 | Camera permission prompt appears. Pause ~2 s so the purpose string is readable, then tap **Allow**. | Item 1's "prompts requesting access to sensitive data". Do not rush this. |
| 5 | Viewfinder appears. Type a subject — "Organic Chemistry". Tap **Start session**. | |
| 6 | Let it run **45–60 seconds**. Show the clock ticking, the frame count climbing, the size estimate updating. | Proves the app actually works on a device. |
| 7 | Tap **Dim screen**, wait ~5 s, tap to bring it back. | A feature a reviewer would otherwise never find. |
| 8 | *Optional but recommended:* swipe to the Home Screen, wait ~4 s, reopen the app. | The interruption banner appears and explains the gap. Shows the honest handling rather than letting a reviewer discover it and file it as a bug. |
| 9 | Tap **Stop**. | |
| 10 | Session recap appears. **Play the time lapse back.** Let it play through. | This is the payoff — the reviewer sees the actual output. |
| 11 | Tap the share button, let the share sheet open, then cancel. | Item 1's user-content flow. |
| 12 | Back to the list — the saved session is now there. | |
| 13 | Tap the gear. In Settings change **Frame every** from 4 s to 2 s and let the size estimate update. Show the front/back camera picker and the privacy note. Tap Done. | |
| 14 | Hold on the session list for ~2 s, then stop the recording. | Clean ending; trailing frames make the export tidy. |

Nothing to skip for accounts, purchases, or subscriptions — the app has none.
Say so in the reply rather than leaving the reviewer to wonder.

## Getting it to App Store Connect

The recording lands in Photos. AirDrop it to the Mac, then attach it in
**App Store Connect → App Review → Reply to App Review**. That reply box takes
attachments; drag the .mov or .mp4 straight in.

If it's over the attachment limit, trim it in Photos first (drop shot 6 to ~20 s)
rather than compressing — a re-encoded blurry video invites a second round.
