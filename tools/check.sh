#!/bin/zsh
# Uses disposable data and a separate preferences suite. Requires a macOS GUI session.
set -euo pipefail
ROOT_DIR="${0:A:h:h}"
"$ROOT_DIR/tools/check-g3.sh"
"$ROOT_DIR/tools/check-resize-arcs.sh"
python3 "$ROOT_DIR/tools/check-localization.py"
APP_BIN="${YIN_SU_APP_BIN:-/private/tmp/YinSu-build/2ndJot.app/Contents/MacOS/YinSu}"
TEST_DIR="$(mktemp -d /private/tmp/YinSu-check.XXXXXX)"
APP_BIN="$("$ROOT_DIR/tools/isolate-app.sh" "$APP_BIN" "$TEST_DIR/双轨记检查.app" "${TEST_DIR:t}")"
export YIN_SU_ISOLATED=1
export VOICE_NOTE_FOLDER_PATH="$TEST_DIR/Vault/语音速记"
export YIN_SU_STICKY_STORE="$TEST_DIR/stickies.plist"
export YIN_SU_EDITOR_DRAFT="$TEST_DIR/editor-draft.txt"
export VOICE_NOTE_NO_OPEN=1 VOICE_NOTE_NO_CLIPBOARD=1
mkdir -p "$TEST_DIR/Vault/.obsidian"
python3 - "$APP_BIN" "$TEST_DIR" <<'PY'
import os, subprocess, sys, tempfile
from pathlib import Path
app, folder = sys.argv[1:]
checks = [
    (['--preview-isolation-check'], ['previewRelaunchIsolated=1']),
    (['--self-test'], ['.md']),
    (['--glass-preferences-check'], ['glassDefaultsDistinct=1 glassProfilesIndependent=1 glassPersistence=1 glassLegacyPreserved=1 glassMigrationIdempotent=1 glassValuesFinite=1']),
    (['--settings-check'], ['settingsLayout=1', 'settingsVisible=1', 'keyWindow=1']),
    (['--glass-check'], ['glassPinSwitch=1 glassQuickOnly=1 glassStickyOnly=1 glassNewNote=1 glassSeparateReset=1 glassResetNotes=1 glassFallbackTint=1']),
    (['--layout-check'], ['initialHeight=154', 'maxHeight=460', 'scroller=1']),
    (['--ui-check', '--commit-check'], ['panelVisible=1 keyWindow=1 textFocused=1', 'commitSaved=1', 'textCleared=1']),
    (['--toggle-check'], ['toggleBefore=1 toggleAfter=0 confirmation=0']),
    (['--open-failure-check'], ['failureTextRetained=1 noDuplicateSave=1 pendingRetry=1 panelVisible=1']),
    (['--confirm-check'], ['confirmationShown=1 panelStillVisible=1']),
    (['--sticky-check'], ['stickies=2 stored=2 valid=1', 'stickyReturnIsNewline=1', 'manualResizeKept=1', 'dragHandleTop=44 shrunkDragHandleTop=44', 'remaining=1', 'selectedPage=1']),
    (['--sticky-restore-check'], ['restored=1 text=1', 'size=360x260', 'rootRadius=18', 'restoredPin=1 restoredPinStatic=1', 'restoredG3Mask=1']),
    (['--pin-check'], ['pinGeometry=1 pinDragTarget=1 pinMotionRespected=1 pinAnimationSettled=1 pinMotionSample=1 pinContentPreserved=1 pinTransitionAnchor=1 centralPinAbsent=1']),
    (['--pin-check', '--reduce-pin-motion'], ['pinGeometry=1 pinDragTarget=1 pinMotionRespected=1 pinAnimationSettled=1 pinMotionSample=1 pinContentPreserved=1 pinTransitionAnchor=1 centralPinAbsent=1']),
    (['--save-button-check'], ['saveButtonWrites=1 pinDoesNotWriteMarkdown=1 stickyCloseAsks=1 stickyCloseSaves=1 saveButtonRetryNoDuplicate=1']),
    (['--brand-check'], ['quickBrand=1 menuBrand=1 appIconBundled=1 stickyPinReplacesLogo=1 curvedResizeHandle=1 appNameUnified=1 legacyIdentityKept=1']),
    (['--corner-check'], ['g3QuickMask=1 g3QuickResize=1 g3StickyMask=1 g3StickyResize=1 g3StickyPortrait=1 g3SingleMaterialOutline=1 g3DragTarget=1 noWindowShadow=1']),
    (['--localization-check'], ['localizedStrings=1 languageSwitchKeepsContent=1 languageSwitchKeepsSettings=1 localizedLayout=1 localizedDefaultHint=1 languagePreferencePersists=1 systemLanguageFallback=1']),
    (['--resize-check'], ['resizeCursorDiagonal=1 resizeCursorHeld=1 resizeCursorReleased=1 resizeDragAnchored=1 resizeDragClamped=1 resizeCancelCleanup=1 resizeDetachCleanup=1 resizeDisabledStateKept=1']),
    (['--draft-save-check'], ['draftSaved=1']),
    (['--draft-check'], ['draftRestored=1']),
]
failures = []
for language in ("zh-Hans", "en"):
    language_folder = Path(folder) / language
    (language_folder / "Vault" / ".obsidian").mkdir(parents=True)
    for flags, expected in checks:
        environment = dict(os.environ, YIN_SU_UI_LANGUAGE=language,
            VOICE_NOTE_FOLDER_PATH=str(language_folder / "Vault" / "语音速记"),
            YIN_SU_STICKY_STORE=str(language_folder / "stickies.plist"),
            YIN_SU_EDITOR_DRAFT=str(language_folder / "editor-draft.txt"))
        if flags[0] == '--preview-isolation-check':
            for key in ('YIN_SU_ISOLATED', 'VOICE_NOTE_FOLDER_PATH', 'YIN_SU_STICKY_STORE',
                        'YIN_SU_EDITOR_DRAFT', 'VOICE_NOTE_NO_OPEN', 'VOICE_NOTE_NO_CLIPBOARD'):
                environment.pop(key, None)
        if flags[0] in {'--glass-check', '--pin-check', '--save-button-check', '--brand-check', '--corner-check', '--resize-check', '--localization-check'}:
            case_dir = Path(tempfile.mkdtemp(prefix='case-', dir=language_folder))
            (case_dir / 'Vault' / '.obsidian').mkdir(parents=True)
            environment.update(VOICE_NOTE_FOLDER_PATH=str(case_dir / 'Vault' / 'Notes'),
                               YIN_SU_STICKY_STORE=str(case_dir / 'stickies.plist'),
                               YIN_SU_EDITOR_DRAFT=str(case_dir / 'editor-draft.txt'))
        if "--reduce-pin-motion" in flags: environment["YIN_SU_REDUCE_MOTION"] = "1"
        result = subprocess.run([app, *flags], text=True, capture_output=True, timeout=25, env=environment)
        output = result.stdout
        if result.returncode or any(value not in output for value in expected):
            print('FAIL', language, *flags, result.returncode, output, result.stderr, sep='\n')
            failures.append(language + ' ' + ' '.join(flags))
            continue
        print('PASS', language, *flags, output.strip().replace('\n', ' | '))
    draft_path = language_folder / 'editor-draft.txt'
    if not draft_path.exists() or draft_path.read_text() != '未提交的长文草稿':
        failures.append(language + ' background draft preservation')
        print('FAIL', language, 'background draft preservation')
    else:
        print('PASS', language, 'background draft preservation')
print('Data:', folder)
if failures:
    print('Failed checks:', ', '.join(failures))
    sys.exit(1)
PY
