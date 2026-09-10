#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift build --disable-sandbox -c release --scratch-path .build -j 4
panda_bin="$(swift build --disable-sandbox -c release --scratch-path .build --show-bin-path)"
panda_app="$PWD/dist/Panda.app"
mkdir -p "$panda_app/Contents/MacOS" "$panda_app/Contents/Resources"
cp "$panda_bin/Panda" "$panda_app/Contents/MacOS/Panda"
cp "$panda_bin/panda-agent" "$panda_app/Contents/Resources/panda-agent"
cat > "$panda_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>wtf.pippo.pulse</string>
<key>CFBundleName</key><string>Panda</string>
<key>CFBundleDisplayName</key><string>Panda</string>
<key>CFBundleExecutable</key><string>Panda</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>CFBundleVersion</key><string>8</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
ln -sfn panda-agent "$panda_app/Contents/Resources/pulse-agent"
codesign --force --sign - "$panda_app/Contents/Resources/panda-agent"
codesign --force --sign - "$panda_app"
codesign --verify --strict "$panda_app"
ditto -c -k --keepParent "$panda_app" "$PWD/dist/Panda-0.2.0-macos-arm64.zip"
echo "Packaged: $panda_app"
