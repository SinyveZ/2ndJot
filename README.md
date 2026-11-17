# 2ndJot · 双轨记

**Stay on track. Jot it down.**

[简体中文](README.zh-CN.md) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md)

While coding with AI, your next idea may arrive while the harness is still working or a usage limit prevents another message. 2ndJot is a macOS menu bar utility for keeping those thoughts handy until you can send them to AI.

![Quick capture and desktop sticky notes](docs/media/workflow-preview.en.png)

## One entry point, two destinations

Press **Control + Shift + Space** to open the capture panel. The shortcut is configurable.

| Where the idea goes | Action and result |
| --- | --- |
| Your note library | Press Return or click the floppy-disk button to create a separate `.md` file. Optionally open it in Obsidian after saving. |
| Your desktop | Click the pin to create a sticky note. Text, position, and size are saved locally. Closing a note can ask whether to save a Markdown copy. |

In a sticky note, Return inserts a line break and `Command + Return` saves a Markdown copy. Drag the upper-left circle to move it; use the lower-right corner to resize. Capture and sticky notes have separate glass settings.

Type or dictate using your current input method.

## Install and get started

The package is for **Apple Silicon Macs**. Preview builds are currently shared privately; you can also [build from source](docs/DEVELOPMENT.md).

1. Unzip the preview package and move `2ndJot.app` into Applications.
2. Open the app, right-click its menu bar icon, then choose **Settings → General → Save Location**. Select a local Obsidian vault or a folder inside it.
3. Press **Control + Shift + Space**, enter a thought, and press Return to save. Click the pin instead to keep a sticky note.

Saving Markdown requires selecting an Obsidian vault or a folder inside it. Desktop sticky notes work independently, without Obsidian.

Left-click the menu bar icon to capture; right-click for the menu.

The preview is not notarized; if macOS blocks first launch, follow [Apple's first-launch guidance](https://support.apple.com/en-us/102445).

## Interface language

The app supports **English and Simplified Chinese** and follows your system language by default. In **Settings → General → App language**, choose **System default**, **简体中文**, or **English**. Changes take effect immediately, without restarting, and preserve your notes and personal settings.

## Data and privacy

No account is required. Notes, drafts, and sticky notes stay on your Mac; the app does not upload their contents. Your input method controls its speech service, and Obsidian controls its sync.

## Development and contributions

Feedback is welcome in [Issues](https://github.com/SinyveZ/2ndJot/issues). See [development notes](docs/DEVELOPMENT.md) and the [contribution guide](CONTRIBUTING.md) to get involved.

## License

[MIT](LICENSE).
