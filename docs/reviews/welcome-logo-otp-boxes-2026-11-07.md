# Welcome logo and six-box OTP verification

Baseline: `4e1c182786f35804081b88b45d60cc4ce64f20c6`.
Implementation was left uncommitted for review; the owner subsequently requested commit and push. Existing iOS project settings, app version and Claude
outputs were preserved. No backend requests, real SMS, production deployment or
store submission are required by this verification.

## RED and characterization

Before production edits:

```sh
flutter test --no-pub test/features/starting_page
```

Result: 80 passed, 3 intended failures. Both welcome phases measured 79.625 units
of visible logo width against the expected ~100; the six-box test found no
`otp_digit_box_0`. The existing controller/loading/lifecycle tests passed unchanged.
Log: `/tmp/ni-otp-boxes-red.log`.

## Implementation

The welcome view now renders the splash image on its same 256-unit canvas inside
the existing 104-unit header slot. The shared header updates both phases. Native
assets and Flutter loading layout remain unchanged.

One new NumberInbox-specific widget renders six decorative boxes over the real
TextField. It retains otp_code_field and the existing controller, native editing
and autofill, and supplies the existing verification callback for Done. It owns
only its focus node. Errors, retry and Verify loading retain controller behavior.

## GREEN

Initial starting-page run: 83 passed (`/tmp/ni-otp-boxes-green.log`).

Final affected suites:

```sh
flutter test --no-pub test/features/starting_page test/features/home/presentation/home_view_test.dart test/branding/splash_config_test.dart test/branding/primary_action_palette_test.dart
```

120 passed (`/tmp/ni-otp-verified-focused.log`). Native splash and HomeView tests
were unchanged. Coverage includes OTP verification/loading/authentication,
delete/relogin lifecycle, numeric input, paste, selection, autofill-style updates,
keyboard Done, absence of automatic submission, error rebuild, controller
replacement/unmount, semantics and 200% RTL layouts. Full welcome-view cases cover
320/900 widths, keyboard insets and long error text.

The test-only semantics cleanup and synthetic clipboard response were corrected
before the final run; the native paste API was still exercised. A deprecated
semantics-tree accessor was subsequently replaced with renderViews owner access;
the component suite then passed all 8 tests again
(`/tmp/ni-otp-component-verified.log`).

No controller, API/client, dependency, native splash asset, or integration-helper
assertion was changed. Existing integration helpers still enter the complete code
through the real TextField carrying otp_code_field. Actual private integration CI
and physical SMS delivery are not claimed by these widget runs.

## Analysis and simulator verification

`flutter analyze --no-pub` reports 75 informational diagnostics, zero errors and
zero warnings. The diagnostic set exactly matches the preceding baseline report
(`/tmp/ni-toast-final-analysis.log`); no diagnostics were added or removed.
`git diff --check` passes.

iPhone 17 Pro simulator, iOS 26.5: built and displayed the real welcome view
through a temporary isolated preview entrypoint outside the repository. The
preview overrides OTP operations locally; no real SMS or backend authentication
request was made. Visually checked phone and code phases, matching logo size,
six slots, leading-zero input `001234`, active outline, backspace to `00123`,
and synthetic error borders/message. Accessibility exposed one code text field
and the Verify button. Screenshot: `/tmp/ni-otp-ios.png` (synthetic error state).

Actual physical-device SMS autofill, VoiceOver/TalkBack, and device keyboard Done
remain unverified. Native paste, selection, Done, autofill-style editing values,
large text, RTL, narrow/wide and keyboard-inset behavior are covered by the widget
tests; that coverage is not a claim of physical-device acceptance. Existing
Verify loading is covered by the unchanged controller/loading suite, rather than
the isolated visual preview.

Android arm64 emulator (API 37): built and rendered the same isolated real view
with a synthetic prefilled `001234`. Six boxes, leading zeros, label, instruction,
logo and Verify fit without clipping at the current phone viewport. Screenshot:
`/tmp/ni-otp-android.png`. Android typing/paste/keyboard behavior was not manually
exercised in this visual run; see the component tests above.

Normal application builds also succeeded for Android debug APK and iOS simulator
(`flutter build apk --debug --no-pub -t lib/main.dart` and
`flutter build ios --simulator --debug --no-pub -t lib/main.dart`). Android
installation returned Success. No app data was cleared.

A concurrent integration-test-only commit advanced HEAD to `be35745f3` during
verification; it was preserved. Only the welcome UI, its tests, ADR and this report
are included in this implementation commit. Existing iOS project/version edits
and Claude outputs remain outside it.
