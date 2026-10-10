# NumberInbox brand reference

The original visual reference is [the September 2026 brand board](reference/numberinbox-brand-board-2026-09-22.png). It shows the full-color N/@ mark, light and dark icon treatments, wordmark, colors, and tagline. It is a design reference, not an app screen or a store screenshot.

The editable artwork used by the mobile app and website lives in `assets/brand/source/`. The light icon source is `assets/brand/source/app-icon-light.svg`; the website also uses the matching `mark-full-color.svg` and `logo-horizontal.svg`. Use the unframed full-color mark on `#F5F7EB` for the iOS and Google Play store icons. The launcher generator uses the same 1024-pixel master for the installed app icons.

To rebuild the store and installed icons from the source artwork, install CairoSVG and Pillow, then run:

```sh
python3 tool/branding/generate_store_icons.py
```

The script produces `docs/store/apple/icon-1024.png`, `docs/store/play/icon-512.png`, the launcher master, the Android Play Store icon, and the native iOS and legacy Android launcher sizes. The existing padded Android adaptive foreground and ice background remain in use. Keep app-store screenshots separate: they must come from the real app UI.

The Google Play feature graphic uses the outlined `logo-horizontal-tagline.svg` source and the exact primary tagline, “Email, reimagined with your number.” Rebuild its editable SVG and opaque 1024×500 PNG with:

```sh
python3 tool/branding/generate_play_feature_graphic.py
```
