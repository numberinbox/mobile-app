# Rich platform notifications — implementation verification

Date: 2026-11-05. Base revision: `6bd1743ae3f64c5566088bea0db9ff4a09990112`.
Branch: `codex/rich-push-notifications`. Changes intentionally uncommitted for owner review.
The pre-existing `pubspec.yaml` version change and untracked audit directory were preserved.

## Scope and rollout boundary

Mobile phases 1–7 are implemented. Backend phase 8 is deliberately **not implemented**:
the approved plan gates it on distribution of the compatible mobile build and owner
confirmation that no relevant older Android installation remains. The current backend
continues sending notification+data; this mobile implementation silently refreshes the
Android cursor in that case, preserving rollout and rollback compatibility.

No production API call, SMS, release upload, deployment, commit, push or CI dispatch
was made. CI on a committed revision and the physical-device matrix remain release
gates. A local simulator test is not proof of background APNs/FCM delivery.

## Implemented behavior

- Android receives an explicit display policy derived from `RemoteMessage.notification`.
  Data-only events use the inherited rich notification; system-displayed events do not
  create another local display. The policy resets between serialized requests.
- Display/filter failures propagate and do not advance the delivery cursor. Successful
  display precedes the real JMAP cursor write. Empty and excluded results still advance
  the real cursor without an alert. Deduplication records only completed work.
- `PlatformPushOutcome` separates completion, intentional drops and retriable failures.
  A parsed data-only Android event gets a generic fallback after failure or a 20-second
  overall deadline, including initialization failure. Fallback failure is swallowed.
  Initialization that completes after expiry cannot dispatch new work. Already-running
  JMAP work is not force-cancelled; a later rich result replaces the same email ID.
- Fallback uses fixed text, the rich notification ID convention, an email tap payload,
  private lock-screen visibility and a non-silent notification. The small icon is explicit
  so early initialization failure does not require a previously initialized default icon.
- Foreground synthetic-state sync advances a real delivery cursor without displaying.
  Android uses the existing cursor store; iOS reads/writes the shared keychain cursor.
  Foreground cursor failure is best effort after UI synchronization. Synthetic states
  are neither persisted nor sent to JMAP as a since-state.
- Synthetic foreground UI work does not overwrite the shared fields of a background
  request waiting on the serialized cursor pipeline. Existing account/delivery dedup,
  HTML escaping, notification tap behavior and legacy websocket paths remain.
- Account activity is rechecked after a platform mail fetch, before rich display or
  cursor persistence, closing the logout/account-switch-during-fetch race. A generic
  fallback can still appear, containing no fetched content.
- Logout cancels delivered notifications with swallowed errors and a two-second cleanup
  deadline. Native-channel mocks were added to the real deletion/relogin tests; their
  navigation and credential-cleanup assertions were retained.
- iOS background cursor ownership remains with the native extension. The Dart background
  handler does not silently consume its changes. Foreground Dart cursor sync is separate.
- The extension validates the version-1 contract, retains original generic content on
  session/fetch failure or expiry, attaches the email tap ID, respects mailbox exclusions,
  and rechecks the keychain session before rich display. New diagnostics name cases only.
- The pure Swift result decoder reads paging/cursor fields from exact `Email/changes,c0`
  and mail from exact `Email/get,c1`. The callback exposes the final real cursor, or nil
  after failure. The legacy extension callback retains its existing behavior.
- ADR 0122 records the owner's rich-notification policy; M5 has a dated supersession note.

## RED evidence

Local logs are outside the repository and contain synthetic fixtures only.

| Reproduction | Observed failure |
|---|---|
| Original listener, new rich-display expectation (`/tmp/ni-rich-phase1-red.log`) | Expected mail plus summary; actual `show` list empty. |
| Original foreground method (`/tmp/ni-rich-order-foreground-red.log`) | No Android cursor write; no iOS keychain cursor pipeline; next background fetch lacked the foreground real cursor. |
| Isolated original write-first handler, adapted only to the new display flag (`/tmp/ni-rich-order-red.log`) | Expected `show, show, store`; actual `store, show, show`. Display error incorrectly reported completion after moving the cursor. |
| In-flight logout before display guard (`/tmp/ni-rich-logout-race-red.log`) | Notification channel received the synthetic private subject after credentials were removed. |
| Foreground/background overlap before field guard (`/tmp/ni-rich-ownership-red.log`) | Alice's pending fetch used Bob's context; expected Alice call absent. |
| iOS background ownership before dispatch guard (same log) | Background Dart attempted the shared-cursor path and returned failure instead of leaving it to the extension. |
| New pure Swift APIs against original models (`/tmp/ni-rich-swift-red.log`) | Missing versioned payload type and `emailChangesResult` members. This is compile-time missing-API RED, not behavioral proof. |

The isolated original listener baseline passed 13 tests before implementation. The
initial broader run picked up the deliberately inverted rich-display test before it
compiled, so it is not recorded as a green baseline. Existing unaffected cases serve
as characterization coverage; no claim is made that every unchanged assertion was RED.

