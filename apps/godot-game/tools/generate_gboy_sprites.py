#!/usr/bin/env python3

from __future__ import annotations

import math
import random
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "sprites" / "player"
FRAME_SIZE = 64
WORK_SIZE = 32
UPSCALE = FRAME_SIZE // WORK_SIZE

PALETTE = {
    "outline": (18, 17, 26, 255),
    "shadow": (9, 18, 43, 105),
    "hood": (226, 72, 67, 255),
    "hood_shade": (170, 42, 47, 255),
    "cape": (214, 58, 61, 255),
    "cape_shade": (148, 31, 40, 255),
    "face": (8, 8, 12, 255),
    "eye": (250, 250, 248, 255),
    "shirt": (238, 224, 170, 255),
    "shirt_shade": (208, 191, 133, 255),
    "shorts": (106, 98, 81, 255),
    "shorts_shade": (78, 72, 60, 255),
    "skinless": (9, 10, 17, 255),
    "sock": (240, 240, 240, 255),
    "shoe": (101, 80, 196, 255),
    "shoe_dark": (59, 44, 126, 255),
    "tear": (102, 190, 255, 255),
    "snack": (157, 211, 98, 255),
    "spark": (255, 245, 174, 255),
    "angry": (255, 210, 130, 255),
    "sleep": (147, 209, 255, 255),
    "screen": (108, 220, 242, 255),
    "screen_dark": (34, 65, 107, 255),
    "plastic": (82, 90, 118, 255),
    "plastic_dark": (56, 62, 84, 255),
    "metal": (152, 160, 174, 255),
    "paper": (231, 224, 200, 255),
    "paper_dark": (194, 180, 150, 255),
    "marker": (31, 31, 38, 255),
    "wood": (133, 96, 69, 255),
    "wood_dark": (92, 64, 44, 255),
    "steam": (228, 243, 255, 180),
    "flame": (255, 142, 61, 255),
    "badge": (255, 216, 84, 255),
    "note_red": (245, 98, 104, 255),
}

FONT_3X5 = {
    "A": ["010", "101", "111", "101", "101"],
    "B": ["110", "101", "110", "101", "110"],
    "C": ["011", "100", "100", "100", "011"],
    "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"],
    "F": ["111", "100", "110", "100", "100"],
    "G": ["011", "100", "101", "101", "011"],
    "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"],
    "J": ["001", "001", "001", "101", "010"],
    "K": ["101", "101", "110", "101", "101"],
    "L": ["100", "100", "100", "100", "111"],
    "M": ["101", "111", "111", "101", "101"],
    "N": ["101", "111", "111", "111", "101"],
    "O": ["010", "101", "101", "101", "010"],
    "P": ["110", "101", "110", "100", "100"],
    "Q": ["010", "101", "101", "111", "011"],
    "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"],
    "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"],
    "V": ["101", "101", "101", "101", "010"],
    "W": ["101", "101", "111", "111", "101"],
    "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"],
    "Z": ["111", "001", "010", "100", "111"],
    "*": ["000", "101", "010", "101", "000"],
    "0": ["111", "101", "101", "101", "111"],
    "3": ["111", "001", "111", "001", "111"],
    "4": ["101", "101", "111", "001", "001"],
    "7": ["111", "001", "010", "100", "100"],
    "-": ["000", "000", "111", "000", "000"],
    ":": ["000", "010", "000", "010", "000"],
}


@dataclass
class Pose:
    bob: int = 0
    stretch: int = 0
    lean: int = 0
    head_tilt: int = 0
    arm_left: int = 0
    arm_right: int = 0
    leg_left: int = 0
    leg_right: int = 0
    shoe_left: int = 0
    shoe_right: int = 0
    cape_left: int = 0
    cape_right: int = 0
    blink: bool = False
    emotion: str = "neutral"
    item: str | None = None
    aura: bool = False
    mouth_shift: int = 0
    eye_shift_x: int = 0
    eye_shift_y: int = 0


def with_alpha(color, alpha: float):
    return (color[0], color[1], color[2], int(color[3] * max(0.0, min(1.0, alpha))))


def polygon(draw: ImageDraw.ImageDraw, points, fill, outline=PALETTE["outline"]):
    draw.polygon(points, fill=fill, outline=outline)


def rect(draw: ImageDraw.ImageDraw, box, fill, outline=PALETTE["outline"]):
    x0, y0, x1, y1 = box
    draw.rectangle((min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)), fill=fill, outline=outline)


def ellipse(draw: ImageDraw.ImageDraw, box, fill, outline=None):
    x0, y0, x1, y1 = box
    draw.ellipse((min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)), fill=fill, outline=outline)


def line(draw: ImageDraw.ImageDraw, points, fill, width=1):
    draw.line(points, fill=fill, width=width)


def draw_pixel_text(draw: ImageDraw.ImageDraw, text: str, x: int, y: int, color, spacing: int = 1):
    cursor_x = x
    for char in text.upper():
        if char == " ":
            cursor_x += 4
            continue
        glyph = FONT_3X5.get(char)
        if glyph is None:
            cursor_x += 4
            continue
        for row, glyph_row in enumerate(glyph):
            for col, bit in enumerate(glyph_row):
                if bit == "1":
                    draw.point((cursor_x + col, y + row), fill=color)
        cursor_x += 3 + spacing
    return cursor_x


def partial_text(text: str, reveal_count: int) -> str:
    shown = 0
    result = []
    for char in text:
        if char == " ":
            result.append(" ")
            continue
        if shown >= reveal_count:
            break
        result.append(char)
        shown += 1
    return "".join(result)


def draw_revealed_lines(draw: ImageDraw.ImageDraw, lines_text: list[str], x: int, y: int, reveal_count: int, color):
    remaining = reveal_count
    for row, text in enumerate(lines_text):
        visible = partial_text(text, remaining)
        draw_pixel_text(draw, visible, x, y + row * 6, color)
        remaining -= sum(1 for char in visible if char != " ")
        if remaining <= 0:
            remaining = 0


def draw_marker(draw: ImageDraw.ImageDraw, x: int, y: int, diagonal: bool = False):
    if diagonal:
        polygon(draw, [(x, y), (x + 3, y + 1), (x + 2, y + 3), (x - 1, y + 2)], PALETTE["marker"], PALETTE["outline"])
        draw.point((x + 3, y + 1), fill=PALETTE["paper"])
    else:
        rect(draw, (x, y, x + 3, y + 1), PALETTE["marker"], PALETTE["outline"])
        draw.point((x + 3, y), fill=PALETTE["paper"])


def hood_points(tilt: int, bob: int):
    """Rounded hood with graceful outward-curving cat ears. Big chibi head."""
    t, b = tilt, bob
    return [
        # Left ear - curves outward gracefully
        (8 + t, 10 + b),
        (7 + t, 7 + b),
        (6 + t, 4 + b),       # Left ear tip - wide outward
        (8 + t, 3 + b),
        (10 + t, 5 + b),
        # Top of hood - smooth dome
        (12 + t, 4 + b),
        (14 + t, 3 + b),
        (16 + t, 3 + b),
        (18 + t, 3 + b),
        (20 + t, 4 + b),
        # Right ear - curves outward gracefully
        (22 + t, 5 + b),
        (24 + t, 3 + b),
        (26 + t, 4 + b),       # Right ear tip - wide outward
        (25 + t, 7 + b),
        (24 + t, 10 + b),
        # Right side
        (25 + t, 13 + b),
        (25 + t, 16 + b),
        (24 + t, 18 + b),
        # Bottom - wide rounded
        (22 + t, 19 + b),
        (16 + t, 20 + b),
        (10 + t, 19 + b),
        # Left side
        (8 + t, 18 + b),
        (7 + t, 16 + b),
        (7 + t, 13 + b),
    ]


def draw_mouth(draw: ImageDraw.ImageDraw, cx: int, y: int, emotion: str):
    """Subtle, understated mouth expressions."""
    if emotion == "happy":
        # Gentle upward curve
        line(draw, [(cx - 2, y), (cx - 1, y + 1), (cx + 1, y + 1), (cx + 2, y)], PALETTE["eye"])
    elif emotion == "angry":
        line(draw, [(cx - 1, y + 1), (cx, y), (cx + 1, y + 1)], PALETTE["angry"])
    elif emotion == "cry":
        line(draw, [(cx - 1, y + 1), (cx, y), (cx + 1, y + 1)], PALETTE["eye"])
    elif emotion == "eat":
        ellipse(draw, (cx - 1, y, cx + 1, y + 2), PALETTE["eye"], None)
    elif emotion == "sleep":
        line(draw, [(cx - 1, y), (cx + 1, y)], PALETTE["eye"])
    else:
        # Default: tiny gentle smile
        line(draw, [(cx - 1, y), (cx, y + 1), (cx + 1, y)], PALETTE["eye"])


def draw_face(draw: ImageDraw.ImageDraw, pose: Pose):
    """Large round void face with big expressive oval eyes."""
    bob = pose.bob
    tilt = pose.head_tilt
    sx = pose.eye_shift_x
    sy = pose.eye_shift_y

    # Large rounded face filling most of the hood
    ellipse(draw, (9 + tilt, 7 + bob, 23 + tilt, 19 + bob), PALETTE["face"], PALETTE["outline"])

    # Eye positions - large, wide-set oval eyes
    ley, rey = 10 + bob + sy, 10 + bob + sy  # eye top y
    lex, rex = 10 + tilt + sx, 18 + tilt + sx  # eye left x

    if pose.blink or pose.emotion == "sleep":
        # Closed eyes - horizontal lines
        line(draw, [(lex, ley + 2), (lex + 4, ley + 2)], PALETTE["eye"])
        line(draw, [(rex, rey + 2), (rex + 4, rey + 2)], PALETTE["eye"])
    elif pose.emotion == "angry":
        # Angry squint eyes
        ellipse(draw, (lex, ley + 1, lex + 4, ley + 4), PALETTE["eye"])
        ellipse(draw, (rex, rey + 1, rex + 4, rey + 4), PALETTE["eye"])
        # Angry brow lines
        line(draw, [(lex - 1, ley - 1), (lex + 3, ley)], PALETTE["angry"])
        line(draw, [(rex + 1, rey), (rex + 5, rey - 1)], PALETTE["angry"])
    else:
        # Big round oval eyes - the signature look
        ellipse(draw, (lex, ley, lex + 4, ley + 5), PALETTE["eye"])
        ellipse(draw, (rex, rey, rex + 4, rey + 5), PALETTE["eye"])

    # Mouth - subtle, positioned lower
    mouth_y = 16 + bob + pose.mouth_shift
    draw_mouth(draw, 16 + tilt, mouth_y, pose.emotion)

    # Emotion extras
    if pose.emotion == "cry":
        line(draw, [(lex + 1, ley + 5), (lex + 1, ley + 7)], PALETTE["tear"])
        line(draw, [(rex + 2, rey + 5), (rex + 2, rey + 7)], PALETTE["tear"])
    elif pose.emotion == "happy":
        draw.point((9 + tilt, mouth_y - 1), fill=PALETTE["spark"])
        draw.point((23 + tilt, mouth_y - 1), fill=PALETTE["spark"])


def draw_body(img: Image.Image, pose: Pose):
    """Draw full front-facing GBOY with chibi proportions matching reference."""
    draw = ImageDraw.Draw(img)
    b = pose.bob
    ln = pose.lean
    ground = 29 + b
    torso_top = 19 + b - pose.stretch   # Shorter torso - big head takes more room
    torso_bot = 24 + b

    # --- Ground shadow ---
    ellipse(draw, (7 + ln, ground + 1, 25 + ln, ground + 3), PALETTE["shadow"])

    # --- Cape (drawn FIRST - behind everything) ---
    # Left cape panel - flows from shoulder down and outward
    polygon(draw, [
        (10 + ln, 18 + b),
        (8 + ln - pose.cape_left, 23 + b),
        (6 + ln - pose.cape_left, 29 + b),
        (8 + ln, 30 + b),
        (13 + ln, 26 + b),
        (13 + ln, 19 + b),
    ], PALETTE["cape"], PALETTE["outline"])
    # Right cape panel
    polygon(draw, [
        (19 + ln, 19 + b),
        (19 + ln, 26 + b),
        (24 + ln, 30 + b),
        (26 + ln + pose.cape_right, 29 + b),
        (24 + ln + pose.cape_right, 23 + b),
        (22 + ln, 18 + b),
    ], PALETTE["cape"], PALETTE["outline"])
    # Cape shade inner edges
    polygon(draw, [
        (10 + ln, 19 + b), (12 + ln, 19 + b),
        (12 + ln, 28 + b), (8 + ln - pose.cape_left, 29 + b),
    ], PALETTE["cape_shade"], None)
    polygon(draw, [
        (20 + ln, 19 + b), (22 + ln, 19 + b),
        (24 + ln + pose.cape_right, 29 + b), (20 + ln, 28 + b),
    ], PALETTE["cape_shade"], None)

    # --- Shirt / torso ---
    polygon(draw, [
        (11 + ln, torso_top),
        (21 + ln, torso_top),
        (22 + ln, torso_top + 2),
        (21 + ln, torso_bot),
        (16 + ln, torso_bot + 1),
        (11 + ln, torso_bot),
        (10 + ln, torso_top + 2),
    ], PALETTE["shirt"], PALETTE["outline"])
    # Shirt shading
    rect(draw, (12 + ln, torso_top + 3, 20 + ln, torso_bot), PALETTE["shirt_shade"], None)
    # Sleeves
    rect(draw, (9 + ln, torso_top + 1, 11 + ln, torso_top + 3), PALETTE["shirt"], PALETTE["outline"])
    rect(draw, (21 + ln, torso_top + 1, 23 + ln, torso_top + 3), PALETTE["shirt"], PALETTE["outline"])

    # --- Arms (void black limbs) ---
    rect(draw, (10 + pose.arm_left, torso_top + 3, 11 + pose.arm_left, torso_bot - 1), PALETTE["skinless"], PALETTE["outline"])
    rect(draw, (21 + pose.arm_right, torso_top + 3, 22 + pose.arm_right, torso_bot - 1), PALETTE["skinless"], PALETTE["outline"])

    # --- Shorts ---
    rect(draw, (11 + ln, torso_bot, 21 + ln, torso_bot + 3), PALETTE["shorts"], PALETTE["outline"])
    rect(draw, (11 + ln, torso_bot + 1, 21 + ln, torso_bot + 3), PALETTE["shorts_shade"], None)

    # --- Legs (void black) ---
    rect(draw, (13 + pose.leg_left, torso_bot + 3, 14 + pose.leg_left, ground - 1), PALETTE["skinless"], PALETTE["outline"])
    rect(draw, (18 + pose.leg_right, torso_bot + 3, 19 + pose.leg_right, ground - 1), PALETTE["skinless"], PALETTE["outline"])

    # --- Shoes (purple sneakers with white sole and lace dots) ---
    # Left shoe
    sl = pose.shoe_left
    polygon(draw, [
        (10 + sl, ground - 1), (15 + sl, ground - 1),
        (16 + sl, ground + 1), (10 + sl, ground + 1),
    ], PALETTE["shoe"], PALETTE["outline"])
    line(draw, [(10 + sl, ground + 1), (16 + sl, ground + 1)], PALETTE["sock"])  # White sole
    draw.point((12 + sl, ground - 1), fill=PALETTE["sock"])   # Lace dot
    draw.point((14 + sl, ground - 1), fill=PALETTE["sock"])   # Lace dot
    # Right shoe
    sr = pose.shoe_right
    polygon(draw, [
        (17 + sr, ground - 1), (22 + sr, ground - 1),
        (22 + sr, ground + 1), (16 + sr, ground + 1),
    ], PALETTE["shoe"], PALETTE["outline"])
    line(draw, [(16 + sr, ground + 1), (22 + sr, ground + 1)], PALETTE["sock"])  # White sole
    draw.point((18 + sr, ground - 1), fill=PALETTE["sock"])   # Lace dot
    draw.point((20 + sr, ground - 1), fill=PALETTE["sock"])   # Lace dot

    # --- Hood (drawn on top of everything) ---
    ht = pose.head_tilt + pose.lean
    hb = pose.bob - pose.stretch
    polygon(draw, hood_points(ht, hb), PALETTE["hood"], PALETTE["outline"])
    # Hood shading - left ear inner
    polygon(draw, [
        (8 + ht, 10 + hb), (7 + ht, 5 + hb),
        (9 + ht, 6 + hb), (10 + ht, 10 + hb),
    ], PALETTE["hood_shade"], None)
    # Hood shading - right ear inner
    polygon(draw, [
        (22 + ht, 10 + hb), (23 + ht, 6 + hb),
        (25 + ht, 5 + hb), (24 + ht, 10 + hb),
    ], PALETTE["hood_shade"], None)

    # --- Face (drawn on top of hood) ---
    draw_face(draw, pose)

    if pose.aura:
        line(draw, [(5, 11 + pose.bob), (7, 9 + pose.bob), (9, 10 + pose.bob)], PALETTE["spark"])
        line(draw, [(24, 10 + pose.bob), (26, 8 + pose.bob), (27, 10 + pose.bob)], PALETTE["spark"])

    if pose.item == "snack":
        polygon(
            draw,
            [
                (22 + pose.arm_right, torso_top + 8),
                (24 + pose.arm_right, torso_top + 7),
                (25 + pose.arm_right, torso_top + 9),
                (23 + pose.arm_right, torso_top + 11),
            ],
            PALETTE["snack"],
            PALETTE["outline"],
        )
    elif pose.item == "zzz":
        line(draw, [(24, 5 + pose.bob), (26, 5 + pose.bob), (24, 8 + pose.bob), (26, 8 + pose.bob)], PALETTE["sleep"])
        line(draw, [(26, 3 + pose.bob), (28, 3 + pose.bob), (26, 6 + pose.bob), (28, 6 + pose.bob)], PALETTE["sleep"])


