import sys
import os
import io
import shutil
import tarfile
import zipfile
import lzma
import gzip
import argparse
from pathlib import Path

try:
    import lief
except ImportError:
    sys.exit("pip install lief first")


CYAN_EXTRAS_CANDIDATES = [
    Path(os.environ.get("APPDATA", "")) / "Python" / "Python314" / "site-packages" / "cyan" / "extras",
    Path(os.environ.get("APPDATA", "")) / "Python" / "Python313" / "site-packages" / "cyan" / "extras",
    Path(os.environ.get("APPDATA", "")) / "Python" / "Python312" / "site-packages" / "cyan" / "extras",
    Path.home() / ".local" / "lib" / "python3.14" / "site-packages" / "cyan" / "extras",
    Path.home() / "Library" / "Python" / "3.14" / "lib" / "python" / "site-packages" / "cyan" / "extras",
]


def find_cyan_extras():
    for p in CYAN_EXTRAS_CANDIDATES:
        if (p / "CydiaSubstrate.framework" / "CydiaSubstrate").exists():
            return p
    try:
        import cyan
        base = Path(cyan.__file__).parent / "extras"
        if (base / "CydiaSubstrate.framework" / "CydiaSubstrate").exists():
            return base
    except Exception:
        pass
    try:
        import subprocess
        r = subprocess.run(["pip", "show", "cyan"], capture_output=True, text=True)
        for line in r.stdout.splitlines():
            if line.startswith("Location:"):
                base = Path(line.split(":", 1)[1].strip()) / "cyan" / "extras"
                if (base / "CydiaSubstrate.framework" / "CydiaSubstrate").exists():
                    return base
    except Exception:
        pass
    return None


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


def rewrite_dylib_paths(path, rewrites, new_id=None):
    binary = lief.MachO.parse(str(path))
    if binary is None:
        raise RuntimeError(f"could not parse {path}")
    for fat in binary:
        for cmd in list(fat.commands):
            if "Dylib" not in type(cmd).__name__:
                continue
            name = getattr(cmd, "name", None)
            if not name:
                continue
            for old, new in rewrites.items():
                if name.startswith(old):
                    tail = name[len(old):]
                    cmd.name = new + tail
                    print(f"      rewrote {old}... -> {new}{tail}")
                    break
        if new_id is not None:
            for cmd in fat.commands:
                if type(cmd).__name__ == "DylibCommand" and str(cmd.command).endswith("ID_DYLIB"):
                    cmd.name = new_id
                    print(f"      set ID to {new_id}")
                    break
    binary.write(str(path))


def inject_load(binary_path, load_path):
    binary = lief.MachO.parse(str(binary_path))
    for fat in binary:
        existing = {getattr(c, "name", None) for c in fat.commands if "Dylib" in type(c).__name__}
        if load_path in existing:
            print(f"      already linked {load_path}")
            continue
        cmd = lief.MachO.DylibCommand.load_dylib(load_path)
        cmd.compatibility_version = (1, 0, 0)
        cmd.current_version = (1, 0, 0)
        fat.add(cmd)
        print(f"      added LC_LOAD_DYLIB {load_path}")
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

    extras = find_cyan_extras()
    if not extras:
        sys.exit("could not find cyan's CydiaSubstrate.framework. pip install --user cyan")
    print(f"Extras: {extras}")

    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)

    print("\n[1/6] unpacking IPA")
    with zipfile.ZipFile(ipa_path) as z:
        z.extractall(work / "ipa")

    print("[2/6] extracting .deb")
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
    print(f"      app    = {app.name}")
    print(f"      binary = {binary.name}")

    print("[3/6] copying CydiaSubstrate.framework into Frameworks/")
    frameworks = app / "Frameworks"
    frameworks.mkdir(exist_ok=True)
    cs_src = extras / "CydiaSubstrate.framework"
    cs_dst = frameworks / "CydiaSubstrate.framework"
    if cs_dst.exists():
        shutil.rmtree(cs_dst)
    shutil.copytree(cs_src, cs_dst)
    print(f"      staged {cs_dst.name}")

    print("[4/6] staging dylibs and bundles into Frameworks/")
    dylibs = find_dylibs(work / "deb")
    if not dylibs:
        sys.exit("no .dylib inside .deb")
    staged_dylibs = []
    for dy in dylibs:
        if dy.name == "CydiaSubstrate":
            continue
        dest = frameworks / dy.name
        shutil.copy2(dy, dest)
        staged_dylibs.append(dest)
        print(f"      staged {dy.name}")

    bundles = find_bundles(work / "deb")
    for b in bundles:
        dest = frameworks / b.name
        if dest.exists():
            shutil.rmtree(dest)
        shutil.copytree(b, dest)
        print(f"      staged bundle {b.name}")

    print("[5/6] rewriting dylib load paths for sideload")
    rewrites = {
        "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate":
            "@executable_path/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",
        "/usr/lib/libsubstrate.dylib":
            "@executable_path/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",
        "/usr/lib/libhooker.dylib":
            "@executable_path/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",
        "/usr/lib/libblackjack.dylib":
            "@executable_path/Frameworks/CydiaSubstrate.framework/CydiaSubstrate",
    }
    for dy in staged_dylibs:
        print(f"    {dy.name}:")
        rewrite_dylib_paths(dy, rewrites, new_id=f"@executable_path/Frameworks/{dy.name}")

    print("[6/6] injecting load commands into main binary")
    print(f"    {binary.name}:")
    for dy in staged_dylibs:
        inject_load(binary, f"@executable_path/Frameworks/{dy.name}")

    print("\n[pack] zipping IPA")
    zip_app(work / "ipa", out_path)
    print(f"\nDone: {out_path}")
    print(f"size: {out_path.stat().st_size / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    main()
