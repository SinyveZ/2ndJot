#!/bin/zsh
# Offline geometry check only: no app, GUI, preferences, or generated repo assets.
set -euo pipefail
ROOT_DIR="${0:A:h:h}"
CHECK_DIR="$(mktemp -d /private/tmp/YinSu-g3-check.XXXXXX)"
trap 'rm -rf "$CHECK_DIR"' EXIT
clang -fobjc-arc -fblocks -std=gnu11 -O2 -Wall -Wextra -Werror \
  -mmacosx-version-min=13.0 -fmodules-cache-path="$CHECK_DIR/module-cache" \
  -framework Cocoa -framework CoreGraphics \
  "$ROOT_DIR/tools/check-g3.m" -o "$CHECK_DIR/check-g3"
"$CHECK_DIR/check-g3"
