#!/usr/bin/env python3
"""Export the owner's selected raster feature graphic at Google Play size.

Requires Pillow. Keep the original artwork intact; resizing needs no new AI
generation, font installation, or reconstruction of its logo and gradients.
"""

from pathlib import Path
from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs/store/play/feature-graphic-preferred-original.png"
OUTPUT = ROOT / "docs/store/play/feature-graphic-preferred-1024x500.png"


def main() -> None:
    with Image.open(SOURCE) as artwork:
        ImageOps.fit(
            artwork.convert("RGB"), (1024, 500), Image.Resampling.LANCZOS
        ).save(OUTPUT, format="PNG", optimize=True)
    print(SOURCE.relative_to(ROOT))
    print(OUTPUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
