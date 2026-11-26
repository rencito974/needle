import os
import sys
import plistlib
import zipfile
import shutil
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw


def draw_spotify_icon(size, bg_color, mark_color):
    S = 4
    big = size * S
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    radius = int(big * 0.235)
    draw.rounded_rectangle((0, 0, big, big), radius=radius, fill=bg_color)

    cx = big / 2
    cy = big * 0.74
    arcs = [
        {"r": big * 0.36, "w": big * 0.090},
        {"r": big * 0.25, "w": big * 0.075},
        {"r": big * 0.145, "w": big * 0.060},
    ]
    for a in arcs:
        r = a["r"]
        w = a["w"]
        bbox = (cx - r, cy - r, cx + r, cy + r)
        draw.arc(bbox, start=200, end=340, fill=mark_color, width=int(w))

    out = img.resize((size, size), Image.LANCZOS)
    return out


ICONS = [
    {"key": "NeedleNoir", "bg": (18, 18, 18), "mark": (255, 255, 255)},
    {"key": "NeedleBlood", "bg": (216, 25, 38), "mark": (255, 255, 255)},
    {"key": "NeedleSynth", "bg": (242, 25, 153), "mark": (10, 10, 10)},
    {"key": "NeedleCream", "bg": (242, 224, 199), "mark": (10, 10, 10)},
    {"key": "NeedleOcean", "bg": (12, 89, 191), "mark": (255, 255, 255)},
    {"key": "NeedleGold", "bg": (242, 191, 64), "mark": (10, 10, 10)},
]


def write_icon_files(icon, out_dir):
    key = icon["key"]
    bg = icon["bg"]
    mark = icon["mark"]
    sizes = [60, 76, 83.5, 40, 29, 20]
    scales = [2, 3]
    for s in sizes:
        for sc in scales:
            px = int(round(s * sc))
            img = draw_spotify_icon(px, bg, mark)
            if s == 60:
                fname = f"{key}@{sc}x.png"
            else:
                base = int(s) if s == int(s) else s
                fname = f"{key}{base}x{base}@{sc}x.png"
            img.save(os.path.join(out_dir, fname), "PNG")


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
        write_icon_files(icon, str(app_dir))

    plist_path = app_dir / "Info.plist"
    with open(plist_path, "rb") as f:
        info = plistlib.load(f)

    alt = {}
    for icon in ICONS:
        alt[icon["key"]] = {
            "CFBundleIconFiles": [icon["key"]],
            "UIPrerenderedIcon": False,
        }

    cfi = info.get("CFBundleIcons", {}) or {}
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
    print(f"Patched {ipa_path}: {len(ICONS)} alternate icons")


if __name__ == "__main__":
    patch(sys.argv[1])
