#!/bin/bash
# Builds build/CurlToCode.app (universal: Apple Silicon + Intel).
# Usage: ./build.sh [--install]   (--install copies the app to /Applications)
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="CurlToCode"
APP="build/$APP_NAME.app"
MIN_MACOS="13.0"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/obj

echo "Compiling..."
for arch in arm64 x86_64; do
    swiftc -O -parse-as-library \
        -target "$arch-apple-macos$MIN_MACOS" \
        Sources/Core/*.swift Sources/Core/Generators/*.swift Sources/App/*.swift \
        -o "build/obj/$APP_NAME-$arch"
done
lipo -create build/obj/$APP_NAME-arm64 build/obj/$APP_NAME-x86_64 -output "$APP/Contents/MacOS/$APP_NAME"

echo "Generating icon..."
rm -rf build/obj/AppIcon.iconset
swift Scripts/make-icon.swift build/obj/AppIcon.iconset
iconutil -c icns build/obj/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>cURL to Code</string>
    <key>CFBundleDisplayName</key><string>cURL to Code</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>com.example.curltocode</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>2.0</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" /Applications/
    echo "Installed to /Applications/$APP_NAME.app"
fi
