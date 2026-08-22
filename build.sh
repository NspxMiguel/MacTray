#!/bin/bash
# Builds MacTray.app (universal binary) into ./build.
set -euo pipefail

cd "$(dirname "$0")"

VERSION="${VERSION:-$(cat VERSION 2>/dev/null || echo 1.0.0)}"
APP="build/MacTray.app"
BUNDLE_ID="dev.nspx.MacTray"

echo "==> Compiling (release, arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/apple/Products/Release/MacTray "$APP/Contents/MacOS/MacTray"

echo "==> Drawing the icon"
rm -rf build/AppIcon.iconset
swift Tools/makeicon.swift build/AppIcon.iconset >/dev/null
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf build/AppIcon.iconset

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>MacTray</string>
    <key>CFBundleDisplayName</key><string>MacTray</string>
    <key>CFBundleExecutable</key><string>MacTray</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT — github.com/NspxMiguel/MacTray</string>
    <key>NSSupportsAutomaticTermination</key><false/>
    <key>NSSupportsSuddenTermination</key><false/>
</dict>
</plist>
PLIST

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "==> Done: $APP ($VERSION)"
