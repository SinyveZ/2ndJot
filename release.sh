#!/bin/zsh
# Package 2ndJot app and sources in dist/ without removing older artifacts.
set -euo pipefail

ROOT_DIR="${0:A:h}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$ROOT_DIR/src/Info.plist")
APP_DIR="$("$ROOT_DIR/build.sh")"
DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"

ARCH="$(uname -m)"
python3 "$ROOT_DIR/tools/zip-release.py" "$APP_DIR" "$DIST_DIR/2ndJot-$VERSION-$ARCH.zip"

SOURCE_STAGE="$(mktemp -d /private/tmp/YinSu-source.XXXXXX)"
trap 'rm -rf "$SOURCE_STAGE"' EXIT
mkdir -p "$SOURCE_STAGE/2ndJot-source/src"
ditto --norsrc --noextattr "$ROOT_DIR/src" "$SOURCE_STAGE/2ndJot-source/src"
for item in build.sh release.sh README.md README.zh-CN.md CHANGELOG.md CONTRIBUTING.md SECURITY.md LICENSE .gitignore .github docs tools; do
  if [ -e "$ROOT_DIR/$item" ]; then
    ditto --norsrc --noextattr "$ROOT_DIR/$item" "$SOURCE_STAGE/2ndJot-source/$item"
  fi
done
python3 "$ROOT_DIR/tools/zip-release.py" "$SOURCE_STAGE/2ndJot-source" "$DIST_DIR/2ndJot-$VERSION-source.zip"

cd "$DIST_DIR"
shasum -a 256 "2ndJot-$VERSION-$ARCH.zip" "2ndJot-$VERSION-source.zip" > "2ndJot-$VERSION-SHA256SUMS.txt"

ls -lh "$DIST_DIR/2ndJot-$VERSION-$ARCH.zip" "$DIST_DIR/2ndJot-$VERSION-source.zip" "$DIST_DIR/2ndJot-$VERSION-SHA256SUMS.txt"
