# Upstream notification restoration verification

Baseline: `f5b14d752302899be8a7e748e58a2eee88b62179`.
Upstream comparison: `5807b75604d63f09d1b404186777d544f6139756`.
Changes are uncommitted. Existing iOS project settings, version changes and Claude
outputs were preserved. No backend, dependency, store or production changes.

## Implementation

Android rich mail uses the inherited InboxStyleInformation, subject title,
preview body, sender summary and branded fixed large icon. Removed custom
presentation, preview formatter, avatar renderer, action executor/coordinator,
category registration, action-only native removal and unused localized strings.
Archive/Reply/Mark as read inside the app were not changed.

Retained a small validated account/email target and existing startup buffering.
Ordinary taps recheck the authenticated account and captured session; obsolete
action responses are ignored. iOS recognizes account metadata without an action
category and refuses non-default action responses before the legacy fallback.
Malformed JSON returns to mailbox instead of remaining on a loading screen.
Remote push contract, authenticated NSE fetching, privacy, cursor ordering,
deduplication, logout cleanup, generic fallback and summary behavior remain.

Android N/@ mask derives from the existing vector N geometry and @ glyph. The
existing five density resources and references are preserved. Export source,
script and instructions are under assets/brand/source and tool/branding.

## RED/GREEN evidence

Initial RED, before production edits:

```sh
flutter test --no-pub test/features/push_notification/presentation/notification/local_notification_manager_test.dart test/features/push_notification/presentation/listener/email_change_listener_test.dart test/main/utils/ios_notification_actions_test.dart
```

48 passed, 4 intended failures: existing iOS category, emitted action responses,
sender-address title instead of subject, accepted iOS Reply response.
Local log: `/tmp/ni-upstream-restore-red.log`.

First focused GREEN: 54 passed (`/tmp/ni-upstream-restore-green.log`).
The real dashboard test harness then exercised matching/wrong accounts, obsolete
actions, and account changes during credential lookup; 51 tests passed.

Additional malformed-JSON RED used the real dashboard harness with the catch
removed: expected mailbox route, actual waiting route. Log:
`/tmp/ni-upstream-restore-json-red.log`. The correction catches FormatException;
recognized invalid account-bound targets also route safely to mailbox.

Final focused GREEN:

```sh
flutter test --no-pub test/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller_test.dart test/features/push_notification/presentation/notification test/features/push_notification/presentation/listener/email_change_listener_test.dart test/main/utils
```

168 passed. Log: `/tmp/ni-upstream-restore-final-focused.log`.
Includes buffered signed-out taps and logout cleanup, local target validation,
old action refusal, HTML escaping, plugin presentation and existing surrounding
regressions. Legacy notification handling remains in place; no new handler framework.

Icon characterization and post-export tests both passed:

```sh
python3 -m unittest discover -s tool/branding/tests
```

One parameterized test covers all five PNG sizes, white visible pixels, alpha,
centering, nonempty content and transparent bounds. This is asset characterization,
not a manufactured behavioral RED or proof of @ recognition on a physical device.

The initial full suite overlapped the deliberate malformed-JSON RED source and
therefore recorded that single intended failure. It is superseded by the final
full run, not treated as a pass.

## External checks and preparation

Selected iOS simulator tests/build passed: 18 tests, zero failures. A subsequent
incremental run covers the final native default-action guard.

Filtered build_runner refresh was blocked by an existing cross-package build
cache error (`InvalidOutputException` for a core-package mock). The obsolete
localization getter was removed from the affected ignored mock locally so analysis
uses the current interface. This generated-file correction is not a tracked change;
a clean dependency/generated-source preparation regenerates the correct mock.

Android emulator checks use a temporary Dart entrypoint in `/tmp`, invoking the
real LocalNotificationManager with synthetic text and no backend/account. This
checks rendering only, not real FCM delivery or authenticated navigation.
Physical Samsung legibility, physical iOS/APNs, and real push lifecycle checks
remain separate release acceptance checks.

## Final recorded results

- Full root suite: **4,804 passed, one existing skip**, zero failures.
  Command: `flutter test --no-pub`.
  Log: `/tmp/ni-upstream-restore-final-full.log`.
- Final focused suites: **168 passed**.
- Final iOS simulator build/tests: **18 passed**, TEST SUCCEEDED.
  Log: `/tmp/ni-upstream-restore-final-xcode.log`.
- Asset checks: all five density masks passed.
- `git diff --check`: passed.

Stock Pixel 7 emulator (Android API 37): actual native expanded/collapsed presentation, absence of
buttons, fixed full-color icon and small N/@ status-bar mask inspected. Android's
newer shade shows the launcher icon at left; this does not mean the monochrome
status-bar resource is unused. Dark-mode rendering was also inspected. Screenshots:
[expanded](notification-restore/android-expanded.png),
[collapsed](notification-restore/android-collapsed.png),
[status bar](notification-restore/android-statusbar.png),
[dark](notification-restore/android-dark.png).

The temporary preview does not execute authenticated tap routing; that behavior
has automated dashboard coverage but still needs production-equivalent device
lifecycle checks. Samsung, real APNs/FCM, large-text and complete grouping lifecycle
visual acceptance remain pending. No physical-device acceptance is claimed.

Final analysis: **75 informational diagnostics**, no errors or warnings. The
normalized diagnostic set is identical to the previously recorded baseline.
Log: `/tmp/ni-upstream-restore-final-analysis.log`.
The final incremental iOS test/build also succeeded with 18 passing tests.

Normal Android app build (`flutter build apk --debug --no-pub -t lib/main.dart`)
passed. The normal APK was reinstalled successfully on the emulator with `adb
install -r`, replacing the temporary preview without clearing app data. No test
preview entrypoint was added to the repository.
