#!/bin/zsh
# Start a disposable preview without touching normal preferences or notes.
set -euo pipefail
ROOT_DIR="${0:A:h:h}"
PREVIEW_LANGUAGE="${2:-}"
if (( $# > 2 )) || [[ -n "$PREVIEW_LANGUAGE" && "$PREVIEW_LANGUAGE" != en && "$PREVIEW_LANGUAGE" != zh-Hans ]]; then
  print -u2 'Usage: tools/preview.sh [settings|editor|light|dark] [en|zh-Hans]'
  exit 1
fi
case "${1:-settings}" in
  settings) MODE=--preview-settings ;;
  editor) MODE=--preview-editor ;;
  light|dark) export YIN_SU_PREVIEW_BACKGROUND="$1"; MODE=--preview-stickies ;;
  *) print -u2 'Usage: tools/preview.sh [settings|editor|light|dark] [en|zh-Hans]'; exit 1 ;;
esac
PREVIEW_DIR="$(mktemp -d /private/tmp/YinSu-preview.XXXXXX)"
export YIN_SU_ISOLATED=1
export VOICE_NOTE_FOLDER_PATH="$PREVIEW_DIR/Demo Vault/Notes"
export YIN_SU_STICKY_STORE="$PREVIEW_DIR/stickies.plist"
export YIN_SU_EDITOR_DRAFT="$PREVIEW_DIR/editor-draft.txt"
export VOICE_NOTE_NO_OPEN=1 VOICE_NOTE_NO_CLIPBOARD=1
if [[ -n "$PREVIEW_LANGUAGE" ]]; then
  export YIN_SU_UI_LANGUAGE="$PREVIEW_LANGUAGE"
else
  unset YIN_SU_UI_LANGUAGE
fi
mkdir -p "$PREVIEW_DIR/Demo Vault/.obsidian"
PREVIEW_APP="$PREVIEW_DIR/2ndJot Preview.app"
PREVIEW_BIN="$("$ROOT_DIR/tools/isolate-app.sh" "${YIN_SU_BUILD_DIR:-/private/tmp/YinSu-build}/2ndJot.app/Contents/MacOS/YinSu" "$PREVIEW_APP" "${PREVIEW_DIR:t}" "$PREVIEW_LANGUAGE")"
print -r -- "Preview data: $PREVIEW_DIR"
print -r -- "Preview app: $PREVIEW_APP"
print -r -- "Preview language: ${PREVIEW_LANGUAGE:-system}"
exec "$PREVIEW_BIN" "$MODE"
