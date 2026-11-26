import sys
import os
import io
import shutil
import tarfile
import zipfile
import lzma
import gzip
import struct
import argparse
from pathlib import Path

try:
    import lief
except ImportError:
    sys.exit("pip install lief first")


LC_LOAD_DYLIB = 0x0C
LC_LOAD_WEAK_DYLIB = 0x80000018
LC_SEGMENT_64 = 0x19
LC_CODE_SIGNATURE = 0x1D
MH_MAGIC_64 = 0xFEEDFACF
MH_CIGAM_64 = 0xCFFAEDFE
FAT_MAGIC = 0xCAFEBABE
FAT_MAGIC_64 = 0xCAFEBABF


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


def strip_slice_code_signature(data_ba, base):
    magic = struct.unpack_from('<I', data_ba, base)[0]
    if magic != MH_MAGIC_64:
        return False
    ncmds = struct.unpack_from('<I', data_ba, base + 16)[0]
    sizeofcmds = struct.unpack_from('<I', data_ba, base + 20)[0]
    lc_start = base + 32
    cmd_off = lc_start
    cs_off = None
    cs_size = None
    for _ in range(ncmds):
        cmd_type, cmd_size = struct.unpack_from('<II', data_ba, cmd_off)
        if cmd_type == LC_CODE_SIGNATURE:
            cs_off = cmd_off
            cs_size = cmd_size
            break
        cmd_off += cmd_size
    if cs_off is None:
        return False
    tail_start = cs_off + cs_size
    tail_end = lc_start + sizeofcmds
    tail = bytes(data_ba[tail_start:tail_end])
    data_ba[cs_off:cs_off + len(tail)] = tail
    zero_start = cs_off + len(tail)
    data_ba[zero_start:zero_start + cs_size] = b'\0' * cs_size
    struct.pack_into('<I', data_ba, base + 16, ncmds - 1)
    struct.pack_into('<I', data_ba, base + 20, sizeofcmds - cs_size)
    return True


def strip_code_signature_inplace(filepath):
    with open(filepath, 'rb') as f:
        data = bytearray(f.read())
    first4 = bytes(data[:4])
    magic_be = struct.unpack('>I', first4)[0]
    magic_le = struct.unpack('<I', first4)[0]
    changed = False
    if magic_be in (FAT_MAGIC, FAT_MAGIC_64):
        is_64_fat = magic_be == FAT_MAGIC_64
        nfat_arch = struct.unpack('>I', data[4:8])[0]
        arch_size = 32 if is_64_fat else 20
        for i in range(nfat_arch):
            arch_off = 8 + i * arch_size
            if is_64_fat:
                _, _, offset, _, _, _ = struct.unpack('>iiQQII', data[arch_off:arch_off + arch_size])
            else:
                _, _, offset, _, _ = struct.unpack('>iiIII', data[arch_off:arch_off + arch_size])
            if strip_slice_code_signature(data, offset):
                changed = True
                print(f"        stripped LC_CODE_SIGNATURE from slice at offset {offset}")
    elif magic_le in (MH_MAGIC_64, MH_CIGAM_64):
        if strip_slice_code_signature(data, 0):
            changed = True
            print(f"        stripped LC_CODE_SIGNATURE (thin)")
    if changed:
        with open(filepath, 'wb') as f:
            f.write(bytes(data))
    return changed


