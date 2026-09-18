"""
Generate stylized reference-image placeholder cards for the FSL Learn
"Colors" lesson (intermediate difficulty).

All six colors are STATIC hand signs whose frozen handshapes match a
letter the static GestureRecognizer already detects (X, B, G, C, P, Y),
so the app can verify them live with the camera.

Outputs to assets/fsl/colors/:
  red.png, blue.png, green.png, orange.png, purple.png, yellow.png
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(r"C:\Projects\fsl_learn\assets\fsl\colors")
OUT.mkdir(parents=True, exist_ok=True)

SIZE = 512
MARGIN = 40
CORNER = 36

# Each theme draws a hand holding the handshape letter next to a color swatch.
# (bg_top, bg_bot, fg, label, handshape_letter, swipe_color)
THEMES = {
    "red": {
        "bg_top": (0x7F, 0x1D, 0x1D), "bg_bot": (0xEF, 0x44, 0x44),
        "fg": (255, 255, 255), "label": "RED", "letter": "X",
        "swatch": (0x2A, 0x0A, 0x0A),
    },
    "blue": {
        "bg_top": (0x1E, 0x3A, 0x8A), "bg_bot": (0x3B, 0x82, 0xF6),
        "fg": (255, 255, 255), "label": "BLUE", "letter": "B",
        "swatch": (0x0D, 0x1B, 0x45),
    },
    "green": {
        "bg_top": (0x16, 0x53, 0x2A), "bg_bot": (0x22, 0xC5, 0x5E),
        "fg": (255, 255, 255), "label": "GREEN", "letter": "G",
        "swatch": (0x0A, 0x33, 0x1C),
    },
    "orange": {
        "bg_top": (0x92, 0x40, 0x0E), "bg_bot": (0xFB, 0x92, 0x3C),
        "fg": (255, 255, 255), "label": "ORANGE", "letter": "C",
        "swatch": (0x4A, 0x24, 0x0A),
    },
    "purple": {
        "bg_top": (0x53, 0x0E, 0x68), "bg_bot": (0xA8, 0x55, 0xF7),
        "fg": (255, 255, 255), "label": "PURPLE", "letter": "P",
        "swatch": (0x2C, 0x0A, 0x38),
    },
    "yellow": {
        "bg_top": (0x78, 0x50, 0x0F), "bg_bot": (0xF9, 0xC7, 0x4F),
        "fg": (0x33, 0x27, 0x07), "label": "YELLOW", "letter": "Y",
        "swatch": (0x4A, 0x32, 0x0A),
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


def hand_silhouette(draw, cx, cy, w, h, color):
    """Right-facing open ASL-style hand: palm + 4 fingers + thumb."""
    finger_w = int(w * 0.22)
    finger_h = int(h * 0.72)
    gap = int(finger_w * 0.4)
    total = 4 * finger_w + 3 * gap
    x0 = cx - total // 2

    for i in range(4):
        x = x0 + i * (finger_w + gap)
        y = cy - finger_h - int(h * 0.06)
        draw.rounded_rectangle(
            [x, y, x + finger_w, y + finger_h],
            radius=finger_w // 2,
            fill=color,
        )

    thumb_w = int(finger_w * 0.95)
    thumb_h = int(finger_h * 0.62)
    tx = x0 - int(gap * 0.7) - thumb_w
    ty = cy - int(h * 0.05)
    draw.rounded_rectangle(
        [tx, ty, tx + thumb_w, ty + thumb_h],
        radius=thumb_w // 2,
        fill=color,
    )

    draw.rounded_rectangle(
        [x0 - 2, cy - int(h * 0.05), x0 + total + 2, cy + h],
        radius=int(w * 0.16),
        fill=color,
    )


def letter_badge(draw, cx, cy, size, letter, color):
    """A filled round badge with the static handshape letter on it."""
    r = size // 2
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    try:
        font = ImageFont.truetype("arialbd.ttf", int(size * 0.62))
    except OSError:
        try:
            font = ImageFont.truetype("arial.ttf", int(size * 0.62))
        except OSError:
            font = ImageFont.load_default()
    bbox = draw.textbbox((0, 0), letter, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(
        (cx - tw // 2 - bbox[0], cy - th // 2 - bbox[1]),
        letter, fill=(255, 255, 255), font=font,
    )


def make_card(name, theme):
    bg = gradient_bg(SIZE, SIZE, theme["bg_top"], theme["bg_bot"])

    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=CORNER, fill=255)

    card = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    card.paste(bg, mask=mask)

    draw = ImageDraw.Draw(card)
    cx, cy = SIZE // 2, SIZE // 2 - 26

    # Hand on the left, its handshape letter badge on the right.
    hand_w, hand_h = int(SIZE * 0.34), int(SIZE * 0.28)
    hand_silhouette(draw, cx - int(SIZE * 0.22), cy + int(SIZE * 0.06), hand_w, hand_h, theme["fg"])
    letter_badge(draw, cx + int(SIZE * 0.24), cy, int(SIZE * 0.30), theme["letter"], theme["swatch"])

    # Label at bottom
    label = theme["label"]
    font_size = 34
    try:
        font = ImageFont.truetype("arial.ttf", font_size)
    except OSError:
        font = ImageFont.load_default()

    bbox = draw.textbbox((0, 0), label, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (SIZE - tw) // 2
    ty = SIZE - MARGIN - th - 8
    draw.text((tx, ty), label, fill=theme["fg"], font=font)

    return card.convert("RGB")


def main():
    for name, theme in THEMES.items():
        img = make_card(name, theme)
        path = OUT / f"{name}.png"
        img.save(path, "PNG")
        print(f"  {path.name}  ({SIZE}x{SIZE})")
    print("Done - colors reference images generated.")


if __name__ == "__main__":
    main()