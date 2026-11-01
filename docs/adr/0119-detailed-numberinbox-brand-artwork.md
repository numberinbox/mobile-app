# 0119 — Detailed NumberInbox raster mark

Date: 2026-11-01. Status: accepted by the owner in the branding review.

The owner selected the original AI-generated Play feature graphic and requested
its richer N/@ appearance across the app's branded surfaces. This is an
explicit NumberInbox branding divergence; inherited app behavior is unchanged.

Use one transparent `assets/brand/source/mark-detailed.png` master. Derive all
full-color app marks, launchers, and splashes from those pixels. Preserve the
outlined wordmark typography, brand color tokens, white splash backgrounds,
existing layout constraints, startup behavior, and native handoff geometry.

Existing SVG consumers retain their asset paths and viewBoxes. Their full-color
marks embed raster pixels to retain fine shading; describe them as hybrid SVGs,
not pure vector reconstructions. Do not regenerate the logo independently for
each screen or promise a pixel-identical vector recreation of an AI image.

Use `python3 tool/branding/generate_brand_assets.py` to rebuild all exports.
This requires Pillow and no new app dependency. Keep Android adaptive artwork
inside its existing safe circle and retain opaque iOS icon backgrounds.
Monochrome notification icons and ordinary interface icons are unchanged.

The asset audit extends the same master to the large notification, web install
banner, and own-app dashboard entries. PWA maskable images retain extra safe
padding. Web splash sizing and default iOS web status-bar metadata follow the
existing white Flutter loading stage; these are branding corrections, not a
navigation, authentication, or startup-timing change.

Website consumer copies and store submissions are separate rollout actions.
Recapture store screenshots from the updated app before publishing so their
branding matches the distributed build. This decision authorizes no deployment.

See [master provenance and verification](../brand/detailed-mark.md).
