# Success toast gradient verification

Verification HEAD: `a4404e094e5ff0d99f96b70d58bf0a67a733fb6e`. Changes are uncommitted.
Existing iOS project settings, app version and Claude outputs remain untouched.

## Implementation and coverage

Success feedback uses NumberInboxPalette.primaryActionGradient with white content.
Added optional backgroundGradient forwarding through AppToast's two general helpers,
TMailToast and ToastView. The existing decoration paints the gradient and leaves its
color null; callers omitting it keep their original solid rendering. No new renderer,
dependency, timer, layout, callback or dismissal policy was introduced.

| Success entrypoint | Migrated calls |
| --- | ---: |
| AppToast shared success helper | 1 |
| ToastManager success with action | 1 |
| Mailbox controller | 2 |
| Mailbox search controller | 2 |
| Mailbox visibility controller | 1 |
| Draft-save extension | 1 |
| Mailbox dashboard | 5 |

All 12 direct callers outside the helper now supply the shared gradient. The old
success color constant remains unused for upstream compatibility. The unrelated
green calendar/event text color was preserved. Existing Undo artwork is already
white, so no redundant tinting or shared-asset edits were retained.

## TDD

RED: existing AppToast.showToastSuccessMessage rendered no gradient; the new widget
test expected the shared LinearGradient and received null. Log: /tmp/ni-toast-red.log.
An earlier setup compilation error was corrected before this behavioral RED run.

GREEN: core toast and palette tests passed, including the new rendering assertion.
Final core command:

```sh
flutter test --no-pub core/test/presentation/utils/app_toast_test.dart core/test/presentation/resources/numberinbox_palette_test.dart
```

9 tests passed (/tmp/ni-toast-final-core.log). Coverage includes white label/icon,
existing padding/radius/max width/placement, solid/default/error/warning compatibility,
gradient precedence, keyboard Undo and pointer Discard callbacks once, timed and
explicit dismissal, replacement, long text, 200% text scale, and RTL at 320/900 widths.
Keyboard focus is requested explicitly before activation, avoiding reliance on the
host test runner's initial traversal state.

The two existing real dashboard draft-success tests now require the shared gradient
while retaining their messages, icons and callback arguments. Dashboard plus primary
palette/interactive accent suites: 61 passed (/tmp/ni-toast-feature-tests.log).
Surrounding base-mailbox, mailbox/search and settings presentation suites: 215 passed
(/tmp/ni-toast-surrounding.log).

./scripts/prebuild.sh completed successfully and regenerated affected ignored mocks.
Only generated localization timestamps changed in tracked files; those timestamp-only
changes were removed. No tracked generated mock was edited by hand.

## Checks and limits

Final Flutter analysis: 75 informational diagnostics, identical normalized set to the
recorded baseline, no errors/warnings or added diagnostics. Log:
/tmp/ni-toast-final-analysis.log. git diff --check passed.

The old success background token has no remaining runtime callers. Core rendering
remains upstream-compatible when the optional argument is omitted. ADR 0121 records
the explicitly selected branding divergence.

Temporary emulator preview uses real AppToast methods and synthetic messages only,
without backend access. Physical Samsung/iOS and a real browser are not claimed as
validated. No deployment, store upload, commit or push was performed.

## Visual inspection

Actual Android rendering inspected on the existing emulator at its original
1080x1920 / 420dpi phone settings and a temporary 1200x900 / 160dpi wide viewport:

- [Phone success](success-toast-gradient/phone-success.png)
- [Phone action](success-toast-gradient/phone-action.png)
- [Wide success](success-toast-gradient/wide-success.png)
- [Wide action](success-toast-gradient/wide-action.png)

The gradient, white icon/label and Undo placement were visible without clipping.
Long text, 200% text and RTL have widget coverage at 320/900 logical widths;
physical-device and real-browser visual checks remain unavailable. Emulator size
and density were reset to their original values after capturing. No preview code
was added to the repository; the entrypoint remained in /tmp.

The normal Android debug APK built successfully and was reinstalled with `adb
install -r` after the preview, preserving app data. Original display settings were
confirmed as 1080x1920 and 420dpi with no overrides. Preview-only durations were
extended for screenshots; the product's default three-second timing is unchanged
and covered by the widget test. The full root suite was not rerun; the affected
core, dashboard/branding and surrounding presentation suites above were run.
