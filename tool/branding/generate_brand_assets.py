#!/usr/bin/env python3
"""Export detailed NumberInbox branding from one transparent raster master.

Requires Pillow. Original wordmark outlines, layout viewBoxes, splash canvas
sizes, and adaptive-icon safe areas stay intact. SVG compatibility assets
embed the same raster mark; they do not claim to be vector reconstructions.
"""

from __future__ import annotations

from base64 import b64encode
from io import BytesIO
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image

from generate_store_icons import main as generate_store_icons


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "assets/brand/source"
SOURCE = SOURCE_DIR / "mark-detailed.png"
SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)


def element(name: str, **attributes: str) -> ET.Element:
    return ET.Element(f"{{{SVG_NS}}}{name}", attributes)


def write_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def data_uri(image: Image.Image) -> str:
    stream = BytesIO()
    image.save(stream, format="PNG", optimize=True)
    return "data:image/png;base64," + b64encode(stream.getvalue()).decode("ascii")


def normalized_mark(size: int, visible_width: int) -> Image.Image:
    with Image.open(SOURCE) as source:
        if source.mode != "RGBA" or min(source.size) < 1024:
            raise ValueError("The master must be a high-resolution transparent RGBA PNG")
        # Use the same meaningful-alpha threshold as the launcher/splash
        # checks. Include a small antialiasing margin, but do not let nearly
        # invisible generator noise determine the mark's center or scale.
        alpha = source.getchannel("A")
        bounds = alpha.point(lambda value: 255 if value > 16 else 0).getbbox()
        if bounds is None or alpha.getextrema()[0] != 0:
            raise ValueError("The master must contain a visible isolated mark")
        left, top, right, bottom = bounds
        ratio = (bottom - top) / (right - left)
        if not 0.96 <= ratio <= 1.04:
            raise ValueError("The mark must remain approximately square")
        margin = 4
        crop_box = (
            max(0, left - margin), max(0, top - margin),
            min(source.width, right + margin), min(source.height, bottom + margin),
        )
        scale = visible_width / (right - left)
        artwork = source.crop(crop_box).resize(
            (round((crop_box[2] - crop_box[0]) * scale),
             round((crop_box[3] - crop_box[1]) * scale)),
            Image.Resampling.LANCZOS,
        )
    canvas = Image.new("RGBA", (size, size))
    canvas.alpha_composite(
        artwork, ((size - artwork.width) // 2, (size - artwork.height) // 2)
    )
    return canvas


def mark_svg(image: Image.Image, *, background: str | None = None) -> ET.Element:
    root = element("svg", viewBox="0 0 512 512", role="img")
    title = element("title")
    title.text = "NumberInbox detailed full-color mark"
    root.append(title)
    desc = element("desc")
    desc.text = "The shared detailed raster mark, embedded to preserve its shading."
    root.append(desc)
    if background:
        root.append(element("rect", width="512", height="512", fill=background))
    root.append(element("image", width="512", height="512", href=data_uri(image)))
    return root


def write_svg(root: ET.Element, path: Path) -> None:
    ET.indent(root)
    path.write_bytes(ET.tostring(root, encoding="utf-8", xml_declaration=True))


def update_lockup(path: Path, image: Image.Image) -> None:
    root = ET.parse(path).getroot()
    # The existing first transformed group contains only the mark. Preserve
    # its transform and every outlined wordmark/tagline element after it.
    group = next(child for child in root if child.tag == f"{{{SVG_NS}}}g")
    for child in list(group):
        group.remove(child)
    group.append(element("image", width="512", height="512", href=data_uri(image)))
    for node in root.iter(f"{{{SVG_NS}}}defs"):
        for child in list(node):
            if child.get("id") in {"left", "right", "diagonal"}:
                node.remove(child)
    write_svg(root, path)


def main() -> None:
    mark = normalized_mark(1024, 784)
    write_png(mark, ROOT / "assets/images/numberinbox_mark.png")
    # Native and Flutter share the 1024px canvas with a 400px mark, giving
    # the existing 100dp visible mark at the 256dp handoff canvas size.
    splash = normalized_mark(1024, 400)
    android12 = normalized_mark(1152, 400)
    write_png(splash, ROOT / "assets/splash/numberinbox_splash_mark.png")
    write_png(splash, ROOT / "web/splash/img/numberinbox-mark.png")
    write_png(android12, ROOT / "assets/splash/numberinbox_splash_mark_android12.png")
    launch_dir = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for suffix, size in [("", 256), ("@2x", 512), ("@3x", 768)]:
        write_png(splash.resize((size, size), Image.Resampling.LANCZOS),
                  launch_dir / f"LaunchImage{suffix}.png")
    resources = ROOT / "android/app/src/main/res"
    for density, scale in [("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2),
                           ("xxhdpi", 3), ("xxxhdpi", 4)]:
        for name, image, canvas_dp in [("splash", splash, 256),
                                       ("android12splash", android12, 288)]:
            size = round(canvas_dp * scale)
            resized = image.resize((size, size), Image.Resampling.LANCZOS)
            write_png(resized, resources / f"drawable-{density}/{name}.png")
            night = resources / f"drawable-night-{density}/{name}.png"
            if night.exists():
                write_png(resized, night)

    # The same normalized pixels feed modern Android icons, including the
    # current 50dp artwork inside the 108dp layer and its 33dp safe circle.
    foreground = normalized_mark(1024, 474)
    write_png(foreground, ROOT / "assets/icons/icon_ni_foreground.png")
    adaptive = element("svg", viewBox="0 0 1024 1024")
    adaptive.append(element("image", width="1024", height="1024",
                            href=data_uri(foreground)))
    write_svg(adaptive, SOURCE_DIR / "adaptive-foreground.svg")
    for density, size in [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216),
                          ("xxhdpi", 324), ("xxxhdpi", 432)]:
        write_png(foreground.resize((size, size), Image.Resampling.LANCZOS),
                  resources / f"drawable-{density}/ic_launcher_foreground.png")

    # Source masters retain full resolution. Runtime SVG compatibility
    # assets embed 512px pixels, enough for existing 44/50dp logo consumers,
    # without adding a new widget or changing any ImagePaths contracts.
    runtime_mark = mark.resize((512, 512), Image.Resampling.LANCZOS)
    write_svg(mark_svg(mark), SOURCE_DIR / "mark-full-color.svg")
    write_svg(mark_svg(mark, background="#F5F7EB"), SOURCE_DIR / "app-icon-light.svg")
    for name in ["logo-horizontal.svg", "logo-horizontal-tagline.svg", "app-icon-dark.svg"]:
        update_lockup(SOURCE_DIR / name, runtime_mark)
    for name in ["ic_numberinbox_logo.svg", "ic_tmail_logo.svg", "ic_logo_twake_welcome.svg"]:
        write_svg(mark_svg(runtime_mark), ROOT / "assets/images" / name)
    for name in ["ic_logo_with_text.svg", "ic_logo_with_text_beta.svg"]:
        update_lockup(ROOT / "assets/images" / name, runtime_mark)
    write_svg(mark_svg(runtime_mark), ROOT / "configurations/icons/ic_numberinbox_app.svg")

    generate_store_icons()
    with Image.open(ROOT / "assets/icons/icon_ni_logo.png") as store_icon:
        master = store_icon.convert("RGB")
    for name, size in [("Icon-192.png", 192), ("Icon-512.png", 512)]:
        write_png(master.resize((size, size), Image.Resampling.LANCZOS),
                  ROOT / "web/icons" / name)
    # PWA masks guarantee only the central 40%-radius circle. The full-size
    # store artwork does not fit that circle, so maskable exports need their
    # own quiet padding rather than being aliases of the regular web icons.
    maskable = Image.new("RGBA", (1024, 1024), "#F5F7EB")
    maskable.alpha_composite(normalized_mark(1024, 640))
    for size in [192, 512]:
        write_png(maskable.convert("RGB").resize((size, size), Image.Resampling.LANCZOS),
                  ROOT / f"web/icons/Icon-maskable-{size}.png")
    write_png(master.resize((192, 192), Image.Resampling.LANCZOS),
              resources / "drawable/ic_large_notification.png")
    for scale in [1, 2, 3, 4]:
        size = 32 * scale
        write_png(mark.resize((size, size), Image.Resampling.LANCZOS),
                  ROOT / f"web/worker_service/img/tmail-{scale}x.png")
    # Keep inherited own-app asset paths usable without leaving the blue
    # envelope in the bundle. Third-party Workplace/Drive icons are separate.
    for name, size in [("icon_launcher.png", 1024), ("icon_android.png", 486),
                       ("icon_logo_ios.png", 234)]:
        write_png(master.resize((size, size), Image.Resampling.LANCZOS),
                  ROOT / "assets/icons" / name)
    write_png(mark, ROOT / "assets/icons/icon_ni_android.png")
    for size in [16, 32, 48]:
        write_png(master.resize((size, size), Image.Resampling.LANCZOS),
                  ROOT / f"web/favicon-{size}.png")
    # Favicons display at small sizes; do not make browsers download the
    # 1024px store texture just to paint a tab icon. Retain the same mark and
    # viewBox with sufficient pixels for high-density browser tabs.
    write_svg(
        mark_svg(mark.resize((128, 128), Image.Resampling.LANCZOS), background="#F5F7EB"),
        ROOT / "web/favicon.svg",
    )
    print("Generated detailed branding from assets/brand/source/mark-detailed.png")


if __name__ == "__main__":
    main()
