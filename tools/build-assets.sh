#!/bin/zsh
set -euo pipefail
ROOT_DIR="${0:A:h:h}"
ASSET_BUILD_DIR="${1:-/private/tmp/YinSu-build}"
mkdir -p "$ASSET_BUILD_DIR"
clang -fobjc-arc -fblocks -framework Cocoa "$ROOT_DIR/tools/render-brand.m" -o "$ASSET_BUILD_DIR/render-brand"
"$ASSET_BUILD_DIR/render-brand" --assets "$ASSET_BUILD_DIR/BrandAssets"
iconutil -c icns -o "$ASSET_BUILD_DIR/BrandAssets/AppIcon.icns" "$ASSET_BUILD_DIR/BrandAssets/AppIcon.iconset"
