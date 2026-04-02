#!/usr/bin/env python3

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


SCRIPT_DIR = Path(__file__).resolve().parent
APP_DIR = SCRIPT_DIR.parent
SPRITE_DIR = APP_DIR.parent / "godot-game" / "assets" / "sprites" / "player"
SOURCE_SHEET = SPRITE_DIR / "happy_sheet.png"
OUTPUT_PNG = APP_DIR / "Assets" / "AppIconSource.png"

FRAME_SIZE = 64
CANVAS_SIZE = 1024


def first_frame(sheet_path: Path) -> Image.Image:
    sheet = Image.open(sheet_path).convert("RGBA")
    return sheet.crop((0, 0, FRAME_SIZE, FRAME_SIZE))


def build_icon(sprite: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))

    # Dark badge background with a subtle green signal glow.
    glow = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse((88, 88, CANVAS_SIZE - 88, CANVAS_SIZE - 88), fill=(57, 255, 163, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(34))
    canvas.alpha_composite(glow)

    badge = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    badge_draw = ImageDraw.Draw(badge)
    badge_draw.ellipse((118, 118, CANVAS_SIZE - 118, CANVAS_SIZE - 118), fill=(16, 20, 27, 255))
    badge_draw.ellipse((140, 140, CANVAS_SIZE - 140, CANVAS_SIZE - 140), outline=(57, 255, 163, 150), width=14)
    canvas.alpha_composite(badge)

    sprite = sprite.resize((620, 620), Image.Resampling.NEAREST)

    shadow = Image.new("RGBA", sprite.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.bitmap((0, 0), sprite.split()[-1], fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas.alpha_composite(shadow, (214, 250))
    canvas.alpha_composite(sprite, (202, 214))

    signal = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    signal_draw = ImageDraw.Draw(signal)
    signal_draw.arc((120, 120, CANVAS_SIZE - 120, CANVAS_SIZE - 120), 206, 334, fill=(57, 255, 163, 120), width=16)
    signal_draw.arc((170, 170, CANVAS_SIZE - 170, CANVAS_SIZE - 170), 210, 328, fill=(57, 255, 163, 90), width=10)
    canvas.alpha_composite(signal)

    return canvas


def main() -> None:
    sprite = first_frame(SOURCE_SHEET)
    icon = build_icon(sprite)
    OUTPUT_PNG.parent.mkdir(parents=True, exist_ok=True)
    icon.save(OUTPUT_PNG)
    print(f"Wrote {OUTPUT_PNG}")


if __name__ == "__main__":
    main()
