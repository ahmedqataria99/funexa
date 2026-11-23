from pathlib import Path

from PIL import Image, ImageDraw

CANVAS = 1024
NAVY = (18, 46, 82, 255)
NAVY_DARK = (12, 35, 65, 255)
WOOD = (205, 137, 82, 255)
WOOD_LIGHT = (226, 166, 109, 255)
WOOD_DARK = (154, 91, 52, 255)


def draw_symbol(draw: ImageDraw.ImageDraw, transparent: bool) -> None:
    if not transparent:
        draw.rectangle((0, 0, CANVAS, CANVAS), fill=NAVY_DARK)

    # Industrial F silhouette: broad vertical spine and two horizontal cuts.
    draw.polygon(
        [(230, 194), (326, 118), (408, 154), (408, 836), (230, 906)],
        fill=NAVY,
    )
    draw.polygon(
        [(326, 118), (826, 118), (826, 232), (455, 324), (326, 268)],
        fill=NAVY,
    )
    draw.polygon(
        [(408, 430), (716, 430), (716, 534), (584, 586), (408, 586)],
        fill=NAVY,
    )

    # Wood grain accents express furniture manufacturing inside the F.
    draw.polygon(
        [(230, 194), (326, 118), (326, 268), (326, 906), (230, 906)],
        fill=WOOD,
    )
    draw.polygon(
        [(326, 118), (408, 154), (408, 836), (326, 906)],
        fill=WOOD_LIGHT,
    )

    # Subtle vertical grain lines remain legible at taskbar scale.
    for x, alpha in ((270, 116), (296, 92), (348, 92), (380, 70)):
        line_color = (WOOD_DARK[0], WOOD_DARK[1], WOOD_DARK[2], alpha)
        draw.line((x, 205, x - 18, 826), fill=line_color, width=5)

    # Wood cut in the lower branch suggests a manufactured joint.
    draw.polygon(
        [(408, 586), (584, 586), (716, 534), (716, 698),
         (648, 768), (408, 700)],
        fill=WOOD,
    )
    draw.line((438, 620, 664, 570), fill=WOOD_LIGHT, width=12)
    draw.line((438, 655, 628, 610), fill=WOOD_DARK, width=7)


def main() -> None:
    from pathlib import Path

    root = Path(__file__).resolve().parents[1]
    icons = root / "assets" / "icons"
    icons.mkdir(parents=True, exist_ok=True)

    master = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw_master = ImageDraw.Draw(master)
    draw_symbol(draw_master, transparent=False)
    master = master.resize((1024, 1024), Image.Resampling.LANCZOS)
    master_path = icons / "furnexa_icon_1024_master.png"
    master.save(master_path, "PNG", optimize=True)

    transparent = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw_transparent = ImageDraw.Draw(transparent)
    draw_symbol(draw_transparent, transparent=True)
    transparent = transparent.resize((1024, 1024), Image.Resampling.LANCZOS)
    transparent_path = icons / "furnexa_icon_transparent.png"
    transparent.save(transparent_path, "PNG", optimize=True)

    windows_resources = root / "windows" / "runner" / "resources"
    windows_resources.mkdir(parents=True, exist_ok=True)
    ico_path = windows_resources / "app_icon.ico"
    transparent.save(
        ico_path,
        format="ICO",
        sizes=[(16, 16), (32, 32), (48, 48), (256, 256)],
    )

    print(master_path)
    print(transparent_path)
    print(ico_path)


if __name__ == "__main__":
    main()
