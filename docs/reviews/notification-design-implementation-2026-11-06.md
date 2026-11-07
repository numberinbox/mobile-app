# Notification design implementation verification

Historical report: its custom layout/actions or formatter have been superseded by
[ADR 0124](../adr/0124-upstream-notification-presentation.md). Original verification
evidence below is retained as history.

Date: 2026-11-06. Base: `338855be07f498e48e624121934a9c9585f95ca4`.
Branch: `master` (this repository's default/main branch). Intentionally uncommitted.

## Scope and decisions

Implemented the owner's complete-plan request using the address-first default and
foreground/unlock actions, as allowed by the plan. [ADR 0123](../adr/0123-native-mail-notification-presentation-and-actions.md)
records these choices. No backend, remote push schema, package version, deployment,
store upload, commit or push was performed by this implementation.

Pre-existing changes to `ios/Runner.xcodeproj/project.pbxproj`, `pubspec.yaml`, the
untracked audit folder and the prior planning artifacts were preserved. Generated
localization timestamps were restored while retaining the new unknown-sender label.

## Implementation

- Explicit NumberInbox BigText opt-in, with inherited InboxStyle/default configuration
  preserved. Expanded fields are escaped separately; collapsed sender is address-first.
  No subject/preview/identity is put in the native header summary.
- Optional local initials PNG (96×96), Unicode graphemes, brand teal/white, no context,
  contacts, network or persistent cache. Failure/150ms timeout omits the avatar.
  Account activity is checked again after optional decoration before platform display.
- Generic fallback and group summary omit the duplicate app logo and have no actions.
- Android actions open the app and do not automatically cancel the notification.
  iOS action categories require foreground/unlock and are assigned only to rich
  platform mail. Normal taps and the legacy native path remain available.
- Local payloads carry only version/native account/email identifiers. Unknown actions,
  versions, extra keys and invalid IDs are refused. Account-bound malformed body taps
  cannot fall through into the legacy email opener.
- Small pending native/local buffers cover startup. Native iOS response handling
  completes once and acknowledges consumed events, preserving ordinary notification taps.
- Existing account lookup, repositories, reply composer and read/move interactors are
  reused. Network reads bypass the ordinary mobile email cache for action verification.
  Account checks and a 20-second deadline guard processing; late continuation checks
  prevent starting effects after expiry. No automatic mutation retry or credential queue.
- Read-back is required after read/archive success. Archive resolves the standard
  Archive/Inbox roles, prefers Inbox over labels, and preserves existing label membership.
  Already archived labelled messages are not moved again.
- Success removes the individual notification and silently updates the Android summary.
  iOS remote notifications are matched by account/email identifiers, not local integer IDs.
  Failure leaves Android alerts available and uses existing generic foreground feedback.
- The current small N icon is intentionally retained. The plan makes N/@ adoption
  conditional on real-device legibility. No launcher/splash/website assets were changed,
  and no unverified replacement mask was shipped.

## TDD and checks

- Existing notification-manager baseline: **16 passed**, `/tmp/ni-design-baseline.log`.
- New expected real-listener layout against unchanged production: **RED**, title was
  subject instead of sender (`/tmp/ni-design-layout-red.log`). Existing callback,
  ordering and privacy assertions were retained when updating presentation assertions.
- New formatter/payload/processor APIs: compile-time missing-API RED recorded in
  `/tmp/ni-design-contract-red.log`; not claimed as behavioral proof by itself.
- Archive membership edge cases: **RED**, label-first source and already-archived
  labelled mail failed (`/tmp/ni-design-archive-membership-red.log`); corrected using
  role-aware source selection and no-op handling.
- New coverage includes malformed/content-free payloads, native foreground/unlock
  categories, original shared icon defaults, no sender header summary, Unicode avatar
  output, bounded bitmap size, partial mutation failure, absent Archive, fresh read-back,
  post-fetch account loss, stale targets, retry after failure, duplicate taps, deadline
  continuation, plugin response routing, silent summaries and buffered iOS startup.
- Final focused presentation/actions/native-manager suite: **39 passed**,
  `/tmp/ni-design-final-actions-verified.log`.
- Existing wider push suite plus iOS manager initially passed **237** tests; focused
  final tests were rerun after the Archive refinement.
- `./scripts/prebuild.sh`: passed when refreshing mocks/localization. No dependency
  upgrade was retained. Only new Dart files were formatted; inherited shared files
  were not reformatted wholesale.
- Final full root suite: **4,814 passed, one existing skip, zero failures**,
  `/tmp/ni-design-release-review-full.log` (`flutter test --no-pub --concurrency=4`).
- Final analysis: **75 existing informational diagnostics**, zero errors/warnings;
  normalized diagnostics exactly match the recorded baseline (none added/removed).
  Log: `/tmp/ni-design-release-review-analysis.log`.
- Final executor tests after the redundant null assertion cleanup: **9 passed**,
  `/tmp/ni-design-executor-accepted.log`.
- Native iOS build and selected notification XCTest suites: **18 passed, TEST SUCCEEDED**,
  `/tmp/ni-design-xcode.log`. Command:
  `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO -derivedDataPath /tmp/ni-notification-design-xcode -only-testing:TwakeMailTests/NumberInboxPushPayloadTests -only-testing:TwakeMailTests/JmapEmailChangesResultTests`.
  This compiles AppDelegate/NSE changes and exercises the native payload/action contract;
  it is not proof of APNs delivery or actual lock-screen interaction.
- `git diff --check` and Xcode project syntax: checked before handoff.

## Device/release gates not represented as passes

Not run: real Samsung and stock Android collapsed/expanded notification inspection;
headless FCM-engine avatar rendering; real-device cold/warm action delivery and unlock;
physical iOS action categories/taps; network-loss interaction and OS-driven alert
retention; multi-message grouping/sound; large text/RTL screenshots; small N versus N/@
legibility; and exact-revision CI. iOS OS-driven dismissal can differ from Android.

No attachment preview, remote photo, inline-send or background mutation feature is
implied. All actions intentionally bring the authenticated application to the foreground.
The pending device gates and conditional icon choice must remain visible in release
review; local unit/native contract tests do not waive them.
