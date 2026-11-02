# NumberInbox brand reference

The original visual reference is [the September 2026 brand board](reference/numberinbox-brand-board-2026-09-22.png). It shows the full-color N/@ mark, light and dark icon treatments, wordmark, colors, and tagline. It is a design reference, not an app screen or a store screenshot.

The shared detailed mark is `assets/brand/source/mark-detailed.png`, reconstructed from the large N/@ mark in the owner's selected feature graphic. Every updated full-color app mark derives from this one transparent master. The SVG compatibility assets embed that raster mark while retaining the original outlined wordmark and layout viewBoxes; they are hybrid files, not infinitely scalable vector reconstructions. The website consumer copies are not automatically deployed by this app change. See [the detailed-mark notes](detailed-mark.md).

The [asset audit](asset-audit.md) records covered surfaces, corrected omissions, regression evidence, and the remaining website/device/screenshot rollout checks.

Primary action styling now follows [ADR 0120](../adr/0120-logo-coloured-primary-actions.md): the selected logo-colour gradient (`#05D792` → `#03CDFC` → `#018AFC`) and white foreground come from `NumberInboxPalette.primaryActionGradient` and `primaryActionForeground`. This supersedes the earlier dark action-gradient treatment for these controls. Ordinary text/link colours and dark Compose styling retain their existing behavior.

To rebuild in-app branding, native splashes, padded Android adaptive foregrounds, store/installed icons, and web branding, install Pillow and run:

```sh
python3 tool/branding/generate_brand_assets.py
```

The script includes `generate_store_icons.py` and produces `docs/store/apple/icon-1024.png`, `docs/store/play/icon-512.png`, the launcher master, the Android Play Store icon, and all referenced native sizes. It preserves the 50dp adaptive foreground inside the safe area, the ice icon background, and the 100dp native/Flutter splash mark on white. Ordinary interface and monochrome notification icons stay unchanged. Keep app-store screenshots separate: they must come from the real app UI; older captures show the previous mark.

The selected Google Play feature graphic is `docs/store/play/feature-graphic-preferred-1024x500.png`. Its original AI-generated artwork is preserved in `feature-graphic-preferred-original.png`; the owner selected its detailed gradients, white background, and large headline. With Pillow installed, rebuild the opaque 1024×500 upload PNG with:

```sh
python3 tool/branding/generate_play_feature_graphic.py
```

`docs/store/play/feature-graphic-v2.svg` is an alternative vector recreation, not the source of the selected PNG. It does not reproduce the raster artwork's fine shading. See `docs/store/play/feature-graphic-v2-notes.md` for provenance and the generation prompt.
