#!/usr/bin/env bash
# Builds a Developer ID-signed universal release into macos-app/dist/.
# release.sh passes the version it is releasing; other builds take the latest v* tag.
set -euo pipefail
cd "$(dirname "$0")"

APP="Headroom.app"
IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
LAST_TAG=$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || echo v0.0.0)
VERSION="${VERSION:-${LAST_TAG#v}}"

xcodegen generate --quiet
rm -rf build dist
# CFBundleVersion is what Sparkle compares with the appcast's sparkle:version, so both carry the version.
xcodebuild -project Headroom.xcodeproj -scheme Headroom -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build -quiet \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$VERSION" build

mkdir -p dist
cp -R "build/Build/Products/Release/$APP" dist/

# Sparkle's helpers need the Developer ID, hardened runtime and a timestamp for notarization.
# Inside out, no --deep: https://sparkle-project.org/documentation/sandboxing/ ("Code Signing")
SPARKLE="dist/$APP/Contents/Frameworks/Sparkle.framework"
sign() { codesign --force --options runtime --timestamp --sign "$IDENTITY" "$@"; }
sign "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
sign "$SPARKLE/Versions/B/Autoupdate"
sign "$SPARKLE/Versions/B/Updater.app"
sign "$SPARKLE"
sign "dist/$APP"

codesign --verify --deep --strict --verbose=1 "dist/$APP"
echo "Built dist/$APP ($VERSION)"
