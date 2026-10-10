#!/usr/bin/env python3
"""Render NumberInbox store and native icons from the editable light SVG.

Requires CairoSVG and Pillow. The iOS catalog uses numeric filenames, which
flutter_launcher_icons 0.12 does not update, so render its referenced files
directly rather than leaving a new but unused icon in the catalog.
"""

import json
from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/brand/source/app-icon-light.svg"
MASTER_SIZE = 1024
RENDER_SIZE = 2048


def write_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)
    print(path.relative_to(ROOT))


def main() -> None:
    rendered = cairosvg.svg2png(
        url=str(SOURCE),
        output_width=RENDER_SIZE,
        output_height=RENDER_SIZE,
    )
    with Image.open(BytesIO(rendered)) as source_image:
        master = source_image.convert("RGB").resize(
            (MASTER_SIZE, MASTER_SIZE), Image.Resampling.LANCZOS
        )

    # The iOS bundle icon must be opaque; both stores use this same artwork.
    write_png(master, ROOT / "assets/icons/icon_ni_logo.png")
    write_png(master, ROOT / "docs/store/apple/icon-1024.png")

    # Google Play requires a 32-bit RGBA PNG even though our ice background is
    # visually opaque. Derive each 512px output from the 1024px master.
    play_icon = master.resize((512, 512), Image.Resampling.LANCZOS).convert("RGBA")
    write_png(play_icon, ROOT / "docs/store/play/icon-512.png")
    write_png(play_icon, ROOT / "android/app/src/main/ic_launcher-playstore.png")

    ios_catalog = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((ios_catalog / "Contents.json").read_text())
    for entry in contents["images"]:
        filename = entry.get("filename")
        if filename is None:
            continue
        size = int(Path(filename).stem)
        write_png(
            master.resize((size, size), Image.Resampling.LANCZOS),
            ios_catalog / filename,
        )

    # Generate the legacy Android icons as well. Modern Android uses the
    # separately padded adaptive foreground and the ice background.
    for mipmap in (ROOT / "android/app/src/main/res").glob("mipmap-*"):
        standard = mipmap / "ic_launcher.png"
        rounded = mipmap / "ic_launcher_round.png"
        if not standard.exists() or not rounded.exists():
            continue
        with Image.open(standard) as existing:
            size = existing.width
        resized = master.resize((size, size), Image.Resampling.LANCZOS)
        write_png(resized, standard)
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
        round_icon = resized.convert("RGBA")
        round_icon.putalpha(mask)
        write_png(round_icon, rounded)

    # Remove only files created by flutter_launcher_icons that this catalog
    # does not reference. They would otherwise look like active iOS icons.
    referenced = {
        entry["filename"] for entry in contents["images"] if "filename" in entry
    }
    for stale_icon in ios_catalog.glob("Icon-App-*.png"):
        if stale_icon.name not in referenced:
            stale_icon.unlink()


if __name__ == "__main__":
    main()
