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
