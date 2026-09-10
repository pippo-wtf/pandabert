#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift build --disable-sandbox -c release --scratch-path .build -j 4
panda_bin="$(swift build --disable-sandbox -c release --scratch-path .build --show-bin-path)"
panda_app="$PWD/dist/PandaBert.app"
mkdir -p "$panda_app/Contents/MacOS" "$panda_app/Contents/Resources"
cp "$panda_bin/Panda" "$panda_app/Contents/MacOS/PandaBert"
cp "$panda_bin/panda-agent" "$panda_app/Contents/Resources/panda-agent"
ditto "$panda_bin/Panda_Panda.bundle" "$panda_app/Contents/Resources/Panda_Panda.bundle"
swift scripts/generate-icons.swift "$PWD" "$PWD/.build/Panda.iconset"
iconutil -c icns "$PWD/.build/Panda.iconset" -o "$panda_app/Contents/Resources/Panda.icns"
cat > "$panda_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>wtf.pippo.pulse</string>
<key>CFBundleName</key><string>PandaBert</string>
<key>CFBundleDisplayName</key><string>PandaBert</string>
<key>CFBundleExecutable</key><string>PandaBert</string>
<key>CFBundleIconFile</key><string>Panda</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.4.4</string>
<key>CFBundleVersion</key><string>20</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
ln -sfn panda-agent "$panda_app/Contents/Resources/pulse-agent"
codesign --force --sign - "$panda_app/Contents/Resources/panda-agent"
codesign --force --sign - "$panda_app"
codesign --verify --strict "$panda_app"
ditto -c -k --keepParent "$panda_app" "$PWD/dist/PandaBert-0.4.4-macos-arm64.zip"
if [ ! -e "$PWD/dist/Panda.app" ]; then ln -sfn PandaBert.app "$PWD/dist/Panda.app"; fi
echo "Packaged: $panda_app"
