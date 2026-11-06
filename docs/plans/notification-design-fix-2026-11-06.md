# Improve NumberInbox notification layout with minimal upstream divergence

Date: 2026-11-06. Status: implemented for review; device acceptance pending.

The owner subsequently authorized the complete plan. Execution uses address-first
titles and foreground/unlock actions; see [ADR 0123](../adr/0123-native-mail-notification-presentation-and-actions.md)
and the [verification report](../reviews/notification-design-implementation-2026-11-06.md).
The original research remains unchanged. Conditional small-icon adoption remains gated
on device legibility; the existing N is retained.

## Inputs and deliverables

- The owner supplied a Samsung notification screenshot showing a truncated app name,
  sender address in the header, subject as the main title, preview underneath, and a
  duplicate NumberInbox logo at the right.
- [Original attached research](references/deep-booping-dragonfly.md) is preserved
  byte-for-byte. Its proposals and third-party Gmail claims are reference material,
  not implementation instructions or a specification for every Gmail version.
- [Interactive mockup source](mockups/notification-design-2026-11-06.html) and
  [browser preview](mockups/notification-design-2026-11-06-preview.html) show the first
  fix, optional initials, future actions, grouping, and existing iOS field order.
  All identities and mail content are synthetic. These are illustrative native-template
  approximations, not screenshots or promises about Samsung's exact rendering.

The current checkout is based on `338855be07f498e48e624121934a9c9585f95ca4`.
Preserve subsequent changes, including unrelated iOS project/version edits and audit
files. Read `AGENTS.md` before implementation. No commit, push, deployment, package
upgrade, or backend change is authorized by this planning document.

## Verified findings and provenance

| Finding | Evidence in current code | Disposition |
|---|---|---|
| Subject is the Android title | `EmailChangeListener._showLocalNotification` passes `presentationEmail.subject` as `title` | Move sender identity to the main title in the NumberInbox layout only. |
| Sender competes with app name/time | `LocalNotificationManager.buildInboxStyleInformation` supplies sender as `summaryText` | Do not set sender summary/subtext for the new single-mail layout. Samsung's exact header allocation remains system-controlled. |
| Preview is a one-line inbox entry | The same helper uses one `InboxStyleInformation.lines` entry | Use `BigTextStyleInformation` for a single expanded message; retain InboxStyle for the group summary. |
| App logo repeats on the right | `LocalNotificationConfig.generateNotificationDetails` always supplies `ic_large_notification` | Omit the large icon first; add a local initials avatar only in a separately validated phase. |
| Small icon lacks @ | Android uses the existing monochrome `notification_icon` asset | Branding refinement, not a missing push capability. Evaluate a legible N/@ mask separately; retain N if the @ is not clear at status-bar size. |
| No action handlers | Details have no actions/categories; the callback accepts only `selectedNotification` | Actions require authenticated operations and lifecycle work, not just three added labels. Separate later phase. |
| iOS already orders sender/subject/preview | `NotificationService.showListNotification` calls title/subtitle/body | Preserve layout in the first Android fix. Real-device behavior is not proved by reading code. |
| Attachment thumbnails absent | No relevant notification thumbnail pipeline | Defer. Not needed for the reported gap. |

The subject-first/InboxStyle design, fixed large-icon slot, and absent action array
also exist in the **locally stored** upstream/master snapshot
`5807b75604d63f09d1b404186777d544f6139756`. This comparison is not a fresh upstream
fetch or proof of the newest release. The NumberInbox icon artwork is fork branding.
The requested design improvement is therefore an intentional NumberInbox presentation
customization, not a claim that all these items are fork-introduced defects.

## Scope and recommended decisions

Implement Phase A first: fix hierarchy and remove the duplicate large logo. It needs
no avatar renderer, new callback infrastructure, backend payload change, or custom
Android RemoteViews. Keep the existing small icon initially.

