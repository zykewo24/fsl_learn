"""Generates the FSL Learn app logo (assets/images/logo.png).

A 1024x1024 rounded-square badge with the app's blue gradient and a white
stylized "ILY" (I-Love-You) hand sign — the international sign language icon
made from the thumb, index and pinky extended.
"""

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
RADIUS = 224
C1 = (30, 58, 138)   # AppColors.primary  #1E3A8A
C2 = (59, 130, 246)  # AppColors.secondary #3B82F6
WHITE = (255, 255, 255, 255)


def gradient_tile():
    grad = Image.new("RGBA", (SIZE, SIZE))
    d = ImageDraw.Draw(grad)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        r = int(C1[0] + (C2[0] - C1[0]) * t)
        g = int(C1[1] + (C2[1] - C1[1]) * t)
        b = int(C1[2] + (C2[2] - C1[2]) * t)
        d.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))

    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [(0, 0), (SIZE - 1, SIZE - 1)], radius=RADIUS, fill=255
    )
    grad.putalpha(mask)
    return grad


def inner_ring():
    ring = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(ring).rounded_rectangle(
        [(46, 46), (SIZE - 47, SIZE - 47)],
        radius=RADIUS - 42,
        outline=(255, 255, 255, 70),
        width=6,
    )
    return ring


def radial_glow():
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [(212, 260), (812, 860)], fill=(255, 255, 255, 30)
    )
    return glow.filter(ImageFilter.GaussianBlur(110))


def capsule(d, a, b, width, fill):
    d.line([a, b], fill=fill, width=width)
    r = width // 2
    for x, y in (a, b):
        d.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def hand_layer():
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    # Folded fingertips resting on the palm (middle + ring fingers).
    capsule(d, (488, 696), (550, 696), 40, WHITE)

    # Thumb stretched out to the side.
    capsule(d, (445, 692), (302, 604), 58, WHITE)

    # Index finger.
    capsule(d, (468, 622), (450, 402), 58, WHITE)

    # Pinky finger.
    capsule(d, (556, 622), (574, 402), 54, WHITE)

    # Palm.
    d.ellipse([(390, 578), (634, 802)], fill=WHITE)

    # Small white ring accent overlapping the wrist area so the hand stays
    # integrated with the badge.
    d.arc([(350, 560), (674, 884)], start=200, end=340, fill=(255, 255, 255, 90), width=10)

    return layer


def shadow_for(layer, offset=(16, 20), radius=26, alpha=70):
    alpha_img = layer.split()[3]
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow.paste((12, 16, 40, alpha), (0, 0), alpha_img)
    shadow = shadow.transform(
        (SIZE, SIZE),
        Image.AFFINE,
        (1, 0, offset[0], 0, 1, offset[1]),
        resample=Image.BICUBIC,
    )
    return shadow.filter(ImageFilter.GaussianBlur(radius))


def diamond(d, cx, cy, r, fill):
    d.polygon(
        [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)],
        fill=fill,
    )


def sparkles():
    s = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(s)
    diamond(d, 742, 286, 26, (255, 255, 255, 210))
    diamond(d, 300, 348, 18, (255, 255, 255, 170))
    diamond(d, 726, 628, 12, (255, 255, 255, 150))
    return s


def main():
    tile = gradient_tile()

    hand = hand_layer()
    shadow = shadow_for(hand)

    base = Image.alpha_composite(tile, radial_glow())
    base = Image.alpha_composite(base, shadow)
    base = Image.alpha_composite(base, hand)
    base = Image.alpha_composite(base, sparkles())
    base = Image.alpha_composite(base, inner_ring())

    base.save("assets/images/logo.png")
    print("wrote assets/images/logo.png", base.size)


if __name__ == "__main__":
    main()