#!/bin/zsh
# Prepare a reviewable source tree without the private Git history or old dist/.
# Does not create a repository, upload, or publish anything.
set -euo pipefail
ROOT_DIR="${0:A:h:h}"
test -f "$ROOT_DIR/LICENSE"
# A source handoff must include both source-owned language bundles, not only
# the app binary or a developer's generated resources.
for BUNDLE_LANGUAGE in en zh-Hans; do
  for STRINGS_TABLE in Localizable InfoPlist; do
    test -f "$ROOT_DIR/src/Resources/$BUNDLE_LANGUAGE.lproj/$STRINGS_TABLE.strings"
  done
done
mkdir -p "$ROOT_DIR/.launch-work"
STAGE_DIR="$(mktemp -d "$ROOT_DIR/.launch-work/2ndJot-public.XXXXXX")"
for item in src build.sh release.sh README.md README.zh-CN.md CHANGELOG.md CONTRIBUTING.md SECURITY.md LICENSE .gitignore .github docs tools; do
  ditto --norsrc --noextattr "$ROOT_DIR/$item" "$STAGE_DIR/$item"
done
print -r -- "$STAGE_DIR"