## Verification commands and results

- `./scripts/prebuild.sh`: passed; repeated when existing Mockito signatures changed.
  Generated localization timestamps were restored; no dependency changes were retained.
- `flutter test --no-pub test/features/push_notification test/main/utils/ios_sharing_manager_test.dart test/features/base/base_controller_test.dart test/features/numberinbox/account_deletion_relogin_lifecycle_test.dart`:
  **235 passed**, `/tmp/ni-rich-final-focused.log`.
- Full root suite, `flutter test --no-pub --concurrency=4`: **4,754 passed**,
  one existing opt-in splash-capture test skipped, zero failures.
  Log: `/tmp/ni-rich-full-verified.log`.
- Full `flutter analyze --no-pub`: **75 pre-existing informational diagnostics**, zero
  errors/warnings. Normalized messages exactly match the recorded prior baseline
  (zero added/removed). Exit status remains 1 for those infos.
  Log: `/tmp/ni-rich-analysis-complete.log`.
- `plutil -lint ios/Runner.xcodeproj/project.pbxproj`: passed.
- `git diff --check`: passed.
- Native simulator build succeeded. Initial parallel test invocation stalled during
  simulator startup and was stopped. Retried without parallel execution on iPhone 17 Pro.
- Full native XCTest invocation executed **22 tests**, with **two existing date-test
  failures** on the Thai/Buddhist-calendar simulator: `testConvertValidDateToISO8601String`
  and `testConvertValidISO8601StringToDate` assumed Gregorian dates (observed year 1481
  versus expected 2024). Their source is unchanged. No unrelated date behavior was edited.
  Log: `/tmp/ni-rich-xcode-retry.log`.
- Focused native XCTest, rebuilt from the final Swift sources:
  `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,id=F1172291-8A62-4A9B-9AC7-3AD6F337F1C2' -parallel-testing-enabled NO -derivedDataPath /tmp/ni-rich-xcode -only-testing:TwakeMailTests/NumberInboxPushPayloadTests -only-testing:TwakeMailTests/JmapEmailChangesResultTests`:
  **9 passed, TEST SUCCEEDED**, `/tmp/ni-rich-xcode-focused.log`.
- The same nine pure Swift tests also passed in an isolated temporary Swift package.

## Remaining release verification

All physical-device rows in the approved matrix are **not run**, not passed: Android
and iOS closed/background delivery, foreground suppression, subsequent-mail cursor
behavior, grouping, cold taps, fallback under network failure, lock-screen privacy,
excluded mailboxes, logout, post-logout arrivals, Android force-stop, iOS extension
expiry/empty-result behavior, and Samsung battery saver.

The extension's empty-content discard behavior specifically needs real iOS validation;
if it produces a blank banner, use the plan's generic fallback alternative. No physical
iPhone/APNs delivery claim is made from the simulator results.

Before backend phase 8: distribute this mobile revision, confirm old Android installs
are retired, then implement/test the private gateway and contract changes. Backend
full Java 25 verification and exact-revision CI belong to that gated phase. Neither
rich push enablement nor store release is complete solely from these mobile changes.

## Review fixes, 2026-11-06

Changes remain uncommitted. Backend phase 8 is still not implemented.

- Outcomes: only sign-out evidence (`NotFoundAuthenticatedAccountException`,
  `NotFoundAuthenticationInfoCache`, `NotFoundStoredTokenException`, `BadCredentials`,
  `InvalidBaseUrl`) or an account mismatch is `dropped`. Storage errors and a re-check that
  throws are `failed`. A sign-out during the mail fetch is now `dropped`, with no fallback.
- Expired cursor: on `cannotCalculateChanges` the Dart pipeline reads the current state
  through `Email/query` plus `Email/get`, and the extension through `Email/get` with empty
  `ids`. The cursor moves there; that push stays generic and later pushes can be rich.
- Extension: one `JmapClient` per notification service, so concurrent pushes cannot mix
  fetch state. Intentional discards no longer send a Sentry message.
- `fcm_receiver.dart` logs background and fallback failures with exception and stack again.

Test evidence: 8 controller outcome tests were seen failing before the fix, on the expected
wrong outcome. Listener, interactor, repository and logging tests were written before the
code but not run separately first. The two display-flag tests were added as coverage for
existing behaviour. Swift tests were written alongside the code, so no separate RED run
exists for them. The change-history expiry has not been exercised against a real Stalwart.

- `flutter test --no-pub --concurrency=4`: 4,791 passed, one existing skip, zero failures.
- `flutter analyze --no-pub`: 75 informational diagnostics, no errors or warnings.
- `xcodebuild test`, `NumberInboxPushPayloadTests` and `JmapEmailChangesResultTests`:
  17 passed. The build includes the extension. The full XCTest target was not re-run.
- Device matrix: still not run. Add a row: stale cursor gives one generic alert, then rich.