Recommended first-release sender policy: **address first**, retaining the fork's
existing spoof-resistance. Use the sender address as the notification title and show
an optional different display name in the expanded content. When the address is
unavailable, use the display name; when both are absent, use the existing localized
unknown-sender wording if available, otherwise add a localized fallback. Do not call
an address authenticated merely because it appears in a From header.

The mockup's optional **Name first** control shows the attached review's proposed
alternative: name as title, address on the first expanded line. That weakens identity
visibility while collapsed. It requires an explicit owner decision before replacing
the address-first default; an AI-generated name or a sender photo never establishes
trust. Do not silently change the iOS sender policy in this Android task.

Phase B (avatar / small-icon refinements) and Phase C (actions) are follow-ups with
separate acceptance gates. Mockups containing those features are labelled accordingly.
Do not implement all later phases automatically when asked to execute Phase A.

## Phase A — Android layout and duplicate-icon fix

### A1. Preserve the shared upstream path

Touch only the notification presentation boundary and its one rich-mail call site:

- `lib/features/push_notification/presentation/notification/local_notification_manager.dart`
- `lib/features/push_notification/presentation/notification/local_notification_config.dart`
- `lib/features/push_notification/presentation/listener/email_change_listener.dart`
- Existing notification tests, plus a small NumberInbox-specific presenter/helper if
  extracting pure formatting avoids putting product policy in a shared component.

Keep `buildInboxStyleInformation` and the existing default `showPushNotification`
rendering for non-opted-in callers. Add one explicit opt-in or an optional, typed
presentation argument for the NumberInbox mail layout; do not infer a layout from
runtime colors, title strings, or an email domain. Avoid changing shared model APIs.

Suggested minimal API shape:

1. A pure NumberInbox formatter accepts the existing subject, preview and
   `EmailAddress?` values and returns collapsed title/text plus expanded style.
   A new dependency, event framework, or alternative mail fetcher is unnecessary.
2. `showPushNotification` retains its existing parameters/default behavior and accepts
   an optional NumberInbox presentation override. `_showLocalNotification` opts in
   for NumberInbox Android rich mail; the generic fallback does not enter rich formatting.
3. `generateNotificationDetails` accepts an optional `AndroidBitmap<Object>? largeIcon`
   whose default is the current `const DrawableResourceAndroidBitmap('ic_large_notification')`.
   Explicit `largeIcon: null` suppresses it for the new NumberInbox path while omitted
   arguments preserve existing upstream rendering. Verify the pinned plugin maps null
   to an absent icon. Do not implement a hidden global icon override.

### A2. Content mapping

| Android slot | New single-mail value |
|---|---|
| System app name | NumberInbox, still supplied by Android |
| Small icon / time / expansion affordance | Existing platform-managed values |
| `show` title | Sender address, then name fallback, then localized unknown-sender fallback |
| `show` body | Subject only; no forced multiline content in the collapsed text slot |
| Expanded `contentTitle` | Same sender identity as the collapsed title |
| Expanded big text | Optional alternate sender name, subject, then preview, separated by line breaks |
| `summaryText` / subtext | Unset for single-mail notifications; never sender text |
| Large icon | Explicit null in Phase A |

Normalize optional strings without confusing an absent subject with an absent sender.
Reuse the existing no-subject localization if one is already used in notifications;
otherwise keep the upstream empty-subject policy. Do not add new product wording
without tests. Plain title/body fields stay plain text. If expanded content uses HTML,
escape **each sender-controlled field once before inserting app-owned line breaks or
formatting**, and set only the corresponding BigText HTML flags. Never interpret
sender HTML. Do not retain the old hardcoded gray inline text color; let the system
choose readable light/dark text. Keep the old escaped InboxStyle tests for its default path.

No custom header label, app-name override, recipient account subtext, sender-name
summary, or gradient notification background. Native notification actions/text are
system UI, not Flutter gradient buttons. The app can provide its optional accent via
existing NumberInbox tokens, but OEM/OS/user settings decide the final treatment.