def draw_portal(draw: ImageDraw.ImageDraw, phase: float):
    glow = max(0.25, phase)
    ellipse(draw, (6, 16, 26, 30), with_alpha((82, 42, 153, 255), 0.45 * glow))
    ellipse(draw, (8, 18, 24, 28), with_alpha((27, 17, 60, 255), 0.9))
    ellipse(draw, (9, 19, 23, 27), None, with_alpha((125, 235, 255, 255), glow))
    line(draw, [(7, 23), (5, 21), (4, 18)], with_alpha(PALETTE["spark"], glow))
    line(draw, [(25, 21), (27, 18), (28, 16)], with_alpha(PALETTE["spark"], glow))


def draw_smoke(draw: ImageDraw.ImageDraw, phase: float):
    puffs = [
        (9, 18, 16, 25),
        (14, 15, 22, 24),
        (19, 18, 26, 26),
        (11, 22, 20, 30),
        (18, 22, 26, 30),
    ]
    alpha = max(0.15, min(1.0, phase))
    for x0, y0, x1, y1 in puffs:
        ellipse(draw, (x0, y0, x1, y1), with_alpha((14, 12, 22, 255), alpha), with_alpha(PALETTE["outline"], alpha))


def draw_crt(draw: ImageDraw.ImageDraw, x: int, y: int, channel: int):
    rect(draw, (x, y + 2, x + 11, y + 10), PALETTE["plastic"], PALETTE["outline"])
    rect(draw, (x + 1, y + 3, x + 10, y + 9), PALETTE["screen_dark"], PALETTE["outline"])
    rect(draw, (x + 4, y + 11, x + 7, y + 12), PALETTE["plastic_dark"], PALETTE["outline"])
    rect(draw, (x + 3, y + 12, x + 8, y + 13), PALETTE["metal"], PALETTE["outline"])
    if channel == 0:
        for offset in range(0, 8, 2):
            line(draw, [(x + 2, y + 4 + offset // 2), (x + 9, y + 4 + offset // 2)], with_alpha(PALETTE["screen"], 0.8))
    elif channel == 1:
        ellipse(draw, (x + 3, y + 4, x + 8, y + 8), PALETTE["eye"])
        rect(draw, (x + 4, y + 6, x + 7, y + 6), PALETTE["outline"], None)
    elif channel == 2:
        polygon(draw, [(x + 5, y + 4), (x + 8, y + 8), (x + 3, y + 8)], PALETTE["note_red"], PALETTE["outline"])
    elif channel == 3:
        rect(draw, (x + 3, y + 4, x + 8, y + 8), PALETTE["badge"], PALETTE["outline"])
        draw.point((x + 5, y + 6), fill=PALETTE["outline"])
    elif channel == 4:
        ellipse(draw, (x + 3, y + 4, x + 8, y + 8), with_alpha((82, 42, 153, 255), 0.9), PALETTE["spark"])
    else:
        draw_pixel_text(draw, "G304", x + 1, y + 4, PALETTE["screen"])


def draw_handheld_device(draw: ImageDraw.ImageDraw, x: int, y: int, phase: int):
    rect(draw, (x, y, x + 10, y + 6), PALETTE["plastic"], PALETTE["outline"])
    rect(draw, (x + 2, y + 1, x + 8, y + 4), PALETTE["screen_dark"], PALETTE["outline"])
    dot = [(x + 3, y + 2), (x + 6, y + 2), (x + 5, y + 3), (x + 7, y + 3)][phase % 4]
    draw.point(dot, fill=PALETTE["screen"])
    draw.point((x + 1, y + 3), fill=PALETTE["outline"])
    draw.point((x + 9, y + 2), fill=PALETTE["note_red"])
    draw.point((x + 8, y + 4), fill=PALETTE["badge"])


def draw_burner(draw: ImageDraw.ImageDraw, x: int, y: int, flame: bool = False):
    rect(draw, (x, y + 3, x + 11, y + 8), PALETTE["metal"], PALETTE["outline"])
    ellipse(draw, (x + 2, y, x + 9, y + 5), PALETTE["plastic_dark"], PALETTE["outline"])
    if flame:
        polygon(draw, [(x + 5, y + 1), (x + 7, y + 4), (x + 4, y + 5), (x + 3, y + 3)], PALETTE["flame"], PALETTE["outline"])


def draw_pan(draw: ImageDraw.ImageDraw, x: int, y: int, toss: int):
    pan_y = y - max(0, toss)
    ellipse(draw, (x, pan_y, x + 8, pan_y + 3), PALETTE["metal"], PALETTE["outline"])
    rect(draw, (x + 8, pan_y + 1, x + 12, pan_y + 1), PALETTE["marker"], PALETTE["outline"])
    if toss > 0:
        polygon(draw, [(x + 3, pan_y - 1), (x + 6, pan_y - 2), (x + 7, pan_y), (x + 4, pan_y + 1)], PALETTE["snack"], PALETTE["outline"])


def draw_bowl(draw: ImageDraw.ImageDraw, x: int, y: int, slurp: int):
    polygon(draw, [(x, y), (x + 8, y), (x + 7, y + 3), (x + 1, y + 3)], PALETTE["paper"], PALETTE["outline"])
    for noodle_x in range(x + 1, x + 7, 2):
        line(draw, [(noodle_x, y + 1), (noodle_x + 1, y + 2)], PALETTE["snack"])
    for steam_x in range(2):
        line(draw, [(x + 2 + steam_x * 3, y - 1 - steam_x), (x + 3 + steam_x * 3, y - 3 - steam_x)], PALETTE["steam"])
    if slurp > 0:
        line(draw, [(x + 4, y), (x + 7 + slurp, y - 3 - slurp)], PALETTE["paper_dark"])


def draw_evidence_board(draw: ImageDraw.ImageDraw, x: int, y: int, blink: int):
    rect(draw, (x, y, x + 12, y + 15), PALETTE["wood"], PALETTE["outline"])
    rect(draw, (x + 1, y + 1, x + 11, y + 14), PALETTE["paper_dark"], None)
    rect(draw, (x + 2, y + 2, x + 5, y + 5), PALETTE["paper"], PALETTE["outline"])
    rect(draw, (x + 7, y + 3, x + 10, y + 6), PALETTE["note_red"], PALETTE["outline"])
    rect(draw, (x + 4, y + 8, x + 8, y + 11), PALETTE["paper"], PALETTE["outline"])
    line(draw, [(x + 4, y + 5), (x + 8, y + 4)], PALETTE["hood"])
    line(draw, [(x + 9, y + 6), (x + 6, y + 8)], PALETTE["hood"])
    draw.point((x + 4, y + 5), fill=PALETTE["badge"])
    draw.point((x + 8, y + 4), fill=PALETTE["badge"])
    draw.point((x + 9, y + 6), fill=PALETTE["badge"])
    draw.point((x + 6, y + 8), fill=PALETTE["badge"])
    if blink % 2 == 0:
        draw_pixel_text(draw, "MIT", x + 1, y + 10, PALETTE["marker"])
    else:
        draw_pixel_text(draw, "G304", x + 1, y + 10, PALETTE["marker"])


def draw_terminal(draw: ImageDraw.ImageDraw, x: int, y: int, phase: int):
    rect(draw, (x, y, x + 9, y + 6), PALETTE["plastic"], PALETTE["outline"])
    rect(draw, (x + 1, y + 1, x + 8, y + 4), PALETTE["screen_dark"], PALETTE["outline"])
    draw_pixel_text(draw, "SJ", x + 2, y + 1, PALETTE["screen"])
    if phase % 2 == 0:
        line(draw, [(x + 2, y + 4), (x + 6, y + 4)], PALETTE["screen"])
    else:
        line(draw, [(x + 3, y + 3), (x + 7, y + 3)], PALETTE["screen"])


def draw_radio(draw: ImageDraw.ImageDraw, x: int, y: int, phase: int):
    rect(draw, (x, y, x + 10, y + 7), PALETTE["plastic_dark"], PALETTE["outline"])
    rect(draw, (x + 1, y + 1, x + 5, y + 5), PALETTE["screen_dark"], PALETTE["outline"])
    line(draw, [(x + 7, y + 1), (x + 9, y + 1)], PALETTE["metal"])
    draw.point((x + 7, y + 3), fill=PALETTE["badge"])
    draw.point((x + 9, y + 3), fill=PALETTE["note_red"])
    line(draw, [(x + 3, y), (x + 3, y - 3)], PALETTE["metal"])
    if phase % 2 == 0:
        line(draw, [(x + 2, y + 3), (x + 4, y + 3)], PALETTE["screen"])
    else:
        line(draw, [(x + 2, y + 2), (x + 4, y + 2)], PALETTE["screen"])


def draw_fridge(draw: ImageDraw.ImageDraw, x: int, y: int, open_amount: int):
    rect(draw, (x, y, x + 8, y + 17), PALETTE["metal"], PALETTE["outline"])
    rect(draw, (x + 1, y + 1, x + 7, y + 7), PALETTE["metal"], None)
    rect(draw, (x + 1, y + 9, x + 7, y + 16), PALETTE["metal"], None)
    line(draw, [(x + 1, y + 8), (x + 7, y + 8)], PALETTE["outline"])
    rect(draw, (x + 6, y + 3, x + 6, y + 5), PALETTE["plastic_dark"], None)
    rect(draw, (x + 6, y + 11, x + 6, y + 13), PALETTE["plastic_dark"], None)
    if open_amount > 0:
        polygon(
            draw,
            [
                (x + 8, y + 1),
                (x + 8 + open_amount, y + 2),
                (x + 8 + open_amount, y + 16),
                (x + 8, y + 17),
            ],
            PALETTE["paper"],
            PALETTE["outline"],
        )
        rect(draw, (x + 9, y + 4, x + 9 + max(0, open_amount - 1), y + 6), with_alpha(PALETTE["screen"], 0.5), None)


def draw_notebook(draw: ImageDraw.ImageDraw, x: int, y: int, phase: int, label: str = "BLOC"):
    rect(draw, (x, y, x + 10, y + 7), PALETTE["paper"], PALETTE["outline"])
    line(draw, [(x + 2, y), (x + 2, y + 7)], PALETTE["note_red"])
    reveal = [2, 4, 6, 8, 10, 10][phase % 6]
    draw_revealed_lines(draw, [label[:4], label[4:8].strip()], x + 4, y + 1, reveal, PALETTE["marker"])


def draw_mug(draw: ImageDraw.ImageDraw, x: int, y: int, phase: int):
    rect(draw, (x, y, x + 5, y + 5), PALETTE["note_red"], PALETTE["outline"])
    rect(draw, (x + 1, y + 1, x + 4, y + 4), PALETTE["paper"], None)
    rect(draw, (x + 5, y + 2, x + 6, y + 4), PALETTE["paper"], PALETTE["outline"])
    steam_height = [0, 1, 2, 1, 2, 0][phase % 6]
    if steam_height > 0:
        line(draw, [(x + 2, y), (x + 2, y - 1 - steam_height)], PALETTE["steam"])
        line(draw, [(x + 4, y + 1), (x + 5, y - steam_height)], PALETTE["steam"])


def draw_file_stack(draw: ImageDraw.ImageDraw, x: int, y: int, phase: int):
    rect(draw, (x, y + 2, x + 8, y + 6), PALETTE["paper_dark"], PALETTE["outline"])
    rect(draw, (x + 1, y, x + 10, y + 4), PALETTE["paper"], PALETTE["outline"])
    rect(draw, (x + 4, y + 3, x + 12, y + 7), PALETTE["paper_dark"], PALETTE["outline"])
    if phase % 2 == 0:
        draw_pixel_text(draw, "MIT", x + 2, y + 1, PALETTE["marker"])
    else:
        draw_pixel_text(draw, "G3", x + 2, y + 1, PALETTE["marker"])
    draw.point((x + 10, y + 5), fill=PALETTE["note_red"])
    draw.point((x + 7, y + 1), fill=PALETTE["badge"])


def draw_side_head(draw: ImageDraw.ImageDraw, bob: int, mood: str = "neutral", tongue: int = 0, facing: str = "left"):
    """Side-view head with rounder hood, bigger face, larger eye."""
    tx = (lambda x: x) if facing == "left" else (lambda x: WORK_SIZE - 1 - x)
    pts = lambda values: [(tx(x), y) for x, y in values]

    # Ear (visible one) - graceful outward curve
    polygon(draw, pts([
        (10, 8 + bob), (8, 4 + bob), (6, 2 + bob),
        (8, 3 + bob), (11, 5 + bob), (12, 8 + bob),
    ]), PALETTE["hood"], PALETTE["outline"])
    # Main hood - rounder profile
    polygon(draw, pts([
        (9, 9 + bob),
        (10, 6 + bob),
        (13, 4 + bob),
        (17, 4 + bob),
        (20, 6 + bob),
        (21, 9 + bob),
        (21, 14 + bob),
        (20, 17 + bob),
        (17, 19 + bob),
        (13, 19 + bob),
        (10, 17 + bob),
        (9, 14 + bob),
    ]), PALETTE["hood"], PALETTE["outline"])
    # Hood shading on back half
    polygon(draw, pts([
        (16, 5 + bob), (19, 7 + bob), (20, 10 + bob),
        (20, 15 + bob), (18, 18 + bob), (16, 19 + bob),
    ]), PALETTE["hood_shade"], None)
    # Face - larger oval visible from side
    polygon(draw, pts([
        (10, 10 + bob), (12, 8 + bob), (14, 8 + bob),
        (15, 10 + bob), (15, 15 + bob), (13, 17 + bob),
        (11, 17 + bob), (10, 15 + bob),
    ]), PALETTE["face"], PALETTE["outline"])

    # Eye - bigger oval from side
    eye_x = tx(11)
    eye_x2 = tx(14)
    if mood == "angry":
        line(draw, [(min(eye_x, eye_x2), 10 + bob), (max(eye_x, eye_x2), 11 + bob)], PALETTE["angry"])
        ellipse(draw, (min(eye_x, eye_x2), 11 + bob, max(eye_x, eye_x2), 14 + bob), PALETTE["eye"])
    elif mood == "sleep":
        line(draw, [(min(eye_x, eye_x2), 12 + bob), (max(eye_x, eye_x2), 12 + bob)], PALETTE["eye"])
    else:
        ellipse(draw, (min(eye_x, eye_x2), 10 + bob, max(eye_x, eye_x2), 15 + bob), PALETTE["eye"])

    # Mouth
    smile_x = tx(12)
    smile_y = 16 + bob
    if mood == "happy":
        line(draw, [(smile_x, smile_y), (tx(13), smile_y + 1)], PALETTE["eye"])
    elif mood == "angry":
        line(draw, [(smile_x, smile_y), (tx(13), smile_y)], PALETTE["angry"])
    else:
        draw.point((smile_x, smile_y), fill=PALETTE["eye"])

    if tongue > 0:
        polygon(draw, pts([
            (14, 16 + bob),
            (17 + max(0, tongue // 2), 17 + bob),
            (20 + tongue, 19 + bob),
            (17 + max(0, tongue // 2), 21 + bob),
            (14, 19 + bob),
        ]), (255, 120, 140, 255), PALETTE["outline"])


def render_look_left_frame(i: int) -> Image.Image:
    pose = Pose(
        bob=[0, -1, 0, -1, 0, 0][i],
        lean=[0, -1, -1, -1, -1, 0][i],
        head_tilt=[0, -1, -2, -2, -1, 0][i],
        arm_left=[0, 0, -1, -1, 0, 0][i],
        arm_right=[0, 0, 1, 1, 0, 0][i],
        cape_left=[1, 2, 1, 1, 2, 1][i],
        cape_right=[1, 1, 1, 2, 1, 1][i],
        eye_shift_x=[0, -1, -1, -1, -1, 0][i],
        blink=i == 2,
    )
    return render_frame(pose)


def render_look_right_frame(i: int) -> Image.Image:
    return mirror_frame(render_look_left_frame(i))


def render_look_up_frame(i: int) -> Image.Image:
    pose = Pose(
        bob=[0, -1, -1, -1, 0, 0][i],
        head_tilt=[0, 0, 0, 0, 0, 0][i],
        arm_left=[0, 0, -1, -1, 0, 0][i],
        arm_right=[0, 0, 1, 1, 0, 0][i],
        cape_left=[1, 2, 1, 1, 2, 1][i],
        cape_right=[1, 1, 2, 2, 1, 1][i],
        eye_shift_y=[0, -1, -1, -1, -1, 0][i],
        mouth_shift=-1,
        blink=i == 2,
    )
    return render_frame(pose)


def render_look_down_frame(i: int) -> Image.Image:
    pose = Pose(
        bob=[0, 0, 1, 1, 0, 0][i],
        head_tilt=[0, 0, 0, 0, 0, 0][i],
        arm_left=[0, -1, 0, 0, -1, 0][i],
        arm_right=[0, 1, 0, 0, 1, 0][i],
        cape_left=[1, 1, 0, 0, 1, 1][i],
        cape_right=[1, 0, 1, 1, 0, 1][i],
        eye_shift_y=[0, 1, 1, 1, 1, 0][i],
        mouth_shift=1,
        blink=i == 2,
    )
    return render_frame(pose)


def render_run_left_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    step = [-3, -2, 1, 3, 2, -1][i]
    bob = [1, 0, -1, 0, 1, 0][i]
    cape = [3, 4, 5, 4, 3, 2][i]
    draw_side_pose(draw, bob, step, cape)
    return scale_frame(canvas)


def render_run_right_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    step = [-3, -2, 1, 3, 2, -1][i]
    bob = [1, 0, -1, 0, 1, 0][i]
    cape = [3, 4, 5, 4, 3, 2][i]
    draw_side_pose(draw, bob, step, cape, facing="right")
    return scale_frame(canvas)


def render_jump_side_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [2, -1, -3, 0, 2, 1][i]
    step = [-1, 0, 1, 1, 0, -1][i]
    cape = [2, 4, 5, 4, 2, 1][i]
    draw_side_pose(draw, bob, step, cape)
    if i in (1, 2, 3):
        line(draw, [(9, 9 + bob), (6, 7 + bob), (9, 6 + bob)], PALETTE["spark"])
    return scale_frame(canvas)


def render_hide_frame(i: int) -> Image.Image:
    pose = [
        Pose(bob=1, stretch=0, arm_left=0, arm_right=0, leg_left=0, leg_right=0, cape_left=1, cape_right=1, blink=False),
        Pose(bob=2, stretch=-1, arm_left=0, arm_right=0, leg_left=0, leg_right=0, cape_left=2, cape_right=2, blink=True),
        Pose(bob=3, stretch=-2, arm_left=-1, arm_right=1, leg_left=0, leg_right=0, cape_left=3, cape_right=3, blink=True, mouth_shift=1),
        Pose(bob=2, stretch=-1, arm_left=0, arm_right=0, leg_left=0, leg_right=0, cape_left=3, cape_right=3, blink=True),
        Pose(bob=1, stretch=0, arm_left=0, arm_right=0, leg_left=0, leg_right=0, cape_left=2, cape_right=2, blink=True),
        Pose(bob=0, stretch=0, arm_left=0, arm_right=0, leg_left=0, leg_right=0, cape_left=1, cape_right=1, blink=False),
    ][i]
    return render_frame(pose)


def render_climb_side_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, 1, 0, -1][i]
    rect(draw, (25, 2, 31, 31), PALETTE["metal"], PALETTE["outline"])
    for rung_y in range(5, 29, 5):
        line(draw, [(25, rung_y), (31, rung_y)], PALETTE["plastic_dark"])
    ellipse(draw, (7, 28 + bob, 23, 31 + bob), PALETTE["shadow"])
    # Cape draped behind while climbing
    polygon(draw, [
        (17, 19 + bob), (19, 24 + bob), (19, 30 + bob),
        (14, 27 + bob), (14, 19 + bob),
    ], PALETTE["cape"], PALETTE["outline"])
    polygon(draw, [
        (17, 20 + bob), (18, 25 + bob), (19, 30 + bob),
        (16, 28 + bob),
    ], PALETTE["cape_shade"], None)
    # Shirt
    polygon(draw, [
        (12, 19 + bob), (17, 19 + bob), (18, 22 + bob),
        (17, 24 + bob), (12, 24 + bob), (11, 22 + bob),
    ], PALETTE["shirt"], PALETTE["outline"])
    # Shorts
    rect(draw, (12, 24 + bob, 17, 26 + bob), PALETTE["shorts"], PALETTE["outline"])
    # Arms reaching for ladder rungs (alternating)
    rect(draw, (16, 17 + bob - (i % 2), 17, 22 + bob - (i % 2)), PALETTE["skinless"], PALETTE["outline"])
    rect(draw, (19, 20 + bob + (i % 2), 20, 25 + bob + (i % 2)), PALETTE["skinless"], PALETTE["outline"])
    # Legs
    rect(draw, (13, 26 + bob - (i % 2), 14, 28 + bob - (i % 2)), PALETTE["skinless"], PALETTE["outline"])
    rect(draw, (17, 25 + bob + (i % 2), 18, 27 + bob + (i % 2)), PALETTE["skinless"], PALETTE["outline"])
    # Shoes with white soles
    polygon(draw, [(12, 28 + bob - (i % 2)), (16, 28 + bob - (i % 2)), (17, 30 + bob - (i % 2)), (12, 30 + bob - (i % 2))], PALETTE["shoe"], PALETTE["outline"])
    polygon(draw, [(16, 27 + bob + (i % 2)), (20, 27 + bob + (i % 2)), (21, 29 + bob + (i % 2)), (16, 29 + bob + (i % 2))], PALETTE["shoe"], PALETTE["outline"])
    line(draw, [(12, 30 + bob - (i % 2)), (17, 30 + bob - (i % 2))], PALETTE["sock"])
    line(draw, [(16, 29 + bob + (i % 2)), (21, 29 + bob + (i % 2))], PALETTE["sock"])
    # Head on top
    draw_side_head(draw, bob)
    return scale_frame(canvas)


def render_climb_back_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, 1, 0, -1][i]
    # Ladder
    rect(draw, (12, 2, 20, 31), PALETTE["metal"], PALETTE["outline"])
    for rung_y in range(5, 29, 5):
        line(draw, [(12, rung_y), (20, rung_y)], PALETTE["plastic_dark"])
    ellipse(draw, (7, 28 + bob, 25, 31 + bob), PALETTE["shadow"])
    # Cape flowing behind
    polygon(draw, [
        (10, 19 + bob), (8, 24 + bob), (7, 30 + bob),
        (16, 29 + bob),
        (25, 30 + bob), (24, 24 + bob), (22, 19 + bob),
    ], PALETTE["cape"], PALETTE["outline"])
    polygon(draw, [
        (10, 20 + bob), (9, 25 + bob), (8, 30 + bob),
        (16, 29 + bob), (12, 28 + bob), (12, 20 + bob),
    ], PALETTE["cape_shade"], None)
    # Shirt
    polygon(draw, [
        (11, 19 + bob), (21, 19 + bob), (22, 21 + bob),
        (21, 24 + bob), (11, 24 + bob), (10, 21 + bob),
    ], PALETTE["shirt"], PALETTE["outline"])
    # Shorts
    rect(draw, (11, 24 + bob, 21, 27 + bob), PALETTE["shorts"], PALETTE["outline"])
    # Arms reaching for rungs (alternating)
    rect(draw, (10 + (i % 2), 17 + bob, 11 + (i % 2), 22 + bob), PALETTE["skinless"], PALETTE["outline"])
    rect(draw, (20 - (i % 2), 20 + bob, 21 - (i % 2), 25 + bob), PALETTE["skinless"], PALETTE["outline"])
    # Legs
    rect(draw, (13 + (i % 2), 27 + bob, 14 + (i % 2), 29 + bob), PALETTE["skinless"], PALETTE["outline"])
    rect(draw, (18 - (i % 2), 26 + bob, 19 - (i % 2), 28 + bob), PALETTE["skinless"], PALETTE["outline"])
    # Shoes with white soles
    polygon(draw, [(11 + (i % 2), 29 + bob), (16 + (i % 2), 29 + bob), (17 + (i % 2), 31 + bob), (11 + (i % 2), 31 + bob)], PALETTE["shoe"], PALETTE["outline"])
    polygon(draw, [(16 - (i % 2), 28 + bob), (21 - (i % 2), 28 + bob), (21 - (i % 2), 30 + bob), (16 - (i % 2), 30 + bob)], PALETTE["shoe"], PALETTE["outline"])
    line(draw, [(11 + (i % 2), 31 + bob), (17 + (i % 2), 31 + bob)], PALETTE["sock"])
    line(draw, [(16 - (i % 2), 30 + bob), (21 - (i % 2), 30 + bob)], PALETTE["sock"])
    # Hood on top - big rounded with cat ears (back view)
    polygon(draw, [
        (8, 10 + bob), (7, 7 + bob), (6, 4 + bob), (8, 3 + bob), (10, 5 + bob),
        (12, 4 + bob), (14, 3 + bob), (16, 3 + bob), (18, 3 + bob), (20, 4 + bob),
        (22, 5 + bob), (24, 3 + bob), (26, 4 + bob), (25, 7 + bob), (24, 10 + bob),
        (25, 13 + bob), (25, 16 + bob), (24, 18 + bob),
        (22, 19 + bob), (16, 20 + bob), (10, 19 + bob),
        (8, 18 + bob), (7, 16 + bob), (7, 13 + bob),
    ], PALETTE["hood"], PALETTE["outline"])
    polygon(draw, [(8, 10 + bob), (7, 5 + bob), (9, 6 + bob), (10, 10 + bob)], PALETTE["hood_shade"], None)
    polygon(draw, [(22, 10 + bob), (23, 6 + bob), (25, 5 + bob), (24, 10 + bob)], PALETTE["hood_shade"], None)
    return scale_frame(canvas)


def render_fridge_open_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 29, 31, 31), PALETTE["wood_dark"], None)
    draw_side_pose(draw, bob=[0, -1, 0, 1, 0, -1][i], step=[0, 1, 0, -1, 0, 1][i], cape=[1, 2, 2, 3, 2, 1][i])
    draw_fridge(draw, 21, 8, [0, 2, 4, 6, 4, 2][i])
    if i in (2, 3, 4):
        rect(draw, (27, 13, 29, 16), PALETTE["screen"], None)
    return scale_frame(canvas)


def draw_seated_side_pose(draw: ImageDraw.ImageDraw, bob: int, mood: str = "neutral", remote: bool = False, facing: str = "left"):
    """Seated side-view with chibi proportions."""
    tx = (lambda x: x) if facing == "left" else (lambda x: WORK_SIZE - 1 - x)
    pts = lambda values: [(tx(x), y) for x, y in values]
    ellipse(draw, (8, 28 + bob, 24, 31 + bob), PALETTE["shadow"])
    # Cape draped behind while seated
    polygon(draw, pts([
        (18, 18 + bob), (21, 23 + bob), (21, 29 + bob),
        (18, 26 + bob), (17, 19 + bob),
    ]), PALETTE["cape"], PALETTE["outline"])
    # Shirt
    polygon(draw, pts([
        (12, 19 + bob), (17, 19 + bob), (18, 22 + bob),
        (17, 24 + bob), (12, 24 + bob), (11, 22 + bob),
    ]), PALETTE["shirt"], PALETTE["outline"])
    # Shorts - seated, legs extended forward
    rect(draw, (min(tx(12), tx(17)), 24 + bob, max(tx(12), tx(17)), 26 + bob), PALETTE["shorts"], PALETTE["outline"])
    rect(draw, (min(tx(15), tx(21)), 25 + bob, max(tx(15), tx(21)), 27 + bob), PALETTE["shorts"], PALETTE["outline"])
    # Legs
    rect(draw, (min(tx(18), tx(22)), 27 + bob, max(tx(18), tx(22)), 28 + bob), PALETTE["skinless"], PALETTE["outline"])
    rect(draw, (min(tx(13), tx(16)), 27 + bob, max(tx(13), tx(16)), 28 + bob), PALETTE["skinless"], PALETTE["outline"])
    # Shoes
    polygon(draw, pts([(18, 28 + bob), (23, 28 + bob), (24, 30 + bob), (19, 30 + bob)]), PALETTE["shoe"], PALETTE["outline"])
    polygon(draw, pts([(12, 28 + bob), (17, 28 + bob), (17, 30 + bob), (12, 30 + bob)]), PALETTE["shoe"], PALETTE["outline"])
    line(draw, pts([(19, 30 + bob), (24, 30 + bob)]), PALETTE["sock"])
    line(draw, pts([(12, 30 + bob), (17, 30 + bob)]), PALETTE["sock"])
    draw_side_head(draw, bob, mood=mood, facing=facing)
    if remote:
        rect(draw, (min(tx(18), tx(22)), 21 + bob, max(tx(18), tx(22)), 22 + bob), PALETTE["marker"], PALETTE["outline"])


def draw_side_pose(draw: ImageDraw.ImageDraw, bob: int, step: int, cape: int, tongue: int = 0, laser: bool = False, facing: str = "left"):
    """Side-view full body with chibi proportions - big head, compact body."""
    tx = (lambda x: x) if facing == "left" else (lambda x: WORK_SIZE - 1 - x)
    pts = lambda values: [(tx(x), y) for x, y in values]
    fs = step if facing == "left" else -step
    rs = -step if facing == "left" else step

    # Shadow
    ellipse(draw, (8, 28 + bob, 24, 31 + bob), PALETTE["shadow"])
    # Cape - flowing behind, widening downward
    polygon(draw, pts([
        (18, 18 + bob), (20 + cape, 22 + bob),
        (21 + cape, 28 + bob), (19, 29 + bob),
        (17, 25 + bob), (17, 19 + bob),
    ]), PALETTE["cape"], PALETTE["outline"])
    # Cape shade
    polygon(draw, pts([
        (18, 20 + bob), (19 + cape, 24 + bob),
        (20 + cape, 28 + bob), (19, 29 + bob),
    ]), PALETTE["cape_shade"], None)
    # Shirt
    polygon(draw, pts([
        (12, 19 + bob), (17, 19 + bob), (18, 22 + bob),
        (17, 24 + bob), (12, 24 + bob), (11, 22 + bob),
    ]), PALETTE["shirt"], PALETTE["outline"])
    # Shorts
    rect(draw, (min(tx(12), tx(17)), 24 + bob, max(tx(12), tx(17)), 26 + bob), PALETTE["shorts"], PALETTE["outline"])
    # Legs (void black)
    rect(draw, (min(tx(13 + fs), tx(14 + fs)), 26 + bob, max(tx(13 + fs), tx(14 + fs)), 29 + bob), PALETTE["skinless"], PALETTE["outline"])
    rect(draw, (min(tx(16 + rs), tx(17 + rs)), 26 + bob, max(tx(16 + rs), tx(17 + rs)), 29 + bob), PALETTE["skinless"], PALETTE["outline"])
    # Shoes with white soles
    polygon(draw, pts([
        (11 + fs, 29 + bob), (16 + fs, 29 + bob),
        (17 + fs, 31 + bob), (11 + fs, 31 + bob),
    ]), PALETTE["shoe"], PALETTE["outline"])
    polygon(draw, pts([
        (14 + rs, 29 + bob), (19 + rs, 29 + bob),
        (19 + rs, 31 + bob), (14 + rs, 31 + bob),
    ]), PALETTE["shoe"], PALETTE["outline"])
    line(draw, pts([(11 + fs, 31 + bob), (17 + fs, 31 + bob)]), PALETTE["sock"])
    line(draw, pts([(14 + rs, 31 + bob), (19 + rs, 31 + bob)]), PALETTE["sock"])
    # Lace dots
    draw.point((tx(13 + fs), 29 + bob), fill=PALETTE["sock"])
    draw.point((tx(16 + rs), 29 + bob), fill=PALETTE["sock"])
    # Head
    draw_side_head(draw, bob, tongue=tongue, facing=facing)
    if laser:
        polygon(draw, pts([(11, 19 + bob), (4, 17 + bob), (0, 18 + bob), (0, 21 + bob), (10, 23 + bob)]), (89, 255, 110, 255), PALETTE["outline"])
        line(draw, pts([(0, 19 + bob), (-1, 19 + bob)]), PALETTE["spark"])


def render_side_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    step = [-2, -1, 1, 2, 1, -1][i]
    bob = [1, 0, -1, 0, 1, 0][i]
    cape = [1, 2, 3, 2, 1, 1][i]
    draw_side_pose(draw, bob, step, cape)
    return scale_frame(canvas)


def render_side_frame_right(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    step = [-2, -1, 1, 2, 1, -1][i]
    bob = [1, 0, -1, 0, 1, 0][i]
    cape = [1, 2, 3, 2, 1, 1][i]
    draw_side_pose(draw, bob, step, cape, facing="right")
    return scale_frame(canvas)


def mirror_frame(frame: Image.Image) -> Image.Image:
    return frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)


def render_side_idle_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, 1, 0, -1][i]
    cape = [1, 2, 1, 1, 1, 2][i]
    draw_side_pose(draw, bob, 0, cape, tongue=0)
    return scale_frame(canvas)


def render_side_idle_frame_right(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, 1, 0, -1][i]
    cape = [1, 2, 1, 1, 1, 2][i]
    draw_side_pose(draw, bob, 0, cape, tongue=0, facing="right")
    return scale_frame(canvas)


def render_front_idle_frame(i: int) -> Image.Image:
    return render_frame(
        Pose(
            bob=[0, -1, -1, 0, 1, 0][i],
            head_tilt=[0, -1, 0, 1, 0, -1][i],
            arm_left=[0, 0, -1, -1, 0, 1][i],
            arm_right=[0, 0, 1, 1, 0, -1][i],
            cape_left=[1, 1, 2, 1, 1, 1][i],
            cape_right=[1, 1, 1, 2, 1, 1][i],
            blink=i in (2, 3),
        )
    )


def render_front_walk_frame(i: int) -> Image.Image:
    step = [-2, -1, 1, 2, 1, -1][i]
    bob = [0, -1, 0, 1, 0, -1][i]
    return render_frame(
        Pose(
            bob=bob,
            arm_left=[-2, -1, 1, 2, 1, -1][i],
            arm_right=[2, 1, -1, -2, -1, 1][i],
            leg_left=step,
            leg_right=-step,
            shoe_left=step,
            shoe_right=-step,
            cape_left=[1, 2, 3, 2, 1, 1][i],
            cape_right=[1, 1, 1, 3, 2, 1][i],
        )
    )


def _draw_back_view(draw: ImageDraw.ImageDraw, bob: int, step: int):
    """Back-view character with chibi proportions - big rounded hood, prominent cape."""
    b = bob
    # Shadow
    ellipse(draw, (7, 29 + b, 25, 31 + b), PALETTE["shadow"])
    # Cape - large flowing behind, with shade
    polygon(draw, [
        (10, 19 + b), (8, 24 + b), (7, 30 + b),
        (16, 29 + b),
        (25, 30 + b), (24, 24 + b), (22, 19 + b),
    ], PALETTE["cape"], PALETTE["outline"])
    polygon(draw, [
        (10, 20 + b), (9, 25 + b), (8, 30 + b),
        (16, 29 + b), (13, 28 + b), (12, 20 + b),
    ], PALETTE["cape_shade"], None)
    polygon(draw, [
        (22, 20 + b), (20, 20 + b), (19, 28 + b),
        (16, 29 + b), (24, 30 + b), (23, 25 + b),
    ], PALETTE["cape_shade"], None)
    # Shirt
    polygon(draw, [
        (11, 19 + b), (21, 19 + b), (22, 21 + b),
        (21, 24 + b), (11, 24 + b), (10, 21 + b),
    ], PALETTE["shirt"], PALETTE["outline"])
    rect(draw, (12, 21 + b, 20, 24 + b), PALETTE["shirt_shade"], None)
    # Shorts
    rect(draw, (11, 24 + b, 21, 27 + b), PALETTE["shorts"], PALETTE["outline"])
    rect(draw, (11, 25 + b, 21, 27 + b), PALETTE["shorts_shade"], None)
    # Legs
    rect(draw, (13 + step, 27 + b, 14 + step, 29 + b), PALETTE["skinless"], PALETTE["outline"])
    rect(draw, (18 - step, 27 + b, 19 - step, 29 + b), PALETTE["skinless"], PALETTE["outline"])
    # Shoes with white soles and lace dots
    polygon(draw, [(11 + step, 29 + b), (16 + step, 29 + b), (17 + step, 31 + b), (11 + step, 31 + b)], PALETTE["shoe"], PALETTE["outline"])
    polygon(draw, [(16 - step, 29 + b), (21 - step, 29 + b), (21 - step, 31 + b), (15 - step, 31 + b)], PALETTE["shoe"], PALETTE["outline"])
    line(draw, [(11 + step, 31 + b), (17 + step, 31 + b)], PALETTE["sock"])
    line(draw, [(15 - step, 31 + b), (21 - step, 31 + b)], PALETTE["sock"])
    draw.point((13 + step, 29 + b), fill=PALETTE["sock"])
    draw.point((19 - step, 29 + b), fill=PALETTE["sock"])
    # Hood - big rounded with cat ears (back view, no face)
    polygon(draw, [
        (8, 10 + b), (7, 7 + b), (6, 4 + b), (8, 3 + b), (10, 5 + b),
        (12, 4 + b), (14, 3 + b), (16, 3 + b), (18, 3 + b), (20, 4 + b),
        (22, 5 + b), (24, 3 + b), (26, 4 + b), (25, 7 + b), (24, 10 + b),
        (25, 13 + b), (25, 16 + b), (24, 18 + b),
        (22, 19 + b), (16, 20 + b), (10, 19 + b),
        (8, 18 + b), (7, 16 + b), (7, 13 + b),
    ], PALETTE["hood"], PALETTE["outline"])
    # Hood ear shading
    polygon(draw, [(8, 10 + b), (7, 5 + b), (9, 6 + b), (10, 10 + b)], PALETTE["hood_shade"], None)
    polygon(draw, [(22, 10 + b), (23, 6 + b), (25, 5 + b), (24, 10 + b)], PALETTE["hood_shade"], None)


def render_back_walk_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, 1, 0, -1][i]
    step = [-1, 0, 1, 0, -1, 0][i]
    _draw_back_view(draw, bob, step)
    return scale_frame(canvas)


def render_back_idle_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, 1, 0, -1][i]
    step = [0, 0, 1, 0, -1, 0][i]
    _draw_back_view(draw, bob, step)
    return scale_frame(canvas)


