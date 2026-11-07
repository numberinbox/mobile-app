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
