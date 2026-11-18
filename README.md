<a name="chinese"></a>

# 双轨记 · 2ndJot

**主线继续，灵感先记。**

[English](#english) · [更新日志](CHANGELOG.md) · [参与贡献](CONTRIBUTING.md)

双轨记是一款 macOS 速记工具：在 AI 执行任务时，或在任意工作占用主进程时，有新想法，先记下来，存为本地 Markdown，或钉成桌面便签。

![快捷输入框与桌面便签](docs/media/workflow-preview.png)

## 为什么做双轨记

我在用 AI 做 vibe coding 时，会遇到这样的情况：AI 编程工具（harness）还在执行当前的任务，我的思路已经往前走了。有时是接下来想做的调整，有时是另一个方向的想法。

但这时我没法直接把它们发给 AI：它还在工作，或者我需要顾及额度限制，或是我的注意力有限，不足以同时推进多个工作。我需要先把这些想法记下来，等合适的时候再发给它。

所以我做了双轨记。当前任务继续跑，我按一下快捷键，把想法先记下来：存进 Obsidian，或留成桌面便签，稍后再整理或推进。

“双轨”就是这两条同时进行的线：一条是正在推进的工作，一条是先记下、稍后处理的想法。

## 一个入口，两个去向

默认按 **⌃⇧Space（Control + Shift + Space）** 呼出输入框，快捷键可在设置中自定义。

| 去向    | 怎么做                                                      |
| ----- | -------------------------------------------------------- |
| 存进笔记库 | 按回车或点击软盘，保存为独立的 `.md` 文件；可在保存后自动打开 Obsidian。             |
| 留在桌面上 | 点击图钉，变成便签；内容、位置、层级和尺寸自动保留。关闭时亦可选择是否另存为 Markdown。便签可存在多个。 |

便签里回车换行，**⌘↩** 另存为 Markdown。拖动左上圆点移动窗口，拖动右下角调整便签大小。输入框和便签的玻璃外观可分别设置。

你可以沿用当前输入法，包括它提供的语音输入，让空中飞行的新灵感更快落在纸面上。

## 开始使用

安装包适用于 **Apple Silicon Mac**，最低系统版本为 macOS 13。

[下载 v1.6.0 安装包](https://github.com/SinyveZ/2ndJot/releases/download/v1.6.0/2ndJot-1.6.0-arm64.zip) · [源码包](https://github.com/SinyveZ/2ndJot/releases/download/v1.6.0/2ndJot-1.6.0-source.zip) · [SHA-256 校验值](https://github.com/SinyveZ/2ndJot/releases/download/v1.6.0/2ndJot-1.6.0-SHA256SUMS.txt) · [发布说明](https://github.com/SinyveZ/2ndJot/releases/tag/v1.6.0)

也可以[从源码构建](docs/DEVELOPMENT.md)。

1. 下载并解压安装包，将 `2ndJot.app` 放入“应用程序”文件夹。
2. 打开应用，右键菜单栏图标，在 **设置 → 通用 → 保存位置** 选择 Obsidian 库或库内文件夹。
3. 按 **⌃⇧Space**，输入想法，回车存盘，或点击图钉留为便签。便签可同时存在多个。
4. 退出快捷输入时，按下Esc或再次按下快捷键 **⌃⇧Space 即可。**

Markdown 保存位置需要选择 Obsidian 库；桌面便签可以独立使用，无需 Obsidian。菜单栏图标左键呼出输入框，右键打开菜单。

安装包尚未经过 Apple 公证；首次打开若被 macOS 拦截，可参考 [Apple 官方说明](https://support.apple.com/en-us/102445)。

## 中英文界面

支持简体中文与 English，默认跟随系统语言。在 **设置 → 通用 → 界面语言** 中随时切换，无需重启。

## 本地记录

无需注册账号。速记、草稿和便签保存在本机，应用不上传笔记内容。Obsidian 的同步和输入法的语音服务由它们各自控制。

## 反馈与贡献

欢迎通过 [Issues](https://github.com/SinyveZ/2ndJot/issues) 反馈使用感受和问题。构建与开发见[开发说明](docs/DEVELOPMENT.md)，提交修改前请阅读[贡献指南](CONTRIBUTING.md)。

## 许可证

[MIT](LICENSE)。

---

<a name="english"></a>

# 2ndJot · 双轨记

**Stay on track. Jot it down.**

[简体中文](#chinese) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md)

2ndJot is a quick capture app for macOS. If an idea comes to you while AI is running a task or you’re focused on other work, jot it down and save it as local Markdown or pin it to your desktop as a sticky note.

![Quick capture and desktop sticky notes](docs/media/workflow-preview.en.png)

## Why I built 2ndJot

When I’m vibe coding, I’m often thinking ahead while my AI coding tool (the harness) is still working on the current task. Sometimes I think of a change I want to make next. Other times, I get an idea that takes me in a different direction.

I can’t always send those ideas to the AI right away. The tool may still be busy, I may need to watch my usage limits, or I may only be able to focus on one task at a time. I need somewhere to jot down these ideas until it’s a good time to send them.

That’s why I built 2ndJot. While the current task keeps running, I press a shortcut and jot down the idea. I can save it to Obsidian or pin it to my desktop, then sort it out or act on it later.

The Chinese name, 双轨记, refers to those two tracks. One is the work already underway. The other is for ideas I’ve set aside for later.

## One entry point, two destinations

By default, press **Control + Shift + Space** to open Quick Capture. You can change the shortcut in Settings.

| Where it goes | What to do |
| --- | --- |
| Your note library | Press Return or click the floppy disk icon to save a separate `.md` file. You can have 2ndJot open it in Obsidian after saving. |
| Your desktop | Click the pin to make a sticky note. Its text, position, window level, and size are kept automatically. When you close a note, you can choose whether to save a Markdown copy. You can keep **multiple desktop sticky notes at the same time**. |

In a sticky note, press Return for a new line or **Command + Return** to save a Markdown copy. Drag the circle at the upper left to move the window, or drag the lower right corner to resize a sticky note. Quick Capture and sticky notes have separate glass settings.

Keep using your usual input method, including any voice input it offers, to get a fleeting idea onto the page a little faster.

## Getting started

The installer requires an **Apple Silicon Mac** and macOS 13 or later.

[Download v1.6.0 for Mac](https://github.com/SinyveZ/2ndJot/releases/download/v1.6.0/2ndJot-1.6.0-arm64.zip) · [Source ZIP](https://github.com/SinyveZ/2ndJot/releases/download/v1.6.0/2ndJot-1.6.0-source.zip) · [SHA-256 checksums](https://github.com/SinyveZ/2ndJot/releases/download/v1.6.0/2ndJot-1.6.0-SHA256SUMS.txt) · [Release notes](https://github.com/SinyveZ/2ndJot/releases/tag/v1.6.0)

You can also [build from source](docs/DEVELOPMENT.md).

1. Download and unzip the installer, then move `2ndJot.app` into Applications.
2. Open the app and right-click its menu bar icon. In **Settings → General → Save Location**, choose an Obsidian vault or a folder inside it.
3. Press **Control + Shift + Space** and enter a thought. Press Return to save it or click the pin to keep it as a sticky note. You can keep multiple desktop sticky notes open at once.
4. To close Quick Capture, press **Esc** or press the same shortcut again (**Control + Shift + Space** by default).

Saving Markdown requires an Obsidian vault. Desktop sticky notes work on their own, without Obsidian. Left-click the menu bar icon to open Quick Capture, and right-click it to open the menu.

<a name="compatibility-and-first-launch"></a>

Apple has not notarized the package. If macOS blocks it on first launch, see [Apple’s instructions](https://support.apple.com/en-us/102445).

## English and Simplified Chinese

2ndJot supports English and Simplified Chinese and follows your system language by default. Switch at any time in **Settings → General → App language**. The change takes effect immediately, without restarting.

## Local storage

You don’t need an account. Captures, drafts, and sticky notes stay on your Mac. 2ndJot doesn’t upload their contents. Obsidian manages its own sync, and your input method handles any dictation service it provides.

## Feedback and contributions

Share feedback or report a problem in [Issues](https://github.com/SinyveZ/2ndJot/issues). See the [development notes](docs/DEVELOPMENT.md) for build instructions and read the [contribution guide](CONTRIBUTING.md) before submitting changes.

## License

[MIT](LICENSE).
