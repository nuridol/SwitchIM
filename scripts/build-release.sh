#!/bin/bash
#
# SwitchIM — Release build & sign script
#
# - Clean build (removes .build, regenerates the Xcode project)
# - Release build with code signing (Developer ID if available, else ad-hoc)
# - Copies the signed SwitchIM.app into dist/
# - Verifies the signature, then cleans the .build/ folder
#
# Usage:
#   ./scripts/build-release.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="SwitchIM"
DERIVED_DATA="$ROOT/.build/DerivedData"
PRODUCT="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
DIST="$ROOT/dist"

echo "==> Cleaning build folder (.build)"
rm -rf "$ROOT/.build"

echo "==> Preparing dist/"
rm -rf "$DIST"
mkdir -p "$DIST"

echo "==> Generating Xcode project"
xcodegen generate

# Pick a Developer ID certificate if present; otherwise fall back to ad-hoc
# signing so the build still succeeds on machines without a signing identity.
SIGN_IDENTITY="-"
if identity=$(security find-identity -v -p codesigning 2>/dev/null |
    grep "Developer ID Application" |
    sed -E 's/^[[:space:]]*[0-9]+\)[[:space:]]+"([^"]+)".*/\1/' | head -1); then
    if [[ -n "$identity" ]]; then
        SIGN_IDENTITY="$identity"
        echo "==> Signing identity: $identity"
    fi
fi

echo "==> Release build"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    build

if [[ ! -d "$PRODUCT" ]]; then
    echo "ERROR: build product not found: $PRODUCT" >&2
    exit 1
fi

echo "==> Copying app to dist/"
cp -R "$PRODUCT" "$DIST/$APP_NAME.app"

echo "==> Verifying code signature"
codesign --verify --deep --strict "$DIST/$APP_NAME.app"
if codesign -dv --verbose=2 "$DIST/$APP_NAME.app" 2>&1 | grep -q "Signature=adhoc"; then
    echo "    signature: ad-hoc (no Developer ID certificate)"
else
    codesign -dv --verbose=2 "$DIST/$APP_NAME.app" 2>&1 | grep -E "Authority|TeamIdentifier" || true
fi

echo "==> Cleaning build folder (.build)"
rm -rf "$ROOT/.build"

echo "==> Done: $DIST/$APP_NAME.app"