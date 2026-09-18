"""
Generate stylized reference-image placeholder cards for the FSL Learn
"Animals" lesson (intermediate difficulty).

All six animals are STATIC hand signs whose frozen handshapes match a
letter/number the static GestureRecognizer already detects (G, F, Y, V,
C, 5), so the app can verify them live with the camera.

Outputs to assets/fsl/animals/:
  bird.png, cat.png, cow.png, frog.png, lion.png, fish.png
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

OUT = Path(r"C:\Projects\fsl_learn\assets\fsl\animals")
OUT.mkdir(parents=True, exist_ok=True)

SIZE = 512
MARGIN = 40
CORNER = 36

# (bg_top, bg_bot, fg, label, handshape_letter, draw)
THEMES = {
    "bird": {
        "bg_top": (0x0E, 0x74, 0x90), "bg_bot": (0x22, 0xD3, 0xEE),
        "fg": (255, 255, 255), "label": "BIRD", "letter": "G", "draw": "bird",
    },
    "cat": {
        "bg_top": (0x86, 0x2B, 0x0E), "bg_bot": (0xF6, 0x8E, 0x4E),
        "fg": (255, 255, 255), "label": "CAT", "letter": "F", "draw": "cat",
    },
    "cow": {
        "bg_top": (0x52, 0x4A, 0x48), "bg_bot": (0xAD, 0xA6, 0xA2),
        "fg": (255, 255, 255), "label": "COW", "letter": "Y", "draw": "cow",
    },
    "frog": {
        "bg_top": (0x16, 0x53, 0x2A), "bg_bot": (0x34, 0xD3, 0x99),
        "fg": (255, 255, 255), "label": "FROG", "letter": "V", "draw": "frog",
    },
    "lion": {
        "bg_top": (0x92, 0x40, 0x0E), "bg_bot": (0xFD, 0xC0, 0x4C),
        "fg": (0x4A, 0x24, 0x0A), "label": "LION", "letter": "C", "draw": "lion",
    },
    "fish": {
        "bg_top": (0x15, 0x52, 0x75), "bg_bot": (0x38, 0xBD, 0xF8),
        "fg": (255, 255, 255), "label": "FISH", "letter": "5", "draw": "fish",
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


def draw_bird(draw, cx, cy, size, color):
    # Simple bird: body circle + head + open beak + wing
    lw = max(6, size // 18)
    body_r = int(size * 0.30)
    body_c = (cx - int(size * 0.08), cy + int(size * 0.10))
    draw.ellipse([body_c[0] - body_r, body_c[1] - body_r, body_c[0] + body_r, body_c[1] + body_r], fill=color)
    head_c = (cx + int(size * 0.30), cy - int(size * 0.24))
    head_r = int(size * 0.22)
    draw.ellipse([head_c[0] - head_r, head_c[1] - head_r, head_c[0] + head_r, head_c[1] + head_r], fill=color)
    # open beak
    bx = head_c[0] + head_r - int(size * 0.04)
    by = head_c[1] + int(size * 0.04)
    draw.polygon([(bx, by), (bx + int(size * 0.10), by - int(size * 0.04)),
                  (bx + int(size * 0.06), by + int(size * 0.04))], outline=color, width=lw)
    # eye
    eye_r = int(size * 0.035)
    draw.ellipse([head_c[0] + int(size * 0.06) - eye_r, head_c[1] - int(size * 0.18) - eye_r,
                  head_c[0] + int(size * 0.06) + eye_r, head_c[1] - int(size * 0.18) + eye_r], fill=color)
    # wing
    draw.pieslice([body_c[0] - body_r, body_c[1] - body_r, body_c[0] + body_r, body_c[1] + body_r],
                  200, 330, fill=color)


def draw_cat(draw, cx, cy, size, color):
    lw = max(6, size // 20)
    # head
    fr = int(size * 0.34)
    fx, fy = cx, cy - int(size * 0.04)
    draw.ellipse([fx - fr, fy - fr, fx + fr, fy + fr], fill=color)
    # ears
    for ex in (-fr, fr):
        draw.polygon([(fx + ex - int(size * 0.09), fy - fr + int(size * 0.06)),
                      (fx + ex + int(size * 0.09), fy - fr + int(size * 0.06)),
                      (fx + ex, fy - fr - int(size * 0.14))], fill=color)
    # eyes
    er = int(size * 0.028)
    for e in (-1, 1):
        draw.ellipse([fx + e * int(size * 0.14) - er, fy - int(size * 0.05) - er,
                      fx + e * int(size * 0.14) + er, fy - int(size * 0.05) + er], fill=(20, 20, 20))
    # whiskers (drawn as short arcs on both cheeks)
    for e in (-1, 1):
        for k in (-1, 0, 1):
            wy = fy + int(size * 0.10) + k * int(size * 0.06)
            wx0 = fx + e * fr - int(size * 0.06)
            wdx = e * int(size * 0.16)
            draw.line([(wx0, wy), (wx0 + wdx, wy)], fill=(20, 20, 20), width=lw // 2)


def draw_cow(draw, cx, cy, size, color):
    lw = max(6, size // 20)
    # face
    fr = int(size * 0.30)
    fx, fy = cx, cy - int(size * 0.02)
    draw.ellipse([fx - fr, fy - fr, fx + fr, fy + fr], fill=color)
    # horns (raised Y-shaped)
    draw.line([(fx - int(size * 0.18), fy - fr + int(size * 0.02)),
               (fx - int(size * 0.30), fy - fr - int(size * 0.24))], fill=color, width=lw)
    draw.line([(fx + int(size * 0.18), fy - fr + int(size * 0.02)),
               (fx + int(size * 0.30), fy - fr - int(size * 0.24))], fill=color, width=lw)
    # muzzle patch
    draw.ellipse([fx - int(size * 0.16), fy + int(size * 0.02), fx + int(size * 0.16), fy + int(size * 0.26)],
                 outline=color, width=lw // 2)
    # eyes
    er = int(size * 0.026)
    for e in (-1, 1):
        draw.ellipse([fx + e * int(size * 0.14) - er, fy - int(size * 0.10) - er,
                      fx + e * int(size * 0.14) + er, fy - int(size * 0.10) + er], fill=(20, 20, 20))


def draw_frog(draw, cx, cy, size, color):
    lw = max(6, size // 20)
    # body
    br = int(size * 0.30)
    bx, by = cx, cy + int(size * 0.12)
    draw.ellipse([bx - br, by - br * 0.8, bx + br, by + br * 0.8], fill=color)
    # eyes (bulging, one on each side)
    for e in (-1, 1):
        ex = bx + e * int(size * 0.16)
        ey = cy - int(size * 0.22)
        er = int(size * 0.10)
        draw.ellipse([ex - er, ey - er, ex + er, ey + er], fill=color)
        pr = int(size * 0.04)
        draw.ellipse([ex - pr, ey + int(size * 0.02) - pr, ex + pr, ey + int(size * 0.02) + pr],
                     fill=(20, 20, 20))
    # mouth
    draw.arc([bx - int(size * 0.24), cy + int(size * 0.18), bx + int(size * 0.24), cy + int(size * 0.42)],
             10, 170, fill=(20, 20, 20), width=lw // 2)


def draw_lion(draw, cx, cy, size, color):
    lw = max(6, size // 22)
    # mane (ring of arcs)
    mr = int(size * 0.42)
    draw.ellipse([cx - mr, cy - mr, cx + mr, cy + mr], outline=color, width=lw)
    # face
    fr = int(size * 0.24)
    draw.ellipse([cx - fr, cy - fr, cx + fr, cy + fr], fill=color)
    # ears
    for e in (-1, 1):
        draw.ellipse([cx + e * int(size * 0.16) - int(size * 0.05), cy - fr - int(size * 0.07),
                      cx + e * int(size * 0.16) + int(size * 0.05), cy - fr + int(size * 0.05)], fill=color)
    # eyes
    er = int(size * 0.022)
    for e in (-1, 1):
        draw.ellipse([cx + e * int(size * 0.10) - er, cy - int(size * 0.05) - er,
                      cx + e * int(size * 0.10) + er, cy - int(size * 0.05) + er], fill=(20, 20, 20))


def draw_fish(draw, cx, cy, size, color):
    lw = max(6, size // 20)
    w = int(size * 0.62)
    h = int(size * 0.34)
    x0 = cx - w // 2
    y0 = cy - h // 2
    draw.ellipse([x0, y0, x0 + w, y0 + h], fill=color)
    # tail
    tx = x0 - int(size * 0.02)
    draw.polygon([(tx, cy), (tx - int(size * 0.20), cy - int(size * 0.22)),
                  (tx - int(size * 0.20), cy + int(size * 0.22))], fill=color)
    # eye
    er = int(size * 0.02)
    draw.ellipse([x0 + int(w * 0.62) - er, cy - int(size * 0.05) - er,
                  x0 + int(w * 0.62) + er, cy - int(size * 0.05) + er], fill=(20, 20, 20))
    # gill + fin line
    draw.line([(x0 + int(w * 0.55), y0 + int(h * 0.1)),
               (x0 + int(w * 0.55), y0 + h - int(h * 0.1))], fill=color, width=lw)
    # fins
    draw.arc([x0 + int(w * 0.3), y0 + h - int(size * 0.05), x0 + int(w * 0.55), y0 + h + int(size * 0.18)],
             180, 360, fill=color, width=lw // 2)


DRAWERS = {
    "bird": draw_bird,
    "cat": draw_cat,
    "cow": draw_cow,
    "frog": draw_frog,
    "lion": draw_lion,
    "fish": draw_fish,
}


def make_card(name, theme):
    bg = gradient_bg(SIZE, SIZE, theme["bg_top"], theme["bg_bot"])

    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=CORNER, fill=255)

    card = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    card.paste(bg, mask=mask)

    draw = ImageDraw.Draw(card)
    cx, cy = SIZE // 2, SIZE // 2 - 26

    # Pictogram on the left, its static handshape letter badge on the right.
    DRAWERS[theme["draw"]](draw, cx - int(SIZE * 0.22), cy - int(SIZE * 0.02), int(SIZE * 0.30), theme["fg"])
    letter_badge(draw, cx + int(SIZE * 0.26), cy, int(SIZE * 0.30), theme["letter"], _darken(theme["bg_top"]))

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


def _darken(color):
    return tuple(int(c * 0.45) for c in color)


def main():
    for name, theme in THEMES.items():
        img = make_card(name, theme)
        path = OUT / f"{name}.png"
        img.save(path, "PNG")
        print(f"  {path.name}  ({SIZE}x{SIZE})")
    print("Done - animals reference images generated.")


if __name__ == "__main__":
    main()