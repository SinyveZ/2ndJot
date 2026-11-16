#!/bin/zsh
set -euo pipefail
ROOT_DIR="${0:A:h:h}"
clang -fobjc-arc -fblocks -framework Cocoa "$ROOT_DIR/tools/render-media.m" -o /private/tmp/YinSu-render-media
/private/tmp/YinSu-render-media "$ROOT_DIR/docs/media"