def render_drop_frame(i: int) -> Image.Image:
    pose = [
        Pose(bob=-2, stretch=2, arm_left=-1, arm_right=1, cape_left=3, cape_right=3, mouth_shift=1),
        Pose(bob=-1, stretch=1, arm_left=-2, arm_right=2, cape_left=4, cape_right=4, mouth_shift=1),
        Pose(bob=0, stretch=0, arm_left=-2, arm_right=2, cape_left=5, cape_right=5, mouth_shift=1),
        Pose(bob=1, stretch=-1, arm_left=-1, arm_right=1, leg_left=1, leg_right=-1, cape_left=5, cape_right=5, mouth_shift=1),
        Pose(bob=2, stretch=-2, arm_left=0, arm_right=0, leg_left=1, leg_right=-1, cape_left=3, cape_right=3),
        Pose(bob=2, stretch=-2, arm_left=0, arm_right=0, leg_left=1, leg_right=-1, cape_left=2, cape_right=2),
    ][i]
    return render_frame(pose)


def render_flutter_frame(i: int) -> Image.Image:
    flutter = [0, 2, 4, 2, 0, -1][i]
    return render_frame(
        Pose(
            bob=[0, -1, 0, 1, 0, -1][i],
            head_tilt=[-1, 0, 1, 0, -1, 0][i],
            cape_left=flutter,
            cape_right=max(0, 4 - flutter),
            aura=i in (1, 2, 3),
        )
    )


