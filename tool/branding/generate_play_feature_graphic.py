#!/usr/bin/env python3
"""Build the Play feature graphic from the approved NumberInbox vector logo.

Requires CairoSVG and Pillow. The source logo already contains the outlined
primary tagline, so this keeps its wording and typography synchronized with
the mobile app and website instead of recreating either with a font.
"""

from copy import deepcopy
from io import BytesIO
from pathlib import Path
import xml.etree.ElementTree as ET

import cairosvg
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/brand/source/logo-horizontal-tagline.svg"
OUTPUT_SVG = ROOT / "docs/store/play/feature-graphic.svg"
OUTPUT_PNG = ROOT / "docs/store/play/feature-graphic-1024x500.png"
SVG_NS = "http://www.w3.org/2000/svg"


def element(name: str, attributes: dict[str, str]) -> ET.Element:
    return ET.Element(f"{{{SVG_NS}}}{name}", attributes)


def main() -> None:
    ET.register_namespace("", SVG_NS)
    artwork = ET.parse(SOURCE).getroot()
    graphic = element("svg", {"viewBox": "0 0 1024 500", "width": "1024", "height": "500"})
    graphic.append(element("title", {}))
    graphic[-1].text = "NumberInbox — Email, reimagined with your number."
    graphic.append(element("rect", {"width": "1024", "height": "500", "fill": "#F5F7EB"}))
    graphic.append(element("circle", {
        "cx": "1015", "cy": "-30", "r": "250", "fill": "#06B6D4", "opacity": ".08"
    }))
    graphic.append(element("circle", {
        "cx": "-20", "cy": "520", "r": "250", "fill": "#10B981", "opacity": ".08"
    }))

    # Source viewBox: 1600×440. This transform keeps the mark, outlined
    # wordmark, and primary tagline together inside Google's center-safe area.
    lockup = element("g", {"transform": "translate(32 145) scale(.6)"})
    for child in artwork:
        if child.tag.rsplit("}", 1)[-1] not in {"title", "desc"}:
            lockup.append(deepcopy(child))
    graphic.append(lockup)

    OUTPUT_SVG.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_SVG.write_bytes(ET.tostring(graphic, encoding="utf-8", xml_declaration=True))
    rendered = cairosvg.svg2png(url=str(OUTPUT_SVG), output_width=2048, output_height=1000)
    with Image.open(BytesIO(rendered)) as image:
        final = image.convert("RGB").resize((1024, 500), Image.Resampling.LANCZOS)
        final.save(OUTPUT_PNG, format="PNG", optimize=True)
    print(OUTPUT_SVG.relative_to(ROOT))
    print(OUTPUT_PNG.relative_to(ROOT))


if __name__ == "__main__":
    main()
