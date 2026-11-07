
## Android notification small icon

`assets/brand/source/notification-icon.svg` is the simplified monochrome N/@
mask derived from the existing brand geometry. Its @ is white with transparent
separation from the N; Android supplies the final tint and surrounding UI.

With `rsvg-convert` (librsvg) installed, export only these notification assets:

```sh
python3 tool/branding/generate_notification_icon.py
python3 -m unittest discover -s tool/branding/tests
```

This exports 24/36/48/72/96px density variants without touching launcher, splash,
iOS, or large notification artwork. Review the mask at actual status-bar and
notification-shade size on stock Android and Samsung before release; passing
asset tests does not establish legibility.