def render_tongue_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw_side_pose(draw, bob=[0, -1, 0, -1, 0, -1][i], step=0, cape=1, tongue=[6, 7, 8, 9, 8, 7][i])
    line(draw, [(25, 19), (29, 21), (24, 23)], (255, 120, 140, 255), 2)
    return scale_frame(canvas)


def render_laser_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw_side_pose(draw, bob=[0, -1, 0, 1, 0, -1][i], step=[0, 1, 0, -1, 0, 1][i], cape=2, laser=True)
    if i >= 2:
        line(draw, [(30, 20), (31, 18), (31, 22)], PALETTE["spark"])
        line(draw, [(31, 20), (31, 20)], (120, 255, 160, 255), 3)
    return scale_frame(canvas)


def render_portal_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    phase = [0.25, 0.5, 0.8, 1.0, 0.8, 0.5][i]
    draw_portal(draw, phase)
    if i < 4:
        alpha = [1.0, 0.95, 0.8, 0.5][i]
        frame = render_frame(Pose(bob=[0, -1, 0, 1][min(i, 3)], cape_left=1 + i, cape_right=1, aura=i > 1))
        if alpha < 1.0:
            frame = frame.copy()
            frame.putalpha(frame.getchannel("A").point(lambda px: int(px * alpha)))
        canvas.alpha_composite(frame.resize((WORK_SIZE, WORK_SIZE), Image.Resampling.NEAREST), (0, 0))
    return scale_frame(canvas)


def render_vanish_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    if i < 4:
        alpha = [1.0, 0.75, 0.45, 0.2][i]
        frame = render_frame(Pose(bob=[0, -1, 0, 1][i], cape_left=1, cape_right=1))
        frame = frame.resize((WORK_SIZE, WORK_SIZE), Image.Resampling.NEAREST)
        frame.putalpha(frame.getchannel("A").point(lambda px: int(px * alpha)))
        canvas.alpha_composite(frame, (0, 0))
    draw_smoke(draw, [0.25, 0.55, 0.8, 1.0, 0.9, 0.75][i])
    return scale_frame(canvas)


def render_sleep_lie_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, 1, 0, 1, 0, 1][i]
    b = bob
    # Shadow
    ellipse(draw, (6, 25 + b, 26, 29 + b), PALETTE["shadow"])
    # Cape - draped beneath/behind while lying down
    polygon(draw, [
        (4, 19 + b), (9, 13 + b), (17, 11 + b), (24, 14 + b),
        (28, 19 + b), (26, 24 + b), (7, 24 + b),
    ], PALETTE["cape"], PALETTE["outline"])
    polygon(draw, [
        (5, 20 + b), (9, 15 + b), (14, 13 + b),
        (10, 16 + b), (8, 22 + b), (7, 24 + b),
    ], PALETTE["cape_shade"], None)
    # Hood - big rounded, lying on side with visible ear
    polygon(draw, [
        (8, 17 + b), (11, 13 + b), (14, 11 + b),
        (16, 10 + b),  # Ear tip
        (18, 11 + b), (22, 13 + b), (24, 16 + b),
        (25, 19 + b), (24, 22 + b),
        (20, 23 + b), (12, 23 + b),
        (9, 22 + b), (7, 19 + b),
    ], PALETTE["hood"], PALETTE["outline"])
    polygon(draw, [(14, 11 + b), (16, 10 + b), (17, 12 + b), (15, 13 + b)], PALETTE["hood_shade"], None)
    # Face - large oval, lying flat
    ellipse(draw, (10, 15 + b, 22, 22 + b), PALETTE["face"], PALETTE["outline"])
    # Eyes - closed (sleeping), horizontal lines
    line(draw, [(12, 18 + b), (15, 18 + b)], PALETTE["eye"])
    line(draw, [(17, 18 + b), (20, 18 + b)], PALETTE["eye"])
    # Subtle sleeping smile
    line(draw, [(15, 20 + b), (16, 21 + b), (17, 20 + b)], PALETTE["eye"])
    # Shirt - horizontal body
    rect(draw, (7, 22 + b, 16, 25 + b), PALETTE["shirt"], PALETTE["outline"])
    rect(draw, (8, 23 + b, 15, 25 + b), PALETTE["shirt_shade"], None)
    # Shorts
    rect(draw, (16, 22 + b, 21, 25 + b), PALETTE["shorts"], PALETTE["outline"])
    # Leg
    rect(draw, (21, 23 + b, 23, 24 + b), PALETTE["skinless"], PALETTE["outline"])
    # Shoe with white sole
    polygon(draw, [(23, 22 + b), (26, 22 + b), (27, 25 + b), (23, 25 + b)], PALETTE["shoe"], PALETTE["outline"])
    line(draw, [(23, 25 + b), (27, 25 + b)], PALETTE["sock"])
    # Zzz floating above
    if i in (1, 3, 5):
        line(draw, [(24, 8 + b), (26, 8 + b), (24, 10 + b), (26, 10 + b)], PALETTE["sleep"])
        line(draw, [(27, 5 + b), (29, 5 + b), (27, 7 + b), (29, 7 + b)], PALETTE["sleep"])
    return scale_frame(canvas)


def render_graffiti_bloc_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (18, 4, 31, 28), PALETTE["paper"], PALETTE["outline"])
    rect(draw, (18, 28, 31, 31), PALETTE["wood"], PALETTE["outline"])
    reveal = [0, 4, 8, 11, 15, 15][i]
    draw_revealed_lines(draw, ["LONG", "LIVE", "THE", "BLOC"], 20, 6, reveal, PALETTE["marker"])
    draw_side_pose(draw, bob=[0, -1, 0, 1, 0, -1][i], step=0, cape=[1, 2, 1, 1, 2, 1][i])
    draw_marker(draw, 18, 21 + [0, 0, 1, 1, 0, 0][i], diagonal=True)
    line(draw, [(17, 22 + [0, 0, 1, 1, 0, 0][i]), (19, 20 + [0, 0, 1, 1, 0, 0][i])], PALETTE["marker"])
    if i == 5:
        line(draw, [(8, 6), (11, 4), (13, 6)], PALETTE["spark"])
    return scale_frame(canvas)


def render_graffiti_was_here_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (17, 6, 31, 29), PALETTE["paper_dark"], PALETTE["outline"])
    reveal = [0, 4, 7, 11, 11, 11][i]
    draw_revealed_lines(draw, ["GBOY", "WAS", "HERE"], 19, 9, reveal, PALETTE["marker"])
    draw_side_pose(draw, bob=[0, -1, 0, 1, 0, -1][i], step=[0, 0, 1, 0, 0, -1][i], cape=1 + (i % 2))
    draw_marker(draw, 18, 22 + (i % 2), diagonal=True)
    if i >= 4:
        line(draw, [(24, 26), (29, 27)], PALETTE["marker"])
    return scale_frame(canvas)


def render_tv_flip_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 29, 31, 31), PALETTE["wood_dark"], None)
    draw_seated_side_pose(draw, bob=[0, 1, 0, 1, 0, 1][i], mood="happy" if i in (2, 4) else "neutral", remote=True)
    draw_crt(draw, 1, 13, i)
    if i in (1, 3, 5):
        line(draw, [(16, 21), (12, 19)], PALETTE["screen"])
    return scale_frame(canvas)


def render_handheld_game_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 29, 31, 31), PALETTE["wood_dark"], None)
    mood = "angry" if i in (2, 3) else "happy"
    draw_seated_side_pose(draw, bob=[0, 1, 0, 1, 0, 1][i], mood=mood)
    draw_handheld_device(draw, 17, 22, i)
    line(draw, [(18, 22), (15, 21)], PALETTE["marker"])
    line(draw, [(27, 20), (29, 18), (28, 21)], PALETTE["spark"])
    if i in (2, 3):
        line(draw, [(12, 10), (15, 9)], PALETTE["angry"])
    return scale_frame(canvas)


