"""Audit the core example's resolved graph and built Android APK (stdlib only)."""
import json
import re
import sys
from pathlib import Path
from zipfile import ZipFile

example = Path(__file__).resolve().parents[1]
apk = Path(sys.argv[1]) if len(sys.argv) > 1 else example / "build/app/outputs/flutter-apk/app-debug.apk"
graph = json.loads((example / ".dart_tool/package_config.json").read_text(encoding="utf-8"))
names = [p["name"] for p in graph["packages"]]
unexpected = [n for n in names if n.startswith("firebase_") or n == "valence_push"]
if unexpected:
    raise SystemExit(f"Unexpected native push dependencies: {unexpected}")
with ZipFile(apk) as archive:
    dex = [n for n in archive.namelist() if re.fullmatch(r"classes[0-9]*\.dex", n)]
    if not dex:
        raise SystemExit("No DEX files found; expected a built Android APK")
    for name in dex:
        data = archive.read(name)
        for marker in [b"Lcom/google/firebase/", b"Lio/flutter/plugins/firebase/"]:
            if marker in data:
                raise SystemExit(f"Firebase class reference in {name}: {marker!r}")
    manifest = archive.read("AndroidManifest.xml")
    for marker in ["com.google.firebase", "io.flutter.plugins.firebase"]:
        for encoding in ["utf-8", "utf-16-le"]:
            if marker.encode(encoding) in manifest:
                raise SystemExit(f"Firebase manifest component: {marker}")
print(f"PASS: core graph and {len(dex)} DEX files / manifest contain no Firebase SDK references ({apk})")
