import os
import sys
import struct
import zlib
import plistlib
import zipfile
import shutil
import subprocess
from io import BytesIO
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


PNG_SIG = b"\x89PNG\r\n\x1a\n"


def defuse_cgbi(data):
    if not data.startswith(PNG_SIG):
        return data
    pos = 8
    chunks = []
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos+4])[0]
        name = data[pos+4:pos+8]
        blob = data[pos+8:pos+8+length]
        chunks.append((name, blob))
        pos += 12 + length

    has_cgbi = any(n == b"CgBI" for n, _ in chunks)
    if not has_cgbi:
        return data

    ihdr = next(c for n, c in chunks if n == b"IHDR")
    width, height = struct.unpack(">II", ihdr[:8])
    bit_depth = ihdr[8]
    color_type = ihdr[9]
    if color_type == 6:
        bpp = 4
    elif color_type == 2:
        bpp = 3
    else:
        bpp = 4

    idat_raw = b"".join(c for n, c in chunks if n == b"IDAT")
    decompressed = zlib.decompress(idat_raw, -zlib.MAX_WBITS)

    stride = width * bpp
    rows = bytearray(decompressed)
    for y in range(height):
        start = y * (stride + 1) + 1
        for x in range(width):
            i = start + x * bpp
            rows[i], rows[i + 2] = rows[i + 2], rows[i]

    new_idat = zlib.compress(bytes(rows), 6)

    def crc_chunk(name, blob):
        crc = zlib.crc32(name + blob) & 0xffffffff
        return struct.pack(">I", len(blob)) + name + blob + struct.pack(">I", crc)

    out = PNG_SIG
    idat_emitted = False
    for name, blob in chunks:
        if name == b"CgBI":
            continue
        if name == b"IDAT":
            if not idat_emitted:
                out += crc_chunk(b"IDAT", new_idat)
                idat_emitted = True
            continue
        out += crc_chunk(name, blob)
    return out


def load_png_safe(path):
    raw = path.read_bytes()
    try:
        fixed = defuse_cgbi(raw)
        return Image.open(BytesIO(fixed)).convert("RGBA")
    except Exception as e:
        print(f"  skip {path.name}: {e}")
        return None


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
        if not p.exists():
            continue
        img = load_png_safe(p)
        if img is not None:
            print(f"Using source icon {name} ({img.size[0]}x{img.size[1]})")
            return img
    pngs = sorted(app_dir.glob("AppIcon*.png"), key=lambda x: -x.stat().st_size)
    for f in pngs:
        img = load_png_safe(f)
        if img is not None:
            print(f"Fallback source icon {f.name} ({img.size[0]}x{img.size[1]})")
            return img
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