def render_cook_meal_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 28, 31, 31), PALETTE["wood_dark"], None)
    draw_side_pose(draw, bob=[0, -1, 0, 1, 0, -1][i], step=[0, 0, 1, 0, -1, 0][i], cape=[1, 2, 3, 2, 1, 2][i])
    draw_burner(draw, 1, 21, flame=i in (1, 2, 3, 4))
    draw_pan(draw, 1, 20, toss=[0, 1, 3, 2, 1, 0][i])
    line(draw, [(17, 22), (12, 21)], PALETTE["marker"])
    if i in (2, 3, 4):
        line(draw, [(5, 16), (6, 13)], PALETTE["steam"])
    return scale_frame(canvas)


def render_noodle_eat_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 29, 31, 31), PALETTE["wood_dark"], None)
    draw_seated_side_pose(draw, bob=[0, 1, 0, 1, 0, 1][i], mood="happy" if i not in (2,) else "angry")
    draw_bowl(draw, 7, 24, slurp=[0, 1, 3, 4, 2, 0][i])
    line(draw, [(17, 21), (12, 23)], PALETTE["marker"])
    line(draw, [(18, 21), (12, 18)], PALETTE["marker"])
    if i in (2, 3):
        line(draw, [(12, 21), (13, 19), (14, 17)], PALETTE["paper_dark"])
    return scale_frame(canvas)


def render_evidence_hack_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 28, 31, 31), PALETTE["wood_dark"], None)
    draw_evidence_board(draw, 0, 4, i)
    draw_terminal(draw, 8, 22, i)
    draw_side_pose(draw, bob=[0, -1, 0, 1, 0, -1][i], step=0, cape=[2, 3, 2, 1, 2, 3][i], laser=False)
    line(draw, [(17, 20), (10, 14)], PALETTE["marker"])
    if i in (1, 3, 5):
        line(draw, [(6, 6), (8, 5), (10, 6)], PALETTE["screen"])
    return scale_frame(canvas)


def render_computer_idle_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 29, 31, 31), PALETTE["wood_dark"], None)
    rect(draw, (0, 20, 16, 22), PALETTE["wood"], PALETTE["outline"])
    rect(draw, (2, 13, 13, 20), PALETTE["plastic"], PALETTE["outline"])
    rect(draw, (3, 14, 12, 19), PALETTE["screen_dark"], PALETTE["outline"])
    if i in (0, 3):
        draw_pixel_text(draw, "SJ", 5, 15, PALETTE["screen"])
    elif i in (1, 4):
        draw_pixel_text(draw, "G3", 5, 15, PALETTE["screen"])
    else:
        line(draw, [(4, 16), (11, 16)], PALETTE["screen"])
    rect(draw, (5, 20, 9, 20), PALETTE["plastic_dark"], None)
    draw_seated_side_pose(draw, bob=[0, 1, 0, 1, 0, 1][i], mood="neutral" if i not in (2, 5) else "happy")
    line(draw, [(17, 22), (12, 21)], PALETTE["marker"])
    line(draw, [(16, 21), (11, 20)], PALETTE["marker"])
    if i in (2, 5):
        line(draw, [(10, 8), (12, 7), (14, 8)], PALETTE["screen"])
    return scale_frame(canvas)


def render_terminal_type_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 29, 31, 31), PALETTE["wood_dark"], None)
    rect(draw, (0, 20, 16, 22), PALETTE["wood"], PALETTE["outline"])
    draw_terminal(draw, 2, 13, i)
    draw_seated_side_pose(draw, bob=[0, 1, 0, 1, 0, 1][i], mood="happy" if i in (2, 5) else "neutral")
    line(draw, [(17, 22), (11, 21)], PALETTE["marker"])
    line(draw, [(16, 21), (10, 20)], PALETTE["marker"])
    if i in (1, 3, 5):
        line(draw, [(8, 10), (10, 9), (11, 11)], PALETTE["screen"])
    return scale_frame(canvas)


def render_crt_watch_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 29, 31, 31), PALETTE["wood_dark"], None)
    draw_seated_side_pose(draw, bob=[0, 1, 0, 1, 0, 1][i], mood="neutral")
    draw_crt(draw, 1, 12, [0, 0, 1, 1, 4, 5][i])
    if i in (2, 4):
        line(draw, [(16, 21), (12, 19)], PALETTE["screen"])
    return scale_frame(canvas)


def render_radio_listen_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 29, 31, 31), PALETTE["wood_dark"], None)
    draw_seated_side_pose(draw, bob=[0, 1, 0, 1, 0, 1][i], mood="angry" if i in (2, 4) else "neutral")
    draw_radio(draw, 2, 19, i)
    line(draw, [(17, 20), (12, 20)], PALETTE["marker"])
    if i in (1, 3, 5):
        line(draw, [(5, 16), (7, 15), (9, 16)], PALETTE["screen"])
    return scale_frame(canvas)


def render_desk_noodle_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 29, 31, 31), PALETTE["wood_dark"], None)
    rect(draw, (0, 20, 16, 22), PALETTE["wood"], PALETTE["outline"])
    rect(draw, (2, 13, 13, 20), PALETTE["plastic"], PALETTE["outline"])
    rect(draw, (3, 14, 12, 19), PALETTE["screen_dark"], PALETTE["outline"])
    draw_bowl(draw, 6, 24, slurp=[0, 1, 2, 4, 3, 1][i])
    draw_seated_side_pose(draw, bob=[0, 1, 0, 1, 0, 1][i], mood="happy" if i not in (2,) else "angry")
    line(draw, [(17, 21), (12, 23)], PALETTE["marker"])
    line(draw, [(18, 21), (12, 18)], PALETTE["marker"])
    if i in (2, 3):
        line(draw, [(12, 21), (13, 19), (14, 17)], PALETTE["paper_dark"])
    return scale_frame(canvas)


def render_desk_sketch_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 29, 31, 31), PALETTE["wood_dark"], None)
    rect(draw, (0, 20, 16, 22), PALETTE["wood"], PALETTE["outline"])
    draw_notebook(draw, 2, 13, i, "BLOC")
    draw_marker(draw, 12, 20 + [0, 0, 1, 1, 0, 0][i], diagonal=True)
    draw_seated_side_pose(draw, bob=[0, 1, 0, 1, 0, 1][i], mood="happy" if i in (2, 4) else "neutral")
    line(draw, [(17, 22), (13, 20 + [0, 0, 1, 1, 0, 0][i])], PALETTE["marker"])
    if i in (1, 3, 5):
        line(draw, [(10, 11), (12, 10), (13, 11)], PALETTE["spark"])
    return scale_frame(canvas)


def render_file_sort_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 29, 31, 31), PALETTE["wood_dark"], None)
    rect(draw, (0, 20, 16, 22), PALETTE["wood"], PALETTE["outline"])
    draw_file_stack(draw, 2 + [0, 1, 0, 1, 0, 1][i], 13, i)
    rect(draw, (9, 15, 15, 19), PALETTE["paper"], PALETTE["outline"])
    if i in (2, 3, 4):
        draw_pixel_text(draw, "G304", 10, 16, PALETTE["marker"])
    else:
        draw_pixel_text(draw, "SJ", 11, 16, PALETTE["marker"])
    draw_seated_side_pose(draw, bob=[0, 1, 0, 1, 0, 1][i], mood="neutral")
    line(draw, [(17, 22), (12, 19 + [0, 1, 0, 1, 0, 1][i])], PALETTE["marker"])
    line(draw, [(16, 21), (10, 22)], PALETTE["marker"])
    return scale_frame(canvas)


def render_mug_sip_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 29, 31, 31), PALETTE["wood_dark"], None)
    rect(draw, (0, 20, 16, 22), PALETTE["wood"], PALETTE["outline"])
    draw_mug(draw, 6, 15 + [1, 0, 0, 1, 0, 1][i], i)
    rect(draw, (1, 13, 4, 19), PALETTE["plastic_dark"], PALETTE["outline"])
    draw_seated_side_pose(draw, bob=[0, 1, 0, 1, 0, 1][i], mood="happy" if i in (1, 4) else "neutral")
    line(draw, [(17, 21), (12, 18 + [1, 0, 0, 1, 0, 1][i])], PALETTE["marker"])
    if i in (2, 5):
        line(draw, [(10, 11), (12, 9), (13, 11)], PALETTE["steam"])
    return scale_frame(canvas)


def render_file_scan_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 28, 31, 31), PALETTE["wood_dark"], None)
    draw_evidence_board(draw, 0, 5, i)
    rect(draw, (8, 22, 16, 26), PALETTE["paper"], PALETTE["outline"])
    draw_pixel_text(draw, "CASE", 9, 23, PALETTE["marker"])
    draw_side_pose(draw, bob=[0, -1, 0, 1, 0, -1][i], step=[0, 1, 0, -1, 0, 1][i], cape=[2, 3, 2, 2, 1, 2][i])
    rect(draw, (17, 20, 21, 22), PALETTE["metal"], PALETTE["outline"])
    line(draw, [(17, 21), (10, 24)], PALETTE["marker"])
    if i in (1, 3, 5):
        line(draw, [(6, 8), (8, 7), (10, 8)], PALETTE["screen"])
    return scale_frame(canvas)


def render_zine_read_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 29, 31, 31), PALETTE["wood_dark"], None)
    rect(draw, (0, 20, 16, 22), PALETTE["wood"], PALETTE["outline"])
    draw_notebook(draw, 3, 14, i, "LONG")
    draw_mug(draw, 0, 15 + [1, 0, 1, 0, 1, 0][i], i)
    draw_seated_side_pose(draw, bob=[0, 1, 0, 1, 0, 1][i], mood="neutral" if i not in (2, 4) else "happy")
    line(draw, [(17, 21), (12, 18 + [1, 0, 1, 0, 1, 0][i])], PALETTE["marker"])
    line(draw, [(16, 22), (12, 20)], PALETTE["marker"])
    if i in (2, 5):
        line(draw, [(9, 11), (11, 10), (13, 11)], PALETTE["spark"])
    return scale_frame(canvas)


def render_pinboard_plot_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 28, 31, 31), PALETTE["wood_dark"], None)
    draw_evidence_board(draw, 0, 4, i)
    rect(draw, (10, 7, 15, 11), PALETTE["paper"], PALETTE["outline"])
    draw_pixel_text(draw, "BLOC", 1, 17, PALETTE["marker"])
    draw_side_pose(draw, bob=[0, -1, 0, 1, 0, -1][i], step=[0, 0, 1, 0, -1, 0][i], cape=[2, 3, 2, 1, 2, 3][i])
    draw_marker(draw, 17, 21 + [0, 0, 1, 1, 0, 0][i], diagonal=True)
    line(draw, [(17, 21 + [0, 0, 1, 1, 0, 0][i]), (9, 10)], PALETTE["hood"])
    if i in (1, 3, 5):
        line(draw, [(7, 6), (9, 5), (10, 7)], PALETTE["screen"])
    return scale_frame(canvas)


def render_monitor_lurk_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 29, 31, 31), PALETTE["wood_dark"], None)
    rect(draw, (0, 20, 16, 22), PALETTE["wood"], PALETTE["outline"])
    rect(draw, (2, 12, 13, 20), PALETTE["plastic"], PALETTE["outline"])
    rect(draw, (3, 13, 12, 19), PALETTE["screen_dark"], PALETTE["outline"])
    draw_pixel_text(draw, ["G3", "SJ", "WATCH", "LOG", "G304", "SAFE"][i], 4, 14, PALETTE["screen"])
    draw_mug(draw, 0, 15 + [0, 1, 0, 1, 0, 1][i], i)
    draw_seated_side_pose(draw, bob=[0, 1, 0, 1, 0, 1][i], mood="neutral")
    line(draw, [(17, 22), (12, 21)], PALETTE["marker"])
    line(draw, [(16, 21), (10, 20)], PALETTE["marker"])
    if i in (2, 3, 4):
        line(draw, [(10, 9), (12, 8), (14, 9)], PALETTE["screen"])
    return scale_frame(canvas)


def scale_frame(img: Image.Image) -> Image.Image:
    return img.resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.NEAREST)


def render_frame(pose: Pose) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw_body(canvas, pose)
    return scale_frame(canvas)


def idle_pose(i: int) -> Pose:
    bob = [0, -1, -1, 0, 1, 1, 0, -1][i]
    return Pose(
        bob=bob,
        head_tilt=[0, -1, 0, 1, 0, -1, 0, 1][i],
        arm_left=[0, 0, -1, -1, 0, 0, 1, 1][i],
        arm_right=[0, 0, 1, 1, 0, 0, -1, -1][i],
        cape_left=[1, 2, 2, 1, 0, 0, 1, 2][i],
        cape_right=[2, 1, 0, 0, 1, 2, 2, 1][i],
        blink=i in (2, 3),
    )


def run_pose(i: int) -> Pose:
    steps = [-2, -1, 0, 2, 2, 0, -1, -2]
    arm = [2, 1, 0, -2, -2, 0, 1, 2]
    bob = [1, 0, -1, 0, 1, 0, -1, 0][i]
    return Pose(
        bob=bob,
        lean=[-1, -1, 0, 1, 1, 1, 0, -1][i],
        head_tilt=[-1, 0, 1, 1, 0, -1, -1, 0][i],
        arm_left=-arm[i],
        arm_right=arm[i],
        leg_left=steps[i],
        leg_right=-steps[i],
        shoe_left=steps[i],
        shoe_right=-steps[i],
        cape_left=max(1, arm[i] + 1),
        cape_right=max(1, -arm[i] + 1),
        mouth_shift=-1,
    )


def jump_pose(i: int) -> Pose:
    return [
        Pose(bob=1, stretch=-1, arm_left=1, arm_right=-1, leg_left=-1, leg_right=1, cape_left=1, cape_right=1),
        Pose(bob=0, stretch=0, arm_left=0, arm_right=0, leg_left=0, leg_right=0, cape_left=2, cape_right=2),
        Pose(bob=0, stretch=1, arm_left=0, arm_right=0, leg_left=0, leg_right=0, cape_left=2, cape_right=2, aura=True),
        Pose(bob=-1, stretch=2, arm_left=-1, arm_right=1, leg_left=1, leg_right=-1, cape_left=2, cape_right=1),
        Pose(bob=0, stretch=1, arm_left=-1, arm_right=1, leg_left=0, leg_right=0, cape_left=1, cape_right=1),
        Pose(bob=0, stretch=0, arm_left=0, arm_right=0, leg_left=0, leg_right=0, cape_left=1, cape_right=1),
    ][i]


def fall_pose(i: int) -> Pose:
    return [
        Pose(bob=-1, stretch=1, arm_left=-1, arm_right=1, leg_left=0, leg_right=0, cape_left=2, cape_right=2),
        Pose(bob=0, stretch=0, arm_left=-1, arm_right=1, leg_left=0, leg_right=0, cape_left=2, cape_right=2),
        Pose(bob=0, stretch=0, arm_left=-2, arm_right=2, leg_left=0, leg_right=0, cape_left=2, cape_right=2, mouth_shift=1),
        Pose(bob=1, stretch=-1, arm_left=-2, arm_right=2, leg_left=1, leg_right=-1, cape_left=3, cape_right=3, mouth_shift=1),
        Pose(bob=1, stretch=-1, arm_left=-1, arm_right=1, leg_left=1, leg_right=-1, cape_left=2, cape_right=2, mouth_shift=1),
        Pose(bob=1, stretch=-1, arm_left=-1, arm_right=1, leg_left=0, leg_right=0, cape_left=2, cape_right=2),
    ][i]


def dash_pose(i: int) -> Pose:
    lean = [2, 3, 4, 3][i]
    return Pose(
        bob=0,
        lean=lean,
        head_tilt=1,
        stretch=1,
        arm_left=-2,
        arm_right=2,
        leg_left=-2,
        leg_right=1,
        shoe_left=-2,
        shoe_right=1,
        cape_left=4 + i,
        cape_right=0,
        aura=True,
        mouth_shift=-1,
    )


def attack_pose(i: int) -> Pose:
    return [
        Pose(bob=1, arm_right=0, arm_left=0, cape_left=0, cape_right=0),
        Pose(bob=0, lean=1, arm_right=1, arm_left=-1, cape_left=1, cape_right=0),
        Pose(bob=-1, lean=2, arm_right=3, arm_left=-2, leg_left=-1, leg_right=1, shoe_left=-1, shoe_right=1, cape_left=1, cape_right=0, aura=True),
        Pose(bob=0, lean=2, arm_right=4, arm_left=-2, cape_left=2, cape_right=0, aura=True, mouth_shift=-1),
        Pose(bob=1, lean=1, arm_right=2, arm_left=-1, cape_left=1, cape_right=0),
        Pose(bob=0, lean=0, arm_right=0, arm_left=0, cape_left=0, cape_right=0, blink=True),
    ][i]


