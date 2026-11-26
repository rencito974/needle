import sys
import lief

path = sys.argv[1]
b = lief.MachO.parse(path)
if b is None:
    sys.exit(f"could not parse {path}")
for fat in b:
    print(f"\n=== arch: {fat.header.cpu_type} ===")
    for c in fat.commands:
        t = str(type(c).__name__)
        if "Dylib" in t:
            print(f"  {t}: {getattr(c, 'name', '?')}")
        elif "RPath" in t:
            print(f"  RPATH: {getattr(c, 'path', '?')}")
