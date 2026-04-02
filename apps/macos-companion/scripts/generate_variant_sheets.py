#!/usr/bin/env python3

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


FRAME_SIZE = 64
FRAMES = 6

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent.parent
SOURCE_DIR = ROOT / "godot-game/assets/sprites/player"
OUTPUT_DIR = ROOT / "macos-companion/Assets/Sprites"

NON_LOOPING_NAMES = {
    "attack", "cape_flutter", "confused", "bored", "wave", "eat", "laser", "dash",
    "drop", "fall", "hide", "stretch", "yawn", "stumble", "headjack", "glitch",
    "peek_left", "peek_right", "fridge_open", "portal", "graffiti_bloc",
    "graffiti_was_here", "spray_tag", "sticker_slap", "tongue", "jump_side",
    "look_left", "look_right", "look_up", "look_down", "vanish",
}

CUSTOM_VARIANT_SOURCES = {"portal", "fridge_open", "noodle_eat", "desk_noodles"}

GLOW_SCREEN_NAMES = {
    "handheld_game", "tv_flip", "crt_watch", "computer_idle", "terminal_type",
    "monitor_lurk", "question_type", "question_lurk",
}

WALL_SHADOW_NAMES = {"wall_sit", "wallslide", "peek_left", "peek_right", "climb_side", "climb_right"}

DESK_PROP_NAMES = {"mug_sip", "eat", "file_sort", "file_scan", "desk_sketch", "pinboard_plot"}

DEVICE_DESK_MASTER_NAMES = {
    "computer_idle", "terminal_type", "tv_flip", "crt_watch", "handheld_game", "cook_meal",
    "noodle_eat_smooth", "desk_noodles_smooth", "radio_listen", "evidence_hack", "desk_sketch",
    "file_sort", "mug_sip", "file_scan", "zine_read", "pinboard_plot", "monitor_lurk",
    "fridge_open_smooth", "question_lurk", "question_type", "dossier_check", "signal_sweep",
    "typing_fast", "phone_call",
}

WALL_CLIMB_MASTER_NAMES = {
    "climb_back", "climb_right", "climb_side", "wall_sit", "wallslide", "peek_left", "peek_right",
}

EMOTION_GESTURE_MASTER_NAMES = {
    "angry", "applaud", "bored", "bow", "confused", "cry", "happy", "headjack", "taunt_signal",
    "wave", "yawn", "stretch", "dizzy", "float", "shiver", "tantrum", "tongue",
}

SMOKE_POWER_MASTER_NAMES = {
    "smoke_burst", "smoke_reform", "smoke_drift", "smoke_orbit",
    "vanish", "glitch", "hide", "laser", "psonic_charge", "psonic_overload",
}

MOVEMENT_SPORT_MASTER_NAMES = {
    "walk_back", "walk_front", "walk_left", "walk_right", "run_left", "run_right", "jump_side",
    "sneak", "skateboard", "dance", "moonwalk", "backflip", "spin", "soccer_goal",
    "idle_front", "idle_back", "idle_left", "idle_right",
}

SCREEN_REWRITE_OUTPUTS = {
    "computer_idle": "computer_idle_backdesk",
    "terminal_type": "terminal_type_backdesk",
    "monitor_lurk": "monitor_lurk_backdesk",
    "question_type": "question_type_backdesk",
    "question_lurk": "question_lurk_backdesk",
    "typing_fast": "typing_fast_backdesk",
    "evidence_hack": "evidence_hack_backdesk",
    "crt_watch": "crt_watch_backdesk",
    "tv_flip": "tv_flip_backdesk",
    "handheld_game": "handheld_game_backdesk",
    "radio_listen": "radio_listen_backdesk",
    "phone_call": "phone_call_backdesk",
    "terminal_trace": "terminal_trace_backdesk",
    "signal_decode": "signal_decode_backdesk",
    "shoulder_scan": "shoulder_scan_backdesk",
    "desk_doze": "desk_doze_backdesk",
}

PROP_CLEAN_OUTPUTS = {
    "cook_meal": "cook_meal_clean",
    "noodle_eat": "noodle_eat_clean",
    "desk_noodles": "desk_noodles_clean",
    "mug_sip": "mug_sip_clean",
    "file_scan": "file_scan_clean",
    "desk_sketch": "desk_sketch_clean",
    "file_sort": "file_sort_clean",
    "pinboard_plot": "pinboard_plot_clean",
    "zine_read": "zine_read_clean",
    "signal_sweep": "signal_sweep_clean",
    "fridge_open": "fridge_open_clean",
}

WALL_CLEAN_OUTPUTS = {
    "climb_side": "climb_side_clean",
    "climb_right": "climb_right_clean",
    "climb_back": "climb_back_clean",
    "wall_sit": "wall_sit_clean",
    "wallslide": "wallslide_clean",
    "peek_left": "peek_left_clean",
    "peek_right": "peek_right_clean",
}

SLEEP_SCENE_OUTPUTS = {
    "sleep_curl": "sleep_curl",
    "sleep_sit": "sleep_sit",
}

EMOTION_SCENE_OUTPUTS = {
    "hood_peek": "hood_peek",
    "side_eye": "side_eye",
    "sulk": "sulk",
    "proud_stance": "proud_stance",
}

GRAFFITI_CLEAN_OUTPUTS = {
    "graffiti_bloc": "graffiti_bloc_clean",
    "graffiti_was_here": "graffiti_was_here_clean",
}

MASTERED_BATCH_NAMES = sorted(
    DEVICE_DESK_MASTER_NAMES
    | WALL_CLIMB_MASTER_NAMES
    | EMOTION_GESTURE_MASTER_NAMES
    | SMOKE_POWER_MASTER_NAMES
    | MOVEMENT_SPORT_MASTER_NAMES
)


def load_frames(name: str):
    image = Image.open(SOURCE_DIR / f"{name}_sheet.png").convert("RGBA")
    return [image.crop((i * FRAME_SIZE, 0, (i + 1) * FRAME_SIZE, FRAME_SIZE)) for i in range(FRAMES)]


def load_any_frames(path: Path):
    image = Image.open(path).convert("RGBA")
    frame_size = image.height
    count = image.width // frame_size
    return [image.crop((i * frame_size, 0, (i + 1) * frame_size, frame_size)) for i in range(count)]