def wallslide_pose(i: int) -> Pose:
    return [
        Pose(bob=0, lean=-1, head_tilt=-1, arm_left=-2, arm_right=1, leg_left=-1, leg_right=1, cape_left=1, cape_right=2),
        Pose(bob=1, lean=-1, head_tilt=-1, arm_left=-2, arm_right=1, leg_left=0, leg_right=1, cape_left=1, cape_right=2),
        Pose(bob=0, lean=-1, head_tilt=0, arm_left=-2, arm_right=1, leg_left=-1, leg_right=1, cape_left=2, cape_right=2),
        Pose(bob=1, lean=-1, head_tilt=0, arm_left=-2, arm_right=1, leg_left=0, leg_right=1, cape_left=2, cape_right=2),
    ][i]


def happy_pose(i: int) -> Pose:
    return Pose(
        bob=[0, -1, -1, 0, -1, 0][i],
        head_tilt=[-1, 0, 1, 0, -1, 0][i],
        arm_left=[-1, -2, -1, 0, -1, 0][i],
        arm_right=[1, 2, 1, 0, 1, 0][i],
        cape_left=[0, 1, 0, -1, 0, 1][i],
        cape_right=[-1, 0, 1, 0, -1, 0][i],
        emotion="happy",
        aura=i in (1, 2, 4),
    )


def angry_pose(i: int) -> Pose:
    stomp = [0, 1, 0, -1, 0, 1][i]
    return Pose(
        bob=stomp,
        lean=[0, 1, 0, -1, 0, 1][i],
        arm_left=[1, 1, 0, 0, 1, 0][i],
        arm_right=[-1, -1, 0, 0, -1, 0][i],
        leg_left=[0, 1, 0, -1, 0, 1][i],
        leg_right=[0, -1, 0, 1, 0, -1][i],
        shoe_left=[0, 1, 0, -1, 0, 1][i],
        shoe_right=[0, -1, 0, 1, 0, -1][i],
        cape_left=1,
        cape_right=1,
        emotion="angry",
        mouth_shift=1,
    )


def cry_pose(i: int) -> Pose:
    return Pose(
        bob=[0, 1, 0, 1, 0, 1][i],
        head_tilt=[0, -1, 0, -1, 0, -1][i],
        arm_left=[0, -1, 0, -1, 0, -1][i],
        arm_right=[0, 1, 0, 1, 0, 1][i],
        cape_left=1,
        cape_right=1,
        emotion="cry",
        blink=i in (1, 3, 5),
        mouth_shift=1,
    )


def eat_pose(i: int) -> Pose:
    return Pose(
        bob=[0, -1, 0, -1, 0, 0][i],
        head_tilt=[0, 1, 0, 1, 0, 0][i],
        arm_left=0,
        arm_right=[1, 2, 2, 1, 1, 0][i],
        cape_left=0,
        cape_right=1,
        emotion="eat",
        item="snack",
        blink=i in (2, 5),
    )


def sleep_pose(i: int) -> Pose:
    return Pose(
        bob=[1, 1, 2, 2, 1, 1][i],
        stretch=-1,
        arm_left=1,
        arm_right=-1,
        leg_left=0,
        leg_right=0,
        cape_left=0,
        cape_right=0,
        emotion="sleep",
        item="zzz" if i in (1, 3, 5) else None,
        blink=True,
        mouth_shift=1,
    )


def render_stretch_frame(i: int) -> Image.Image:
    return render_frame(
        Pose(
            bob=[0, -1, -2, -1, 0, 1][i],
            stretch=[0, 1, 2, 2, 1, 0][i],
            arm_left=[-1, -2, -3, -3, -2, -1][i],
            arm_right=[1, 2, 3, 3, 2, 1][i],
            cape_left=[1, 2, 1, 2, 1, 1][i],
            cape_right=[1, 1, 2, 1, 2, 1][i],
            emotion="sleep" if i in (2, 3) else "neutral",
            mouth_shift=-1,
        )
    )


def render_sneak_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, 0, -1, -1, 0, 0, -1, -1][i]
    step = [-1, 0, 1, 0, -1, 0, 1, 0][i]
    cape = 1
    crouch = 2
    draw_side_pose(draw, bob + crouch, step, cape)
    return scale_frame(canvas)


def render_glitch_frame(i: int) -> Image.Image:
    rng = random.Random(i * 42)
    base = render_frame(Pose(bob=rng.randint(-1, 1), head_tilt=rng.randint(-1, 1)))
    work = base.resize((WORK_SIZE, WORK_SIZE), Image.Resampling.NEAREST)
    draw = ImageDraw.Draw(work)
    if i % 2 == 0:
        for _ in range(3):
            sy = rng.randint(0, WORK_SIZE - 2)
            shift = rng.randint(1, 3)
            strip = work.crop((0, sy, WORK_SIZE, sy + 1))
            work.paste(strip, (shift, sy))
    else:
        glitch_colors = [PALETTE["spark"], PALETTE["screen"], PALETTE["hood"]]
        for _ in range(4):
            gy = rng.randint(0, WORK_SIZE - 1)
            gx0 = rng.randint(0, WORK_SIZE - 4)
            gx1 = gx0 + rng.randint(2, 6)
            line(draw, [(gx0, gy), (min(gx1, WORK_SIZE - 1), gy)], rng.choice(glitch_colors))
    return scale_frame(work)


def render_sit_cross_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, 1, 0, -1][i]
    tilt = [0, -1, 0, 1, 0, -1][i]
    ground = 29 + bob
    torso_top = 17 + bob
    ellipse(draw, (6, ground + 1, 26, ground + 4), PALETTE["shadow"])
    polygon(draw, [(12, 18 + bob), (9, 24 + bob), (8, 30 + bob), (13, 26 + bob), (14, 19 + bob)], PALETTE["cape"], PALETTE["outline"])
    polygon(draw, [(20, 19 + bob), (19, 26 + bob), (24, 30 + bob), (23, 24 + bob), (20, 18 + bob)], PALETTE["cape"], PALETTE["outline"])
    rect(draw, (11, torso_top + 2, 12, torso_top + 6), PALETTE["skinless"], PALETTE["outline"])
    rect(draw, (20, torso_top + 2, 21, torso_top + 6), PALETTE["skinless"], PALETTE["outline"])
    polygon(draw, [(10, torso_top + 1), (22, torso_top + 1), (23, torso_top + 3), (22, torso_top + 7), (16, torso_top + 8), (10, torso_top + 7), (9, torso_top + 3)], PALETTE["shirt"], PALETTE["outline"])
    rect(draw, (11, torso_top + 5, 21, torso_top + 7), PALETTE["shirt_shade"], None)
    rect(draw, (11, torso_top + 7, 21, torso_top + 9), PALETTE["shorts"], PALETTE["outline"])
    polygon(draw, [(10, torso_top + 9), (16, torso_top + 10), (22, torso_top + 9), (20, torso_top + 12), (12, torso_top + 12)], PALETTE["skinless"], PALETTE["outline"])
    polygon(draw, [(10, torso_top + 11), (15, torso_top + 13), (11, torso_top + 13)], PALETTE["shoe"], PALETTE["outline"])
    polygon(draw, [(22, torso_top + 11), (17, torso_top + 13), (21, torso_top + 13)], PALETTE["shoe"], PALETTE["outline"])
    polygon(draw, hood_points(tilt, bob), PALETTE["hood"], PALETTE["outline"])
    polygon(draw, [(9 + tilt, 9 + bob), (7 + tilt, 4 + bob), (10 + tilt, 6 + bob), (11 + tilt, 11 + bob)], PALETTE["hood_shade"], None)
    polygon(draw, [(21 + tilt, 11 + bob), (22 + tilt, 6 + bob), (25 + tilt, 4 + bob), (23 + tilt, 9 + bob)], PALETTE["hood_shade"], None)
    draw_face(draw, Pose(bob=bob, head_tilt=tilt))
    return scale_frame(canvas)


def render_wall_sit_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, 1, 0, 1, 0, 1][i]
    mood = "happy" if i in (2, 4) else "neutral"
    rect(draw, (27, 4, 31, 31), PALETTE["metal"], PALETTE["outline"])
    draw_seated_side_pose(draw, bob, mood=mood, facing="right")
    return scale_frame(canvas)


def render_peek_left_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    offsets = [24, 20, 18, 18, 20, 24]
    ox = offsets[i]
    bob = [0, -1, 0, -1, 0, 0][i]
    draw_side_head(draw, bob, mood="neutral", facing="left")
    head_canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    hd = ImageDraw.Draw(head_canvas)
    draw_side_head(hd, bob, mood="neutral", facing="left")
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    canvas.paste(head_canvas, (ox, 0))
    return scale_frame(canvas)


def render_peek_right_frame(i: int) -> Image.Image:
    return mirror_frame(render_peek_left_frame(i))


def render_confused_frame(i: int) -> Image.Image:
    canvas_img = render_frame(
        Pose(
            bob=[0, 0, -1, 0, 0, 1][i],
            head_tilt=[-1, 0, 1, 0, -1, 0][i],
            arm_left=[0, 0, -1, 0, 0, 0][i],
            arm_right=[0, 0, 1, 0, 0, 0][i],
            cape_left=[1, 1, 1, 1, 1, 1][i],
            cape_right=[1, 1, 1, 1, 1, 1][i],
            blink=i == 3,
        )
    )
    work = canvas_img.resize((WORK_SIZE, WORK_SIZE), Image.Resampling.NEAREST)
    draw = ImageDraw.Draw(work)
    qmark_bob = [0, 0, -1, 0, 0, 1][i]
    qx, qy = 15, 1 + qmark_bob
    draw.point((qx, qy), fill=PALETTE["spark"])
    draw.point((qx + 1, qy), fill=PALETTE["spark"])
    draw.point((qx + 1, qy + 1), fill=PALETTE["spark"])
    draw.point((qx, qy + 2), fill=PALETTE["spark"])
    draw.point((qx, qy + 4), fill=PALETTE["spark"])
    return scale_frame(work)


def render_bored_frame(i: int) -> Image.Image:
    emotion = ["neutral", "neutral", "sleep", "sleep", "neutral", "neutral"][i]
    frame = render_frame(
        Pose(
            bob=[0, 0, 1, 1, 0, 0][i],
            head_tilt=[0, -1, 0, 1, 0, -1][i],
            arm_left=[1, 1, 2, 2, 1, 1][i],
            arm_right=[-1, -1, -2, -2, -1, -1][i],
            cape_left=[0, 0, 0, 0, 0, 0][i],
            cape_right=[0, 0, 0, 0, 0, 0][i],
            emotion=emotion,
        )
    )
    if i in (3, 4):
        work = frame.resize((WORK_SIZE, WORK_SIZE), Image.Resampling.NEAREST)
        draw = ImageDraw.Draw(work)
        puff_y = 16
        line(draw, [(23, puff_y), (25, puff_y - 1), (27, puff_y)], PALETTE["steam"])
        frame = scale_frame(work)
    return frame


def render_wave_frame(i: int) -> Image.Image:
    arm_r = [0, -1, -3, -4, -3, -1][i]
    frame = render_frame(
        Pose(
            bob=[0, -1, -1, 0, 0, 0][i],
            head_tilt=[0, 0, 1, 0, -1, 0][i],
            arm_left=[0, 0, 0, 0, 0, 0][i],
            arm_right=arm_r,
            cape_left=[1, 1, 1, 1, 1, 1][i],
            cape_right=[1, 1, 2, 2, 1, 1][i],
            emotion="happy",
        )
    )
    work = frame.resize((WORK_SIZE, WORK_SIZE), Image.Resampling.NEAREST)
    draw = ImageDraw.Draw(work)
    hand_y = 17 + [0, -1, -1, 0, 0, 0][i] + min(0, arm_r)
    hand_x = 21 + arm_r
    rect(draw, (hand_x, hand_y, hand_x + 1, hand_y + 1), PALETTE["face"], PALETTE["outline"])
    return scale_frame(work)


def render_yawn_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, 0, -1, 0, 1, 0][i]
    draw_side_pose(draw, bob, step=0, cape=1)
    mouth_open = [0, 1, 2, 3, 2, 0][i]
    if mouth_open > 0:
        mx, my = 12, 17 + bob
        rect(draw, (mx - 1, my, mx + mouth_open, my + mouth_open), PALETTE["face"], PALETTE["outline"])
    return scale_frame(canvas)


def render_stumble_frame(i: int) -> Image.Image:
    return render_frame(
        Pose(
            bob=[0, 0, -1, 0, 1, 0][i],
            lean=[0, 1, 2, 3, 2, 0][i],
            head_tilt=[0, 1, -1, 2, -1, 0][i],
            arm_left=[0, -1, -2, -3, -1, 0][i],
            arm_right=[0, 2, 1, 3, 2, 0][i],
            leg_left=[0, 1, 1, 2, 1, 0][i],
            leg_right=[0, -1, 0, -1, 0, 0][i],
            shoe_left=[0, 1, 1, 2, 1, 0][i],
            shoe_right=[0, -1, 0, -1, 0, 0][i],
            cape_left=[1, 2, 3, 4, 3, 1][i],
            cape_right=[1, 0, 0, 0, 0, 1][i],
            mouth_shift=1,
        )
    )


def render_dance_frame(i: int) -> Image.Image:
    return render_frame(
        Pose(
            bob=[0, -1, 0, -2, 0, -1, 0, -2][i],
            head_tilt=[-1, 1, -1, 1, -1, 1, -1, 1][i],
            arm_left=[-2, 0, -3, 0, -2, 0, -3, 0][i],
            arm_right=[2, 0, 3, 0, 2, 0, 3, 0][i],
            leg_left=[-1, 1, -1, 1, -1, 1, -1, 1][i],
            leg_right=[1, -1, 1, -1, 1, -1, 1, -1][i],
            shoe_left=[-1, 1, -1, 1, -1, 1, -1, 1][i],
            shoe_right=[1, -1, 1, -1, 1, -1, 1, -1][i],
            cape_left=[2, 0, 3, 1, 2, 0, 3, 1][i],
            cape_right=[0, 2, 1, 3, 0, 2, 1, 3][i],
            emotion="happy",
            aura=i in (3, 7),
        )
    )


def render_spray_tag_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    rect(draw, (0, 4, 5, 31), PALETTE["paper_dark"], PALETTE["outline"])
    bob = [0, -1, 0, 1, 0, -1][i]
    draw_side_pose(draw, bob, step=0, cape=[1, 2, 1, 1, 2, 1][i])
    can_x, can_y = 11, 19 + bob
    rect(draw, (can_x, can_y, can_x + 2, can_y + 3), PALETTE["hood"], PALETTE["outline"])
    draw.point((can_x + 1, can_y - 1), fill=PALETTE["metal"])
    paint_dots = [(3, 10), (4, 12), (2, 14), (4, 16), (3, 18)]
    for dx, dy in paint_dots[:min(i + 1, 5)]:
        draw.point((dx, dy), fill=PALETTE["hood"])
    if i >= 2:
        line(draw, [(can_x, can_y), (5, can_y - 2)], with_alpha(PALETTE["hood"], 0.5))
    return scale_frame(canvas)


def render_bug_sweep_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, 1, 0, -1][i]
    draw_side_pose(draw, bob, step=[0, 1, 0, -1, 0, 1][i], cape=[1, 2, 1, 1, 2, 1][i])
    dev_x, dev_y = 10, 20 + bob
    rect(draw, (dev_x, dev_y, dev_x + 5, dev_y + 3), PALETTE["plastic"], PALETTE["outline"])
    rect(draw, (dev_x + 1, dev_y + 1, dev_x + 4, dev_y + 2), PALETTE["screen_dark"], PALETTE["outline"])
    if i % 2 == 0:
        draw.point((dev_x + 2, dev_y + 1), fill=PALETTE["screen"])
    else:
        draw.point((dev_x + 3, dev_y + 1), fill=PALETTE["screen"])
    line(draw, [(dev_x + 5, dev_y + 1), (dev_x + 7, dev_y)], PALETTE["metal"])
    return scale_frame(canvas)