### A3. Preserve behavior

Keep notification IDs, per-account group keys, timestamp, importance, sound/silent
rules, private lock-screen visibility, payload email ID, account rechecks, display-before-
cursor ordering, delivery dedup, bounded fallback, expiry recovery, mailbox filtering,
and logout cleanup. This is a presentation change, not a push-delivery redesign.

- Keep group summaries in InboxStyle with their current count and no sender avatar.
  Do not apply one mail's new title/body to the summary or announce it twice.
- Generic fallback remains fixed `NumberInbox` / `You have new mail`, no sender,
  no preview and no mail actions. It may also explicitly omit the duplicate large icon
  through the same optional API; do not change its ID or tap payload.
- Keep old-backend/system-displayed compatibility. Do not touch the five-field push
  contract, platform gateway, Android channel ID, or notification permissions.
- Do not remove `ic_large_notification` globally: it can remain a shared default or
  be referenced by other paths. Delete assets only after a separate complete caller search.

### A4. TDD sequence

Write and execute behavioral tests first against the unchanged layout. Capture the
intended mismatch (subject title, sender summary, fixed logo, old style), not a setup
or missing-generated-mock failure. Implement the smallest fix and rerun GREEN.

1. Extend `test/features/push_notification/presentation/notification/local_notification_manager_test.dart`:
   default old helper still produces its escaped InboxStyle; opted-in rich output
   uses BigText, sender title, subject collapsed text, and ordered wrapped expanded text.
2. Method-channel assertions: no single-mail sender `summaryText`, explicit null/absent
   large icon, private visibility, original ID/group/payload/sound/priority. Confirm
   the default configuration still supplies its original icon when not overridden.
3. Cases: name + address, address only, name only, neither, equal name/address,
   empty subject/preview, whitespace, non-Latin names, combining marks/emoji, long
   addresses, RTL text, and HTML-like sender/subject/preview. Assert escaping without
   double escaping and without stripping legitimate plain text.
4. Use a synthetic spoofed display name with an unrelated address: address must remain
   the leading collapsed identity; expanded text must not imply sender verification.
5. Extend the existing listener channel-mock test: real rich mail opts into the new
   presentation; two mails each keep their own content; summary stays InboxStyle.
   Verify tap payload, display/cursor order and silent child/audible summary behavior.
6. Generic fallback and old-backend/system-notification tests remain GREEN. No generic
   alert becomes a rich alert by accident. Account mismatch, logout during fetch,
   excluded mail and duplicate deliveries still display no unauthorized rich content.
7. Do not replace useful legacy assertions with broad source-code scans. If a test
   deliberately asserts the old NumberInbox layout, change that expectation first,
   observe RED and retain its other security/behavior assertions.

## Phase B — optional visual refinements

### B1. Local initials avatar

Only after Phase A is accepted. Reuse existing initials/color **logic**, not a new
remote image lookup or an offscreen widget requiring a `BuildContext`. Inspect
`core/presentation/views/image/avatar_builder.dart` and existing sender-name utilities
before creating a small fork-owned raster helper. Do not refactor the shared avatar
system just for notifications.

- Render a small bounded PNG from local text/color using engine-supported canvas APIs;
  use `ByteArrayAndroidBitmap` through the new optional icon slot. Derive stable initials
  from existing Unicode-aware helpers, with address fallback. Never split a surrogate
  pair or combine arbitrary unbounded text into an image.
- Verify canvas/font availability in the actual Android headless background engine.
  Rendering failure, unavailable fonts, or deadline exhaustion means **no large icon**,
  never failed mail delivery or a generic fallback solely because an avatar failed.
- No contact permission, HTTP avatar service, network fetch, disk cache, or backend work.
  Use existing palette/color selection; no deterministic sender color implies trust.
