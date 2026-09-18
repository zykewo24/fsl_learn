"""
Generate branded launcher icons and splash background for FSL Learn.

Outputs:
  android/app/src/main/res/mipmap-hdpi/ic_launcher.png      (72×72)
  android/app/src/main/res/mipmap-xhdpi/ic_launcher.png      (96×96)
  android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png    (144×144)
  android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png   (192×192)
  android/app/src/main/res/drawable/launch_background.xml   (vector shape)
  android/app/src/main/res/values/styles.xml               (updated)
  android/app/src/main/res/values-night/styles.xml         (updated)
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math, textwrap, os

ROOT = Path(r"C:\Projects\fsl_learn")
RES = ROOT / "android" / "app" / "src" / "main" / "res"

PRIMARY   = (0x1E, 0x3A, 0x8A)
SECONDARY = (0x3B, 0x82, 0xF6)
WHITE     = (255, 255, 255)

MIPMAPS = {
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi":192,
}

def make_launcher(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    r = size // 2
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=r // 2, fill=PRIMARY)

    # Hand-palm silhouette (simplified)
    palm_w = int(size * 0.38)
    palm_h = int(size * 0.30)
    cx, cy = size // 2, size // 2 + int(size * 0.04)

    # four "fingers" as vertical rounded rects
    finger_w = int(palm_w * 0.22)
    finger_h = int(palm_h * 0.75)
    gap = int(finger_w * 0.35)
    total = 4 * finger_w + 3 * gap
    x0 = cx - total // 2

    for i in range(4):
        x = x0 + i * (finger_w + gap)
        y = cy - finger_h - int(palm_h * 0.08)
        draw.rounded_rectangle(
            [x, y, x + finger_w, y + finger_h],
            radius=finger_w // 3,
            fill=WHITE,
        )

    # thumb
    thumb_w = int(finger_w * 0.9)
    thumb_h = int(finger_h * 0.65)
    tx = x0 - int(gap * 0.6) - thumb_w
    ty = cy - int(palm_h * 0.1)
    draw.rounded_rectangle(
        [tx, ty, tx + thumb_w, ty + thumb_h],
        radius=thumb_w // 3,
        fill=WHITE,
    )

    # palm
    draw.rounded_rectangle(
        [x0, cy - int(palm_h * 0.12), x0 + total, cy + palm_h],
        radius=int(palm_w * 0.18),
        fill=WHITE,
    )

    # Sign-language dot on index finger tip (secondary blue)
    dot_r = int(finger_w * 0.30)
    dot_cx = x0 + finger_w // 2
    dot_cy = cy - finger_h - int(palm_h * 0.08) + int(finger_h * 0.15)
    draw.ellipse(
        [dot_cx - dot_r, dot_cy - dot_r, dot_cx + dot_r, dot_cy + dot_r],
        fill=SECONDARY,
    )

    return img


def write_styles():
    style_common = textwrap.dedent("""\
        <?xml version="1.0" encoding="utf-8"?>
        <resources>
          <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
            <item name="android:windowBackground">@drawable/launch_background</item>
          </style>
          <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
            <item name="android:windowBackground">@color/flutter_background_color</item>
          </style>
        </resources>
    """)
    style_dark = textwrap.dedent("""\
        <?xml version="1.0" encoding="utf-8"?>
        <resources>
          <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
            <item name="android:windowBackground">@drawable/launch_background</item>
          </style>
          <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
            <item name="android:windowBackground">@color/flutter_background_color</item>
          </style>
        </resources>
    """)
    (RES / "values" / "styles.xml").write_text(style_common, encoding="utf-8")
    (RES / "values-night" / "styles.xml").write_text(style_dark, encoding="utf-8")


def write_launch_background():
    xml = textwrap.dedent("""\
        <?xml version="1.0" encoding="utf-8"?>
        <layer-list xmlns:android="http://schemas.android.com/apk/res/android">
          <item android:drawable="@android:color/white" />
          <item android:gravity="center">
            <shape android:shape="oval">
              <solid android:color="#1E3A8A" />
              <size android:width="80dp" android:height="80dp" />
            </shape>
          </item>
          <item android:gravity="center"
                android:drawable="@mipmap/ic_launcher" />
        </layer-list>
    """)
    (RES / "drawable" / "launch_background.xml").write_text(xml, encoding="utf-8")


def main():
    for folder, size in MIPMAPS.items():
        out = RES / folder
        out.mkdir(parents=True, exist_ok=True)
        icon = make_launcher(size)
        icon.save(out / "ic_launcher.png")
        print(f"  {folder}/ic_launcher.png  ({size}×{size})")

    # Adaptive icon foreground (108dp base, icon is 66% of that = 72dp)
    adaptive_dir = RES / "mipmap-anydpi-v26"
    adaptive_dir.mkdir(parents=True, exist_ok=True)

    # Generate adaptive icon foreground PNG (108dp at xxxhdpi = 432px)
    fg_size = 432
    fg = Image.new("RGBA", (fg_size, fg_size), (0, 0, 0, 0))
    fg_draw = ImageDraw.Draw(fg)
    # centered hand silhouette at 66% = 286px
    inner = make_launcher(286)
    offset = (fg_size - 286) // 2
    fg.paste(inner, (offset, offset), inner)
    fg.save(adaptive_dir / "ic_launcher_foreground.png")
    print("  mipmap-anydpi-v26/ic_launcher_foreground.png")

    # Adaptive icon XML
    adaptive_xml = textwrap.dedent("""\
        <?xml version="1.0" encoding="utf-8"?>
        <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
          <background android:drawable="@color/ic_launcher_background"/>
          <foreground android:drawable="@drawable/ic_launcher_foreground"/>
        </adaptive-icon>
    """)
    # Also need a vector drawable foreground — but simpler to just reference the PNG
    adaptive_xml2 = textwrap.dedent("""\
        <?xml version="1.0" encoding="utf-8"?>
        <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
          <background android:drawable="@color/ic_launcher_background"/>
          <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
        </adaptive-icon>
    """)
    (adaptive_dir / "ic_launcher.xml").write_text(adaptive_xml2, encoding="utf-8")

    # Color resource for background
    colors_dir = RES / "values"
    colors_file = colors_dir / "ic_launcher_background.xml"
    colors_file.write_text(textwrap.dedent("""\
        <?xml version="1.0" encoding="utf-8"?>
        <resources>
          <color name="ic_launcher_background">#1E3A8A</color>
        </resources>
    """), encoding="utf-8")
    print("  values/ic_launcher_background.xml")

    write_launch_background()
    print("  drawable/launch_background.xml")

    write_styles()
    print("  values/styles.xml + values-night/styles.xml")

    print("Done — launcher icons and splash generated.")


if __name__ == "__main__":
    main()
