# 0120 — Logo-coloured primary actions with white foregrounds

Date: 2026-11-02. Status: selected by the owner after the button preview.

Use the bright emerald → cyan → blue gradient shown beside the detailed logo,
with white labels, icons and loading indicators on the branded primary actions.
The preview's representative sampled colours are `#05D792`, `#03CDFC`, and
`#018AFC`, in that order with evenly spaced stops. These reproduce the selected
colour family; a linear button gradient does not reproduce every shaded layer
of the raster logo.

`NumberInboxPalette.primaryActionGradient` and `primaryActionForeground` are
the shared controls. Welcome/OTP, deletion Continue, mobile Compose and light
sidebar Compose reuse them. Preserve geometry, loading/disabled behaviour,
destructive red confirmations, ordinary text/link colours and existing dark
Compose styling. Do not recolour the entire inherited theme.

The prior dark action gradient and proposed navy foreground are superseded for
these branded primary controls. The owner selected white after comparing the
white and navy variants. White on the bright stops has lower contrast than the
previous dark gradient and does not satisfy the 4.5:1 normal-text threshold.
Do not describe this choice as passing that accessibility contrast criterion;
the contrast tradeoff was explained before the owner chose this appearance.

Tests verify the exact selected colour stops, white foreground, shared consumers,
and unchanged layout and interaction. The previous navy-label contrast test
belonged to the unselected navy design and is replaced by the owner's chosen
white-foreground requirement, not presented as an accessibility pass.

The website uses separate CSS tokens and is not deployed or recoloured by this
mobile change. Its eventual alignment must use these stops and white foreground
together rather than copying only the background.

Verification: the exact-stop/foreground tests demonstrated RED against the
unselected navy treatment, then all 57 focused palette, OTP, Compose and deletion
tests passed after this change. Focused analysis reported no issues. Fresh
Android debug and iOS simulator builds succeeded and were reinstalled and
launched on Pixel 7 and iPhone 17 Pro Max, preserving existing app data.

Consistency audit: all branded-action consumers were traced: both OTP phases,
deletion Continue, thread/inbox Compose, both sending-queue Compose placements,
and web/sidebar Compose. Labels, glyphs and loading indicators use the shared
white foreground; the existing tests cover expanded/collapsed and loading
states. A redundant theme branch selecting white in both cases was removed,
and the mobile Compose glyph gained an explicit foreground assertion. All 57
focused checks passed again. Grey inactive controls, red destructive confirmation,
ordinary links and the preserved dark Compose fill are intentional exceptions.