- Avatar only on individual rich messages. Group summaries and generic alerts omit it.
- TDD: Unicode/empty initials, stable colors, bounded dimensions, null on rendering
  failure, headless integration, and preservation of display-before-cursor/sound/tap.
  Measure device latency within the existing overall push budget; do not add another
  initialization stage or raise the deadline to accommodate optional decoration.

### B2. Small notification mark

A separate branding asset patch, not an app-icon replacement. Keep current resource
names and all mdpi–xxxhdpi assets. Use the existing brand source/generator where possible.
Notification icons are monochrome masks: do not feed the full-color launcher icon into
this slot. Compare N and a simplified N/@ at native 24dp and status-bar size on Samsung
and a stock emulator. Adopt N/@ only when the @ is recognizable and the N remains
unclipped; otherwise retain N. Check transparent padding and alpha masks at every density.
Run the existing brand generation/check scripts and add an asset-shape regression.
No launcher, splash, website or iOS icon changes.

## Phase C — notification actions, separate feature implementation

Not part of the minimal layout patch. Recommended set: **Mark as read, Archive, Reply**.
Do not add Delete or send a reply in the background. Do not show nonfunctional buttons
just to resemble a mockup. Android action controls are native solid/system accents,
not gradient Flutter controls. Register localized labels using the existing localization path.

Before implementing, choose explicitly between foreground actions (smaller scope,
opens the authenticated app for all operations) and background Mark as read/Archive
(more infrastructure; Reply still opens the composer). The attached research's
background design is not approved by merely copying its document.

If background actions are selected:

- Add a fork-owned action processor, a top-level `@pragma('vm:entry-point')` callback,
  and the pinned plugin's Android ActionBroadcastReceiver/required initialization.
  Register `onDidReceiveBackgroundNotificationResponse` as well as foreground handling.
  `_handleReceiveNotificationResponse` currently ignores `selectedNotificationAction`;
  route recognized action IDs explicitly while preserving ordinary body taps.
- Action allowlist: `mark_read`, `archive`, `reply`. Use a versioned local action payload
  carrying only opaque email/account identifiers; it is not the FCM payload. Preserve
  inherited `NotificationPayload` decoding for ordinary/legacy taps. Do not put a
  subject, sender, URL, password, token or phone number into action payloads/logs.
- Bootstrap existing account/session/JMAP services and recheck the selected account
  before any effect, including after async fetches. Never trust a caller-selected
  endpoint or switch accounts automatically. Reuse current bindings and timeouts;
  avoid cloning the push receive pipeline or creating another auth implementation.
- Read current email/mailbox state through authenticated JMAP. Use
  `MarkAsEmailReadInteractor.execute(session, accountId, emailId, ReadActions, MarkReadAction, mailboxId)`
  and `MoveToMailboxInteractor.execute(session, accountId, MoveToMailboxRequest, emailIdsWithReadStatus)`.
  Resolve the standard Archive role from current mailbox data, never a display name.
  Missing Archive/mail, revoked credentials and stale account must fail safely.
- Await final success/failure states; stream completion alone is not mutation success.
  Use `cancelNotification: false` for mutation actions and dismiss/update the child and
  correct summary only after confirmed success/read-back. Offline/timeout retains the
  notification for retry. Do not create persistent credential-bearing retry queues.
  Mark/read and archive retries must be idempotent; handle partial mutation failure.
- Reply uses `showsUserInterface: true`, waits for existing startup/auth navigation,
  fetches the original mail, then reuses the existing reply composer arguments/action.
  Never auto-send or compose from untrusted push subject/body/URL parameters.
- iOS requires categories at app initialization, category assignment by the rich NSE
  branch, and explicit `response.actionIdentifier` dispatch in AppDelegate. Preserve
  existing plugin forwarding/body taps and call completion exactly once. Use
  authentication-required actions; do not add mutating actions to generic fallback.
  Confirm whether the pinned plugin supports equivalent lock-screen requirements;
  otherwise choose foreground/unlock behavior rather than adding a new native fork.

