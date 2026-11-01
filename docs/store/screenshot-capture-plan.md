# NumberInbox store screenshot capture plan

Status: planned on 2026-10-10, updated 2026-10-11. The icon and feature-graphic work is
committed as `55822e1fe`. Eighteen screenshots are captured and validated locally under
`docs/store/play/phone/`, `docs/store/apple/iphone-medium/` and `docs/store/apple/ipad-13/`
(six each, identical filenames and order across all three sets). Nothing has been uploaded to
Play Console or App Store Connect yet, and the store submission gates below are still open.

## Goal and source of truth

Produce English-language Google Play and App Store screenshots from the **running release-candidate app** using the dedicated reviewer mailbox supplied in the task. The September brand board in `docs/brand/reference/` sets the palette and typography direction; its phone mockups are references, never screenshot source material. Use the real NumberInbox light UI and real mail in the test mailbox. Record the app commit, version/build, backend environment, device, OS, and capture date in a local capture manifest before publishing.

The task-provided test number and reusable code are in the Git-ignored local companion `docs/store/.screenshot-reviewer-access.local.md`, beside this plan. Do not commit or publish that file, authentication tokens, or mailbox credentials; do not copy the code into image metadata, shell history, or screenshot filenames. Never capture the OTP screen with the code visible. Keep this account available for App Review; do not test account deletion with it.

## Reviewer OTP login: exact capture setup

The app's current Flutter flow is `TwakeWelcomeView` → `TwakeWelcomeController.sendCode()` → `NumberInboxAuthClient.startOtp()` (`POST /v1/otp/start`) → code screen → `verifyCode()` → `NumberInboxAuthClient.verifyOtp()` (`POST /v1/otp/verify`) → JMAP session → dashboard. The app does **not** skip its phone-number screen for the reviewer account. The backend's `OtpService` recognizes only the configured reviewer E.164 number: `start` creates a five-minute reviewer challenge without calling the SMS gateway; `verify` requires that active challenge, compares the configured six-digit code, consumes the challenge once, then issues ordinary mailbox/JMAP credentials. The code alone cannot log in without a fresh `start`. Confirm that this reviewer configuration is active in the deployed backend before capture; local source code does not prove deployment settings. The current backend allows **five OTP starts per number per hour**. Each new `start` replaces that number's previous challenge, so complete login on one device before starting another and track the start count. Stalwart login credentials are capped at **five app passwords** per mailbox; a sixth distinct device may evict the oldest session. Capture the five named devices in order, check each remains signed in, and avoid extra installs/devices until the set is complete.

On **each** fresh Android, iPhone, and iPad install/session:

1. Open the NumberInbox welcome screen. Tap the country picker and select **United States (+1)**. The default country follows device locale and may be Thailand, so do not assume `+1` is preselected.
2. Enter the **10-digit national part only** from the local companion file into **Phone number**. The picker supplies `+1`; entering the full E.164 value in that field could build an invalid value because the current `Country.buildE164()` prepends the selected dial code.
3. Tap **Send code** once and wait for the **Verification code** field. This calls `/v1/otp/start` even for the reviewer number; the backend should suppress SMS for this number. Do not keep tapping: start attempts are rate limited, and a new start replaces the previous challenge.
4. Within five minutes, enter the six-digit reviewer code from the local companion file and tap **Verify** once. Wait for the actual mailbox to load. Check that the visible account is the dedicated reviewer mailbox and seeded mail appears; then dismiss keyboard and loading indicators before any store capture.
5. If verification fails or the five-minute challenge expires, return to the phone step and request a **new** challenge before retrying. Check the country selection, entered national digits, deployment configuration, network response, and rate-limit/error state. Do not try random codes or switch to a private user's number. Record only outcome and HTTP/error category in the QA report; do not log code, access token, or JMAP credential.
6. Preserve the logged-in reviewer mailbox across screenshot sessions. Android phone, iPhone medium, iPad, Android tablet, and optional large iPhone can consume all five starts in one hour. Perform a sign-out/relogin proof on one iPhone **in a later rate-limit window**, after capture, rather than spending a sixth start during setup. Do not delete the account or clear its mail after seeding.

