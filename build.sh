#!/bin/zsh
# Build 2ndJot: /private/tmp/YinSu-build/2ndJot.app.
set -euo pipefail

ROOT_DIR="${0:A:h}"
BUILD_DIR="${YIN_SU_BUILD_DIR:-/private/tmp/YinSu-build}"
APP_DIR="$BUILD_DIR/2ndJot.app"

for BUNDLE_LANGUAGE in en zh-Hans; do
  for STRINGS_TABLE in Localizable InfoPlist; do
    test -f "$ROOT_DIR/src/Resources/$BUNDLE_LANGUAGE.lproj/$STRINGS_TABLE.strings"
    plutil -lint "$ROOT_DIR/src/Resources/$BUNDLE_LANGUAGE.lproj/$STRINGS_TABLE.strings" >&2
  done
done

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$BUILD_DIR/module-cache"
cp "$ROOT_DIR/src/Info.plist" "$APP_DIR/Contents/Info.plist"
"$ROOT_DIR/tools/build-assets.sh" "$BUILD_DIR" >&2
cp "$BUILD_DIR/BrandAssets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/LICENSE" "$APP_DIR/Contents/Resources/LICENSE"
for LOCALIZED_DIR in "$ROOT_DIR"/src/Resources/*.lproj(/N); do
  ditto --norsrc --noextattr "$LOCALIZED_DIR" "$APP_DIR/Contents/Resources/${LOCALIZED_DIR:t}"
done

clang \
  -fobjc-arc \
  -O2 \
  -mmacosx-version-min=13.0 \
  -fmodules-cache-path="$BUILD_DIR/module-cache" \
  -framework Cocoa \
  -framework ApplicationServices \
  -framework Carbon \
  -framework QuartzCore \
  -framework ServiceManagement \
  -o "$APP_DIR/Contents/MacOS/YinSu" \
  "$ROOT_DIR/src/main.m"

chmod +x "$APP_DIR/Contents/MacOS/YinSu"
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
