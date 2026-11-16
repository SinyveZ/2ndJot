#!/bin/zsh
# Offline geometry only: no app launch, preferences, GUI, or user data.
set -euo pipefail
ROOT_DIR="${0:A:h:h}"
CHECK_DIR="$(mktemp -d /private/tmp/YinSu-resize-arcs-check.XXXXXX)"
trap 'rm -rf "$CHECK_DIR"' EXIT
clang -fobjc-arc -fblocks -std=gnu11 -O2 -Wall -Wextra -Werror \
  -mmacosx-version-min=13.0 -fmodules-cache-path="$CHECK_DIR/module-cache" \
  -framework Cocoa -framework CoreGraphics \
  "$ROOT_DIR/tools/check-resize-arcs.m" -o "$CHECK_DIR/check-resize-arcs"
"$CHECK_DIR/check-resize-arcs"
