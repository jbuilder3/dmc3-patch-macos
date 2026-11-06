#!/bin/zsh
set -euo pipefail
PROJECT_DIR="${0:A:h}"
cd "$PROJECT_DIR"
VARIANT=public
if [[ -f mods/crimson/prepared/payload.zip ]]; then VARIANT=local; fi
if [[ "${1:-}" == --public ]]; then VARIANT=public
elif [[ -n "${1:-}" ]]; then print -u2 'Uso: ./build.sh [--public]'; exit 1
fi
if [[ "$PROJECT_DIR" == */Contents/Resources/Project ]]; then
  BUILD_DIR="$HOME/Library/Application Support/DMC3 Patch/DevelopmentBuild"
else
  BUILD_DIR="$PROJECT_DIR/.build"
fi
APP_DIR="${DMC3_PATCH_APP_OUTPUT:-$BUILD_DIR/DMC3 Patch.app}"
APP_DIR="${APP_DIR:A}"
if [[ -e "$APP_DIR" ]]; then print -u2 "Ya existe: $APP_DIR"; exit 1; fi
export TMPDIR="$BUILD_DIR/tmp"
export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/module-cache"
export SWIFT_MODULECACHE_PATH="$CLANG_MODULE_CACHE_PATH"
mkdir -p "$TMPDIR" "$CLANG_MODULE_CACHE_PATH" "${APP_DIR:h}"
STAGE=$(/usr/bin/mktemp -d "$BUILD_DIR/package.XXXXXXXX")
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/DMC3 Patch.app"
mkdir -p "$APP/Contents/MacOS"
/usr/bin/xcrun swiftc -swift-version 5 -Osize -whole-module-optimization -Xlinker -dead_strip \
  -module-cache-path "$CLANG_MODULE_CACHE_PATH" -target arm64-apple-macosx13.0 \
  -framework AppKit -framework CryptoKit Sources/*.swift \
  -o "$APP/Contents/MacOS/DMC3Patch"
/usr/bin/strip -S -x "$APP/Contents/MacOS/DMC3Patch"
python3 tools/package-resources.py "$PROJECT_DIR" "$APP/Contents/Resources" "$VARIANT"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>DMC3Patch</string>
<key>CFBundleIdentifier</key><string>local.dmc3.patch.mac</string>
<key>CFBundleName</key><string>DMC3 Patch</string>
<key>CFBundleDisplayName</key><string>DMC3 Patch</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.10.5</string>
<key>CFBundleVersion</key><string>18</string>
<key>CFBundleIconFile</key><string>DMC3Patch.icns</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSQuitAlwaysKeepsWindows</key><false/>
<key>NSHumanReadableCopyright</key><string>DMC3 Patch. Original authors and licenses included.</string>
</dict></plist>
PLIST
TOOL_DIR="$APP/Contents/Resources/Project/tools/bin"
for binary in "$TOOL_DIR"/lib/*.dylib "$TOOL_DIR/ffmpeg" "$TOOL_DIR/ffprobe" "$TOOL_DIR/xdelta3decode"; do
  /usr/bin/codesign --force --sign - "$binary"
done
/usr/bin/codesign --force --sign - "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"
mv "$APP" "$APP_DIR"
print "App creada ($VARIANT) en $APP_DIR"
