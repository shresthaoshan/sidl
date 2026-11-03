#!/bin/sh
# Builds Touchyy.app so macOS can grant it Accessibility permission.
# Usage: scripts/bundle.sh [debug|release]
#
# Signs with the "Touchyy Dev" certificate (or $SIGN_IDENTITY), so Accessibility permission
# survives rebuilds. Without it, the app is ad-hoc signed and loses the permission on every build.
# To create the certificate: Keychain Access > Certificate Assistant > Create a Certificate,
# name "Touchyy Dev", Identity Type "Self Signed Root", Certificate Type "Code Signing".
# Then open the certificate and set Trust > Code Signing to "Always Trust".
set -eu
cd "$(dirname "$0")/.."
config="${1:-debug}"

swift build -c "$config"
app=Touchyy.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp ".build/$config/Touchyy" "$app/Contents/MacOS/Touchyy"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>dev.touchyy.Touchyy</string>
    <key>CFBundleName</key><string>Touchyy</string>
    <key>CFBundleExecutable</key><string>Touchyy</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
identity="${SIGN_IDENTITY:-Touchyy Dev}"
if ! security find-identity -v -p codesigning | grep -qF "\"$identity\""; then
    echo "warning: no valid signing identity \"$identity\"; using ad-hoc signing (Accessibility resets on every build)" >&2
    identity=-
fi
codesign --force --sign "$identity" "$app"
echo "Built $app"
