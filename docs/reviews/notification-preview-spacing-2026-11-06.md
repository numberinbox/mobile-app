# Notification preview spacing verification

Base revision: `f992b66f000965ea47bc69b00a18c204b690c808`.
Changes remain uncommitted. Existing iOS project, version, and Claude outputs changes were preserved.

## Cause and correction

The NumberInbox-only formatter applied the display-name sanitizer to the whole
preview. That sanitizer removes newlines and tabs, joining adjacent words.
Normalize CRLF/CR/Unicode line separators to LF and tabs to spaces, then sanitize
individual lines. Escape each line once and insert app-owned HTML breaks.
Collapsed subjectless previews flatten whitespace to spaces. Shared sanitization,
iOS, upstream layout, fetching, actions and account handling are unchanged.

## TDD evidence

RED command (before production edits):

```sh
flutter test --no-pub test/features/push_notification/presentation/notification/numberinbox_notification_design_test.dart test/features/push_notification/presentation/listener/email_change_listener_test.dart
```

Result: 41 passed, 9 failed for intended spacing assertions. Example:
expected `Test<br>Hi,<br>Tested from iPhone<br>Manish`, actual
`Test<br>Hi,Tested from iPhoneManish`. The listener's serialized Android
notification also failed with the joined preview. Local log: `/tmp/ni-preview-red.log`.

GREEN command:

```sh
flutter test --no-pub test/features/push_notification/presentation/notification test/features/push_notification/presentation/listener/email_change_listener_test.dart
```

Result: all 82 tests passed. Local log: `/tmp/ni-preview-green.log`.
Coverage includes LF/CRLF/CR/Unicode separators, tabs, blank lines, collapsed
fallback, unchanged subject, HTML escaping, unsafe controls, absent/Unicode/flat
previews, Android channel output, and surrounding notification behavior.

`git diff --check` passed. Focused `flutter analyze --no-pub` on the three
changed Dart files reported no issues. Full analysis before the fix reported
149 diagnostic entries (including duplicates); logs are local under `/tmp/ni-preview-analysis-*.log`.

## External verification

`adb devices` returned no connected devices. Samsung/emulator visual verification
and controlled-mail authenticated JMAP preview inspection were not performed.
The screenshot does not establish whether its server preview contained separators.
Already-concatenated server previews remain unchanged; this fix does not reconstruct
signatures or fetch message bodies. A server-generated concatenation must be
investigated separately using controlled mail without retaining content or credentials.

Full analysis after the fix: 75 informational diagnostics, no errors or warnings.
The before-run contained duplicate entries; the distinct diagnostic sets match
exactly (75 each), with no new diagnostics.
