"""Generate app icons from assets/branding/icon-money.svg.

Android icons are transparent SVG-only marks. iOS icons are composited on an
opaque dark background because the App Store rejects alpha.
"""

from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "branding" / "icon-money.svg"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
IOS_SET = (
    ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
)

MASTER = 1024
IOS_SCALE = 0.80
ANDROID_SCALE = 0.94
ADAPTIVE_SCALE = 0.62
LAUNCH_SIZE = 128
GRADIENT_TOP = (14, 17, 14)
GRADIENT_BOTTOM = (5, 6, 5)


def render_mark(size: int) -> Image.Image:
    png = cairosvg.svg2png(
        url=str(SOURCE),
        output_width=size,
        output_height=size,
    )
    return Image.open(BytesIO(png)).convert("RGBA")


def background(size: int) -> Image.Image:
    strip = Image.new("RGB", (1, size))
    pixels = strip.load()
    for y in range(size):
        t = y / max(1, size - 1)
        pixels[0, y] = tuple(
            round(GRADIENT_TOP[i] + (GRADIENT_BOTTOM[i] - GRADIENT_TOP[i]) * t)
            for i in range(3)
        )
    return strip.resize((size, size), Image.Resampling.BICUBIC)


def compose(size: int, scale: float = IOS_SCALE) -> Image.Image:
    canvas = background(size).convert("RGBA")
    mark_size = round(size * scale)
    mark = render_mark(MASTER).resize(
        (mark_size, mark_size),
        Image.Resampling.LANCZOS,
    )
    offset = (size - mark_size) // 2
    canvas.alpha_composite(mark, (offset, offset))
    return canvas


def transparent_mark(size: int, scale: float = ANDROID_SCALE) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mark_size = round(size * scale)
    mark = render_mark(MASTER).resize(
        (mark_size, mark_size),
        Image.Resampling.LANCZOS,
    )
    offset = (size - mark_size) // 2
    canvas.alpha_composite(mark, (offset, offset))
    return canvas


def foreground(size: int) -> Image.Image:
    return transparent_mark(size, ADAPTIVE_SCALE)


def write_android() -> None:
    legacy_sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    foreground_sizes = {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }

    for density, size in legacy_sizes.items():
        folder = ANDROID_RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        transparent_mark(size).save(folder / "ic_launcher.png")
        transparent_mark(size).save(folder / "ic_launcher_round.png")

    for density, size in foreground_sizes.items():
        folder = ANDROID_RES / f"mipmap-{density}"
        foreground(size).save(folder / "ic_launcher_foreground.png")

    anydpi = ANDROID_RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    adaptive = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@android:color/transparent" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
    (anydpi / "ic_launcher.xml").write_text(adaptive, encoding="utf-8")
    (anydpi / "ic_launcher_round.xml").write_text(adaptive, encoding="utf-8")


def write_ios() -> None:
    icons = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    master = compose(MASTER).convert("RGB")
    for name, size in icons.items():
        icon = master if size == MASTER else master.resize(
            (size, size),
            Image.Resampling.LANCZOS,
        )
        icon.save(IOS_SET / name)


def write_launch_marks() -> None:
    densities = {
        "mdpi": 128,
        "hdpi": 192,
        "xhdpi": 256,
        "xxhdpi": 384,
        "xxxhdpi": 512,
    }
    for density, size in densities.items():
        folder = ANDROID_RES / f"drawable-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        transparent_mark(size, 1.0).save(folder / "launch_mark.png")

    launch_set = (
        ROOT
        / "ios"
        / "Runner"
        / "Assets.xcassets"
        / "LaunchImage.imageset"
    )
    for name, size in (
        ("LaunchImage.png", LAUNCH_SIZE),
        ("LaunchImage@2x.png", LAUNCH_SIZE * 2),
        ("LaunchImage@3x.png", LAUNCH_SIZE * 3),
    ):
        transparent_mark(size, 1.0).save(launch_set / name)


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Missing source icon: {SOURCE}")

    branding = ROOT / "assets" / "branding"
    master = compose(MASTER).convert("RGB")
    master.save(branding / "app_icon.png")
    master.save(branding / "app_icon_rgb.png")
    transparent_mark(512, 1.0).save(branding / "splash_mark.png")

    write_android()
    write_ios()
    write_launch_marks()



if __name__ == "__main__":
    main()
