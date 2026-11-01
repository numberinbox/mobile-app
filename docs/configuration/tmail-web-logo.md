# Customizing NumberInbox web branding

NumberInbox uses a shared transparent PNG master for its detailed full-color
mark. SVG logo files embed that image and retain outlined wordmark typography.
See [the brand reference](../brand/README.md) before changing an export.

Rebuild all corresponding exports before creating a web image:

```sh
python3 tool/branding/generate_brand_assets.py
```

For an existing web container, the corresponding files live below
`/usr/share/nginx/html/`:

- `favicon.svg` and `favicon-32.png`: the SVG favicon and raster fallback.
- `icons/Icon-192.png` and `icons/Icon-512.png`: regular PWA icons.
- `icons/Icon-maskable-192.png` and `icons/Icon-maskable-512.png`: padded PWA icons; retain their mask-safe padding.
- `splash/img/numberinbox-mark.png`: the padded splash canvas shared with Flutter; retain its dimensions and CSS sizing.
- `worker_service/img/tmail-{1,2,3,4}x.png`: mobile-web install-banner marks. Their inherited filenames are intentional compatibility paths.
- `assets/assets/images/numberinbox_mark.png`: in-app full-color mark.
- `assets/assets/images/ic_logo_with_text.svg`: in-app horizontal logo.

Mounting only one old logo filename does not update every branding surface.
Prefer regenerating and rebuilding the web bundle as a unit. Existing Flutter
asset caches can retain a previously loaded image until the app is restarted.