def render_blanket_nest_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, 1, 0, 1, 0, 1][i]
    tilt = [0, -1, 0, 1, 0, -1][i]
    ellipse(draw, (6, 28 + bob, 26, 31 + bob), PALETTE["shadow"])
    polygon(draw, [(7, 17 + bob), (25, 17 + bob), (27, 22 + bob), (28, 30 + bob), (4, 30 + bob), (5, 22 + bob)], PALETTE["cape"], PALETTE["outline"])
    polygon(draw, [(8, 18 + bob), (24, 18 + bob), (26, 22 + bob), (27, 29 + bob), (5, 29 + bob), (6, 22 + bob)], PALETTE["cape_shade"], None)
    polygon(draw, hood_points(tilt, bob - 4), PALETTE["hood"], PALETTE["outline"])
    polygon(draw, [(9 + tilt, 5 + bob), (7 + tilt, 0 + bob), (10 + tilt, 2 + bob), (11 + tilt, 7 + bob)], PALETTE["hood_shade"], None)
    polygon(draw, [(21 + tilt, 7 + bob), (22 + tilt, 2 + bob), (25 + tilt, 0 + bob), (23 + tilt, 5 + bob)], PALETTE["hood_shade"], None)
    draw_face(draw, Pose(bob=bob - 4, head_tilt=tilt, emotion="sleep", blink=True))
    return scale_frame(canvas)


def render_skateboard_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, -1, 0, -1, 0, -1][i]
    step = [-1, 0, 1, 0, -1, 0, 1, 0][i]
    cape = [2, 3, 4, 3, 2, 3, 4, 3][i]
    board_y = 28
    rect(draw, (8, board_y, 24, board_y + 1), PALETTE["wood"], PALETTE["outline"])
    draw.point((9, board_y + 2), fill=PALETTE["outline"])
    draw.point((23, board_y + 2), fill=PALETTE["outline"])
    ellipse(draw, (7, board_y + 2, 10, board_y + 3), PALETTE["metal"], PALETTE["outline"])
    ellipse(draw, (22, board_y + 2, 25, board_y + 3), PALETTE["metal"], PALETTE["outline"])
    draw_side_pose(draw, bob - 2, step, cape)
    return scale_frame(canvas)


def render_headjack_frame(i: int) -> Image.Image:
    frame = render_frame(
        Pose(
            bob=[0, -1, -1, 0, 0, 0][i],
            head_tilt=[0, 0, 0, 0, 0, 0][i],
            arm_left=[-2, -3, -3, -3, -2, -1][i],
            arm_right=[2, 3, 3, 3, 2, 1][i],
            cape_left=[1, 2, 2, 2, 1, 1][i],
            cape_right=[1, 2, 2, 2, 1, 1][i],
            aura=True,
        )
    )
    work = frame.resize((WORK_SIZE, WORK_SIZE), Image.Resampling.NEAREST)
    draw = ImageDraw.Draw(work)
    bob = [0, -1, -1, 0, 0, 0][i]
    if i >= 1:
        energy_len = min(i, 4)
        line(draw, [(7, 5 + bob), (5, 3 + bob - energy_len)], PALETTE["spark"])
        line(draw, [(25, 5 + bob), (27, 3 + bob - energy_len)], PALETTE["spark"])
        line(draw, [(16, 3 + bob), (16, 1 + bob - energy_len)], PALETTE["screen"])
    return scale_frame(work)


def render_sticker_slap_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, 1, 0, -1][i]
    draw_side_pose(draw, bob, step=[0, 1, 2, 1, 0, -1][i], cape=[1, 2, 1, 1, 2, 1][i])
    rect(draw, (0, 4, 5, 31), PALETTE["paper_dark"], PALETTE["outline"])
    sticker_positions = [(2, 8), (1, 14), (3, 20), (2, 26)]
    for si, (sx, sy) in enumerate(sticker_positions):
        if i > si:
            color = [PALETTE["hood"], PALETTE["badge"], PALETTE["screen"], PALETTE["note_red"]][si]
            rect(draw, (sx, sy, sx + 2, sy + 2), color, PALETTE["outline"])
    if i in (1, 2, 3, 4):
        arm_reach = [0, 2, 4, 2, 0, 0][i]
        line(draw, [(13, 20 + bob), (13 - arm_reach, 20 + bob)], PALETTE["marker"])
    return scale_frame(canvas)


def render_throne_frame(i: int) -> Image.Image:
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, 1, 0, -1][i]
    rect(draw, (6, 2, 26, 31), PALETTE["wood_dark"], PALETTE["outline"])
    rect(draw, (7, 3, 25, 14), PALETTE["wood"], PALETTE["outline"])
    polygon(draw, [(6, 2), (8, 0), (10, 2)], PALETTE["badge"], PALETTE["outline"])
    polygon(draw, [(22, 2), (24, 0), (26, 2)], PALETTE["badge"], PALETTE["outline"])
    polygon(draw, [(14, 2), (16, 0), (18, 2)], PALETTE["badge"], PALETTE["outline"])
    rect(draw, (7, 15, 10, 30), PALETTE["wood"], PALETTE["outline"])
    rect(draw, (22, 15, 25, 30), PALETTE["wood"], PALETTE["outline"])
    tilt = [0, -1, 0, 1, 0, -1][i]
    emotion = "happy" if i in (0, 2, 4) else "neutral"
    torso_top = 14 + bob
    ellipse(draw, (8, 28 + bob, 24, 31 + bob), PALETTE["shadow"])
    polygon(draw, [(12, 14 + bob), (9, 20 + bob), (8, 26 + bob), (13, 22 + bob), (14, 15 + bob)], PALETTE["cape"], PALETTE["outline"])
    polygon(draw, [(20, 15 + bob), (19, 22 + bob), (24, 26 + bob), (23, 20 + bob), (20, 14 + bob)], PALETTE["cape"], PALETTE["outline"])
    rect(draw, (11, torso_top + 2, 12, torso_top + 6), PALETTE["skinless"], PALETTE["outline"])
    rect(draw, (20, torso_top + 2, 21, torso_top + 6), PALETTE["skinless"], PALETTE["outline"])
    polygon(draw, [(10, torso_top + 1), (22, torso_top + 1), (23, torso_top + 3), (22, torso_top + 7), (16, torso_top + 8), (10, torso_top + 7), (9, torso_top + 3)], PALETTE["shirt"], PALETTE["outline"])
    rect(draw, (11, torso_top + 7, 21, torso_top + 9), PALETTE["shorts"], PALETTE["outline"])
    rect(draw, (13, torso_top + 9, 14, torso_top + 12), PALETTE["skinless"], PALETTE["outline"])
    rect(draw, (18, torso_top + 9, 19, torso_top + 12), PALETTE["skinless"], PALETTE["outline"])
    polygon(draw, [(11, torso_top + 12), (15, torso_top + 12), (17, torso_top + 14), (11, torso_top + 14)], PALETTE["shoe"], PALETTE["outline"])
    polygon(draw, [(17, torso_top + 12), (21, torso_top + 12), (23, torso_top + 14), (17, torso_top + 14)], PALETTE["shoe"], PALETTE["outline"])
    polygon(draw, hood_points(tilt, bob - 4), PALETTE["hood"], PALETTE["outline"])
    polygon(draw, [(9 + tilt, 5 + bob), (7 + tilt, 0 + bob), (10 + tilt, 2 + bob), (11 + tilt, 7 + bob)], PALETTE["hood_shade"], None)
    polygon(draw, [(21 + tilt, 7 + bob), (22 + tilt, 2 + bob), (25 + tilt, 0 + bob), (23 + tilt, 5 + bob)], PALETTE["hood_shade"], None)
    draw_face(draw, Pose(bob=bob - 4, head_tilt=tilt, emotion=emotion))
    return scale_frame(canvas)


def render_spin_frame(i: int) -> Image.Image:
    """8-frame spin: front, front-left, side, back-left, back, back-right, side-right, front-right."""
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, -1, 0, -1, 0, -1][i]
    if i in (0, 7, 1):
        # Front-facing frames
        tilt = [-1, 0, 1, 0, -1, 0, 1, 0][i]
        return render_frame(Pose(bob=bob, head_tilt=tilt, cape_left=[2, 3, 4, 3, 2, 3, 4, 3][i], cape_right=[4, 3, 2, 3, 4, 3, 2, 3][i], emotion="happy"))
    elif i in (2, 6):
        # Side-facing
        facing = "left" if i == 2 else "right"
        draw_side_pose(draw, bob, step=[0, 1, 0, -1, 0, 1, 0, -1][i], cape=[3, 4, 3, 4, 3, 4, 3, 4][i], facing=facing)
        return scale_frame(canvas)
    else:
        # Back-facing
        step = [0, 0, 0, -1, 0, 1, 0, 0][i]
        _draw_back_view(draw, bob, step)
        return scale_frame(canvas)


def render_tantrum_frame(i: int) -> Image.Image:
    """8-frame tantrum: stomping, flailing arms, angry face."""
    stomp = [0, -2, 0, -2, 0, -2, 0, -2][i]
    return render_frame(
        Pose(
            bob=[0, -2, 1, -2, 1, -2, 0, -1][i],
            head_tilt=[-2, 2, -2, 2, -2, 2, -1, 1][i],
            arm_left=[-3, 1, -4, 2, -3, 1, -2, 0][i],
            arm_right=[3, -1, 4, -2, 3, -1, 2, 0][i],
            leg_left=[0, 2, 0, 2, 0, 2, 0, 1][i],
            leg_right=[0, -2, 0, -2, 0, -2, 0, -1][i],
            shoe_left=[0, 2, 0, 2, 0, 2, 0, 1][i],
            shoe_right=[0, -2, 0, -2, 0, -2, 0, -1][i],
            cape_left=[3, 1, 4, 1, 3, 1, 2, 1][i],
            cape_right=[1, 3, 1, 4, 1, 3, 1, 2][i],
            emotion="angry",
            mouth_shift=[0, 1, 0, 1, 0, 1, 0, 0][i],
        )
    )


def render_float_frame(i: int) -> Image.Image:
    """8-frame levitation: hovering with billowing cape and sparkle aura."""
    lift = [0, -1, -2, -3, -3, -2, -1, 0][i]
    return render_frame(
        Pose(
            bob=lift,
            stretch=[0, 1, 1, 2, 2, 1, 1, 0][i],
            arm_left=[0, -1, -2, -2, -2, -1, 0, 0][i],
            arm_right=[0, 1, 2, 2, 2, 1, 0, 0][i],
            cape_left=[2, 3, 4, 5, 5, 4, 3, 2][i],
            cape_right=[2, 3, 4, 5, 5, 4, 3, 2][i],
            aura=True,
        )
    )


def render_shiver_frame(i: int) -> Image.Image:
    """8-frame shiver: rapid tiny trembling."""
    shake = [-1, 1, -1, 1, -1, 1, -1, 0][i]
    return render_frame(
        Pose(
            bob=[0, 0, 0, 0, 0, 0, 0, 0][i],
            lean=shake,
            head_tilt=[-shake, shake, -shake, shake, -shake, shake, 0, 0][i],
            arm_left=[1, 0, 1, 0, 1, 0, 1, 0][i],
            arm_right=[-1, 0, -1, 0, -1, 0, -1, 0][i],
            cape_left=[0, 1, 0, 1, 0, 1, 0, 0][i],
            cape_right=[0, 1, 0, 1, 0, 1, 0, 0][i],
            emotion="cry",
        )
    )


def render_applaud_frame(i: int) -> Image.Image:
    """8-frame clapping/applause."""
    clap = [0, 0, 1, 0, 0, 0, 1, 0][i]  # 1 = hands together
    return render_frame(
        Pose(
            bob=[0, -1, 0, -1, 0, -1, 0, -1][i],
            head_tilt=[0, 1, 0, -1, 0, 1, 0, -1][i],
            arm_left=[-2, -1, 0, -1, -2, -1, 0, -1][i],
            arm_right=[2, 1, 0, 1, 2, 1, 0, 1][i],
            cape_left=[1, 1, 1, 1, 1, 1, 1, 1][i],
            cape_right=[1, 1, 1, 1, 1, 1, 1, 1][i],
            emotion="happy",
            aura=clap == 1,
        )
    )


def render_dizzy_frame(i: int) -> Image.Image:
    """8-frame dizzy: wobbling with stars circling head."""
    frame = render_frame(
        Pose(
            bob=[0, 1, 0, -1, 0, 1, 0, -1][i],
            lean=[1, 2, 1, 0, -1, -2, -1, 0][i],
            head_tilt=[1, 2, 1, 0, -1, -2, -1, 0][i],
            arm_left=[1, 2, 1, 0, -1, -2, -1, 0][i],
            arm_right=[-1, -2, -1, 0, 1, 2, 1, 0][i],
            cape_left=[1, 2, 3, 2, 1, 0, 1, 2][i],
            cape_right=[3, 2, 1, 0, 1, 2, 3, 2][i],
        )
    )
    work = frame.resize((WORK_SIZE, WORK_SIZE), Image.Resampling.NEAREST)
    draw = ImageDraw.Draw(work)
    # Orbiting stars
    angle = (i / 8.0) * math.pi * 2
    for offset in range(3):
        a = angle + offset * (math.pi * 2 / 3)
        sx = int(16 + math.cos(a) * 8)
        sy = int(4 + math.sin(a) * 3)
        if 0 <= sx < WORK_SIZE and 0 <= sy < WORK_SIZE:
            draw.point((sx, sy), fill=PALETTE["spark"])
            if sx + 1 < WORK_SIZE:
                draw.point((sx + 1, sy), fill=PALETTE["badge"])
    return scale_frame(work)


def render_bow_frame(i: int) -> Image.Image:
    """8-frame curtain call bow."""
    lean_amt = [0, 1, 3, 5, 5, 3, 1, 0][i]
    return render_frame(
        Pose(
            bob=[0, 0, 1, 2, 2, 1, 0, 0][i],
            lean=0,
            stretch=[-lean_amt // 2, -lean_amt, -lean_amt, -lean_amt, -lean_amt, -lean_amt, -lean_amt // 2, 0][i],
            head_tilt=[0, 1, 2, 3, 3, 2, 1, 0][i],
            arm_left=[0, 1, 2, 3, 3, 2, 1, 0][i],
            arm_right=[0, -1, -2, -3, -3, -2, -1, 0][i],
            cape_left=[1, 2, 3, 4, 4, 3, 2, 1][i],
            cape_right=[1, 2, 3, 4, 4, 3, 2, 1][i],
            emotion="happy",
        )
    )


def render_moonwalk_frame(i: int) -> Image.Image:
    """8-frame moonwalk - sliding backward with smooth leg motion."""
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, -1, 0, -1, 0, -1][i]
    step = [2, 1, 0, -1, -2, -1, 0, 1][i]
    cape = [1, 2, 3, 2, 1, 2, 3, 2][i]
    draw_side_pose(draw, bob, step, cape, facing="right")
    return scale_frame(canvas)


def render_backflip_frame(i: int) -> Image.Image:
    """8-frame backflip - dramatic aerial rotation."""
    if i <= 1:
        # Crouch and launch
        return render_frame(
            Pose(
                bob=[1, -2][i],
                stretch=[-1, 2][i],
                arm_left=[0, -3][i],
                arm_right=[0, 3][i],
                cape_left=[1, 3][i],
                cape_right=[1, 3][i],
            )
        )
    elif i <= 5:
        # Airborne rotation - use side views at different heights
        canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
        draw = ImageDraw.Draw(canvas)
        lift = [0, 0, -4, -6, -5, -3, 0, 0][i]
        # Rotate the character by drawing at different orientations
        if i == 2:
            draw_side_pose(draw, lift, step=0, cape=5)
        elif i == 3:
            _draw_back_view(draw, lift, 0)
        elif i == 4:
            draw_side_pose(draw, lift, step=0, cape=5, facing="right")
        else:
            _draw_back_view(draw, lift, 0)
        return scale_frame(canvas)
    else:
        # Landing
        return render_frame(
            Pose(
                bob=[0, 0, 0, 0, 0, 0, 1, 0][i],
                stretch=[0, 0, 0, 0, 0, 0, -1, 0][i],
                leg_left=[0, 0, 0, 0, 0, 0, 1, 0][i],
                leg_right=[0, 0, 0, 0, 0, 0, -1, 0][i],
                cape_left=[0, 0, 0, 0, 0, 0, 4, 2][i],
                cape_right=[0, 0, 0, 0, 0, 0, 4, 2][i],
                aura=i == 7,
                emotion="happy",
            )
        )