Action TDD: foreground/background/cold-start routing; unknown action/version; malformed
payload; signed out; another account; account switch/logout during each await; deleted
mail; absent Archive; offline/timeout; partial failure; duplicate taps; mutation success
before cancellation; summary counts; ordinary body taps; Reply opens once without
sending; and redaction of sentinel credentials/content. Verify both Dart callbacks and
iOS category/response routing. Real-device closed-app tests remain mandatory.

## Deferred scope

Attachment previews, inline reply sending, remote sender photos, notification settings,
backend changes, channel migrations, a custom notification view, upstream sync,
package upgrades, and mail cache/auth behavior are excluded. Revisit only after the
above stages and with a separate approved requirement.

## Verification and review handoff

1. Record mobile HEAD, comparison snapshot, affected paths and explicit NumberInbox
   divergence in the next free ADR (check numbering; do not assume 0123 is free).
2. Run dependency/mock preparation with `./scripts/prebuild.sh` only when necessary.
3. Run the existing notification manager/config/listener/receiver and push suites,
   related branding tests for Phase B, then the full root unit/widget suite.
4. Run Flutter analysis; compare normalized diagnostics to the current baseline rather
   than silently ignoring new infos. Run `git diff --check`. Record RED/GREEN commands,
   actual assertions, source revision, and unavailable checks.
5. On Samsung and a stock Android emulator: collapsed/expanded, 320–360dp width,
   large system font, dark/light, RTL, one/two/many messages, long identities, no sender,
   grouping, generic fallback, cold tap, private lock screen, offline and logout races.
   Remove the temporary volume overlay before taking evidence screenshots.
6. In Phase A, verify iOS remains unchanged with its existing tests/build. For Phase C,
   require real-device action delivery and lock/unlock checks. No claim of real APNs
   behavior from simulator-only results.
7. Exact header spacing, visible action count, avatar crop and truncation belong to
   the OS/OEM/user settings. Accept clear identity/subject, preserved privacy and correct
   operations, not pixel-for-pixel Gmail duplication or a guaranteed untruncated app name.
8. Save evidence and remaining findings in `docs/reviews/`. Leave changes uncommitted
   when implementation is requested for review; commit/push/release only when authorized.
   An implementation MR, if opened/updated, must receive the standalone `/review` note.

## Source checks made while planning

- [Android notification anatomy](https://developer.android.com/develop/ui/compose/notifications#notification-anatomy):
  the OS supplies the app name; the optional large icon is intended for contact photos,
  not a duplicate application icon. This supports omitting it in Phase A.
- [Android expanded templates](https://developer.android.com/develop/ui/compose/notifications/expanded):
  BigText supports expanded continuous text; InboxStyle is useful for multiple short
  summary lines. This supports changing single-mail style without replacing grouping.
- [Android actions](https://developer.android.com/develop/ui/compose/notifications/create-notification#actions):
  up to three explicit actions, distinct from a body tap; direct reply is a separate API.
- [Apple action categories](https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types):
  category registration and action dispatch are platform integration work.
- Installed `flutter_local_notifications` **17.2.2** source verified locally: BigText
  HTML flags, nullable large-icon configuration, action IDs, `showsUserInterface`,
  `cancelNotification`, Darwin categories, and background callback APIs. Do not use
  newer-version examples without checking this pin. No dependency upgrade is needed.

Gmail's current attachment rollout, exact button order and iOS avatar presentation are
not acceptance criteria and are not independently verified by this plan. The user's
screenshot and the current implementation are the evidence for the reported layout gap.

## Planning-artifact checks

The archived research matches the supplied file byte-for-byte (`cmp`). Mockup markup
has unique IDs, five labelled designs, and no escaped-markup serialization artifacts;
the standalone browser preview was generated successfully. A local headless Chrome
screenshot attempt failed with a macOS display-link error, so browser screenshot,
responsive interaction and native-device rendering are **not claimed as verified**.
No application test suite was run for these documentation-only additions.
