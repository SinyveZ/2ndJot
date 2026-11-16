#!/bin/zsh
set -euo pipefail
ROOT_DIR="${0:A:h:h}"
clang -fobjc-arc -fblocks -framework Cocoa -framework ImageIO "$ROOT_DIR/tools/render-pin-design.m" -o /private/tmp/YinSu-render-pin-design
/private/tmp/YinSu-render-pin-design "$ROOT_DIR/docs/media"
