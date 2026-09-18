"""
Generate improved emergency-sign placeholder PNGs for the FSL Learn app.

Outputs to assets/fsl/emergency/:
  help.png     – white H-cross on blue gradient, label "HELP"
  fire.png     – white flame on red gradient,  label "FIRE"
  danger.png   – black ! on yellow gradient,   label "DANGER"
  medical.png  – white cross on green gradient, label "MEDICAL"
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

OUT = Path(r"C:\Projects\fsl_learn\assets\fsl\emergency")
OUT.mkdir(parents=True, exist_ok=True)

SIZE = 512
MARGIN = 40
CORNER = 36

THEMES = {
    "help": {
        "bg_top": (0x1E, 0x3A, 0x8A),    # dark blue
        "bg_bot": (0x3B, 0x82, 0xF6),    # bright blue
        "fg": (255, 255, 255),
        "label_color": (255, 255, 255),
        "label": "HELP",
        "draw": "h_cross",
    },
    "fire": {
        "bg_top": (0x99, 0x1B, 0x1B),    # dark red
        "bg_bot": (0xDC, 0x26, 0x26),    # bright red
        "fg": (255, 255, 255),
        "label_color": (255, 255, 255),
        "label": "FIRE",
        "draw": "flame",
    },
    "danger": {
        "bg_top": (0xCA, 0x8A, 0x04),    # dark yellow
        "bg_bot": (0xFA, 0xCC, 0x15),    # bright yellow
        "fg": (0x11, 0x18, 0x27),        # near-black
        "label_color": (0x11, 0x18, 0x27),
        "label": "DANGER",
        "draw": "exclamation",
    },
    "medical": {
        "bg_top": (0x16, 0x65, 0x34),    # dark green
        "bg_bot": (0x22, 0xC5, 0x5E),    # bright green
        "fg": (255, 255, 255),
        "label_color": (255, 255, 255),
        "label": "MEDICAL",
        "draw": "cross",
    },
}


def gradient_bg(w, h, top, bot):
    img = Image.new("RGB", (w, h))
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(top[0] * (1 - t) + bot[0] * t)
        g = int(top[1] * (1 - t) + bot[1] * t)
        b = int(top[2] * (1 - t) + bot[2] * t)
        for x in range(w):
            img.putpixel((x, y), (r, g, b))
    return img


def draw_h_cross(draw, cx, cy, arm_w, arm_h, color):
    """Medical H-shaped cross."""
    draw.rounded_rectangle(
        [cx - arm_w, cy - arm_h, cx - arm_w // 2, cy + arm_h],
        radius=arm_w // 6,
        fill=color,
    )
    draw.rounded_rectangle(
        [cx + arm_w // 2, cy - arm_h, cx + arm_w, cy + arm_h],
        radius=arm_w // 6,
        fill=color,
    )
    draw.rounded_rectangle(
        [cx - arm_w, cy - arm_w // 2, cx + arm_w, cy + arm_w // 2],
        radius=arm_w // 6,
        fill=color,
    )


def draw_cross(draw, cx, cy, size, color):
    """Simple + cross (medical)."""
    t = size // 4
    draw.rounded_rectangle(
        [cx - t, cy - size, cx + t, cy + size],
        radius=t // 3,
        fill=color,
    )
    draw.rounded_rectangle(
        [cx - size, cy - t, cx + size, cy + t],
        radius=t // 3,
        fill=color,
    )


def draw_flame(draw, cx, cy, size, color):
    """Stylized flame shape using overlapping ellipses + triangle."""
    # Outer flame body
    r = size // 2
    draw.ellipse([cx - r, cy - r + size // 6, cx + r, cy + r + size // 6], fill=color)
    # Top尖
    draw.polygon([
        (cx, cy - r - size // 8),
        (cx - r // 2, cy - size // 6),
        (cx + r // 2, cy - size // 6),
    ], fill=color)
    # Inner dark cutout
    inner_r = r // 3
    cut_color = (0x99, 0x1B, 0x1B) if color == (255, 255, 255) else (0x40, 0x00, 0x00)
    draw.ellipse(
        [cx - inner_r, cy, cx + inner_r, cy + inner_r + size // 8],
        fill=cut_color,
    )


def draw_exclamation(draw, cx, cy, size, color):
    """Exclamation mark."""
    w = size // 3
    h_bar = int(size * 0.55)
    gap = size // 8
    dot_r = w // 2 + 1

    # Bar (top)
    draw.rounded_rectangle(
        [cx - w, cy - h_bar - dot_r - gap, cx + w, cy - gap],
        radius=w // 3,
        fill=color,
    )
    # Dot
    draw.ellipse(
        [cx - dot_r, cy + gap - 1, cx + dot_r, cy + gap + dot_r * 2 - 1],
        fill=color,
    )


def make_card(theme):
    bg = gradient_bg(SIZE, SIZE, theme["bg_top"], theme["bg_bot"])

    # Rounded card via mask
    mask = Image.new("L", (SIZE, SIZE), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=CORNER, fill=255)

    card = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    card.paste(bg, mask=mask)

    draw = ImageDraw.Draw(card)
    cx, cy = SIZE // 2, SIZE // 2 - 20
    icon_size = int(SIZE * 0.28)
    color = theme["fg"]

    shape = theme["draw"]
    if shape == "h_cross":
        draw_h_cross(draw, cx, cy, icon_size // 2, icon_size, color)
    elif shape == "cross":
        draw_cross(draw, cx, cy, icon_size, color)
    elif shape == "flame":
        draw_flame(draw, cx, cy, icon_size, color)
    elif shape == "exclamation":
        draw_exclamation(draw, cx, cy, icon_size, color)

    # Label at bottom
    label = theme["label"]
    label_color = theme["label_color"]
    font_size = 36
    try:
        font = ImageFont.truetype("arial.ttf", font_size)
    except OSError:
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", font_size)
        except OSError:
            font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), label, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (SIZE - tw) // 2
    ty = SIZE - MARGIN - th - 10
    draw.text((tx, ty), label, fill=label_color, font=font)

    return card.convert("RGB")


def main():
    for name, theme in THEMES.items():
        img = make_card(theme)
        path = OUT / f"{name}.png"
        img.save(path, "PNG")
        print(f"  {path.name}  ({SIZE}×{SIZE})")
    print("Done — emergency placeholder images regenerated.")


if __name__ == "__main__":
    main()
