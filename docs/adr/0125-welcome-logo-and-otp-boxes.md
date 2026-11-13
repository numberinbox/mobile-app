# ADR 0125: Splash-sized welcome mark and six-box OTP presentation

Date: 2026-11-07. Status: implemented for review; physical SMS autofill pending.

The owner approved matching the phone-entry/OTP logo to the splash and replacing
the large OTP field with six outlined visual boxes. These are NumberInbox-only
branding and OTP presentation changes; upstream shared components are unchanged.

The shared welcome header retains its 104-unit layout slot, existing padding,
wordmark and positioning strategy. It centers the same 256-unit padded splash
canvas used by HomeView in an OverflowBox, yielding ~100 units of visible artwork
rather than ~80. Native splash assets and HomeView are unchanged. Natural layout
reflow between phases/keyboard states remains governed by the existing spacers
and scrollable view; no new global anchor or fixed vertical offset is introduced.

VerificationCodeField uses one existing code controller and one native TextField
with the retained otp_code_field key. Six pointer-ignored, semantics-excluded
slots display the digits; the native field retains editing, selection, paste,
numeric keyboard, Done submission and oneTimeCode autofill hints. The widget owns
only its focus node and listener wiring, never the parent's editing controller.
ASCII digits and the six-character limit are enforced at the UI boundary. No
automatic verification occurs at digit six. Existing explicit Verify, loading,
error clearing and controller/session lifecycle remain unchanged.

The code order is LTR within RTL views. Slots use navy tabular digits, the shared
teal focus accent, neutral idle borders and the existing theme error color. Their
height grows for large text. The English-only instruction follows the existing
welcome-screen language policy. No dependency, authentication API, resend flow,
controller refactor or automatic focus is introduced.

Platform editing-value tests verify the autofill input path, not SMS delivery.
Physical-device autofill and screen-reader acceptance remain device checks.

## OTP destination and phone correction

The verification phase displays the formatted international destination from the
successful OTP start. Verification uses that same E.164 value. The draft and
country picker are preserved when Change phone number returns to phone entry.
The action dismisses the code field, clears the local code and error, and leaves
the next SMS request to Send code. It is disabled throughout sign-in. Backend
expiry and rate limits still govern earlier codes.

### Verification

Baseline revision: `46fc264e4`.

- RED: `flutter test --no-pub test/features/starting_page/twake_welcome_view_test.dart test/features/starting_page/twake_welcome_controller_test.dart --name 'shows the SMS destination|ignores duplicate starts|does not verify a six-digit' --reporter expanded`.
  Three expected failures showed a missing destination, two OTP start requests
  for repeated Send, and one Verify request from phone entry.
- GREEN: `flutter test --no-pub test/features/starting_page test/features/numberinbox/phone_number_parser_test.dart test/branding/primary_action_palette_test.dart --reporter expanded`.
  All 123 tests passed, including correction, loading, keyboard activation, and
  large-text/RTL coverage.
- `flutter analyze --no-pub` reported 75 informational diagnostics and no
  warnings or errors. `git diff --check` passed.
- The owner reported the flow works. Separate Android and iOS simulator
  walkthroughs were not completed by Codex for this revision.
