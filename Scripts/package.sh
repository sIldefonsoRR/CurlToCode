#!/bin/bash
# Builds the macOS installers into dist/:
#   CurlToCode-<version>.pkg  Installer wizard that installs the app into /Applications
#   CurlToCode-<version>.dmg  Disk image to drag the app into Applications
#
# Without a signing identity everything is ad-hoc signed, which is fine on this Mac.
# To distribute to other Macs without Gatekeeper warnings, set:
#   DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)"
#   DEVELOPER_ID_INSTALLER="Developer ID Installer: Your Name (TEAMID)"
#   NOTARY_PROFILE=<profile saved with: xcrun notarytool store-credentials>
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="CurlToCode"
DISPLAY_NAME="cURL to Code"
BUNDLE_ID="com.example.curltocode"

echo "==> Building app"
./build.sh >/dev/null
APP="build/$APP_NAME.app"
# Keep stray extended attributes (quarantine, Finder info) out of the installers.
# (com.apple.provenance is system-managed and can't be removed; Installer restores
# it as an attribute, so the ._ entries it leaves in the pkg payload are harmless.)
/usr/bin/xattr -cr "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")

WORK=build/package
DIST=dist
rm -rf "$WORK" && mkdir -p "$WORK" "$DIST"
PKG="$DIST/$APP_NAME-$VERSION.pkg"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
rm -f "$PKG" "$DMG"

if [[ -n "${DEVELOPER_ID_APP:-}" ]]; then
    echo "==> Signing app with $DEVELOPER_ID_APP"
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APP" "$APP"
fi

notarize() { # file
    [[ -n "${NOTARY_PROFILE:-}" ]] || return 0
    echo "==> Notarizing $(basename "$1")"
    xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$1"
}

# ---------------------------------------------------------------- .pkg
echo "==> Building installer package"
ROOT="$WORK/root"
mkdir -p "$ROOT/Applications"
ditto --noextattr --noqtn "$APP" "$ROOT/Applications/$APP_NAME.app"

# Always install to /Applications, even if a copy of the app exists elsewhere
# (by default Installer "relocates" the update to wherever it finds the app).
pkgbuild --analyze --root "$ROOT" "$WORK/components.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$WORK/components.plist"

export COPYFILE_DISABLE=1
pkgbuild --root "$ROOT" \
    --component-plist "$WORK/components.plist" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --install-location / \
    "$WORK/$APP_NAME-component.pkg" >/dev/null

RES="$WORK/resources"
mkdir -p "$RES"
sed "s/__VERSION__/$VERSION/g" Installer/welcome.html > "$RES/welcome.html"
cp Installer/conclusion.html "$RES/conclusion.html"
swift Scripts/make-installer-art.swift "$APP/Contents/Resources/AppIcon.icns" "$RES"

cat > "$WORK/Distribution.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>$DISPLAY_NAME</title>
    <organization>$BUNDLE_ID</organization>
    <welcome file="welcome.html" mime-type="text/html"/>
    <conclusion file="conclusion.html" mime-type="text/html"/>
    <background file="background.png" mime-type="image/png" alignment="bottomleft" scaling="none"/>
    <background-darkAqua file="background-dark.png" mime-type="image/png" alignment="bottomleft" scaling="none"/>
    <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
    <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
    <volume-check>
        <allowed-os-versions>
            <os-version min="13.0"/>
        </allowed-os-versions>
    </volume-check>
    <choices-outline>
        <line choice="default">
            <line choice="$BUNDLE_ID"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="$BUNDLE_ID" visible="false">
        <pkg-ref id="$BUNDLE_ID"/>
    </choice>
    <pkg-ref id="$BUNDLE_ID" version="$VERSION" onConclusion="none">$APP_NAME-component.pkg</pkg-ref>
</installer-gui-script>
EOF

SIGN_ARGS=()
[[ -n "${DEVELOPER_ID_INSTALLER:-}" ]] && SIGN_ARGS=(--sign "$DEVELOPER_ID_INSTALLER" --timestamp)
productbuild --distribution "$WORK/Distribution.xml" \
    --resources "$RES" \
    --package-path "$WORK" \
    ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} \
    "$PKG" >/dev/null
notarize "$PKG"

# ---------------------------------------------------------------- .dmg
echo "==> Building disk image"
STAGE="$WORK/dmg"
mkdir -p "$STAGE"
ditto --noextattr --noqtn "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"

# Build read-write, give the volume a custom icon, then compress
RW="$WORK/rw.dmg"
hdiutil create -quiet -volname "$DISPLAY_NAME" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW"
MOUNT=$(hdiutil attach -nobrowse -noautoopen -readwrite "$RW" | awk -F'\t' '/\/Volumes\// {print $NF}')
SetFile -a C "$MOUNT" 2>/dev/null || true
sync
hdiutil detach -quiet "$MOUNT" || hdiutil detach -quiet -force "$MOUNT"
hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG"
rm -f "$RW"

if [[ -n "${DEVELOPER_ID_APP:-}" ]]; then
    codesign --force --timestamp --sign "$DEVELOPER_ID_APP" "$DMG"
fi
notarize "$DMG"

echo
echo "Done:"
ls -lh "$PKG" "$DMG" | awk '{print "  " $NF "  (" $5 ")"}'