Preflight assertions: `/v1/otp/start` succeeds for this number and makes **zero SMS requests** (confirm from backend/gateway evidence if available); `/v1/otp/verify` loads Inbox after a fresh challenge. The backend unit/integration tests, not repeated production guesses, should prove that consumed/expired challenges fail and ordinary numbers still use real SMS. A clean-device production login must be observed before using the account for store assets. Share the reviewer number and code with Apple only through App Store Connect's App Review Information at submission time; rotate the code and update those notes if it is exposed. Never embed it in a store screenshot or public listing.

## Store rules to check at capture time

- [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/): 1–10 opaque PNG/JPEG screenshots per required device size. Current required sets are a Dynamic Island iPhone medium display and, because `TARGETED_DEVICE_FAMILY = "1,2"`, a 13-inch iPad. Capture native pixels, not stretched exports. App Store Connect can scale some larger sizes, but this plan also captures a large iPhone set for layout review.
- [Apple guideline 2.3.3](https://developer.apple.com/help/app-review/guideline-reference/2-3-3-screenshots): the majority of every submitted set must show the actual app in use. The first three should be real mailbox interactions; no splash/login-only gallery.
- [Google Play asset guidance](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en): at least two screenshots to publish, up to eight per device type; use opaque PNG/JPEG. For strong Play placement, make at least four phone images at 1080 × 1920 portrait (9:16), with the real app visible. If publishing tablet support, prepare at least four large-screen images for the appropriate tablet listing. Text overlays, if any, occupy under 20% of an image and do not hide UI. No store badges, rankings, prices, calls to install, or unverified feature claims.
- Recheck these live store requirements before upload; they may change. Only create sets for device types the release actually supports and has been tested on.

## Device and build matrix

| Set | Available target / setup | Native export target | Planned images |
| --- | --- | --- | --- |
| Google Play phone | Android SDK has a `Pixel_7` AVD, currently not booted. Start it and confirm `adb devices`. Configure a genuine 9:16, 1080 × 1920 logical display before launching the app; if that causes layout problems, create a 9:16 phone AVD rather than cropping or stretching UI. | 1080 × 1920 opaque PNG | Six |
| Google Play tablet | Create or select a supported 7-inch or 10-inch Android tablet AVD. Test a 9:16 portrait profile at 1080 × 1920 or larger, with tablet-appropriate density; retain native UI proportions. | 9:16, at least 1080 × 1920 | Four if tablet distribution remains enabled |
| App Store iPhone medium | Device Hub: iPhone 17, iOS 26.5, already booted. | 1206 × 2622 opaque PNG | Six |
| App Store iPhone large | Device Hub: iPhone 17 Pro Max, iOS 26.5, available but currently shut down. | 1320 × 2868 opaque PNG | Six if layout differs or a tailored large set improves presentation |
| App Store iPad | Device Hub: iPad Pro 13-inch (M5), iOS 26.5, already booted. | 2064 × 2752 opaque PNG | Four to six |

The initial sandboxed terminal checks could not access Flutter's SDK cache or the local simulator/ADB daemons. An unsandboxed read-only check confirmed the iOS devices; `adb devices` reported no running Android emulator. Resolve tool access at capture time rather than silently substituting mockups. Device Hub's Camera control or `xcrun simctl io <UDID> screenshot` can capture iOS pixels; `adb exec-out screencap -p` can capture Android pixels. Verify one sample's dimensions before capturing the full set.

Use the final intended release candidate, with production URLs and current NumberInbox branding, on all devices. If a bug fix changes any shown screen, recapture that screen on every affected device. Keep Android and iOS screenshot order, fixture mail, and copy aligned, while allowing native platform controls to differ.

## Prepare a safe, believable mailbox

1. Confirm the dedicated test account can sign in on a clean Android emulator, iPhone, and iPad using the task-provided test flow. Confirm incoming mail resolves to the canonical NumberInbox address. Do not put the reusable code into scripts or the capture manifest.
2. Send sample mail **only** from sender accounts or aliases the team controls, with valid delivery and ownership. Use real SMTP delivery and verify the messages appear in Stalwart/JMAP and in the app. Do not forge third-party brands or stage messages by altering screenshots. Start with one message, verify delivery, then seed the rest once to avoid unnecessary notifications or SMS cost.
3. Use fictional names and generic content with no real customer data, addresses, payment details, phone numbers, OTPs, or private documents. Prepare approximately 10–12 messages, enough to show a varied inbox and search results without looking repetitive. This is the approved English fixture copy; the sender names are display goals, **not permission to impersonate a sender**. Use corresponding authenticated, team-controlled identities or aliases. If none are available, stop before seeding and obtain controlled sender access from the owner.

   | Sender role (controlled identity) | Subject | Body copy / screenshot use |
   | --- | --- | --- |
   | NumberInbox team | Welcome to your NumberInbox | “Your mailbox is ready. Share your NumberInbox address to receive email, then read and reply here.” Open-mail view; send only from a real team identity. |
   | Alex | Plans for Saturday | “Coffee at 10 works for me. I’ll bring the notes so we can pick up where we left off.” Warm, personal inbox row. |
   | Studio team | Project brief and next steps | “The updated brief is ready for review. I added the open questions at the end so we can discuss them together.” Work-related inbox row. |
   | Priya | A few photos from the weekend | “I picked a few favorites from the weekend. Hope these bring back good memories.” Attach one small team-owned image if attachments work. |
   | Events team | Your workshop details | “The workshop starts at 10:00. The agenda and joining details are below.” Search keyword `workshop`; use fictional location/details only. |
   | Jordan | Notes from our meeting | “Thanks for the thoughtful discussion. We agreed to review the draft, collect feedback, and reconnect next week.” Readable open-mail alternative. |
   | Travel desk | Your weekend itinerary | “Your weekend plan is ready: arrive Friday, explore Saturday, and head home Sunday.” Distinct inbox row, no real booking claim. |
   | Community team | Community update | “Here are a few ideas and stories from the community this week.” Evergreen newsletter-style preview. |
   | Morgan | Quick question about the draft | “Could you take one more look at the opening paragraph? I think we are close.” Leave unread. |
   | Design team | Revised layout is ready | “The latest layout is ready for your review. Let me know what you would change.” Leave unread. |

4. Give each message concise, polished text that remains accurate if read aloud or opened in a screenshot. Do not claim encryption, instant delivery, global SMS coverage, or other capabilities without verified product behavior. Use one small team-owned attachment only after attachment rendering is confirmed.
5. Send one outbound message from the app to a controlled recipient, verify it appears in Sent, and retain it as a compose/send proof. Leave several messages unread and some read. Star or move only if those features work in the release candidate. Avoid showing the public reviewer number in store images; if the address must appear in a screen, use an approved test identity that is safe to publish or choose another screen. Never blur a broken UI element to make the screen look finished.
6. Capture a fixture manifest outside the screenshots with sender role, subject, intended read/unread state, and message ID or safe local reference. Keep any actual addresses or identifiers in a local, non-committed record. Verify the reviewer mailbox remains populated and usable after capture.

## Screenshot storyboard and order

| Order | Phone screen (capture on Android and iPhone) | What it proves / quality check |
| --- | --- | --- |
| 01 | Inbox with a varied mix of sender names, subjects, read/unread states, and timestamps | Core experience immediately visible; no spinner, error banner, duplicate contacts, empty rows, or keyboard |
| 02 | Open the clear, polished welcome or meeting message | Reading controls, legibility, accurate sender and body; no clipped text |
| 03 | Compose a real draft with a controlled recipient, subject, and short body | Writing UI, recipient chips, send control; keyboard dismissed and no draft accidentally sent during capture |
| 04 | Search results for a seeded term such as `workshop` | Real search behavior and non-empty result; clear query and matching row |
| 05 | Mailbox navigation or folders with Inbox/Sent visible | Organization and navigation; show only working destinations |
| 06 | Sent message or attachment view, whichever looks clearer and is verified end-to-end | Distinct functional proof; avoid repeating the same inbox composition |

For iPad, capture at least Inbox, open message, compose, and search. Add navigation and Sent/attachment if the tablet layout is polished. Reframe via normal UI navigation, not by stretching a phone capture. Do not include sign-in, OTP, splash, deletion confirmation, notifications containing personal data, debug banners, or unimplemented dark mode in the submitted sets. A separately saved internal QA capture of sign-in/settings may document those flows, but it is not a store image.

Optional branded presentation: retain the raw, unmodified app screenshots as the source of truth. If a headline is needed for the final listing, create an editable layout using the existing emerald `#10B981`, cyan `#06B6D4`, navy `#0F172A`, and ice `#F5F7EB`; use the committed wordmark/mark assets, ample margins, and short truthful lines. Keep the app UI dominant. Review raw and designed variants side by side and choose one coherent style per store set. Do not insert the brand-board phone mockups or redraw app controls.

## Capture procedure

1. Freeze the candidate commit/build and confirm production backend, test account, and seeded messages work on each device. Copy `docs/store/screenshots/capture-manifest.example.json` to the Git-ignored `docs/store/screenshots/capture-manifest.local.json` and fill exact versions, endpoints, device IDs, sender identities, and results. Never add the reviewer code or JMAP credentials.
2. Set English locale, light appearance, portrait orientation, standard font size, 100% battery, strong Wi-Fi, and clean status bars. Set the clock consistently (for example 9:41) using simulator/emulator status-bar controls. Disable unrelated notifications and keyboard suggestions that expose personal data. Do not change the phone number or OTP flow itself.
3. Capture raw screenshots at native pixels. For Android, use the SDK `adb` binary and `adb exec-out screencap -p > ...`; for Apple, use Device Hub Camera or `xcrun simctl io <UDID> screenshot ...`. Confirm output is a real PNG from the selected device, with no desktop frame, cursor, capture controls, or black bars.
4. Capture each storyboard view in sequence on Android phone, iPhone 17, iPhone Pro Max if used, iPad, and Android tablet if distributed. After every capture, inspect it at full size and at a phone-sized thumbnail. Fix actual layout defects in the app and recapture; do not mask them with graphics.
5. Export final opaque RGB PNGs with stable filenames (`01-inbox.png` through `06-sent-or-attachment.png`) under `docs/store/play/phone/`, `docs/store/play/tablet/`, `docs/store/apple/iphone-medium/`, `docs/store/apple/iphone-large/`, and `docs/store/apple/ipad-13/`. Keep raw originals in sibling `raw/` folders until approved. Do not add sensitive raw captures to Git.
6. Upload a draft set to Play Console and App Store Connect to verify the current wells accept every file. Record any automatic scaling or rejection, fix and re-upload. Do not submit the app for review merely by uploading screenshots.

Example capture commands, after confirming the correct device serial/UDID and saving the prior display settings:

```sh
ANDROID_ADB="$HOME/Library/Android/sdk/platform-tools/adb"
"$ANDROID_ADB" devices -l
"$ANDROID_ADB" shell wm size 1080x1920
"$ANDROID_ADB" shell wm size
"$ANDROID_ADB" exec-out screencap -p > docs/store/play/phone/raw/01-inbox.png
# Restore the emulator after the session: "$ANDROID_ADB" shell wm size reset

xcrun simctl list devices available
xcrun simctl status_bar '<iPhone-UDID>' override --time '9:41' --batteryState charged --batteryLevel 100 --wifiMode active --wifiBars 3
xcrun simctl io '<iPhone-UDID>' screenshot docs/store/apple/iphone-medium/raw/01-inbox.png
# Clear the override after the session: xcrun simctl status_bar '<iPhone-UDID>' clear
```

Do not type the OTP into a command or save it in a script. The terminal may need access to Flutter's SDK cache, ADB, and CoreSimulator services beyond the workspace sandbox; use approved access for those tools if required.

### Automated capture split: device drives, host captures

`integration_test/numberinbox/store_capture/store_capture_test.dart` runs **on the device**, so it cannot read this repository's working copy or launch `xcrun`/`adb`. It only drives the app into the target state. Screenshots are taken afterwards from the **host**:

```sh
# iOS: auto-detects the booted simulator, or pass a udid
./docs/store/screenshots/capture-ios.sh docs/store/apple/ipad-13/raw/01-inbox.png
./docs/store/screenshots/capture-ios.sh docs/store/apple/ipad-13/raw/01-inbox.png '<UDID>'

# Android: uses ANDROID_ADB or the default SDK path
./docs/store/screenshots/capture-android.sh docs/store/play/phone/raw/01-inbox.png
```

Both scripts validate the output dimensions and aspect ratio and exit non-zero on a rejectable file. The device test reads its inputs from environment variables forwarded to the run — `STORE_CAPTURE_PHONE` (10-digit national part only) and `STORE_CAPTURE_OTP` — and never from a credential file on the repository host. Export them only for that command; do not write them into a script, a committed file, or shell history that gets committed.

## Automated and human acceptance checks

- Add a small validator and tests before final export: assert exact dimensions for Apple sets, 9:16 and minimum size for Play sets, RGB/RGBA with no transparent pixels in final files, allowed PNG/JPEG format, Play file-size limit, consistent filename/order/count, and unique checksums. Fail if a required device folder is absent. Test it with intentionally undersized, transparent, duplicate, and wrong-aspect fixtures before trusting the pass.
- Visually review every image for brand colors, capitalization, legibility at thumbnail size, native status bar, keyboard coverage, clipped recipient fields, overflow, hidden controls, stale loading state, real message data, and visible private information. Check left-to-right order and that the first three clearly show Inbox, Read, Compose.
- Check every screenshot against the captured build, including iPad layout and Android tablet layout. Avoid applying a filter that changes actual app colors. Check language and spelling in all sample messages and optional overlay copy.
- Confirm the public reviewer mailbox still has the seeded mail and that login works after capture. Keep sample messages available throughout review. If capture requires switching accounts or a reset, verify no production customer data was exposed.
- Save a review sheet with thumbnails, device/build metadata, source capture, final export, and pass/fail notes. Mark completion only after both store consoles accept the assets and a second visual pass approves them.

## Deliverables and decision gates

Deliver the final screenshot files, editable presentation source if overlays are used, local capture manifest, seed-mail inventory, and a short QA report containing device/OS/app/backend versions plus upload acceptance. The current app and backend must first pass login, receive/read, send, search, and compose on the chosen devices. A broken iPad or tablet view is a product issue to fix or a device-support decision to make before submission, not an excuse to fabricate that platform's screenshots.

Agent handoff order: verify the release build and deployed reviewer OTP settings → sign in on one phone → send and verify one controlled email → seed the remaining fixture once → capture all raw device sets → add optional branded layouts → run the validator and human review → upload draft assets and record acceptance. Stop and report a concrete blocker if the deployed reviewer code differs from the local note, no controlled sending identity exists, real mail fails to arrive, required tablet UI is broken, or either store rejects a required size. Do not silently substitute mockups, private customer mail, or a different login account.