def render_typing_fast_frame(i: int) -> Image.Image:
    """8-frame intense typing at keyboard - arms flailing on keys."""
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, -1, 0, -1, 0, -1][i]
    # Desk
    rect(draw, (0, 22, 31, 24), PALETTE["wood"], PALETTE["outline"])
    # Keyboard
    rect(draw, (2, 20, 14, 22), PALETTE["plastic"], PALETTE["outline"])
    # Key presses
    key_x = [4, 8, 6, 10, 3, 9, 5, 11][i]
    draw.point((key_x, 21), fill=PALETTE["screen"])
    draw.point((key_x + 1, 21), fill=PALETTE["screen"])
    # Monitor
    draw_crt(draw, 17, 8, i % 3)
    # Character seated, typing
    draw_seated_side_pose(draw, bob, mood="neutral" if i % 3 else "happy", facing="right")
    return scale_frame(canvas)


def render_phone_call_frame(i: int) -> Image.Image:
    """8-frame phone call - holding phone to ear, pacing."""
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, 1, 0, -1, 0, 1][i]
    step = [0, 1, 0, -1, 0, 1, 0, -1][i]
    cape = [1, 2, 1, 1, 1, 2, 1, 1][i]
    draw_side_pose(draw, bob, step, cape)
    # Phone held up to ear
    rect(draw, (8, 9 + bob, 10, 13 + bob), PALETTE["plastic"], PALETTE["outline"])
    draw.point((9, 10 + bob), fill=PALETTE["screen"])
    # Speech indicator
    if i in (1, 3, 5, 7):
        line(draw, [(7, 10 + bob), (5, 9 + bob)], PALETTE["spark"])
        draw.point((4, 8 + bob), fill=PALETTE["spark"])
    return scale_frame(canvas)


def render_umbrella_frame(i: int) -> Image.Image:
    """8-frame walking with umbrella - rain drops falling."""
    canvas = Image.new("RGBA", (WORK_SIZE, WORK_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, -1, 0, -1, 0, -1][i]
    step = [-1, 0, 1, 0, -1, 0, 1, 0][i]
    draw_side_pose(draw, bob, step, cape=1)
    # Umbrella above
    polygon(draw, [
        (5, 4 + bob), (16, 1 + bob), (27, 4 + bob),
        (25, 6 + bob), (16, 5 + bob), (7, 6 + bob),
    ], PALETTE["hood"], PALETTE["outline"])
    # Handle
    line(draw, [(16, 5 + bob), (16, 10 + bob)], PALETTE["wood"])
    # Rain drops
    rain_offsets = [(3, 8), (10, 6), (20, 7), (28, 5), (6, 3), (25, 2), (14, 4), (31, 6)]
    for ri in range(4):
        rx, ry = rain_offsets[(i + ri) % len(rain_offsets)]
        ry_drop = (ry + i * 3 + ri * 5) % 32
        if ry_drop > 6 + bob:
            line(draw, [(rx, ry_drop), (rx, ry_drop + 2)], PALETTE["sleep"])
    return scale_frame(canvas)


ANIMATIONS = {
    "idle": {"frames": 8, "builder": idle_pose, "speed": 8.0, "loop": True, "sheet": "idle"},
    "run": {"frames": 8, "builder": run_pose, "speed": 12.0, "loop": True, "sheet": "run"},
    "jump": {"frames": 6, "builder": jump_pose, "speed": 8.0, "loop": False, "sheet": "jump"},
    "fall": {"frames": 6, "builder": fall_pose, "speed": 8.0, "loop": True, "sheet": "fall"},
    "dash": {"frames": 4, "builder": dash_pose, "speed": 16.0, "loop": False, "sheet": "dash"},
    "attack": {"frames": 6, "builder": attack_pose, "speed": 14.0, "loop": False, "sheet": "attack"},
    "wall_slide": {"frames": 4, "builder": wallslide_pose, "speed": 8.0, "loop": True, "sheet": "wallslide"},
    "happy": {"frames": 6, "builder": happy_pose, "speed": 8.0, "loop": True, "sheet": "happy"},
    "angry": {"frames": 6, "builder": angry_pose, "speed": 7.0, "loop": True, "sheet": "angry"},
    "cry": {"frames": 6, "builder": cry_pose, "speed": 6.0, "loop": True, "sheet": "cry"},
    "eat": {"frames": 6, "builder": eat_pose, "speed": 6.0, "loop": True, "sheet": "eat"},
    "sleep": {"frames": 6, "builder": sleep_pose, "speed": 3.0, "loop": True, "sheet": "sleep"},
    "walk_side": {"frames": 6, "builder": render_side_frame, "speed": 10.0, "loop": True, "sheet": "walk_side"},
    "walk_front": {"frames": 6, "builder": render_front_walk_frame, "speed": 10.0, "loop": True, "sheet": "walk_front"},
    "walk_back": {"frames": 6, "builder": render_back_walk_frame, "speed": 10.0, "loop": True, "sheet": "walk_back"},
    "drop": {"frames": 6, "builder": render_drop_frame, "speed": 10.0, "loop": False, "sheet": "drop"},
    "cape_flutter": {"frames": 6, "builder": render_flutter_frame, "speed": 10.0, "loop": True, "sheet": "cape_flutter"},
    "tongue": {"frames": 6, "builder": render_tongue_frame, "speed": 8.0, "loop": True, "sheet": "tongue"},
    "laser": {"frames": 6, "builder": render_laser_frame, "speed": 10.0, "loop": False, "sheet": "laser"},
    "portal": {"frames": 6, "builder": render_portal_frame, "speed": 10.0, "loop": False, "sheet": "portal"},
    "vanish": {"frames": 6, "builder": render_vanish_frame, "speed": 10.0, "loop": False, "sheet": "vanish"},
    "sleep_lie": {"frames": 6, "builder": render_sleep_lie_frame, "speed": 3.0, "loop": True, "sheet": "sleep_lie"},
    "idle_front": {"frames": 6, "builder": render_front_idle_frame, "speed": 8.0, "loop": True, "sheet": "idle_front"},
    "idle_back": {"frames": 6, "builder": render_back_idle_frame, "speed": 8.0, "loop": True, "sheet": "idle_back"},
    "idle_left": {"frames": 6, "builder": render_side_idle_frame, "speed": 8.0, "loop": True, "sheet": "idle_left"},
    "idle_right": {"frames": 6, "builder": render_side_idle_frame_right, "speed": 8.0, "loop": True, "sheet": "idle_right"},
    "walk_left": {"frames": 6, "builder": render_side_frame, "speed": 10.0, "loop": True, "sheet": "walk_left"},
    "walk_right": {"frames": 6, "builder": render_side_frame_right, "speed": 10.0, "loop": True, "sheet": "walk_right"},
    "run_left": {"frames": 6, "builder": render_run_left_frame, "speed": 12.0, "loop": True, "sheet": "run_left"},
    "run_right": {"frames": 6, "builder": render_run_right_frame, "speed": 12.0, "loop": True, "sheet": "run_right"},
    "jump_side": {"frames": 6, "builder": render_jump_side_frame, "speed": 10.0, "loop": False, "sheet": "jump_side"},
    "hide": {"frames": 6, "builder": render_hide_frame, "speed": 8.0, "loop": False, "sheet": "hide"},
    "climb_side": {"frames": 6, "builder": render_climb_side_frame, "speed": 9.0, "loop": True, "sheet": "climb_side"},
    "climb_right": {"frames": 6, "builder": lambda i: render_climb_side_frame(i).transpose(Image.Transpose.FLIP_LEFT_RIGHT), "speed": 9.0, "loop": True, "sheet": "climb_right"},
    "climb_back": {"frames": 6, "builder": render_climb_back_frame, "speed": 9.0, "loop": True, "sheet": "climb_back"},
    "look_left": {"frames": 6, "builder": render_look_left_frame, "speed": 10.0, "loop": False, "sheet": "look_left"},
    "look_right": {"frames": 6, "builder": render_look_right_frame, "speed": 10.0, "loop": False, "sheet": "look_right"},
    "look_up": {"frames": 6, "builder": render_look_up_frame, "speed": 10.0, "loop": False, "sheet": "look_up"},
    "look_down": {"frames": 6, "builder": render_look_down_frame, "speed": 10.0, "loop": False, "sheet": "look_down"},
    "graffiti_bloc": {"frames": 6, "builder": render_graffiti_bloc_frame, "speed": 8.0, "loop": False, "sheet": "graffiti_bloc"},
    "graffiti_was_here": {"frames": 6, "builder": render_graffiti_was_here_frame, "speed": 8.0, "loop": False, "sheet": "graffiti_was_here"},
    "tv_flip": {"frames": 6, "builder": render_tv_flip_frame, "speed": 8.0, "loop": True, "sheet": "tv_flip"},
    "handheld_game": {"frames": 6, "builder": render_handheld_game_frame, "speed": 8.0, "loop": True, "sheet": "handheld_game"},
    "cook_meal": {"frames": 6, "builder": render_cook_meal_frame, "speed": 8.0, "loop": True, "sheet": "cook_meal"},
    "noodle_eat": {"frames": 6, "builder": render_noodle_eat_frame, "speed": 8.0, "loop": True, "sheet": "noodle_eat"},
    "evidence_hack": {"frames": 6, "builder": render_evidence_hack_frame, "speed": 8.0, "loop": True, "sheet": "evidence_hack"},
    "computer_idle": {"frames": 6, "builder": render_computer_idle_frame, "speed": 8.0, "loop": True, "sheet": "computer_idle"},
    "terminal_type": {"frames": 6, "builder": render_terminal_type_frame, "speed": 8.0, "loop": True, "sheet": "terminal_type"},
    "crt_watch": {"frames": 6, "builder": render_crt_watch_frame, "speed": 8.0, "loop": True, "sheet": "crt_watch"},
    "radio_listen": {"frames": 6, "builder": render_radio_listen_frame, "speed": 8.0, "loop": True, "sheet": "radio_listen"},
    "desk_noodles": {"frames": 6, "builder": render_desk_noodle_frame, "speed": 8.0, "loop": True, "sheet": "desk_noodles"},
    "desk_sketch": {"frames": 6, "builder": render_desk_sketch_frame, "speed": 8.0, "loop": True, "sheet": "desk_sketch"},
    "file_sort": {"frames": 6, "builder": render_file_sort_frame, "speed": 8.0, "loop": True, "sheet": "file_sort"},
    "mug_sip": {"frames": 6, "builder": render_mug_sip_frame, "speed": 8.0, "loop": True, "sheet": "mug_sip"},
    "file_scan": {"frames": 6, "builder": render_file_scan_frame, "speed": 8.0, "loop": True, "sheet": "file_scan"},
    "zine_read": {"frames": 6, "builder": render_zine_read_frame, "speed": 8.0, "loop": True, "sheet": "zine_read"},
    "pinboard_plot": {"frames": 6, "builder": render_pinboard_plot_frame, "speed": 8.0, "loop": True, "sheet": "pinboard_plot"},
    "monitor_lurk": {"frames": 6, "builder": render_monitor_lurk_frame, "speed": 8.0, "loop": True, "sheet": "monitor_lurk"},
    "fridge_open": {"frames": 6, "builder": render_fridge_open_frame, "speed": 8.0, "loop": False, "sheet": "fridge_open"},
    "stretch": {"frames": 6, "builder": render_stretch_frame, "speed": 7.0, "loop": False, "sheet": "stretch"},
    "sneak": {"frames": 8, "builder": render_sneak_frame, "speed": 9.0, "loop": True, "sheet": "sneak"},
    "glitch": {"frames": 8, "builder": render_glitch_frame, "speed": 12.0, "loop": False, "sheet": "glitch"},
    "sit_cross": {"frames": 6, "builder": render_sit_cross_frame, "speed": 6.0, "loop": True, "sheet": "sit_cross"},
    "wall_sit": {"frames": 6, "builder": render_wall_sit_frame, "speed": 6.0, "loop": True, "sheet": "wall_sit"},
    "peek_left": {"frames": 6, "builder": render_peek_left_frame, "speed": 8.0, "loop": False, "sheet": "peek_left"},
    "peek_right": {"frames": 6, "builder": render_peek_right_frame, "speed": 8.0, "loop": False, "sheet": "peek_right"},
    "confused": {"frames": 6, "builder": render_confused_frame, "speed": 8.0, "loop": False, "sheet": "confused"},
    "bored": {"frames": 6, "builder": render_bored_frame, "speed": 7.0, "loop": False, "sheet": "bored"},
    "wave": {"frames": 6, "builder": render_wave_frame, "speed": 9.0, "loop": False, "sheet": "wave"},
    "yawn": {"frames": 6, "builder": render_yawn_frame, "speed": 6.0, "loop": False, "sheet": "yawn"},
    "stumble": {"frames": 6, "builder": render_stumble_frame, "speed": 10.0, "loop": False, "sheet": "stumble"},
    "dance": {"frames": 8, "builder": render_dance_frame, "speed": 10.0, "loop": True, "sheet": "dance"},
    "spray_tag": {"frames": 6, "builder": render_spray_tag_frame, "speed": 8.0, "loop": False, "sheet": "spray_tag"},
    "bug_sweep": {"frames": 6, "builder": render_bug_sweep_frame, "speed": 7.0, "loop": True, "sheet": "bug_sweep"},
    "blanket_nest": {"frames": 6, "builder": render_blanket_nest_frame, "speed": 5.0, "loop": True, "sheet": "blanket_nest"},
    "skateboard": {"frames": 8, "builder": render_skateboard_frame, "speed": 12.0, "loop": True, "sheet": "skateboard"},
    "headjack": {"frames": 6, "builder": render_headjack_frame, "speed": 7.0, "loop": False, "sheet": "headjack"},
    "sticker_slap": {"frames": 6, "builder": render_sticker_slap_frame, "speed": 9.0, "loop": False, "sheet": "sticker_slap"},
    "throne": {"frames": 6, "builder": render_throne_frame, "speed": 6.0, "loop": True, "sheet": "throne"},
    # New 8-frame animations
    "spin": {"frames": 8, "builder": render_spin_frame, "speed": 12.0, "loop": False, "sheet": "spin"},
    "tantrum": {"frames": 8, "builder": render_tantrum_frame, "speed": 10.0, "loop": True, "sheet": "tantrum"},
    "float": {"frames": 8, "builder": render_float_frame, "speed": 6.0, "loop": True, "sheet": "float"},
    "shiver": {"frames": 8, "builder": render_shiver_frame, "speed": 14.0, "loop": True, "sheet": "shiver"},
    "applaud": {"frames": 8, "builder": render_applaud_frame, "speed": 10.0, "loop": True, "sheet": "applaud"},
    "dizzy": {"frames": 8, "builder": render_dizzy_frame, "speed": 8.0, "loop": True, "sheet": "dizzy"},
    "bow": {"frames": 8, "builder": render_bow_frame, "speed": 7.0, "loop": False, "sheet": "bow"},
    "moonwalk": {"frames": 8, "builder": render_moonwalk_frame, "speed": 10.0, "loop": True, "sheet": "moonwalk"},
    "backflip": {"frames": 8, "builder": render_backflip_frame, "speed": 12.0, "loop": False, "sheet": "backflip"},
    "typing_fast": {"frames": 8, "builder": render_typing_fast_frame, "speed": 10.0, "loop": True, "sheet": "typing_fast"},
    "phone_call": {"frames": 8, "builder": render_phone_call_frame, "speed": 8.0, "loop": True, "sheet": "phone_call"},
    "umbrella": {"frames": 8, "builder": render_umbrella_frame, "speed": 10.0, "loop": True, "sheet": "umbrella"},
}


def write_sheet(sheet_name: str, frames: list[Image.Image]):
    sheet = Image.new("RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * FRAME_SIZE, 0))
    sheet.save(OUTPUT_DIR / f"{sheet_name}_sheet.png")


def write_master_sheet(rendered: dict[str, list[Image.Image]]):
    max_frames = max(len(frames) for frames in rendered.values())
    rows = list(rendered.keys())
    master = Image.new("RGBA", (FRAME_SIZE * max_frames, FRAME_SIZE * len(rows)), (0, 0, 0, 0))
    for row_index, row in enumerate(rows):
        for frame_index, frame in enumerate(rendered[row]):
            master.alpha_composite(frame, (frame_index * FRAME_SIZE, row_index * FRAME_SIZE))
    master.save(OUTPUT_DIR / "gboy_master_sheet.png")


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    rendered: dict[str, list[Image.Image]] = {}
    for name, config in ANIMATIONS.items():
        frames: list[Image.Image] = []
        for i in range(config["frames"]):
            built = config["builder"](i)
            frames.append(built if isinstance(built, Image.Image) else render_frame(built))
        rendered[name] = frames
        write_sheet(config["sheet"], frames)
    write_master_sheet(rendered)
    print(f"Generated {len(rendered)} animation sheets in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