def patch_slice_add_dylib(data_ba, base, dylib_path):
    magic = struct.unpack_from('<I', data_ba, base)[0]
    if magic == MH_CIGAM_64:
        raise RuntimeError("big-endian 64-bit mach-o not supported")
    if magic != MH_MAGIC_64:
        raise RuntimeError(f"not a 64-bit mach-o: magic={hex(magic)}")

    ncmds = struct.unpack_from('<I', data_ba, base + 16)[0]
    sizeofcmds = struct.unpack_from('<I', data_ba, base + 20)[0]

    lc_start = base + 32
    lc_end = lc_start + sizeofcmds

    first_text_section_fileoff = None
    cmd_off = lc_start
    dylib_cmd_types = (LC_LOAD_DYLIB, 0x18, 0x1F, 0x24, 0x80000018, 0x80000022)
    existing = []
    for _ in range(ncmds):
        cmd_type, cmd_size = struct.unpack_from('<II', data_ba, cmd_off)
        if cmd_type in dylib_cmd_types:
            name_off = struct.unpack_from('<I', data_ba, cmd_off + 8)[0]
            ns = cmd_off + name_off
            ne = ns
            while data_ba[ne] != 0:
                ne += 1
            existing.append(data_ba[ns:ne].decode('utf-8', errors='replace'))
        if cmd_type == LC_SEGMENT_64:
            seg_name = bytes(data_ba[cmd_off + 8:cmd_off + 24]).rstrip(b'\0')
            if seg_name == b'__TEXT':
                nsects = struct.unpack_from('<I', data_ba, cmd_off + 64)[0]
                for s in range(nsects):
                    sec_off = cmd_off + 72 + s * 80
                    sec_fileoff = struct.unpack_from('<I', data_ba, sec_off + 48)[0]
                    if sec_fileoff > 0:
                        if first_text_section_fileoff is None or sec_fileoff < first_text_section_fileoff:
                            first_text_section_fileoff = sec_fileoff
        cmd_off += cmd_size

    if dylib_path in existing:
        return False

    if first_text_section_fileoff is None:
        raise RuntimeError("no __TEXT section fileoff found")

    path_bytes = dylib_path.encode('utf-8') + b'\0'
    path_padded = (len(path_bytes) + 7) & ~7
    cmd_total = 24 + path_padded

    free = (base + first_text_section_fileoff) - lc_end
    if cmd_total > free:
        raise RuntimeError(f"not enough header padding: free={free}, need={cmd_total}")

    load_cmd = struct.pack('<IIIIII',
        LC_LOAD_WEAK_DYLIB, cmd_total, 24, 2, 0x00000000, 0x00000000)
    load_cmd += path_bytes + b'\0' * (path_padded - len(path_bytes))

    data_ba[lc_end:lc_end + cmd_total] = load_cmd
    struct.pack_into('<I', data_ba, base + 16, ncmds + 1)
    struct.pack_into('<I', data_ba, base + 20, sizeofcmds + cmd_total)
    return True


def insert_dylib_inplace(filepath, dylib_path):
    with open(filepath, 'rb') as f:
        data = bytearray(f.read())

    first4 = bytes(data[:4])
    magic_be = struct.unpack('>I', first4)[0]
    magic_le = struct.unpack('<I', first4)[0]

    changed_any = False
    if magic_be in (FAT_MAGIC, FAT_MAGIC_64):
        is_64_fat = magic_be == FAT_MAGIC_64
        nfat_arch = struct.unpack('>I', data[4:8])[0]
        arch_size = 32 if is_64_fat else 20
        for i in range(nfat_arch):
            arch_off = 8 + i * arch_size
            if is_64_fat:
                cputype, cpusubtype, offset, size, align, reserved = struct.unpack('>iiQQII', data[arch_off:arch_off + arch_size])
            else:
                cputype, cpusubtype, offset, size, align = struct.unpack('>iiIII', data[arch_off:arch_off + arch_size])
            print(f"      slice cpu={cputype} subtype={cpusubtype}")
            if patch_slice_add_dylib(data, offset, dylib_path):
                changed_any = True
                print(f"        added LC_LOAD_DYLIB")
            else:
                print(f"        already linked, skipped")
    elif magic_le in (MH_MAGIC_64, MH_CIGAM_64):
        if patch_slice_add_dylib(data, 0, dylib_path):
            changed_any = True
            print(f"      added LC_LOAD_DYLIB (thin)")
        else:
            print(f"      already linked")
    else:
        raise RuntimeError(f"unknown magic: {hex(magic_be)} / {hex(magic_le)}")

    if changed_any:
        with open(filepath, 'wb') as f:
            f.write(bytes(data))
    return changed_any


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
    cs_sigdir = cs_dst / "_CodeSignature"
    if cs_sigdir.exists():
        shutil.rmtree(cs_sigdir)
        print(f"      removed CydiaSubstrate.framework/_CodeSignature/")
    cs_binary = cs_dst / "CydiaSubstrate"
    if cs_binary.exists():
        if strip_code_signature_inplace(cs_binary):
            print(f"      CydiaSubstrate binary signature stripped")

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

    print("[5/6] rewriting dylib load paths (LIEF, safe on no-fixup dylibs)")
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

    print("[6/6] injecting load commands into main binary (in-place, byte-level)")
    print(f"    {binary.name}:")
    for dy in staged_dylibs:
        insert_dylib_inplace(binary, f"@rpath/{dy.name}")

    print("[cleanup] stripping dylib code signatures and app-level _CodeSignature")
    for dy in staged_dylibs:
        if strip_code_signature_inplace(dy):
            print(f"      stripped signature from {dy.name}")
    cs_dir = app / "_CodeSignature"
    if cs_dir.exists():
        shutil.rmtree(cs_dir)
        print(f"      removed {cs_dir.name}/")
    for prov in app.glob("embedded.mobileprovision"):
        prov.unlink()
        print(f"      removed {prov.name}")
    for prov in app.glob("*.provisionprofile"):
        prov.unlink()
        print(f"      removed {prov.name}")

    print("\n[pack] zipping IPA")
    zip_app(work / "ipa", out_path)
    print(f"\nDone: {out_path}")
    print(f"size: {out_path.stat().st_size / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    main()
