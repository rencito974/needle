import os
import sys
import plistlib
import zipfile
import shutil
import subprocess
from pathlib import Path
from PIL import Image
import numpy as np


ICONS = [
    {"key": "NeedleNoir", "bg": (18, 18, 18), "mark": (255, 255, 255)},
    {"key": "NeedleBlood", "bg": (216, 25, 38), "mark": (255, 255, 255)},
    {"key": "NeedleSynth", "bg": (242, 25, 153), "mark": (10, 10, 10)},
    {"key": "NeedleCream", "bg": (242, 224, 199), "mark": (10, 10, 10)},
    {"key": "NeedleOcean", "bg": (12, 89, 191), "mark": (255, 255, 255)},
    {"key": "NeedleGold", "bg": (242, 191, 64), "mark": (10, 10, 10)},
]


def find_source_icon(app_dir):
    candidates = [
        "AppIcon60x60@3x.png",
        "AppIcon60x60@2x.png",
        "AppIcon76x76@2x~ipad.png",
        "AppIcon76x76~ipad.png",
        "AppIcon.png",
    ]
    for name in candidates:
        p = app_dir / name
        if p.exists():
            return Image.open(p).convert("RGBA")
    pngs = sorted(app_dir.glob("AppIcon*.png"), key=lambda x: -x.stat().st_size)
    for f in pngs:
        try:
            return Image.open(f).convert("RGBA")
        except Exception:
            pass
    return None


def recolor_from_source(src, target_bg, target_mark, out_size):
    base = src.resize((out_size, out_size), Image.LANCZOS)
    arr = np.array(base, dtype=np.float32)
    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3:4]
    luminance = (0.2126 * rgb[:, :, 0] + 0.7152 * rgb[:, :, 1] + 0.0722 * rgb[:, :, 2])
    mark_weight = np.clip(luminance / 255.0, 0.0, 1.0)[:, :, None]
    bg = np.array(target_bg, dtype=np.float32).reshape(1, 1, 3)
    fg = np.array(target_mark, dtype=np.float32).reshape(1, 1, 3)
    new_rgb = bg * (1.0 - mark_weight) + fg * mark_weight
    new_arr = np.concatenate([new_rgb, alpha], axis=2)
    return Image.fromarray(np.clip(new_arr, 0, 255).astype(np.uint8), mode="RGBA")


def write_icon_files(src, icon, out_dir):
    key = icon["key"]
    bg = icon["bg"]
    mark = icon["mark"]
    sizes = [60, 76, 83.5, 40, 29, 20]
    scales = [2, 3]
    for s in sizes:
        for sc in scales:
            px = int(round(s * sc))
            img = recolor_from_source(src, bg, mark, px)
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

    src = find_source_icon(app_dir)
    if src is None:
        raise SystemExit("Spotify source icon not found in .app")
    print(f"Using source icon {src.size[0]}x{src.size[1]}")

    for icon in ICONS:
        write_icon_files(src, icon, str(app_dir))

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
    print(f"Patched {ipa_path}: {len(ICONS)} alternate icons recolored from Spotify base")


if __name__ == "__main__":
    patch(sys.argv[1])
