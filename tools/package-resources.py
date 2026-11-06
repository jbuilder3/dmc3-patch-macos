"""Assemble the runtime allowlist. The public build carries no game or mod payload."""
from pathlib import Path
import json
import shutil
import sys

source = Path(sys.argv[1]).resolve()
resources = Path(sys.argv[2]).resolve()
variant = sys.argv[3]
assert variant in {"local", "public"}
project = resources / "Project"
licenses = resources / "licenses"

files = [
    "build.sh", "README.md", "LICENSE",
    "tools/package-resources.py", "tools/build-ffmpeg.sh",
    "tools/bin/ffmpeg", "tools/bin/ffprobe", "tools/bin/xdelta3decode",
    "tools/downloads/xdelta3-3.2.2.tar.gz", "docs/Xdelta-LICENSE.txt",
    "tools/downloads/ffmpeg-8.0.1.tar.xz",
    "docs/Translations.json", "docs/CREDITOS.json",
    "docs/GUIA-CRIMSON-ES.html", "docs/COPYING.LGPLv2.1",
    "docs/THIRD-PARTY.md", "docs/CRIMSON-THIRD-PARTY.md",
    "docs/PERMISOS.md", "docs/CREDITOS.md", "docs/Crimson-LICENSE.txt",
]
files.extend(str(p.relative_to(source)) for p in sorted((source / "Sources").glob("*.swift")))
files.extend(str(p.relative_to(source)) for p in sorted((source / "tools/bin/lib").glob("*.dylib")))
files.extend(f"mods/crimson/compat/{name}.vcdiff" for name in (
    "dmc3.exe", "dmcLauncher.exe", "crimson_api.dll",
    "dmcload.dll", "DMCHDFix.asi", "DMCHDFix.ini",
))
if variant == "local":
    files.append("mods/crimson/prepared/payload.zip")

for path in files:
    original = source / path
    if original.is_symlink() or not original.is_file():
        raise SystemExit(f"Invalid package resource: {original}")
    target = project / path
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(original, target)

icon_name = "DMC3Patch.icns"
icon = source / "artwork" / icon_name
if source.name == "Project" and source.parent.name == "Resources":
    icon = source.parent / icon_name
if not icon.is_file() or icon.is_symlink():
    raise SystemExit(f"Missing app icon: {icon}")
shutil.copy2(icon, resources / icon_name)

manifest = Path("mods/crimson/prepared/manifest.json")
recipe = json.loads((source / manifest).read_text())
recipe.pop("sourceDirectory", None)
if variant == "public":
    recipe.pop("archiveSHA256", None)
elif not recipe.get("archiveSHA256"):
    raise SystemExit("Missing Crimson ZIP hash in manifest")
target_manifest = project / manifest
target_manifest.parent.mkdir(parents=True, exist_ok=True)
target_manifest.write_text(json.dumps(recipe, indent=2, ensure_ascii=False) + "\n")

licenses.mkdir(parents=True)
shutil.copy2(project / "LICENSE", licenses / "DMC3-Patch-MIT.txt")
shutil.copy2(project / "docs/Xdelta-LICENSE.txt", licenses / "Xdelta-LICENSE.txt")
for name in ["COPYING.LGPLv2.1", "THIRD-PARTY.md", "CRIMSON-THIRD-PARTY.md", "PERMISOS.md", "CREDITOS.md", "Crimson-LICENSE.txt"]:
    shutil.copy2(project / "docs" / name, licenses)
