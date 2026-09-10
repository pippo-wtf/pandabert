#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift build --disable-sandbox -c release --scratch-path .build -j 4
pulse_bin="$(swift build --disable-sandbox -c release --scratch-path .build --show-bin-path)"
pulse_app="$PWD/dist/Pulse.app"
mkdir -p "$pulse_app/Contents/MacOS" "$pulse_app/Contents/Resources"
cp "$pulse_bin/Pulse" "$pulse_app/Contents/MacOS/Pulse"
cp "$pulse_bin/pulse-agent" "$pulse_app/Contents/Resources/pulse-agent"
cat > "$pulse_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>wtf.pippo.pulse</string>
<key>CFBundleName</key><string>Pulse</string>
<key>CFBundleDisplayName</key><string>Pulse</string>
<key>CFBundleExecutable</key><string>Pulse</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.6</string>
<key>CFBundleVersion</key><string>7</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$pulse_app/Contents/Resources/pulse-agent"
codesign --force --sign - "$pulse_app"
codesign --verify --strict "$pulse_app"
ditto -c -k --keepParent "$pulse_app" "$PWD/dist/Pulse-0.1.6-macos-arm64.zip"
echo "Packaged: $pulse_app"
