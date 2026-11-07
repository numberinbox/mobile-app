# 0121 — Accessible primary action gradient

Date: 2026-11-03. Status: selected by the owner after a side-by-side preview.
Supersedes [ADR 0120](0120-logo-coloured-primary-actions.md).

White labels on the bright logo gradient (`#05D792`, `#03CDFC`, `#018AFC`) had
1.9:1 contrast on the green and cyan stops and 3.5:1 on the blue stop. The logo
reads well because its white @ is large and sits on a darker disc; a 16px button
label does not.

Branded primary actions now paint `#0D7C66` → `#0B7A94` → `#0A6FB5`, in that
order with evenly spaced stops, with the white foreground kept. The stops stay in
the logo's green, teal and blue family and give white text 5.1:1, 5.0:1 and
5.3:1, so the 4.5:1 normal-text threshold is met on every stop.

`NumberInboxPalette.primaryActionGradient` (stops `primaryActionStart`,
`primaryActionMiddle`, `primaryActionEnd`) and `primaryActionForeground` remain
the shared controls. They also cover contact picker Done and native composer
Send on phones, tablets, and the responsive web composer. The bright
`logoGreen`, `logoCyan` and `logoBlue` values stay as brand reference samples;
labelled controls must not use them.

Alternatives previewed: navy labels on the bright gradient (8.2:1 on green and
cyan, 4.4:1 on blue) and the previous `#047857` → `#0369A1` gradient (5.5:1 to
5.9:1). A test now asserts at least 4.5:1 white contrast on every stop, so a
future colour change cannot silently drop below it.


## Shared solid accent

The owner selected `#0B7A94` for small icons, links, cursors, focus borders,
selection indicators, progress tracks, and other existing green accents.
`NumberInboxPalette.interactiveAccent` is the shared value. Legacy aliases
retain their names and resolve to that accent for upstream compatibility.

Primary fills also cover account actions (including logout and identities),
rules, vacation, forwarding, recovery, search, folder/label modals, legacy login,
and positive edit/color dialogs. They use the existing gradient and white
foreground. Callers supplying destructive, neutral, or unavailable styles retain
those explicit styles. Dialogs with no supplied positive fill use the gradient.
The small gray profile-popover icon override remains effective.

See [the migration checklist](../brand/interactive-accent-verification.md)
for source coverage, tests, and validation limits.

## Success toast gradient

On 2026-11-07 the owner selected the Brand gradient toast mockup. Success toasts,
including draft saves and success feedback with Undo/Discard actions, use
`primaryActionGradient` with existing white foregrounds. Optional
`backgroundGradient` forwarding in the existing toast helpers and decoration is
the only shared rendering extension. Other callers retain their solid rendering;
error, warning and neutral toast colors remain unchanged. The old solid success
constant remains for compatibility, but no active success-toast caller uses it.
Toast geometry, placement, timers, callbacks and dismissal are unchanged.

## About product-story screen

On 2026-11-07 the owner approved the Product story mockup with the clearer
Simple and useful wording, then removed the repeated login tagline. About keeps
its existing Settings entry and app-bar title; the content uses the existing
78-unit full-color mark, “Your number. / Your inbox.” headline, an SMS sign-in
introduction, and three unboxed rows for everyday email, no ads/data selling,
and account choices. The footer reads “Email that starts with you.”

The sole action, “Explore numberinbox.com”, opens the existing fixed homepage
through AppUtils.launchLink. It uses primaryActionGradient and white foreground
with a 14-unit radius and a 54-unit minimum (not fixed) height. Text can wrap and
the page scrolls at large text sizes. This is a local NumberInbox presentation
change; no shared button API, navigation, website, dependency or backend change.

### Implementation verification

Baseline: `f0cecc0980f1463da1e2fcba6cce54f5fd9f38f1`. Preserve unrelated iOS
project, version, FCM registration and Claude outputs work. Leave uncommitted.

RED: `flutter test --no-pub test/branding/about_attribution_test.dart` against
unchanged production code failed six tests. Intended assertions found the
obsolete standalone NumberInbox heading and no FilledButton/shared gradient.
Log: `/tmp/ni-about-red.log`.

Initial GREEN development run passed 13 tests; one URL test attempted to tap
the now-below-viewport button. The harness was corrected to scroll it into view
before tapping; the exact URL assertion remains unchanged. The final test
matrix includes content, appearance, button semantics, excluded decorative
icons, keyboard activation, back navigation, 320/900 widths, 100%/200% text,
and LTR/RTL.

GREEN/regression: `flutter test --no-pub test/branding
 test/features/manage_account/presentation/menu/settings/settings_first_level_view_contract_test.dart`
passed 145 tests. The existing opt-in splash frame test was skipped because its
device-recording environment variables were unset. Log:
`/tmp/ni-about-regression.log`. All 14 About cases passed in this run.

Android API 37 isolated preview: visually inspected the real About layout,
content and shared-gradient action; screenshot `/tmp/ni-about-android.png`. The
footer is reached by scrolling. No authentication/backend calls are involved in
this preview. Enlarged-text and RTL behavior is exercised by widget tests, not
claimed as a physical-device screen-reader check.

iPhone 17 Pro, iOS 26.5: visually inspected the real About screen in an isolated
preview using the existing app theme. All feature rows, the button and footer
fit; the accessibility tree exposes the content and named website button.
The preview intentionally starts at About rather than through Settings; route
return is covered separately by the widget navigation test. No backend call.

`flutter analyze --no-pub` completed with 75 informational diagnostics, zero
warnings/errors; the diagnostic set exactly matches the preceding baseline
(`/tmp/ni-otp-final-analysis.log`). Log: `/tmp/ni-about-analysis.log`.
`git diff --check` passes.

Manual simulator large-text/RTL scrolling and physical-device screen-reader
acceptance were not performed; these layout paths are covered by the explicit
widget matrix. No full root test suite or private integration CI is claimed.
Normal Android and iOS application builds replace the temporary previews without
clearing app data; temporary preview entrypoints are outside the repository.
