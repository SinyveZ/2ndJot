#!/bin/zsh
set -euo pipefail
ROOT_DIR="${0:A:h:h}"
clang -fobjc-arc -O2 -framework Cocoa "$ROOT_DIR/tools/render-corner-design.m" -o /private/tmp/2ndJot-corner-design
/private/tmp/2ndJot-corner-design "$ROOT_DIR/docs/media"
