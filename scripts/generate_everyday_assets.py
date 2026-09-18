"""
Generate stylized reference-image placeholder cards for the FSL Learn
"Everyday Communication" lesson (intermediate difficulty).

Outputs to assets/fsl/everyday/:
  yes.png, no.png, please.png, sorry.png, excuse_me.png,
  good_morning.png, good_night.png, love.png, welcome.png,
  water.png, eat.png, drink.png
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

OUT = Path(r"C:\Projects\fsl_learn\assets\fsl\everyday")
OUT.mkdir(parents=True, exist_ok=True)

SIZE = 512
MARGIN = 40
CORNER = 36

# (bg_top, bg_bot, pictogram_color, label_color, label, draw_fn)
THEMES = {
    "yes": {
        "bg_top": (0x16, 0x53, 0x2A), "bg_bot": (0x22, 0xC5, 0x5E),
        "fg": (255, 255, 255), "label_color": (255, 255, 255),
        "label": "YES", "draw": "yes",
    },
    "no": {
        "bg_top": (0x7F, 0x1D, 0x1D), "bg_bot": (0xEF, 0x44, 0x44),
        "fg": (255, 255, 255), "label_color": (255, 255, 255),
        "label": "NO", "draw": "no",
    },
    "please": {
        "bg_top": (0x1E, 0x3A, 0x8A), "bg_bot": (0x3B, 0x82, 0xF6),
        "fg": (255, 255, 255), "label_color": (255, 255, 255),
        "label": "PLEASE", "draw": "please",
    },
    "sorry": {
        "bg_top": (0x9F, 0x12, 0x39), "bg_bot": (0xE1, 0x1D, 0x48),
        "fg": (255, 255, 255), "label_color": (255, 255, 255),
        "label": "SORRY", "draw": "sorry",
    },
    "excuse_me": {
        "bg_top": (0x92, 0x40, 0x0E), "bg_bot": (0xF5, 0x9E, 0x0B),
        "fg": (255, 255, 255), "label_color": (255, 255, 255),
        "label": "EXCUSE ME", "draw": "excuse_me",
    },
    "good_morning": {
        "bg_top": (0x9A, 0x34, 0x12), "bg_bot": (0xFB, 0x92, 0x3C),
        "fg": (255, 255, 255), "label_color": (255, 255, 255),
        "label": "GOOD MORNING", "draw": "sun",
    },
    "good_night": {
        "bg_top": (0x31, 0x2E, 0x81), "bg_bot": (0x63, 0x66, 0xF1),
        "fg": (255, 255, 255), "label_color": (255, 255, 255),
        "label": "GOOD NIGHT", "draw": "moon",
    },
    "love": {
        "bg_top": (0x9D, 0x17, 0x4D), "bg_bot": (0xA8, 0x55, 0xF7),
        "fg": (255, 255, 255), "label_color": (255, 255, 255),
        "label": "LOVE", "draw": "heart",
    },
    "welcome": {
        "bg_top": (0x0F, 0x76, 0x6E), "bg_bot": (0x2D, 0xD4, 0xBF),
        "fg": (255, 255, 255), "label_color": (255, 255, 255),
        "label": "WELCOME", "draw": "welcome",
    },
    "water": {
        "bg_top": (0x0E, 0x74, 0x90), "bg_bot": (0x22, 0xD3, 0xEE),
        "fg": (255, 255, 255), "label_color": (255, 255, 255),
        "label": "WATER", "draw": "drop",
    },
    "eat": {
        "bg_top": (0x92, 0x40, 0x0E), "bg_bot": (0xFB, 0xBF, 0x24),
        "fg": (255, 255, 255), "label_color": (255, 255, 255),
        "label": "EAT", "draw": "eat",
    },
    "drink": {
        "bg_top": (0x15, 0x52, 0x75), "bg_bot": (0x38, 0xBD, 0xF8),
        "fg": (255, 255, 255), "label_color": (255, 255, 255),
        "label": "DRINK", "draw": "drink",
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

    # fingers
    for i in range(4):
        x = x0 + i * (finger_w + gap)
        y = cy - finger_h - int(h * 0.06)
        draw.rounded_rectangle(
            [x, y, x + finger_w, y + finger_h],
            radius=finger_w // 2,
            fill=color,
        )

    # thumb (left, angled inward)
    thumb_w = int(finger_w * 0.95)
    thumb_h = int(finger_h * 0.62)
    tx = x0 - int(gap * 0.7) - thumb_w
    ty = cy - int(h * 0.05)
    draw.rounded_rectangle(
        [tx, ty, tx + thumb_w, ty + thumb_h],
        radius=thumb_w // 2,
        fill=color,
    )

    # palm
    draw.rounded_rectangle(
        [x0 - 2, cy - int(h * 0.05), x0 + total + 2, cy + h],
        radius=int(w * 0.16),
        fill=color,
    )


def draw_yes(draw, cx, cy, size, color):
    r = size // 2
    lw = max(6, size // 14)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=lw)
    # check mark
    draw.line(
        [(cx - r * 0.42, cy - 2), (cx - r * 0.08, cy + r * 0.34), (cx + r * 0.5, cy - r * 0.38)],
        fill=color, width=lw,
    )
    draw.ellipse(
        [cx - r * 0.08 - lw // 2, cy + r * 0.34 - lw // 2,
         cx - r * 0.08 + lw // 2, cy + r * 0.34 + lw // 2],
        fill=color,
    )


def draw_no(draw, cx, cy, size, color):
    r = size // 2
    lw = max(6, size // 14)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=lw)
    # X crossing
    r2 = int(r * 0.55)
    draw.line([(cx - r2, cy - r2), (cx + r2, cy + r2)], fill=color, width=lw)
    draw.line([(cx - r2, cy + r2), (cx + r2, cy - r2)], fill=color, width=lw)


def draw_please(draw, cx, cy, size, color):
    w = int(size * 0.62)
    h = int(size * 0.52)
    hand_silhouette(draw, cx, cy - size // 14, w, h, color)


def draw_sorry(draw, cx, cy, size, color):
    # heart outline with a small hand resting on it (ask for forgiveness)
    r = size // 2
    # heart via two circles + triangle
    hw = int(r * 0.9)
    hh = int(r * 0.72)
    c1 = (cx - hw // 2, cy - int(r * 0.14))
    c2 = (cx + hw // 2, cy - int(r * 0.14))
    cr = int(r * 0.42)
    draw.ellipse([c1[0] - cr, c1[1] - cr, c1[0] + cr, c1[1] + cr], outline=color, width=8)
    draw.ellipse([c2[0] - cr, c2[1] - cr, c2[0] + cr, c2[1] + cr], outline=color, width=8)
    # connecting triangle outline
    pts = [(c1[0] - cr + 2, c1[1] + int(cr * 0.3)),
           (c2[0] + cr - 2, c2[1] + int(cr * 0.3)),
           (cx, cy + int(r * 0.62))]
    for i in range(3):
        a, b = pts[i], pts[(i + 1) % 3]
        draw.line([a, b], fill=color, width=8)
    # hand in bottom-right corner of the heart
    hand_silhouette(draw, cx - int(r * 0.35), cy + int(r * 0.12), int(size * 0.34), int(size * 0.26), color)


def draw_excuse_me(draw, cx, cy, size, color):
    w = int(size * 0.52)
    h = int(size * 0.44)
    hand_silhouette(draw, cx - size // 10, cy, w, h, color)
    # two "waving" arcs above the hand
    lw = max(5, size // 18)
    for dx in (-15, 15):
        ax = cx + int(size * 0.16 * (1 if dx > 0 else -1))
        ay = cy - int(size * 0.22)
        draw.arc(
            [ax - size // 5, ay - size // 5, ax + size // 5, ay + size // 5],
            start=200, end=340, fill=color, width=lw,
        )


def draw_sun(draw, cx, cy, size, color):
    r = size // 3
    lw = max(6, size // 16)
    # rays
    for ang_deg in range(0, 360, 45):
        ang = math.radians(ang_deg)
        x1 = cx + math.cos(ang) * r
        y1 = cy + math.sin(ang) * r
        x2 = cx + math.cos(ang) * (r + size // 6)
        y2 = cy + math.sin(ang) * (r + size // 6)
        draw.line([(x1, y1), (x2, y2)], fill=color, width=lw)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)


def draw_moon(draw, cx, cy, size, color):
    r = size // 2
    # build crescent on a separate layer so we can erase cleanly
    moon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    m = ImageDraw.Draw(moon)
    m.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    erase = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    er = ImageDraw.Draw(erase)
    er.ellipse([cx - int(r * 0.1), cy - int(r * 0.55), cx + int(r * 1.15), cy + int(r * 0.75)], fill=(0, 0, 0, 255))
    moon = Image.composite(moon, Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), erase.split()[3])
    draw.bitmap((0, 0), moon.convert("L"), fill=color)
    # stars
    for (sx, sy, sr) in [
        (cx + r * 1.15, cy - r * 0.9, 5),
        (cx - r * 1.05, cy - r * 0.5, 4),
        (cx + r * 1.25, cy + r * 0.35, 3),
    ]:
        draw.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=color)


def draw_heart(draw, cx, cy, size, color):
    r = size // 2
    hw = int(r * 0.95)
    cr = int(r * 0.46)
    c1 = (cx - hw // 2, cy - int(r * 0.12))
    c2 = (cx + hw // 2, cy - int(r * 0.12))
    draw.ellipse([c1[0] - cr, c1[1] - cr, c1[0] + cr, c1[1] + cr], fill=color)
    draw.ellipse([c2[0] - cr, c2[1] - cr, c2[0] + cr, c2[1] + cr], fill=color)
    draw.polygon([
        (c1[0] - cr + 1, c1[1]),
        (c2[0] + cr - 1, c2[1]),
        (cx, cy + int(r * 0.72)),
    ], fill=color)


def draw_welcome(draw, cx, cy, size, color):
    # open doorway arch
    lw = max(6, size // 16)
    aw = int(size * 0.6)
    ah = int(size * 0.62)
    x0 = cx - aw // 2
    y1 = cy - ah // 2
    y0 = y1 + int(ah * 0.35)
    draw.arc([x0, y0, x0 + aw, y0 + ah], start=180, end=360, fill=color, width=lw)  # arch top
    draw.line([(x0, y0 + ah // 2), (x0, y0 + ah)], fill=color, width=lw)  # door frames
    draw.line([(x0 + aw, y0 + ah // 2), (x0 + aw, y0 + ah)], fill=color, width=lw)
    # welcome mat
    draw.line([(cx - aw // 2, y0 + ah + 8), (cx + aw // 2, y0 + ah + 8)], fill=color, width=lw)
    # open hand inside the archway
    hand_silhouette(draw, cx, y0 + int(ah * 0.28), int(size * 0.42), int(size * 0.34), color)


def draw_drop(draw, cx, cy, size, color):
    r = size // 2
    # teardrop: circle bottom + triangle top
    rr = int(r * 0.62)
    base_y = cy + int(r * 0.26)
    draw.ellipse([cx - rr, base_y - rr, cx + rr, base_y + rr], fill=color)
    draw.polygon([
        (cx, cy - r * 0.55),
        (cx - rr, base_y - int(rr * 0.1)),
        (cx + rr, base_y - int(rr * 0.1)),
    ], fill=color)
    # shine
    draw.ellipse([cx - rr // 2, base_y - rr // 2 - 4, cx - rr // 8, base_y - 4], fill=(255, 255, 255))


def draw_eat(draw, cx, cy, size, color):
    lw = max(6, size // 16)
    bw = int(size * 0.72)
    bh = int(size * 0.38)
    x0 = cx - bw // 2
    y0 = cy - int(size * 0.08)
    # bowl: lower half semicircle
    draw.pieslice([x0, y0 - bh, x0 + bw, y0 + bh], start=0, end=180, fill=color)
    draw.line([(x0, y0), (x0 + bw, y0)], fill=color, width=lw)
    # chopsticks
    cx0 = cx - int(size * 0.16)
    draw.line([(cx0, y0 + 6), (cx0 - int(size * 0.2), cy - int(size * 0.4))], fill=color, width=lw)
    draw.line([(cx0 + int(size * 0.06), y0), (cx0 + int(size * 0.1), cy - int(size * 0.44))], fill=color, width=lw)


def draw_drink(draw, cx, cy, size, color):
    lw = max(6, size // 16)
    w = int(size * 0.5)
    h = int(size * 0.52)
    x0 = cx - w // 2
    y0 = cy - h // 2
    # cup
    draw.rounded_rectangle([x0, y0, x0 + w, y0 + h], radius=10, outline=color, width=lw)
    # straw
    sx = cx + int(w * 0.26)
    draw.line([(sx, y0 + 6), (sx + int(size * 0.12), y0 - int(size * 0.18))], fill=color, width=lw)
    # handle
    draw.arc([x0 + w - 4, y0 + int(h * 0.18), x0 + w + int(size * 0.22), y0 + int(h * 0.7)],
             start=270, end=90, fill=color, width=lw)


DRAWERS = {
    "yes": draw_yes,
    "no": draw_no,
    "please": draw_please,
    "sorry": draw_sorry,
    "excuse_me": draw_excuse_me,
    "sun": draw_sun,
    "moon": draw_moon,
    "heart": draw_heart,
    "welcome": draw_welcome,
    "drop": draw_drop,
    "eat": draw_eat,
    "drink": draw_drink,
}


def make_card(name, theme):
    bg = gradient_bg(SIZE, SIZE, theme["bg_top"], theme["bg_bot"])

    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=CORNER, fill=255)

    card = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    card.paste(bg, mask=mask)

    draw = ImageDraw.Draw(card)
    cx, cy = SIZE // 2, SIZE // 2 - 18
    color = theme["fg"]

    DRAWERS[theme["draw"]](draw, cx, cy, int(SIZE * 0.36), color)

    # Label at bottom
    label = theme["label"]
    font_size = 34
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
    ty = SIZE - MARGIN - th - 8
    draw.text((tx, ty), label, fill=theme["label_color"], font=font)

    return card.convert("RGB")


def main():
    for name, theme in THEMES.items():
        img = make_card(name, theme)
        path = OUT / f"{name}.png"
        img.save(path, "PNG")
        print(f"  {path.name}  ({SIZE}x{SIZE})")
    print("Done - everyday communication reference images generated.")


if __name__ == "__main__":
    main()