#!/bin/zsh
# Give disposable UI runs their own app identity, so the daily app keeps its focus.
set -euo pipefail
if (( $# < 3 || $# > 4 )); then
  print -u2 'Usage: tools/isolate-app.sh source/Contents/MacOS/YinSu destination.app suffix [en|zh-Hans]'
  exit 1
fi
SOURCE_APP="${1:A:h:h:h}"
DEST_APP="${2:A}"
RUN_SUFFIX="$3"
PREVIEW_LANGUAGE="${4:-}"
[[ "$RUN_SUFFIX" =~ ^[A-Za-z0-9.-]+$ ]]
[[ -z "$PREVIEW_LANGUAGE" || "$PREVIEW_LANGUAGE" == en || "$PREVIEW_LANGUAGE" == zh-Hans ]]
test -f "$SOURCE_APP/Contents/Info.plist"
test ! -e "$DEST_APP"
mkdir -p "${DEST_APP:h}"
ditto --norsrc --noextattr "$SOURCE_APP" "$DEST_APP"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.sinyve.YinSu.preview.$RUN_SUFFIX" "$DEST_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName 2ndJot Preview' "$DEST_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName 2ndJot Preview' "$DEST_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :YinSuPreviewDirectory string ${DEST_APP:h}" "$DEST_APP/Contents/Info.plist"
if [[ -n "$PREVIEW_LANGUAGE" ]]; then
  /usr/libexec/PlistBuddy -c "Add :YinSuPreviewLanguage string $PREVIEW_LANGUAGE" "$DEST_APP/Contents/Info.plist"
fi
# Localized InfoPlist.strings overrides the base plist in Launch Services/CUA.
# Rewrite both names before signing, preserving any other localized metadata.
python3 - "$DEST_APP" <<'PY'
import json
import plistlib
import subprocess
import sys
from pathlib import Path

resources = Path(sys.argv[1]) / 'Contents' / 'Resources'
for language, name in (('en', '2ndJot Preview'), ('zh-Hans', '双轨记预览')):
    table = resources / (language + '.lproj') / 'InfoPlist.strings'
    values = {}
    if table.exists():
        values = json.loads(subprocess.check_output(
            ['plutil', '-convert', 'json', '-o', '-', str(table)]))
    values.update(CFBundleName=name, CFBundleDisplayName=name)
    table.parent.mkdir(parents=True, exist_ok=True)
    table.write_bytes(plistlib.dumps(values, fmt=plistlib.FMT_XML))
PY
mkdir -p "${DEST_APP:h}/Demo Vault/.obsidian"
codesign --force --deep --sign - "$DEST_APP" >&2
print -r -- "$DEST_APP/Contents/MacOS/YinSu"