def compose_strip(frames, output_name: str):
    strip = Image.new("RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * FRAME_SIZE, 0))
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    strip.save(OUTPUT_DIR / f"{output_name}_sheet.png")


def blend_frames(a: Image.Image, b: Image.Image, amount: float = 0.5):
    return Image.blend(a, b, amount)


def draw_question(draw: ImageDraw.ImageDraw, origin_x: int, origin_y: int, color):
    points = [
        (1, 0), (2, 0), (3, 0),
        (0, 1),         (4, 1),
                  (3, 2),
               (2, 3),
               (2, 4),
               (2, 6),
    ]
    for x, y in points:
        draw.rectangle((origin_x + x, origin_y + y, origin_x + x, origin_y + y), fill=color)


def add_question_overlay(frame: Image.Image, frame_index: int, accent_shift: int = 0):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    bob = [0, -1, 0, 1, 0, -1][frame_index % 6]
    qx = 34 + accent_shift + ((frame_index % 2) * 2 - 1)
    qy = 3 + bob
    shadow = (36, 20, 46, 220)
    glow = (255, 94, 110, 255)
    ember = (255, 202, 118, 255)
    draw_question(draw, qx + 1, qy + 1, shadow)
    draw_question(draw, qx, qy, glow if frame_index % 3 != 1 else ember)
    draw.rectangle((qx + 2, qy + 8, qx + 2, qy + 8), fill=ember)
    draw.rectangle((qx + 3, qy + 8, qx + 3, qy + 8), fill=glow)
    return canvas


def add_taunt_overlay(frame: Image.Image, frame_index: int):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    magenta = (255, 96, 170, 255)
    cyan = (120, 234, 255, 210)
    amber = (255, 210, 110, 210)
    origin_x = 34 + ((frame_index % 3) - 1)
    origin_y = 10 + (frame_index % 2)
    glyph = [
        (0, 0), (1, 0), (2, 0), (4, 0), (5, 0),
        (1, 1), (4, 1),
        (1, 2), (2, 2), (3, 2), (4, 2),
        (0, 3), (5, 3),
    ]
    for x, y in glyph:
        draw.rectangle((origin_x + x, origin_y + y, origin_x + x, origin_y + y), fill=magenta if (x + y) % 2 == 0 else amber)
    draw.rectangle((origin_x - 8, origin_y + 8, origin_x + 8, origin_y + 9), fill=cyan)
    return canvas


def draw_sleep_z(draw: ImageDraw.ImageDraw, origin_x: int, origin_y: int, color):
    for x in range(4):
        draw.rectangle((origin_x + x, origin_y, origin_x + x, origin_y), fill=color)
        draw.rectangle((origin_x + 3 - x, origin_y + 3, origin_x + 3 - x, origin_y + 3), fill=color)
    draw.rectangle((origin_x + 2, origin_y + 1, origin_x + 2, origin_y + 1), fill=color)
    draw.rectangle((origin_x + 1, origin_y + 2, origin_x + 1, origin_y + 2), fill=color)


def build_scaled_text(text: str, fill, scale: int = 2):
    font = ImageFont.load_default()
    canvas = Image.new("RGBA", (140, 40), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.multiline_text((0, 0), text, font=font, fill=fill, spacing=1, align="center")
    bbox = canvas.getbbox()
    if bbox is None:
        return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    cropped = canvas.crop(bbox)
    return cropped.resize((cropped.width * scale, cropped.height * scale), Image.Resampling.NEAREST)


PIXEL_GLYPHS = {
    "A": ["01110", "10001", "11111", "10001", "10001"],
    "B": ["11110", "10001", "11110", "10001", "11110"],
    "C": ["01111", "10000", "10000", "10000", "01111"],
    "E": ["11111", "10000", "11110", "10000", "11111"],
    "G": ["01111", "10000", "10111", "10001", "01111"],
    "H": ["10001", "10001", "11111", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "11111"],
    "L": ["10000", "10000", "10000", "10000", "11111"],
    "N": ["10001", "11001", "10101", "10011", "10001"],
    "O": ["01110", "10001", "10001", "10001", "01110"],
    "R": ["11110", "10001", "11110", "10100", "10010"],
    "S": ["01111", "10000", "01110", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100"],
    "V": ["10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10101", "11011", "10001"],
    "Y": ["10001", "01010", "00100", "00100", "00100"],
    " ": ["000", "000", "000", "000", "000"],
}


def render_pixel_text(lines, fill, accent=None):
    line_height = 6
    width = max(sum((3 if ch == " " else 5) + 1 for ch in line) - 1 for line in lines)
    height = len(lines) * line_height - 1
    canvas = Image.new("RGBA", (width + 2, height + 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    for row, line in enumerate(lines):
        x = 1
        y = row * line_height + 1
        for ch in line:
            glyph = PIXEL_GLYPHS.get(ch, PIXEL_GLYPHS[" "])
            for gy, glyph_row in enumerate(glyph):
                for gx, bit in enumerate(glyph_row):
                    if bit == "1":
                        if accent:
                            draw.rectangle((x + gx + 1, y + gy + 1, x + gx + 1, y + gy + 1), fill=accent)
                        draw.rectangle((x + gx, y + gy, x + gx, y + gy), fill=fill)
            x += (3 if ch == " " else 5) + 1
    return canvas


def add_glitch_overlay(frame: Image.Image, frame_index: int, seed_offset: int = 0):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    teal = (77, 240, 220, 255)
    magenta = (255, 98, 170, 255)
    amber = (255, 204, 86, 255)
    rows = [8, 14, 18, 23, 29, 34]
    base_x = 4 + seed_offset
    for idx, y in enumerate(rows):
        length = 4 + ((frame_index + idx + seed_offset) % 5)
        x = (base_x + idx * 7 + frame_index * 3) % 42 + 10
        draw.rectangle((x, y, x + length, y + 1), fill=teal if idx % 2 == 0 else magenta)
        if (idx + frame_index) % 3 == 0:
            draw.rectangle((x + length + 2, y, x + length + 4, y + 1), fill=amber)
    return canvas


def add_dossier_overlay(frame: Image.Image, frame_index: int):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    paper = (236, 221, 185, 255)
    ink = (46, 34, 40, 255)
    alert = (255, 96, 106, 255)
    left = 40
    top = 14
    draw.rectangle((left, top, left + 12, top + 15), fill=paper)
    for row in range(5):
        y = top + 3 + row * 2
        width = 8 if row % 2 == 0 else 6
        draw.rectangle((left + 2, y, left + 2 + width, y), fill=ink)
    pin_x = left + 9 + (frame_index % 2)
    draw.rectangle((pin_x, top + 1, pin_x + 1, top + 2), fill=alert)
    return canvas


def build_variant(base_name: str, output_name: str, overlays):
    frames = load_frames(base_name)
    for overlay in overlays:
        frames = [overlay(frame, index) for index, frame in enumerate(frames)]
    compose_strip(frames, output_name)


def smooth_sequence(base_frames, reverse: bool = False, hold_first: int = 0, hold_last: int = 1):
    ordered = list(reversed(base_frames)) if reverse else list(base_frames)
    output = []
    if ordered:
        output.extend([ordered[0].copy() for _ in range(hold_first)])
    for index, frame in enumerate(ordered):
        output.append(frame.copy())
        if index < len(ordered) - 1:
            output.append(blend_frames(frame, ordered[index + 1], 0.5))
    if ordered:
        output.extend([ordered[-1].copy() for _ in range(hold_last)])
    return output


def add_noodle_support(frame: Image.Image, frame_index: int):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    shadow = (30, 22, 31, 220)
    bowl_shadow_y = 50 + (1 if frame_index in (1, 4) else 0)
    draw.rectangle((12, bowl_shadow_y, 24, bowl_shadow_y), fill=shadow)
    draw.rectangle((14, bowl_shadow_y + 1, 22, bowl_shadow_y + 1), fill=shadow)
    return canvas


def add_desk_support(frame: Image.Image, frame_index: int):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    desk = (127, 97, 72, 255)
    desk_dark = (77, 56, 43, 255)
    support_x = 6 + (frame_index % 2)
    draw.rectangle((support_x, 42, 30, 43), fill=desk)
    draw.rectangle((support_x, 44, 30, 44), fill=desk_dark)
    draw.rectangle((18, 45, 19, 52), fill=desk_dark)
    draw.rectangle((11, 50, 24, 50), fill=(28, 21, 29, 200))
    return canvas


def add_fridge_shadow(frame: Image.Image, frame_index: int):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((34, 56, 57, 57), fill=(26, 20, 28, 210))
    if frame_index >= 4:
        draw.rectangle((48, 38, 51, 44), fill=(178, 245, 255, 180))
    return canvas


def add_portal_glow(frame: Image.Image, frame_index: int):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    glow = (128, 255, 154, 150 if frame_index < 4 else 220)
    green = (28, 170, 92, 180)
    draw.rectangle((16, 40, 46, 41), fill=green)
    if frame_index >= 2:
        draw.rectangle((18, 38, 44, 39), fill=glow)
    return canvas


def add_screen_glow(frame: Image.Image, frame_index: int):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    colors = [
        (120, 234, 255, 180),
        (255, 99, 171, 170),
        (255, 210, 90, 170),
        (120, 234, 255, 180),
    ]
    color = colors[frame_index % len(colors)]
    draw.rectangle((6, 28, 24, 34), fill=color)
    return canvas


def add_wall_shadow(frame: Image.Image, frame_index: int):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((43, 8, 47, 55), fill=(27, 20, 31, 120 + (frame_index % 3) * 18))
    return canvas


def add_desk_prop_shadow(frame: Image.Image, frame_index: int):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((10, 49, 26, 50), fill=(28, 21, 29, 180))
    if frame_index % 2 == 0:
        draw.rectangle((11, 48, 24, 48), fill=(53, 40, 52, 120))
    return canvas


def add_ground_shadow(frame: Image.Image, frame_index: int, width: int = 18):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    offset = (frame_index % 3) - 1
    left = 22 + offset
    draw.rectangle((left, 56, left + width, 57), fill=(23, 18, 27, 175))
    draw.rectangle((left + 2, 55, left + width - 2, 55), fill=(49, 38, 58, 95))
    return canvas


def draw_green_portal(draw: ImageDraw.ImageDraw, left: int, top: int, width: int, height: int,
                      frame_index: int, alpha_scale: float = 1.0):
    outer = (30, 210, 114, int(210 * alpha_scale))
    glow = (142, 255, 172, int(170 * alpha_scale))
    core = (44, 92, 66, int(130 * alpha_scale))
    pulse = frame_index % 4
    draw.ellipse((left, top, left + width, top + height), outline=outer, width=1)
    draw.ellipse((left + 2, top + 2, left + width - 2, top + height - 2), outline=glow, width=1)
    draw.ellipse((left + 5, top + 5, left + width - 5, top + height - 5), fill=core)
    if pulse in (1, 2):
        draw.rectangle((left + width // 2 - 1, top + 4, left + width // 2 + 1, top + height - 4), fill=glow)
    if pulse in (0, 3):
        draw.rectangle((left + 5, top + height // 2 - 1, left + width - 5, top + height // 2 + 1), fill=outer)


def clear_zone(canvas: Image.Image, box):
    canvas.paste((0, 0, 0, 0), box)


def draw_monitor(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, h: int, frame_index: int):
    glow_cycle = [
        (118, 232, 255, 210),
        (255, 98, 171, 200),
        (255, 212, 110, 200),
        (118, 232, 255, 210),
    ]
    bezel = (49, 52, 72, 255)
    glow = glow_cycle[frame_index % len(glow_cycle)]
    draw.rectangle((x, y, x + w, y + h), fill=bezel)
    draw.rectangle((x + 2, y + 2, x + w - 2, y + h - 2), fill=glow)
    draw.rectangle((x + w // 2 - 1, y + h + 1, x + w // 2 + 1, y + h + 6), fill=(89, 94, 120, 255))
    draw.rectangle((x + w // 2 - 5, y + h + 7, x + w // 2 + 5, y + h + 8), fill=(97, 76, 62, 255))


def draw_desk_line(draw: ImageDraw.ImageDraw, x0: int = 2, x1: int = 34, y: int = 46):
    draw.rectangle((x0, y, x1, y + 1), fill=(124, 92, 67, 255))
    draw.rectangle((x0, y + 2, x1, y + 2), fill=(61, 44, 37, 255))


def back_body_sequence(active: bool = False, count: int = 12):
    source = "walk_back" if active else "idle_back"
    frames = build_loop_extended(load_any_frames(SOURCE_DIR / f"{source}_sheet.png"))
    return [frames[index % len(frames)].copy() for index in range(count)]


def side_body_sequence(active: bool = False, left: bool = False, count: int = 12):
    source = "walk_left" if left and active else "idle_left" if left else "walk_right" if active else "idle_right"
    frames = build_loop_extended(load_any_frames(SOURCE_DIR / f"{source}_sheet.png"))
    return [frames[index % len(frames)].copy() for index in range(count)]


def draw_keyboard(draw: ImageDraw.ImageDraw, x: int, y: int, frame_index: int, width: int = 12):
    body = (67, 71, 86, 255)
    key = (168, 206, 92, 255) if frame_index % 3 == 0 else (114, 232, 255, 180)
    draw.rectangle((x, y, x + width, y + 3), fill=body)
    for offset in range(0, width - 1, 3):
        draw.rectangle((x + 1 + offset, y + 1, x + 1 + offset, y + 1), fill=key)


def draw_glow_panel(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int,
                    glow, bezel=(45, 49, 68, 255), stand: bool = True, rounded: bool = False,
                    rear_panel: bool = False):
    for pad, alpha in ((7, 24), (5, 42), (3, 70)):
        draw.rectangle((x0 - pad, y0 - pad, x1 + pad, y1 + pad),
                       fill=(glow[0], glow[1], glow[2], alpha))
    if rounded and not rear_panel:
        draw.rounded_rectangle((x0, y0, x1, y1), radius=3, fill=bezel)
        draw.rounded_rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), radius=2, fill=glow)
    else:
        draw.rectangle((x0, y0, x1, y1), fill=bezel)
        if rear_panel:
            draw.rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), fill=(28, 31, 43, 255))
            draw.rectangle((x0 + 2, y0 + 2, x1 - 2, y0 + 3), fill=(glow[0], glow[1], glow[2], 150))
            draw.rectangle((x0 + 2, y1 - 3, x1 - 2, y1 - 2), fill=(glow[0], glow[1], glow[2], 55))
            draw.rectangle((x0 + 2, y0 + 5, x0 + 3, y1 - 5), fill=(glow[0], glow[1], glow[2], 70))
            draw.rectangle((x1 - 3, y0 + 5, x1 - 2, y1 - 5), fill=(glow[0], glow[1], glow[2], 70))
        else:
            draw.rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), fill=glow)
    if stand:
        stem_x = (x0 + x1) // 2
        draw.rectangle((stem_x - 1, y1 + 1, stem_x + 1, y1 + 7), fill=(88, 94, 118, 255))
        draw.rectangle((stem_x - 6, y1 + 8, stem_x + 6, y1 + 9), fill=(94, 74, 58, 255))


def draw_rear_hood_top(draw: ImageDraw.ImageDraw, scene: str, frame_index: int, shift_x: int = 0):
    hood = (154, 25, 39, 255)
    hood_dark = (90, 13, 21, 255)
    glow = (118, 232, 255, 110 if scene != "desk_doze" else 70)
    top_y = (8 if scene != "desk_doze" else 11) + (frame_index % 2)
    x0 = 24 + shift_x
    x1 = 40 + shift_x
    draw.rectangle((x0, top_y, x1, top_y + 6), fill=hood)
    draw.rectangle((x0 - 2, top_y + 2, x0 + 1, top_y + 8), fill=hood_dark)
    draw.rectangle((x1 - 1, top_y + 2, x1 + 2, top_y + 8), fill=hood_dark)
    draw.rectangle((x0 + 1, top_y - 4, x0 + 4, top_y + 1), fill=hood)
    draw.rectangle((x1 - 4, top_y - 4, x1 - 1, top_y + 1), fill=hood)
    draw.rectangle((x0 + 4, top_y + 1, x1 - 4, top_y + 2), fill=glow)


def draw_rear_legs(draw: ImageDraw.ImageDraw, frame_index: int, seated: bool = False):
    hood = (145, 20, 33, 255)
    hood_dark = (82, 11, 18, 255)
    shoe = (223, 228, 236, 255)
    sole = (101, 86, 216, 255)
    bob = [0, 1, 1, 0, -1, -1, 0, 0][frame_index % 8]
    if seated:
        draw.rectangle((22, 44, 28, 50), fill=hood_dark)
        draw.rectangle((36, 44, 42, 50), fill=hood_dark)
        draw.rectangle((20, 50, 30, 53), fill=shoe)
        draw.rectangle((34, 50, 44, 53), fill=shoe)
        draw.rectangle((20, 53, 30, 54), fill=sole)
        draw.rectangle((34, 53, 44, 54), fill=sole)
        return
    draw.rectangle((24, 40 + bob, 29, 52), fill=hood)
    draw.rectangle((35, 40 - bob, 40, 52), fill=hood)
    draw.rectangle((22, 52, 31, 55), fill=shoe)
    draw.rectangle((33, 52, 42, 55), fill=shoe)
    draw.rectangle((22, 55, 31, 56), fill=sole)
    draw.rectangle((33, 55, 42, 56), fill=sole)


def draw_rear_hidden_torso(draw: ImageDraw.ImageDraw, frame_index: int, desk_y: int = 40):
    hood = (145, 20, 33, 255)
    hood_dark = (82, 11, 18, 255)
    center_shift = [0, 0, 1, 0, -1, 0, 0, 0][frame_index % 8]
    draw.rectangle((24 + center_shift, 22, 40 + center_shift, desk_y), fill=hood)
    draw.rectangle((21 + center_shift, 24, 25 + center_shift, desk_y), fill=hood_dark)
    draw.rectangle((39 + center_shift, 24, 43 + center_shift, desk_y), fill=hood_dark)


def draw_rear_desk(draw: ImageDraw.ImageDraw, frame_index: int, width: int = 42):
    left = 11
    right = left + width
    draw.rectangle((left, 39, right, 42), fill=(130, 98, 71, 255))
    draw.rectangle((left, 42, right, 55), fill=(82, 58, 44, 255))
    draw.rectangle((15 + (frame_index % 2), 56, 48 + (frame_index % 2), 57), fill=(22, 18, 27, 150))


def draw_rear_arms_custom(draw: ImageDraw.ImageDraw, scene: str, frame_index: int):
    coat = (145, 20, 33, 255)
    coat_dark = (82, 11, 18, 255)
    cuff = (225, 230, 238, 255)
    if scene == "desk_doze":
        draw.rectangle((23, 33, 31, 35), fill=coat_dark)
        draw.rectangle((33, 33, 41, 35), fill=coat_dark)
        return
    reach = 2 if scene in {"terminal_type", "typing_fast", "terminal_trace", "signal_decode"} else 0
    settle = 1 if scene in {"computer_idle", "monitor_lurk", "question_lurk", "tv_flip", "crt_watch"} else 0
    hand_y = 35 + settle + (frame_index % 3 == 1)
    draw.rectangle((23 - reach, 24, 26 - reach, 34), fill=coat)
    draw.rectangle((38 + reach, 24, 41 + reach, 34), fill=coat)
    draw.rectangle((26 - reach, 33, 30, hand_y), fill=coat_dark)
    draw.rectangle((34, 33, 38 + reach, hand_y), fill=coat_dark)
    draw.rectangle((29, hand_y, 30, hand_y + 1), fill=cuff)
    draw.rectangle((34, hand_y, 35, hand_y + 1), fill=cuff)


def draw_side_desk(draw: ImageDraw.ImageDraw, frame_index: int, width: int = 34):
    draw.rectangle((4, 42, 4 + width, 44), fill=(126, 95, 70, 255))
    draw.rectangle((4, 45, 4 + width, 56), fill=(81, 58, 44, 255))
    draw.rectangle((10 + (frame_index % 2), 56, 34 + (frame_index % 2), 57), fill=(22, 18, 27, 150))


def draw_side_prop_arm(draw: ImageDraw.ImageDraw, scene: str, frame_index: int):
    coat = (151, 24, 36, 255)
    coat_dark = (92, 12, 20, 255)
    cuff = (228, 232, 242, 255)
    elbow_y = 31 + (frame_index % 2)
    hand_y = 35 + (frame_index % 3 == 1)
    if scene == "fridge_open":
        draw.rectangle((35, 21, 38, 31), fill=coat)
        draw.rectangle((38, 29, 46, 31), fill=coat_dark)
        draw.rectangle((45, 28, 46, 31), fill=cuff)
        return
    draw.rectangle((30, 24, 33, elbow_y), fill=coat)
    draw.rectangle((33, elbow_y - 1, 41, hand_y), fill=coat_dark)
    draw.rectangle((40, hand_y - 1, 41, hand_y), fill=cuff)
    if scene in {"mug_sip", "zine_read"}:
        draw.rectangle((28, 28, 31, 33), fill=coat)
        draw.rectangle((24, 32, 28, 34), fill=coat_dark)


def draw_fridge_prop(draw: ImageDraw.ImageDraw, frame_index: int):
    draw.rectangle((42, 10, 58, 52), fill=(176, 183, 194, 255))
    draw.rectangle((42, 30, 58, 31), fill=(88, 92, 104, 255))
    draw.rectangle((45, 18, 46, 24), fill=(74, 80, 95, 255))
    draw.rectangle((45, 38, 46, 44), fill=(74, 80, 95, 255))
    swing = min(8, frame_index)
    if frame_index >= 2:
        door_left = 33 - swing // 2
        draw.rectangle((door_left, 12, 42, 50), fill=(198, 204, 214, 235))
        draw.rectangle((door_left + 1, 18, door_left + 2, 24), fill=(124, 128, 138, 255))
        draw.rectangle((34, 20, 39, 24), fill=(118, 232, 255, 120))
    draw.rectangle((40, 56, 60, 57), fill=(24, 18, 27, 165))


def draw_scene_prop(draw: ImageDraw.ImageDraw, scene: str, frame_index: int):
    if scene == "cook_meal":
        draw.rectangle((8, 39, 23, 42), fill=(72, 75, 86, 255))
        draw.rectangle((5, 40, 8, 41), fill=(152, 154, 163, 255))
        flame = [(255, 208, 92, 255), (255, 118, 64, 255), (255, 98, 171, 210)][frame_index % 3]
        draw.rectangle((12, 34, 17, 38), fill=flame)
        draw.rectangle((14, 32, 15, 33), fill=(255, 232, 162, 190))
    elif scene in {"noodle_eat", "desk_noodles"}:
        draw.rectangle((9, 39, 23, 43), fill=(216, 229, 202, 255))
        draw.rectangle((11, 38, 21, 39), fill=(186, 198, 169, 255))
        lift = 1 if frame_index % 4 in (1, 2) else 0
        draw.rectangle((14, 32 - lift, 15, 38), fill=(210, 214, 224, 255))
        draw.rectangle((18, 32 - lift, 19, 38), fill=(210, 214, 224, 255))
        if scene == "desk_noodles":
            draw.rectangle((24, 28, 28, 39), fill=(67, 72, 89, 255))
            draw.rectangle((25, 30, 27, 37), fill=(118, 232, 255, 180))
    elif scene == "mug_sip":
        mug_y = 31 + (frame_index % 3 == 0)
        draw.rectangle((22, mug_y, 28, mug_y + 6), fill=(204, 222, 236, 255))
        draw.rectangle((28, mug_y + 1, 29, mug_y + 4), fill=(204, 222, 236, 255))
    elif scene in {"file_scan", "file_sort", "desk_sketch", "pinboard_plot", "zine_read"}:
        draw.rectangle((11, 27, 23, 40), fill=(236, 221, 185, 255))
        draw.rectangle((13, 30, 20, 30), fill=(48, 34, 41, 255))
        draw.rectangle((13, 33, 21, 33), fill=(48, 34, 41, 255))
        if scene == "file_sort":
            draw.rectangle((21, 24, 31, 36), fill=(224, 210, 176, 220))
        if scene in {"desk_sketch", "pinboard_plot"}:
            draw.rectangle((24, 26, 26, 39), fill=(255, 98, 171, 255))
        if scene == "zine_read":
            draw.rectangle((23, 28, 30, 40), fill=(96, 102, 126, 255))
            draw.rectangle((25, 30, 28, 37), fill=(118, 232, 255, 150))
    elif scene == "signal_sweep":
        draw.rectangle((10, 30, 24, 42), fill=(65, 70, 85, 255))
        draw.rectangle((13, 34, 20, 37), fill=(118, 232, 255, 210))
        draw.rectangle((22, 24, 23, 35), fill=(210, 212, 220, 255))
        pulse = (255, 98, 171, 220) if frame_index % 2 == 0 else (118, 232, 255, 180)
        draw.rectangle((25, 18, 31, 19), fill=pulse)
        draw.rectangle((29, 14, 35, 15), fill=pulse)


def draw_prop_clean_scene(scene: str):
    active = scene in {"cook_meal", "signal_sweep", "fridge_open"}
    count = 14 if scene in {"fridge_open", "noodle_eat", "desk_noodles"} else 12
    sequence = side_body_sequence(active=active, left=False, count=count)
    output = []
    for index, base in enumerate(sequence):
        canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        canvas.alpha_composite(base, (0, 0))
        draw = ImageDraw.Draw(canvas)
        if scene != "fridge_open":
            draw_side_desk(draw, index)
        draw_side_prop_arm(draw, scene, index)
        if scene == "fridge_open":
            draw_fridge_prop(draw, index)
        else:
            draw_scene_prop(draw, scene, index)
        output.append(canvas)
    compose_strip(output, PROP_CLEAN_OUTPUTS[scene])


def draw_back_arms(draw: ImageDraw.ImageDraw, scene: str, frame_index: int):
    coat = (151, 24, 36, 255)
    coat_dark = (92, 12, 20, 255)
    cuff = (228, 232, 242, 255)
    if scene == "desk_doze":
        draw.rectangle((21, 34, 30, 36), fill=coat_dark)
        draw.rectangle((34, 34, 43, 36), fill=coat_dark)
        draw.rectangle((28, 33, 35, 35), fill=coat)
        return
    reach = 1 if scene in {"terminal_type", "typing_fast", "terminal_trace", "signal_decode"} else 0
    rest = scene in {"computer_idle", "monitor_lurk", "question_lurk", "crt_watch", "tv_flip", "radio_listen", "handheld_game"}
    left_x = 23 - reach + (frame_index % 2)
    right_x = 37 + reach - (frame_index % 2)
    hand_y = (37 if rest else 36) + (frame_index % 3 == 1)
    draw.rectangle((left_x, 26, left_x + 2, 35), fill=coat)
    draw.rectangle((right_x, 26, right_x + 2, 35), fill=coat)
    draw.rectangle((left_x + 2, 34, 29, hand_y), fill=coat_dark)
    draw.rectangle((35, 34, right_x, hand_y), fill=coat_dark)
    draw.rectangle((28, hand_y, 29, hand_y + 1), fill=cuff)
    draw.rectangle((35, hand_y, 36, hand_y + 1), fill=cuff)


def add_over_shoulder_turn(canvas: Image.Image, frame_index: int, direction: str = "right", strong: bool = False):
    draw = ImageDraw.Draw(canvas)
    hood = (145, 20, 33, 255)
    hood_dark = (78, 11, 18, 255)
    face = (232, 206, 186, 255)
    eye = (20, 20, 26, 255)
    x = 36 if direction == "right" else 23
    if strong:
        draw.rectangle((x - 2, 12, x + 4, 20), fill=face)
        draw.rectangle((x - 3, 11, x + 5, 13), fill=hood)
        draw.rectangle((x - 3, 14, x - 2, 20), fill=hood_dark)
        draw.rectangle((x + 4, 14, x + 5, 20), fill=hood_dark)
        eye_x = x + 1 if direction == "right" else x + 2
        draw.rectangle((eye_x, 15, eye_x, 15), fill=eye)
        draw.rectangle((eye_x, 18, eye_x + 1, 18), fill=hood_dark)
    else:
        draw.rectangle((x - 1, 14, x + 2, 19), fill=face)
        draw.rectangle((x - 2, 12, x + 3, 14), fill=hood)
        eye_x = x if direction == "right" else x + 1
        draw.rectangle((eye_x, 16, eye_x, 16), fill=eye)
    return canvas


def add_question_mark(frame: Image.Image, frame_index: int, shift: int = 0):
    return add_question_overlay(frame, frame_index, accent_shift=shift)


def add_screen_console(draw: ImageDraw.ImageDraw, scene: str, frame_index: int):
    cyan_cycle = [
        (118, 232, 255, 210),
        (166, 244, 255, 205),
        (255, 212, 110, 185),
        (255, 98, 171, 175),
    ]
    cyan = cyan_cycle[frame_index % len(cyan_cycle)]
    amber = (255, 212, 110, 185)
    phosphor = (138, 238, 188, 205)
    if scene == "crt_watch":
        draw_glow_panel(draw, 16, 12, 46, 35, phosphor, bezel=(84, 92, 106, 255), rounded=True, rear_panel=True)
        draw.rectangle((23, 20, 39, 21), fill=(76, 130, 106, 80))
    elif scene == "tv_flip":
        colors = [(120, 232, 255, 210), (255, 96, 170, 210), (255, 212, 110, 210), (130, 255, 170, 200)]
        draw_glow_panel(draw, 15, 11, 47, 33, colors[frame_index % len(colors)], bezel=(64, 66, 80, 255), rounded=True, rear_panel=True)
        draw.rectangle((21, 19, 41, 20), fill=(24, 24, 28, 80))
    elif scene == "handheld_game":
        body = (70, 74, 94, 255)
        draw_glow_panel(draw, 21, 20, 43, 36, cyan, bezel=body, stand=False, rounded=True, rear_panel=True)
        draw.rectangle((23, 26, 24, 27), fill=amber)
        draw.rectangle((40, 26, 41, 27), fill=(255, 98, 171, 255))
    elif scene in {"radio_listen", "signal_decode"}:
        shell = (76, 80, 91, 255)
        draw_glow_panel(draw, 17, 16, 47, 34, cyan, bezel=shell, stand=False, rounded=True, rear_panel=True)
        draw.rectangle((36, 20, 41, 24), fill=(206, 208, 216, 180))
        draw.rectangle((44, 8, 45, 22), fill=(210, 212, 220, 255))
        draw.rectangle((20, 29, 44, 30), fill=(54, 58, 72, 255))
    elif scene == "phone_call":
        shell = (54, 58, 72, 255)
        draw_glow_panel(draw, 19, 17, 44, 34, cyan, bezel=shell, stand=False, rounded=True, rear_panel=True)
        draw.rectangle((42, 20, 47, 29), fill=(202, 206, 216, 255))
        draw.rectangle((19, 33, 43, 36), fill=shell)
    else:
        if scene == "evidence_hack":
            draw_glow_panel(draw, 8, 13, 29, 31, cyan, stand=False, rear_panel=True)
            draw_glow_panel(draw, 35, 11, 56, 29, (255, 96, 170, 190), stand=False, rear_panel=True)
            draw.rectangle((29, 26, 35, 27), fill=(94, 74, 58, 255))
        elif scene == "desk_doze":
            draw_glow_panel(draw, 16, 14, 47, 34, (92, 210, 255, 120), rounded=True, rear_panel=True)
            draw.rectangle((20, 20, 42, 21), fill=(30, 54, 66, 100))
        else:
            width = 28 if scene in {"computer_idle", "monitor_lurk", "question_lurk"} else 30
            draw_glow_panel(draw, 16, 13, 16 + width, 34, cyan, rounded=True, rear_panel=True)
            draw.rectangle((21, 17, 40, 18), fill=(cyan[0], cyan[1], cyan[2], 55))


def draw_backdesk_scene(scene: str):
    count = 16 if scene in {"typing_fast", "terminal_trace", "signal_decode", "shoulder_scan", "desk_doze"} else 12
    output = []
    for index in range(count):
        canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        draw = ImageDraw.Draw(canvas)
        seated = scene == "desk_doze"
        draw_rear_legs(draw, index, seated=seated)
        if scene not in {"handheld_game"}:
            draw_rear_desk(draw, index)
            if scene != "desk_doze":
                draw_keyboard(draw, 24, 36, index, width=16 if scene in {"typing_fast", "terminal_trace"} else 14)
        draw_rear_hidden_torso(draw, index, desk_y=39 if scene != "desk_doze" else 35)
        draw_rear_arms_custom(draw, scene, index)
        add_screen_console(draw, scene, index)
        if scene in {"terminal_type", "typing_fast", "terminal_trace"}:
            draw.rectangle((23, 33, 25, 34), fill=(181, 206, 91, 255))
            draw.rectangle((38, 33, 40, 34), fill=(118, 232, 255, 200))
        if scene in {"evidence_hack", "signal_decode"}:
            draw.rectangle((12, 34, 17, 36), fill=(236, 221, 185, 255))
            draw.rectangle((46, 34, 51, 36), fill=(236, 221, 185, 255))
        if scene == "shoulder_scan":
            shift = 6 if (index // 4) % 2 == 0 else -6
            draw_rear_hood_top(draw, scene, index, shift_x=shift)
            peek_x = 42 if shift > 0 else 16
            draw.rectangle((peek_x, 12, peek_x + 4, 18), fill=(232, 206, 186, 255))
            draw.rectangle((peek_x - 1, 11, peek_x + 5, 13), fill=(145, 20, 33, 255))
            draw.rectangle((peek_x + (2 if shift > 0 else 1), 14, peek_x + (2 if shift > 0 else 1), 14), fill=(20, 20, 26, 255))
        else:
            draw_rear_hood_top(draw, scene, index)
        if scene in {"question_type", "question_lurk"}:
            canvas = add_question_mark(canvas, index, shift=-2 if scene == "question_type" else 1)
        if scene == "desk_doze":
            canvas = add_question_overlay(canvas, index, accent_shift=-3 if index % 8 < 3 else 2) if index % 12 in (10, 11) else canvas
            draw.rectangle((24, 18, 40, 26), fill=(32, 20, 28, 180))
        output.append(canvas)

    compose_strip(output, SCREEN_REWRITE_OUTPUTS[scene])


def draw_wall_clean_scene(scene: str):
    left = scene in {"climb_right", "peek_right"}
    active = scene in {"climb_side", "climb_right", "wallslide"}
    count = 16 if scene in {"climb_side", "climb_right", "wallslide"} else 12
    sequence = side_body_sequence(active=active, left=left, count=count)
    output = []
    climb_offsets = [6, 4, 1, -2, -5, -7, -4, -1, 2, 5, 7, 4, 1, -2, -5, -7]
    for index, base in enumerate(sequence):
        canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        draw = ImageDraw.Draw(canvas)
        wall_x0 = 9 if left else 50
        wall_x1 = 14 if left else 55
        draw.rectangle((wall_x0, 8, wall_x1, 56), fill=(184, 188, 204, 255))
        draw.rectangle((wall_x0 - 3 if left else wall_x1, 8, wall_x0 - 1 if left else wall_x1 + 2, 56),
                       fill=(54, 48, 64, 180))

        if scene in {"peek_left", "peek_right"}:
            hood = (150, 24, 38, 255)
            hood_dark = (86, 12, 20, 255)
            face = (232, 206, 186, 255)
            eye = (20, 20, 26, 255)
            hand_left = 43 if not left else 13
            hand_right = 47 if not left else 17
            head_x0 = 38 if not left else 11
            head_x1 = 49 if not left else 22
            draw.rectangle((head_x0, 14, head_x1, 27), fill=hood)
            draw.rectangle((head_x0 + 2, 16, head_x1 - 2, 23), fill=face)
            draw.rectangle((head_x0 + 1, 15, head_x1 - 1, 17), fill=hood_dark)
            draw.rectangle((head_x0 + (7 if not left else 2), 19, head_x0 + (7 if not left else 2), 19), fill=eye)
            draw.rectangle((head_x0 + (6 if not left else 1), 23, head_x0 + (8 if not left else 3), 23), fill=hood_dark)
            draw.rectangle((hand_left, 27, hand_right, 33), fill=hood_dark)
        elif scene == "climb_back":
            y_shift = climb_offsets[index]
            canvas.alpha_composite(back_body_sequence(active=True, count=count)[index], (0, y_shift))
            draw.rectangle((8, 10, 54, 14), fill=(184, 188, 204, 255))
            draw.rectangle((8, 14, 54, 15), fill=(54, 48, 64, 180))
            draw.rectangle((24, 13 + y_shift, 27, 19 + y_shift), fill=(86, 12, 20, 255))
            draw.rectangle((37, 13 + y_shift, 40, 19 + y_shift), fill=(86, 12, 20, 255))
        else:
            y_shift = climb_offsets[index] if scene in {"climb_side", "climb_right", "wallslide"} else 0
            x_shift = 10 if not left else -10
            if scene == "wall_sit":
                y_shift = 6
            canvas.alpha_composite(base, (x_shift, y_shift))
            coat_dark = (86, 12, 20, 255)
            contact_x0 = 45 if not left else 14
            contact_x1 = 47 if not left else 16
            if scene in {"climb_side", "climb_right"}:
                draw.rectangle((contact_x0, 24 + y_shift, contact_x1, 34 + y_shift), fill=coat_dark)
                draw.rectangle((42 if not left else 15, 38 + y_shift, 46 if not left else 19, 46 + y_shift), fill=coat_dark)
            elif scene == "wallslide":
                draw.rectangle((contact_x0, 20 + y_shift, contact_x1, 32 + y_shift), fill=coat_dark)
                spark_x = 47 if not left else 13
                draw.rectangle((spark_x, 37, spark_x + (1 if not left else -1), 42), fill=(118, 232, 255, 170))
            elif scene == "wall_sit":
                draw.rectangle((34 if not left else 20, 47, 44 if not left else 30, 49), fill=coat_dark)
        draw.rectangle((20, 56, 44, 57), fill=(22, 18, 27, 140))
        output.append(canvas)
    compose_strip(output, WALL_CLEAN_OUTPUTS[scene])


def build_sleep_scene(name: str):
    if name == "sleep_curl":
        frames = build_loop_extended(load_any_frames(SOURCE_DIR / "sleep_lie_sheet.png"))[:14]
    else:
        frames = build_loop_extended(load_any_frames(SOURCE_DIR / "sit_cross_sheet.png"))[:14]
    output = []
    for index, frame in enumerate(frames):
        canvas = add_ground_shadow(frame, index, width=20)
        draw = ImageDraw.Draw(canvas)
        if name == "sleep_curl":
            draw.ellipse((13, 41, 24, 49), fill=(210, 214, 224, 255))
            draw.rectangle((18, 31, 42, 47), fill=(86, 92, 126, 130))
            draw.rectangle((20, 33, 40, 46), fill=(118, 125, 166, 120))
            z_y = 10 - (index % 3)
            draw_sleep_z(draw, 42 + (index % 2), z_y, (188, 222, 255, 210))
            if index % 7 in (4, 5):
                draw_sleep_z(draw, 48, 5, (255, 214, 110, 180))
        else:
            clear_zone(canvas, (18, 12, 46, 31))
            draw.rectangle((21, 17, 43, 29), fill=(118, 22, 34, 230))
            draw.rectangle((24, 19, 40, 28), fill=(58, 20, 28, 200))
            draw.rectangle((23, 14, 27, 18), fill=(118, 22, 34, 230))
            draw.rectangle((37, 14, 41, 18), fill=(118, 22, 34, 230))
            draw.rectangle((22, 16, 42, 24), fill=(86, 12, 20, 160))
            draw.rectangle((24, 19, 40, 29), fill=(32, 20, 28, 110))
            draw.rectangle((22, 47, 42, 49), fill=(86, 92, 126, 130))
            bob = 1 if index % 6 in (2, 3) else 0
            draw_sleep_z(draw, 40, 9 - bob, (188, 222, 255, 190))
        output.append(canvas)
    compose_strip(output, SLEEP_SCENE_OUTPUTS[name])


def build_emotion_scene(name: str):
    base_source = "happy_sheet.png" if name == "proud_stance" else "idle_front_sheet.png"
    frames = build_loop_extended(load_any_frames(SOURCE_DIR / base_source))[:12]
    output = []
    for index, frame in enumerate(frames):
        canvas = add_ground_shadow(frame, index, width=16)
        draw = ImageDraw.Draw(canvas)
        if name == "hood_peek":
            clear_zone(canvas, (21, 12, 43, 25))
            draw.rectangle((24, 14, 39, 23), fill=(86, 12, 20, 160))
            eye_x = 28 if (index // 3) % 2 == 0 else 35
            draw.rectangle((eye_x, 19, eye_x + 1, 19), fill=(245, 244, 248, 255))
            draw.rectangle((eye_x + 1, 19, eye_x + 1, 19), fill=(20, 20, 26, 255))
        elif name == "side_eye":
            clear_zone(canvas, (20, 13, 44, 25))
            draw.rectangle((22, 14, 28, 16), fill=(58, 32, 42, 255))
            draw.rectangle((36, 17, 42, 18), fill=(58, 32, 42, 255))
            draw.rectangle((28, 18, 29, 19), fill=(20, 20, 26, 255))
            draw.rectangle((37, 19, 40, 20), fill=(20, 20, 26, 255))
            draw.rectangle((25, 22, 38, 23), fill=(58, 32, 42, 180))
        elif name == "sulk":
            clear_zone(canvas, (19, 13, 45, 26))
            draw.rectangle((21, 16, 25, 18), fill=(58, 32, 42, 255))
            draw.rectangle((39, 16, 43, 18), fill=(58, 32, 42, 255))
            draw.rectangle((20, 20, 44, 23), fill=(118, 22, 34, 160))
            draw.rectangle((20, 33, 44, 37), fill=(86, 12, 20, 220))
        elif name == "proud_stance":
            draw.rectangle((18, 32, 24, 35), fill=(118, 22, 34, 190))
            draw.rectangle((40, 32, 46, 35), fill=(118, 22, 34, 190))
            draw.rectangle((23, 11, 26, 12), fill=(255, 214, 110, 210))
            draw.rectangle((39, 11, 42, 12), fill=(118, 232, 255, 210))
            draw.rectangle((22, 34, 42, 36), fill=(255, 98, 171, 120))
        output.append(canvas)
    compose_strip(output, EMOTION_SCENE_OUTPUTS[name])


def build_graffiti_scene(name: str):
    output = []
    text_art = {
        "graffiti_bloc": render_pixel_text(["LONG", "LIVE", "THE", "BLOC"], (33, 19, 19, 255), accent=(255, 98, 171, 120)),
        "graffiti_was_here": render_pixel_text(["GBOY", "WAS", "HERE"], (28, 20, 14, 255), accent=(255, 214, 110, 110)),
    }
    reveal_steps = [0.12, 0.18, 0.26, 0.36, 0.48, 0.62, 0.76, 0.9, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
    for index in range(14):
        canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        draw = ImageDraw.Draw(canvas)
        bob = [0, 1, 0, -1, 0, 1, 0, -1][index % 8]
        hood = (145, 20, 33, 255)
        hood_dark = (82, 11, 18, 255)
        face = (232, 206, 186, 255)
        shoe = (223, 228, 236, 255)
        sole = (101, 86, 216, 255)
        draw.rectangle((21, 7, 63, 55), fill=(217, 220, 226, 255))
        draw.rectangle((19, 7, 21, 55), fill=(74, 70, 84, 180))
        draw.rectangle((22, 10, 62, 11), fill=(255, 244, 255, 110 if name == "graffiti_bloc" else 85))
        draw.rectangle((7, 18 + bob, 18, 34 + bob), fill=hood)
        draw.rectangle((6, 20 + bob, 9, 35 + bob), fill=hood_dark)
        draw.rectangle((13, 22 + bob, 16, 27 + bob), fill=face)
        draw.rectangle((15, 23 + bob, 15, 23 + bob), fill=(20, 20, 26, 255))
        draw.rectangle((10, 34 + bob, 14, 51), fill=hood)
        draw.rectangle((4, 34, 8, 51), fill=hood)
        draw.rectangle((3, 51, 10, 54), fill=shoe)
        draw.rectangle((9, 51, 16, 54), fill=shoe)
        draw.rectangle((3, 54, 10, 55), fill=sole)
        draw.rectangle((9, 54, 16, 55), fill=sole)
        draw.rectangle((17, 22 + bob, 23, 30 + bob), fill=hood_dark)
        draw.rectangle((22, 28 + bob, 30, 30 + bob), fill=hood_dark)

        art = text_art[name]
        reveal = reveal_steps[index]
        visible_h = max(1, int(art.height * reveal))
        art_crop = art.crop((0, 0, art.width, visible_h))
        text_x = 27
        text_y = 13 if name == "graffiti_bloc" else 16
        canvas.alpha_composite(art_crop, (text_x, text_y))
        if name == "graffiti_was_here" and index >= 7:
            underline_y = 45 + ((index - 7) % 2)
            draw.rectangle((28, underline_y, 51, underline_y + 1), fill=(26, 18, 18, 190))
        if name == "graffiti_bloc" and index >= 8:
            draw.rectangle((28, 43, 51, 44), fill=(255, 98, 171, 90))
        draw.rectangle((4, 56, 28, 57), fill=(22, 18, 27, 140))
        output.append(canvas)
    compose_strip(output, GRAFFITI_CLEAN_OUTPUTS[name])


def build_bow_clean():
    frames = build_nonloop_extended(load_any_frames(SOURCE_DIR / "idle_front_sheet.png"))[:12]
    offsets = [0, 1, 3, 5, 7, 8, 8, 7, 5, 3, 1, 0]
    output = []
    for index, frame in enumerate(frames):
        canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        upper = frame.crop((16, 8, 48, 36))
        lower = frame.crop((16, 36, 48, 60))
        canvas.alpha_composite(lower, (16, 36))
        canvas.alpha_composite(upper, (16, 8 + offsets[index]))
        draw = ImageDraw.Draw(canvas)
        draw.rectangle((20, 56, 44, 57), fill=(22, 18, 27, 150))
        if index in (3, 4, 5, 6):
            draw.rectangle((45, 18 + offsets[index], 49, 19 + offsets[index]), fill=(255, 214, 110, 180))
        output.append(canvas)
    compose_strip(output, "bow_clean")


def build_tongue_clean():
    frames = build_nonloop_extended(load_any_frames(SOURCE_DIR / "idle_front_sheet.png"))[:10]
    tongue_lengths = [0, 1, 2, 3, 4, 4, 3, 2, 1, 0]
    output = []
    for index, frame in enumerate(frames):
        canvas = frame.copy()
        draw = ImageDraw.Draw(canvas)
        tongue = tongue_lengths[index]
        mouth_x = 31
        mouth_y = 23
        draw.rectangle((mouth_x - 1, mouth_y, mouth_x + 1, mouth_y), fill=(46, 20, 28, 255))
        if tongue > 0:
            draw.rectangle((mouth_x, mouth_y + 1, mouth_x, mouth_y + tongue), fill=(255, 108, 142, 255))
            if tongue > 2:
                draw.rectangle((mouth_x - 1, mouth_y + tongue, mouth_x + 1, mouth_y + tongue), fill=(255, 146, 170, 255))
        if index in (2, 3, 4, 5):
            draw.rectangle((22, 15, 24, 16), fill=(255, 214, 110, 180))
            draw.rectangle((40, 15, 42, 16), fill=(255, 214, 110, 180))
        output.append(canvas)
    compose_strip(output, "tongue_clean")


def master_device_desk_scene(frame: Image.Image, frame_index: int, name: str):
    canvas = add_ground_shadow(frame, frame_index, width=20)
    draw = ImageDraw.Draw(canvas)

    if name == "fridge_open_smooth":
        clear_zone(canvas, (28, 8, 63, 58))
        draw.rectangle((42, 11, 58, 52), fill=(175, 182, 194, 255))
        draw.rectangle((42, 31, 58, 32), fill=(88, 92, 104, 255))
        draw.rectangle((44, 18, 46, 24), fill=(74, 80, 95, 255))
        draw.rectangle((44, 38, 46, 44), fill=(74, 80, 95, 255))
        draw.rectangle((40, 56, 60, 57), fill=(24, 18, 27, 165))
        if frame_index >= 4:
            draw.rectangle((48, 20, 55, 24), fill=(118, 232, 255, 150))
        return canvas

    draw_desk_line(draw)

    if name in {"computer_idle", "terminal_type", "question_type", "monitor_lurk", "question_lurk", "typing_fast", "evidence_hack"}:
        draw_monitor(draw, 6, 20, 18, 12, frame_index)
        draw.rectangle((6, 36, 24, 39), fill=(53, 66, 96, 255))
        if name in {"terminal_type", "question_type", "typing_fast"}:
            draw.rectangle((8, 37, 22, 38), fill=(181, 206, 91, 255))
        if name in {"question_type", "question_lurk"}:
            draw.rectangle((25, 8, 29, 12), fill=(255, 98, 171, 255))
    elif name in {"tv_flip", "crt_watch"}:
        draw_monitor(draw, 5, 18, 20, 15, frame_index)
    elif name == "handheld_game":
        draw.rectangle((9, 35, 24, 44), fill=(66, 74, 108, 255))
        draw.rectangle((12, 37, 21, 41), fill=(118, 232, 255, 210))
        draw.rectangle((10, 39, 11, 40), fill=(255, 210, 110, 255))
        draw.rectangle((22, 39, 23, 40), fill=(255, 98, 171, 255))
    elif name == "radio_listen":
        draw.rectangle((7, 30, 25, 42), fill=(82, 88, 101, 255))
        draw.rectangle((10, 33, 17, 37), fill=(118, 232, 255, 180))
        draw.rectangle((22, 24, 23, 34), fill=(210, 212, 220, 255))
    elif name == "phone_call":
        draw.rectangle((7, 38, 25, 43), fill=(67, 66, 86, 255))
        draw.rectangle((9, 32, 20, 35), fill=(192, 198, 216, 255))
        draw.rectangle((21, 33, 24, 35), fill=(192, 198, 216, 255))
    elif name in {"file_scan", "dossier_check", "file_sort", "desk_sketch", "pinboard_plot", "zine_read"}:
        draw.rectangle((10, 27, 22, 41), fill=(236, 221, 185, 255))
        draw.rectangle((12, 30, 19, 30), fill=(48, 34, 41, 255))
        draw.rectangle((12, 33, 20, 33), fill=(48, 34, 41, 255))
        if name in {"desk_sketch", "pinboard_plot"}:
            draw.rectangle((23, 27, 26, 39), fill=(255, 98, 171, 255))
    elif name in {"mug_sip"}:
        draw.rectangle((12, 36, 19, 42), fill=(204, 222, 236, 255))
        draw.rectangle((20, 37, 21, 40), fill=(204, 222, 236, 255))
    elif name in {"eat", "noodle_eat_smooth", "desk_noodles_smooth"}:
        draw.rectangle((10, 40, 23, 43), fill=(218, 230, 202, 255))
        draw.rectangle((11, 39, 22, 39), fill=(188, 198, 170, 255))
        draw.rectangle((14, 34, 15, 39), fill=(210, 214, 224, 255))
        draw.rectangle((18, 34, 19, 39), fill=(210, 214, 224, 255))
    elif name == "cook_meal":
        draw.rectangle((6, 39, 22, 42), fill=(72, 75, 86, 255))
        draw.rectangle((4, 41, 8, 42), fill=(152, 154, 163, 255))
        draw.rectangle((11, 35, 17, 38), fill=(255, 208, 92, 255))
        draw.rectangle((13, 33, 15, 34), fill=(255, 98, 171, 255))
    elif name == "signal_sweep":
        draw.rectangle((8, 31, 24, 42), fill=(65, 70, 85, 255))
        draw.rectangle((12, 35, 20, 37), fill=(118, 232, 255, 210))
        draw.rectangle((22, 25, 23, 34), fill=(210, 212, 220, 255))
    return canvas


def master_wall_scene(frame: Image.Image, frame_index: int, name: str):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    right_side = name in {"climb_side", "peek_left", "wall_sit", "wallslide"}
    left_side = name in {"climb_right", "peek_right"}
    if right_side:
        draw.rectangle((47, 8, 50, 56), fill=(184, 188, 204, 255))
        draw.rectangle((51, 8, 53, 56), fill=(54, 48, 64, 180))
    if left_side:
        draw.rectangle((11, 8, 14, 56), fill=(184, 188, 204, 255))
        draw.rectangle((8, 8, 10, 56), fill=(54, 48, 64, 180))
    if name == "climb_back":
        draw.rectangle((8, 11, 54, 13), fill=(184, 188, 204, 255))
        draw.rectangle((8, 14, 54, 15), fill=(54, 48, 64, 180))
    draw.rectangle((22, 56, 40, 57), fill=(22, 18, 27, 150))
    return canvas


def master_emotion_scene(frame: Image.Image, frame_index: int, name: str):
    canvas = add_ground_shadow(frame, frame_index, width=16)
    draw = ImageDraw.Draw(canvas)
    if name == "angry":
        draw.rectangle((26, 8, 28, 12), fill=(255, 98, 171, 255))
        draw.rectangle((35, 8, 37, 12), fill=(255, 98, 171, 255))
    elif name == "happy":
        draw.rectangle((24, 8, 24, 10), fill=(255, 214, 110, 255))
        draw.rectangle((37, 8, 37, 10), fill=(118, 232, 255, 255))
    elif name == "confused":
        return add_question_overlay(canvas, frame_index)
    elif name == "bored":
        draw.rectangle((29, 9, 31, 9), fill=(188, 194, 206, 255))
        draw.rectangle((33, 9, 35, 9), fill=(188, 194, 206, 255))
    elif name == "cry":
        draw.rectangle((26, 24, 26, 34), fill=(118, 232, 255, 210))
        draw.rectangle((38, 24, 38, 34), fill=(118, 232, 255, 210))
    elif name == "wave":
        draw.rectangle((42, 17, 47, 18), fill=(255, 214, 110, 220))
        draw.rectangle((43, 20, 48, 21), fill=(255, 98, 171, 200))
    elif name == "headjack":
        draw.rectangle((18, 11, 22, 12), fill=(118, 232, 255, 210))
        draw.rectangle((42, 11, 46, 12), fill=(255, 98, 171, 210))
    elif name == "yawn":
        draw.rectangle((40, 18, 45, 19), fill=(210, 214, 224, 255))
        draw.rectangle((44, 15, 48, 16), fill=(210, 214, 224, 255))
    elif name in {"taunt_signal", "tongue"}:
        return add_taunt_overlay(canvas, frame_index)
    elif name == "dizzy":
        draw.rectangle((20, 9, 22, 10), fill=(255, 214, 110, 255))
        draw.rectangle((39, 9, 41, 10), fill=(118, 232, 255, 255))
    elif name == "shiver":
        draw.rectangle((18, 20, 19, 24), fill=(118, 232, 255, 210))
        draw.rectangle((44, 20, 45, 24), fill=(118, 232, 255, 210))
    elif name == "tantrum":
        draw.rectangle((18, 13, 20, 14), fill=(255, 98, 171, 255))
        draw.rectangle((43, 13, 45, 14), fill=(255, 98, 171, 255))
    return canvas


def master_smoke_power_scene(frame: Image.Image, frame_index: int, name: str):
    canvas = frame.copy()
    if name in {"portal_entry_smooth", "smoke_burst", "smoke_reform", "smoke_drift", "smoke_orbit", "vanish", "hide"}:
        canvas = add_smoke_shell(canvas, frame_index, drift_x=(frame_index % 5) - 2, reveal=0.12)
    if name in {"laser", "psonic_charge"}:
        canvas = add_psonic_fx(canvas, frame_index, intense=False)
    if name in {"psonic_overload", "glitch"}:
        canvas = add_psonic_fx(canvas, frame_index, intense=True)
    return canvas


def master_movement_sport_scene(frame: Image.Image, frame_index: int, name: str):
    canvas = add_ground_shadow(frame, frame_index, width=22)
    draw = ImageDraw.Draw(canvas)
    if name in {"walk_left", "walk_right", "run_left", "run_right", "moonwalk", "sneak"}:
        draw.rectangle((6, 38, 14, 39), fill=(118, 232, 255, 140))
    if name in {"run_left", "run_right", "skateboard", "soccer_goal", "backflip", "spin"}:
        draw.rectangle((4, 45, 18, 46), fill=(255, 98, 171, 130))
    if name == "skateboard":
        draw.rectangle((18, 52, 38, 53), fill=(74, 82, 110, 255))
        draw.rectangle((22, 54, 23, 55), fill=(210, 214, 224, 255))
        draw.rectangle((34, 54, 35, 55), fill=(210, 214, 224, 255))
    if name == "soccer_goal":
        draw.rectangle((54, 26, 60, 40), fill=(118, 232, 255, 120))
    return canvas


def load_master_source_frames(name: str):
    candidates = [
        OUTPUT_DIR / f"{name}_extended_sheet.png",
        OUTPUT_DIR / f"{name}_sheet.png",
        SOURCE_DIR / f"{name}_sheet.png",
    ]
    for candidate in candidates:
        if candidate.exists():
            try:
                return load_any_frames(candidate)
            except Exception:
                continue
    raise FileNotFoundError(name)


def build_mastered_variant(name: str):
    frames = load_master_source_frames(name)
    output = [add_ground_shadow(frame, index, width=18) for index, frame in enumerate(frames)]

    if name in DEVICE_DESK_MASTER_NAMES:
        output = [master_device_desk_scene(frame, index, name) for index, frame in enumerate(output)]
    if name in WALL_CLIMB_MASTER_NAMES:
        output = [master_wall_scene(frame, index, name) for index, frame in enumerate(output)]
    if name in EMOTION_GESTURE_MASTER_NAMES:
        output = [master_emotion_scene(frame, index, name) for index, frame in enumerate(output)]
    if name in SMOKE_POWER_MASTER_NAMES:
        output = [master_smoke_power_scene(frame, index, name) for index, frame in enumerate(output)]
    if name in MOVEMENT_SPORT_MASTER_NAMES:
        output = [master_movement_sport_scene(frame, index, name) for index, frame in enumerate(output)]

    compose_strip(output, f"{name}_mastered")


def build_loop_extended(base_frames):
    output = []
    count = len(base_frames)
    for index, frame in enumerate(base_frames):
        output.append(frame.copy())
        output.append(blend_frames(frame, base_frames[(index + 1) % count], 0.5))
    if count <= 4:
        output.extend(frame.copy() for frame in base_frames)
    return output


def build_nonloop_extended(base_frames):
    output = [base_frames[0].copy()]
    for index, frame in enumerate(base_frames):
        output.append(frame.copy())
        if index < len(base_frames) - 1:
            output.append(blend_frames(frame, base_frames[index + 1], 0.5))
    hold_count = 4 if len(base_frames) <= 4 else 3
    output.extend(base_frames[-1].copy() for _ in range(hold_count))
    return output


def extend_frames(base_name: str, frames):
    if base_name in NON_LOOPING_NAMES:
        output = build_nonloop_extended(frames)
    else:
        output = build_loop_extended(frames)

    if base_name in GLOW_SCREEN_NAMES:
        output = [add_screen_glow(frame, index) for index, frame in enumerate(output)]
    if base_name in WALL_SHADOW_NAMES:
        output = [add_wall_shadow(frame, index) for index, frame in enumerate(output)]
    if base_name in DESK_PROP_NAMES:
        output = [add_desk_prop_shadow(frame, index) for index, frame in enumerate(output)]
    return output


def build_extended_variant(base_name: str, frames):
    compose_strip(extend_frames(base_name, frames), f"{base_name}_extended")


def add_soccer_elements(frame: Image.Image, frame_index: int):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    post = (224, 228, 236, 255)
    net = (96, 146, 220, 180)
    grass = (84, 142, 72, 255)
    shadow = (28, 21, 29, 185)
    goal_left = 47
    draw.rectangle((goal_left, 26, goal_left + 1, 49), fill=post)
    draw.rectangle((goal_left, 26, 60, 27), fill=post)
    draw.rectangle((goal_left + 11, 27, goal_left + 11, 49), fill=post)
    for offset in range(4):
        draw.rectangle((goal_left + 2 + offset * 3, 30 + (offset % 2), goal_left + 2 + offset * 3, 47 - (offset % 2)), fill=net)
    draw.rectangle((0, 56, 63, 57), fill=grass)
    draw.rectangle((0, 58, 63, 58), fill=shadow)

    ball_x_positions = [20, 23, 26, 30, 35, 41, 47, 51, 54, 56, 57, 57, 57, 57, 57, 57]
    ball_y_positions = [49, 49, 48, 47, 45, 42, 39, 36, 34, 33, 32, 32, 32, 32, 32, 32]
    ball_x = ball_x_positions[frame_index]
    ball_y = ball_y_positions[frame_index]
    draw.ellipse((ball_x, ball_y, ball_x + 5, ball_y + 5), fill=(245, 246, 248, 255))
    draw.rectangle((ball_x + 2, ball_y + 1, ball_x + 3, ball_y + 2), fill=(43, 44, 49, 255))
    if frame_index >= 9:
        flash = (120, 234, 255, 130 + (frame_index % 3) * 35)
        draw.rectangle((53, 28, 60, 40), fill=flash)
    return canvas


def add_smoke_shell(frame: Image.Image, frame_index: int, drift_x: int = 0, reveal: float = 0.0):
    canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    dark = (5, 5, 8, 246)
    mid = (14, 14, 20, 230)
    soft = (32, 32, 42, 150)
    twist = (52, 52, 64, 96)
    phase = frame_index / 15.0
    vertical_rise = int(phase * 8)
    centers = [
        (20 + drift_x, 39 - vertical_rise),
        (29 + drift_x, 31 - vertical_rise),
        (39 + drift_x, 37 - vertical_rise),
        (25 + drift_x, 22 - vertical_rise // 2),
        (35 + drift_x, 24 - vertical_rise // 2),
        (16 + drift_x, 31 - vertical_rise // 3),
        (44 + drift_x, 30 - vertical_rise // 3),
    ]
    for idx, (cx, cy) in enumerate(centers):
        rx = 6 + ((frame_index + idx) % 3) * 2
        ry = 5 + ((frame_index + idx * 2) % 4) * 2
        fill = dark if idx % 2 == 0 else mid
        draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=fill)
    wisp_rows = [
        (10 + drift_x, 24 - vertical_rise // 2, 20 + drift_x, 28 - vertical_rise // 2),
        (40 + drift_x, 20 - vertical_rise // 2, 52 + drift_x, 24 - vertical_rise // 2),
        (12 + drift_x, 46 - vertical_rise, 26 + drift_x, 50 - vertical_rise),
        (34 + drift_x, 44 - vertical_rise, 50 + drift_x, 48 - vertical_rise),
    ]
    for left, top, right, bottom in wisp_rows:
        draw.ellipse((left, top, right, bottom), fill=soft)
    draw.arc((15 + drift_x, 18 - vertical_rise // 2, 45 + drift_x, 46 - vertical_rise // 2),
             start=220, end=340, fill=twist, width=1)
    draw.arc((11 + drift_x, 24 - vertical_rise // 3, 49 + drift_x, 54 - vertical_rise // 3),
             start=20, end=150, fill=soft, width=1)
    if reveal > 0:
        alpha = int(110 * reveal)
        draw.ellipse((24 + drift_x, 24 - vertical_rise // 2, 36 + drift_x, 38 - vertical_rise // 2),
                     fill=(210, 210, 220, alpha // 3))
    return canvas


def build_smoke_burst():
    vanish_frames = load_any_frames(SOURCE_DIR / "vanish_sheet.png")
    frames = build_nonloop_extended(vanish_frames)
    frames = [add_smoke_shell(frame, index, drift_x=(index // 3) - 2, reveal=max(0, 0.35 - index * 0.02)) for index, frame in enumerate(frames)]
    compose_strip(frames, "smoke_burst")


def build_smoke_reform():
    vanish_frames = load_any_frames(SOURCE_DIR / "vanish_sheet.png")
    frames = list(reversed(build_nonloop_extended(vanish_frames)))[:16]
    frames = [add_smoke_shell(frame, index, drift_x=2 - (index // 4), reveal=min(0.65, index * 0.05)) for index, frame in enumerate(frames)]
    compose_strip(frames, "smoke_reform")


def build_smoke_drift():
    base = build_loop_extended(load_any_frames(SOURCE_DIR / "vanish_sheet.png"))[:16]
    frames = []
    for index, frame in enumerate(base):
        frames.append(add_smoke_shell(frame, index, drift_x=-10 + index, reveal=0.12))
    compose_strip(frames, "smoke_drift")


def build_smoke_orbit():
    base = build_loop_extended(load_any_frames(SOURCE_DIR / "vanish_sheet.png"))[:16]
    frames = []
    offsets = [0, 2, 4, 5, 6, 5, 3, 1, -1, -3, -5, -6, -5, -3, -1, 0]
    for index, frame in enumerate(base):
        frames.append(add_smoke_shell(frame, index, drift_x=offsets[index], reveal=0.04))
    compose_strip(frames, "smoke_orbit")


def add_psonic_fx(frame: Image.Image, frame_index: int, intense: bool = False):
    canvas = frame.copy()
    draw = ImageDraw.Draw(canvas)
    cyan = (120, 234, 255, 220)
    magenta = (255, 96, 170, 200)
    violet = (98, 72, 181, 180)
    gold = (255, 214, 110, 190)
    center_x = 28 + (frame_index % 3 - 1)
    center_y = 25 + (frame_index % 2)
    draw.ellipse((center_x - 12, center_y - 11, center_x + 12, center_y + 11), outline=violet if intense else cyan)
    draw.rectangle((center_x + 10, center_y - 1, 60, center_y + 1), fill=cyan)
    draw.rectangle((center_x + 6, center_y - 3, 58, center_y - 2), fill=magenta)
    draw.rectangle((center_x + 8, center_y + 3, 56, center_y + 4), fill=gold if intense else violet)
    if intense:
        draw.rectangle((6, 12, 12, 13), fill=magenta)
        draw.rectangle((10, 42, 16, 43), fill=cyan)
        draw.rectangle((18, 8, 21, 9), fill=gold)
    return canvas


def build_psonic_charge():
    laser_frames = load_any_frames(SOURCE_DIR / "laser_sheet.png")
    frames = build_nonloop_extended(laser_frames)
    frames = [add_psonic_fx(frame, index, intense=False) for index, frame in enumerate(frames)]
    compose_strip(frames, "psonic_charge")


def build_psonic_overload():
    laser_frames = load_any_frames(SOURCE_DIR / "laser_sheet.png")
    glitch_frames = load_any_frames(SOURCE_DIR / "glitch_sheet.png")
    base = laser_frames + glitch_frames[:4] + list(reversed(laser_frames[:4])) + glitch_frames[4:]
    frames = [add_psonic_fx(frame, index, intense=True) for index, frame in enumerate(base[:18])]
    compose_strip(frames, "psonic_overload")


def build_soccer_goal():
    run_frames = load_any_frames(SOURCE_DIR / "run_right_sheet.png")
    happy_frames = load_any_frames(SOURCE_DIR / "happy_sheet.png")
    celebration_frames = [run_frames[0], run_frames[1], run_frames[2], run_frames[3], run_frames[4], run_frames[5],
                          happy_frames[0], happy_frames[1], happy_frames[2], happy_frames[3], happy_frames[4], happy_frames[5],
                          happy_frames[0], happy_frames[1], happy_frames[2], happy_frames[3]]
    celebration_frames = [add_soccer_elements(frame, index) for index, frame in enumerate(celebration_frames)]
    compose_strip(celebration_frames, "soccer_goal")


def build_portal_walk():
    walk_frames = load_any_frames(SOURCE_DIR / "walk_right_sheet.png")
    vanish_frames = load_any_frames(SOURCE_DIR / "vanish_sheet.png")
    base = [
        walk_frames[0], walk_frames[1], walk_frames[2], walk_frames[3], walk_frames[4], walk_frames[5],
        walk_frames[2], walk_frames[3], walk_frames[4], walk_frames[5],
        vanish_frames[0], vanish_frames[1], vanish_frames[2], vanish_frames[3], vanish_frames[4], vanish_frames[5],
    ]
    frames = []
    for index, frame in enumerate(base):
        canvas = frame.copy()
        draw = ImageDraw.Draw(canvas)
        portal_w = 10 + min(index, 8)
        portal_h = 22 + min(index, 8) * 2
        portal_left = 46 - min(index, 6)
        portal_top = 18 - min(index // 3, 3)
        draw_green_portal(draw, portal_left, portal_top, portal_w, portal_h, index, alpha_scale=0.75 + min(index, 8) * 0.03)
        if index >= 9:
            fade = max(0, 150 - (index - 9) * 24)
            draw.rectangle((26, 18, 46, 52), fill=(24, 60, 38, fade))
        frames.append(canvas)
    compose_strip(frames, "portal_walk")


def build_skyfall():
    fall_frames = load_any_frames(SOURCE_DIR / "fall_sheet.png")
    drop_frames = load_any_frames(SOURCE_DIR / "drop_sheet.png")
    base = [
        fall_frames[0], fall_frames[1], fall_frames[2], fall_frames[3], fall_frames[4], fall_frames[5],
        drop_frames[0], drop_frames[1], drop_frames[2], drop_frames[3], drop_frames[4], drop_frames[5],
        fall_frames[3], fall_frames[4], drop_frames[4], drop_frames[5],
    ]
    frames = []
    for index, frame in enumerate(base):
        canvas = frame.copy()
        draw = ImageDraw.Draw(canvas)
        streak = (140, 255, 174, 180 if index < 10 else 120)
        for offset in range(3):
            x = 10 + offset * 8 + (index % 3)
            draw.rectangle((x, 7 + offset * 3, x + 1, 22 + offset * 5), fill=streak)
        if index < 6:
            draw.rectangle((29, 2, 34, 4), fill=(180, 255, 192, 210))
        if index >= 10:
            draw.rectangle((20, 54, 42, 56), fill=(48, 38, 33, 170))
        frames.append(canvas)
    compose_strip(frames, "skyfall")


def build_landing_recover():
    drop_frames = load_any_frames(SOURCE_DIR / "drop_sheet.png")
    stretch_frames = load_any_frames(SOURCE_DIR / "stretch_sheet.png")
    happy_frames = load_any_frames(SOURCE_DIR / "happy_sheet.png")
    base = [
        drop_frames[4], drop_frames[5], drop_frames[5],
        stretch_frames[0], stretch_frames[1], stretch_frames[2], stretch_frames[3], stretch_frames[4], stretch_frames[5],
        happy_frames[0], happy_frames[1], happy_frames[2], happy_frames[3], happy_frames[4],
    ]
    frames = []
    for index, frame in enumerate(base):
        canvas = add_ground_shadow(frame, index, width=20)
        draw = ImageDraw.Draw(canvas)
        if index < 5:
            dust = (92, 86, 72, 150)
            draw.ellipse((14, 49, 26, 55), fill=dust)
            draw.ellipse((34, 49, 48, 55), fill=dust)
        if 5 <= index <= 8:
            draw.rectangle((16, 17, 19, 18), fill=(182, 170, 145, 190))
            draw.rectangle((42, 16, 45, 17), fill=(182, 170, 145, 190))
        frames.append(canvas)
    compose_strip(frames, "landing_recover")


def main():
    for scene in PROP_CLEAN_OUTPUTS:
        draw_prop_clean_scene(scene)
    for scene in SCREEN_REWRITE_OUTPUTS:
        if scene not in {"terminal_trace", "signal_decode", "shoulder_scan"}:
            draw_backdesk_scene(scene)
    draw_backdesk_scene("terminal_trace")
    draw_backdesk_scene("signal_decode")
    draw_backdesk_scene("shoulder_scan")
    for scene in WALL_CLEAN_OUTPUTS:
        draw_wall_clean_scene(scene)
    for scene in SLEEP_SCENE_OUTPUTS:
        build_sleep_scene(scene)
    for scene in EMOTION_SCENE_OUTPUTS:
        build_emotion_scene(scene)
    for scene in GRAFFITI_CLEAN_OUTPUTS:
        build_graffiti_scene(scene)
    build_bow_clean()
    build_tongue_clean()
    build_variant("tongue", "taunt_signal", [add_taunt_overlay])
    build_variant("monitor_lurk", "question_lurk", [add_question_overlay])
    build_variant("terminal_type", "question_type", [lambda frame, index: add_glitch_overlay(add_question_overlay(frame, index, -2), index, 1)])
    build_variant("file_scan", "dossier_check", [add_dossier_overlay, lambda frame, index: add_question_overlay(frame, index, 1)])
    build_variant("bug_sweep", "signal_sweep", [lambda frame, index: add_glitch_overlay(frame, index, 2), lambda frame, index: add_question_overlay(frame, index, -1)])

    portal_frames = smooth_sequence(load_frames("portal"), reverse=True, hold_first=2, hold_last=2)
    portal_frames = [add_portal_glow(frame, index) for index, frame in enumerate(portal_frames)]
    compose_strip(portal_frames, "portal_entry_smooth")

    fridge_frames = smooth_sequence(load_frames("fridge_open"), hold_first=1, hold_last=2)
    fridge_frames = [add_fridge_shadow(frame, index) for index, frame in enumerate(fridge_frames)]
    fridge_frames = [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in fridge_frames]
    compose_strip(fridge_frames, "fridge_open_smooth")

    noodle_frames = smooth_sequence(load_frames("noodle_eat"), hold_first=1, hold_last=2)
    noodle_frames = [add_noodle_support(frame, index) for index, frame in enumerate(noodle_frames)]
    compose_strip(noodle_frames, "noodle_eat_smooth")

    desk_frames = smooth_sequence(load_frames("desk_noodles"), hold_first=1, hold_last=2)
    desk_frames = [add_desk_support(frame, index) for index, frame in enumerate(desk_frames)]
    compose_strip(desk_frames, "desk_noodles_smooth")

    for source_path in sorted(SOURCE_DIR.glob("*_sheet.png")):
        if source_path.name == "gboy_master_sheet.png":
            continue
        base_name = source_path.stem.replace("_sheet", "")
        if base_name in CUSTOM_VARIANT_SOURCES:
            continue
        build_extended_variant(base_name, load_any_frames(source_path))

    build_extended_variant("question_lurk", load_any_frames(OUTPUT_DIR / "question_lurk_sheet.png"))
    build_extended_variant("question_type", load_any_frames(OUTPUT_DIR / "question_type_sheet.png"))
    build_extended_variant("dossier_check", load_any_frames(OUTPUT_DIR / "dossier_check_sheet.png"))
    build_extended_variant("signal_sweep", load_any_frames(OUTPUT_DIR / "signal_sweep_sheet.png"))
    build_smoke_burst()
    build_smoke_reform()
    build_smoke_drift()
    build_smoke_orbit()
    build_psonic_charge()
    build_psonic_overload()
    build_soccer_goal()
    build_portal_walk()
    build_skyfall()
    build_landing_recover()
    for mastered_name in MASTERED_BATCH_NAMES:
        build_mastered_variant(mastered_name)


if __name__ == "__main__":
    main()
