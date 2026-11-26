import sys
import os
import io
import shutil
import tarfile
import zipfile
import lzma
import gzip
import argparse
import subprocess
from pathlib import Path

try:
    import lief
except ImportError:
    sys.exit("pip install lief first")


def extract_deb(deb_path, out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    with open(deb_path, "rb") as f:
        magic = f.read(8)
        if magic != b"!<arch>\n":
            raise ValueError(f"{deb_path} is not a .deb (ar magic missing)")
        while True:
            header = f.read(60)
            if len(header) < 60:
                return
            name = header[0:16].decode("ascii", errors="replace").strip()
            size = int(header[48:58].decode("ascii").strip())
            data = f.read(size)
            if size % 2 == 1:
                f.read(1)
            if name.startswith("data.tar"):
                if name.endswith(".xz"):
                    data = lzma.decompress(data)
                elif name.endswith(".gz") or name.endswith(".tgz"):
                    data = gzip.decompress(data)
                elif name.endswith(".zst"):
                    import zstandard as zstd
                    data = zstd.ZstdDecompressor().decompress(data)
                with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as tf:
                    tf.extractall(out_dir)
                return


def find_dylibs(root):
    return list(Path(root).rglob("*.dylib"))


def find_bundles(root):
    return [p for p in Path(root).rglob("*.bundle") if p.is_dir()]


def inject_load(binary_path, load_path):
    binary = lief.MachO.parse(str(binary_path))
    for fat in binary:
        existing = {c.name for c in fat.commands if isinstance(c, lief.MachO.DylibCommand)}
        if load_path in existing:
            print(f"  already linked {load_path}")
            continue
        cmd = lief.MachO.DylibCommand.load_dylib(load_path)
        cmd.compatibility_version = (1, 0, 0)
        cmd.current_version = (1, 0, 0)
        fat.add(cmd)
        print(f"  added LC_LOAD_DYLIB {load_path}")
    binary.write(str(binary_path))


def zip_app(ipa_root, out_ipa):
    if Path(out_ipa).exists():
        Path(out_ipa).unlink()
    base = Path(ipa_root)
    with zipfile.ZipFile(out_ipa, "w", zipfile.ZIP_DEFLATED, allowZip64=True) as z:
        for f in base.rglob("*"):
            if f.is_file() or f.is_symlink():
                arc = f.relative_to(base)
                zi = zipfile.ZipInfo(str(arc).replace(os.sep, "/"))
                zi.compress_type = zipfile.ZIP_DEFLATED
                try:
                    zi.external_attr = (f.stat().st_mode & 0xFFFF) << 16
                except Exception:
                    pass
                with open(f, "rb") as src:
                    z.writestr(zi, src.read())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-i", "--ipa", required=True)
    ap.add_argument("-f", "--deb", required=True)
    ap.add_argument("-o", "--out", default="Needle-Spotify.ipa")
    ap.add_argument("-w", "--work", default="needle-work")
    args = ap.parse_args()

    ipa_path = Path(args.ipa).resolve()
    deb_path = Path(args.deb).resolve()
    out_path = Path(args.out).resolve()
    work = Path(args.work).resolve()

    print(f"IPA : {ipa_path}")
    print(f"Deb : {deb_path}")
    print(f"Out : {out_path}")
    print(f"Work: {work}")

    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)

    print("\n[1/5] unpacking IPA")
    with zipfile.ZipFile(ipa_path) as z:
        z.extractall(work / "ipa")

    print("[2/5] extracting .deb")
    extract_deb(deb_path, work / "deb")

    payload = work / "ipa" / "Payload"
    apps = list(payload.glob("*.app"))
    if not apps:
        sys.exit("no .app in Payload/")
    app = apps[0]
    binary = app / app.stem
    if not binary.exists():
        candidates = [p for p in app.iterdir() if p.is_file() and not p.suffix]
        if candidates:
            binary = candidates[0]
    print(f"  app    = {app.name}")
    print(f"  binary = {binary.name}")

    print("[3/5] staging dylibs into Frameworks/")
    frameworks = app / "Frameworks"
    frameworks.mkdir(exist_ok=True)
    dylibs = find_dylibs(work / "deb")
    if not dylibs:
        sys.exit("no .dylib inside .deb")
    staged = []
    for dy in dylibs:
        dest = frameworks / dy.name
        shutil.copy2(dy, dest)
        staged.append(dest.name)
        print(f"  staged {dy.name}")

    bundles = find_bundles(work / "deb")
    for b in bundles:
        dest = frameworks / b.name
        if dest.exists():
            shutil.rmtree(dest)
        shutil.copytree(b, dest)
        print(f"  staged bundle {b.name}")

    print("[4/5] patching main binary load commands")
    for name in staged:
        inject_load(binary, f"@executable_path/Frameworks/{name}")

    print("[5/5] packaging IPA")
    zip_app(work / "ipa", out_path)
    print(f"\nDone: {out_path}")
    print(f"size: {out_path.stat().st_size / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    main()
