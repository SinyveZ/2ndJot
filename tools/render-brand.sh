#!/bin/zsh
set -euo pipefail
ROOT_DIR="${0:A:h:h}"
"$ROOT_DIR/tools/build-assets.sh" /private/tmp/YinSu-brand-preview
/private/tmp/YinSu-brand-preview/render-brand --preview "$ROOT_DIR/docs/media"
