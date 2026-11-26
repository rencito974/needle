import os
import sys
import math
import json
import plistlib
import zipfile
import shutil
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw


def draw_spotify_icon(size, bg_color, mark_color):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((0, 0, size, size), radius=int(size * 0.235), fill=bg_color)

    cx = size / 2
    cy = size * 0.72
    radii = [size * 0.42, size * 0.30, size * 0.18]
    widths = [size * 0.095, size * 0.085, size * 0.075]

    for r, w in zip(radii, widths):
        bbox = (cx - r, cy - r, cx + r, cy + r)
        draw.arc(bbox, start=180, end=360, fill=mark_color, width=int(w))

    return img


ICONS = [
    {"key": "NeedleNoir", "bg": (18, 18, 18), "mark": (255, 255, 255)},
    {"key": "NeedleBlood", "bg": (216, 25, 38), "mark": (255, 255, 255)},
    {"key": "NeedleSynth", "bg": (242, 25, 153), "mark": (0, 0, 0)},
    {"key": "NeedleCream", "bg": (242, 224, 199), "mark": (0, 0, 0)},
    {"key": "NeedleOcean", "bg": (12, 89, 191), "mark": (255, 255, 255)},
    {"key": "NeedleGold", "bg": (242, 191, 64), "mark": (0, 0, 0)},
]

SIZES = [
    (60, 2, "@2x"),
    (60, 3, "@3x"),
    (76, 1, ""),
    (76, 2, "@2x"),
    (83.5, 2, "@2x"),
    (40, 2, "@2x"),
    (40, 3, "@3x"),
    (29, 2, "@2x"),
    (29, 3, "@3x"),
]


def generate_icon_set(key, bg, mark, out_dir):
    files = []
    for base, scale, suffix in SIZES:
        px = int(round(base * scale))
        img = draw_spotify_icon(px, bg, mark)
        fname = f"{key}{int(base) if base == int(base) else base}x{int(base) if base == int(base) else base}{suffix}.png"
        fname = f"{key}{suffix}.png" if base == 60 else fname
        out_path = os.path.join(out_dir, fname)
        img.save(out_path, "PNG")
        files.append(fname)
    main_60_2x = os.path.join(out_dir, f"{key}@2x.png")
    main_60_3x = os.path.join(out_dir, f"{key}@3x.png")
    draw_spotify_icon(120, bg, mark).save(main_60_2x, "PNG")
    draw_spotify_icon(180, bg, mark).save(main_60_3x, "PNG")
    return [key]


def patch(ipa_path):
    work_dir = Path("work/unzipped")
    if work_dir.exists():
        shutil.rmtree(work_dir)
    work_dir.mkdir(parents=True)

    with zipfile.ZipFile(ipa_path, "r") as zf:
        zf.extractall(work_dir)

    payload = work_dir / "Payload"
    app_dir = None
    for child in payload.iterdir():
        if child.suffix == ".app":
            app_dir = child
            break
    if not app_dir:
        raise SystemExit("No .app inside Payload")

    for icon in ICONS:
        generate_icon_set(icon["key"], icon["bg"], icon["mark"], str(app_dir))

    plist_path = app_dir / "Info.plist"
    with open(plist_path, "rb") as f:
        info = plistlib.load(f)

    cfi = info.get("CFBundleIcons", {}) or {}
    alt = {}
    for icon in ICONS:
        alt[icon["key"]] = {
            "CFBundleIconFiles": [icon["key"]],
            "UIPrerenderedIcon": False,
        }
    cfi["CFBundleAlternateIcons"] = alt
    info["CFBundleIcons"] = cfi

    if "CFBundleIcons~ipad" in info:
        ipad = info["CFBundleIcons~ipad"]
        ipad["CFBundleAlternateIcons"] = alt
        info["CFBundleIcons~ipad"] = ipad

    with open(plist_path, "wb") as f:
        plistlib.dump(info, f)

    out_ipa = Path(ipa_path).with_suffix(".patched.ipa")
    if out_ipa.exists():
        out_ipa.unlink()

    subprocess.check_call(
        ["zip", "-r", "-q", "-y", str(out_ipa.resolve()), "Payload"],
        cwd=work_dir,
    )
    shutil.move(str(out_ipa), ipa_path)
    print(f"Patched {ipa_path}: added {len(ICONS)} alternate icons")


if __name__ == "__main__":
    patch(sys.argv[1])
