# 双轨记 · 2ndJot 1.6.0 发布说明（待审）

当前为私有预览，仓库保持私有。`v1.6.0` 标签和三个 Release 附件均待上线，公开发布须另行确认。

发布标题可用 `双轨记 · 2ndJot 1.6.0`。只复制 `RELEASE_BODY_START` 与 `RELEASE_BODY_END` 之间的正文。发布前核对最终附件、SHA-256 和正文链接。[验证记录](VERIFICATION.md)

<!-- RELEASE_BODY_START -->

## 中文

**双轨记 · 主线继续，灵感先记。**

双轨记（2ndJot，读作 Second Jot）是一款 macOS 菜单栏速记工具。**1.6.0** 是我第一次公开分享它。

我用 AI 做 vibe coding 时，AI 编程工具（harness）还在跑当前任务，我已经在想下一轮怎么改，有时还会想到另一个方向。我不一定能马上把想法发给 AI。有时工具还在忙，有时我得顾及额度，有时是注意力有限，没法同时推进几件事。

所以我做了双轨记。当前任务继续跑，我按一下快捷键，把想法先记下来。回车或点软盘，存成自己 Obsidian 库里的独立本地 Markdown 文件。也可以点图钉，留成桌面便签。等合适的时候，我再整理或发给 AI。“双轨”就来自这两条线。一条是正在推进的工作，另一条是先记下、稍后处理的想法。

### 使用

- 按默认快捷键 **Control + Shift + Space**，或左键点击菜单栏图标，即可呼出快捷输入框。可以自定义快捷键，沿用当前输入法及其语音输入。按 **Esc** 或再按一次快捷键可关闭输入框。有未保存的内容时会先询问。
- 桌面便签可独立于 Obsidian 使用，也可以同时保留多张。重新打开应用时会恢复每张便签的内容、位置、大小及置顶或置底状态。便签中回车换行，**⌘↩** 另存 Markdown，关闭时默认询问是否另存。
- 界面默认跟随系统，可在 **设置 → 通用 → 界面语言** 切换简体中文或英文，无需重启。

### 安装与附件

下载 Apple Silicon（arm64）安装包 `2ndJot-1.6.0-arm64.zip`，用 `2ndJot-1.6.0-SHA256SUMS.txt` 核对 SHA-256。解压后将 `2ndJot.app` 拖入“应用程序”文件夹。升级前先退出旧版。

要保存 Markdown，打开应用，右键点击菜单栏图标，在 **设置 → 通用 → 保存位置** 选择本地 Obsidian 库或库内文件夹。

应用包采用 ad-hoc 签名，未经 Apple 公证。首次打开若被 macOS 拦截，可参考 [Apple 官方说明](https://support.apple.com/zh-cn/102445)。

源码包为 `2ndJot-1.6.0-source.zip`，校验文件包含两个 ZIP 的 SHA-256。[从源码构建](https://github.com/SinyveZ/2ndJot/blob/v1.6.0/docs/DEVELOPMENT.md)

欢迎分享使用感受或报告问题，报告时请附应用和 macOS 版本、芯片、界面语言及复现步骤。[Issues](https://github.com/SinyveZ/2ndJot/issues)

[中文 README](https://github.com/SinyveZ/2ndJot/blob/v1.6.0/README.zh-CN.md) · [验证记录](https://github.com/SinyveZ/2ndJot/blob/v1.6.0/docs/launch/VERIFICATION.md) · [MIT 许可证](https://github.com/SinyveZ/2ndJot/blob/v1.6.0/LICENSE)

---

## English

**2ndJot · Stay on track. Jot it down.**

2ndJot (pronounced “Second Jot,” 双轨记 in Chinese) is a macOS menu bar app for quick capture. **1.6.0** is the first version I’m sharing publicly.

When I’m vibe coding with AI, I can be thinking ahead while my AI coding tool (the harness) is still running the current task. I might have a change in mind for the next round or an idea for a different direction. I can’t always send those ideas to the AI right away. The tool may still be busy, I may need to watch my usage limits, or I may only be able to focus on one task at a time.

That’s why I built 2ndJot. While the current task keeps running, I hit a shortcut and jot down the thought. I press Return or click the floppy disk icon to save it as a separate local Markdown file in my own Obsidian vault, or click the pin to keep it as a desktop sticky note. When the time is right, I can sort through those ideas or send them to the AI. The Chinese name, 双轨记, refers to those two tracks. One is the work already underway. The other is for ideas I’m saving for later.

### Using 2ndJot

- Open Quick Capture with the default **Control + Shift + Space** shortcut or by left-clicking the menu bar icon. You can change the shortcut and use your usual input method, including any voice input it provides. Press **Esc** or the same shortcut again to close Quick Capture. The app asks for confirmation if you have unsaved text.
- Desktop sticky notes work independently of Obsidian, and you can keep multiple desktop sticky notes open at once. Reopening the app restores each note’s text, position, size, and whether it stays on top of or below other windows. In a sticky note, Return inserts a new line and **Command + Return** saves a Markdown copy. By default, the app asks whether to save a copy when you close a note.
- The interface follows your system language by default. Switch between English and Simplified Chinese in **Settings → General → App language** without restarting.

### Installation and assets

Download `2ndJot-1.6.0-arm64.zip` for Apple Silicon (arm64) Macs and verify its SHA-256 against `2ndJot-1.6.0-SHA256SUMS.txt`. Unzip it and drag `2ndJot.app` into Applications. Quit any existing version before upgrading.

To save Markdown, open the app, right-click the menu bar icon, and select a local Obsidian vault or a folder inside it in **Settings → General → Save Location**.

The app has an ad-hoc signature and hasn’t been notarized by Apple. If macOS blocks it on first launch, see [Apple’s instructions](https://support.apple.com/en-us/102445).

The source archive is `2ndJot-1.6.0-source.zip`. The checksum file covers both ZIPs. [Build from source](https://github.com/SinyveZ/2ndJot/blob/v1.6.0/docs/DEVELOPMENT.md)

Feedback and bug reports are welcome. For bugs, include the app and macOS versions, chip, interface language, and steps to reproduce. [Issues](https://github.com/SinyveZ/2ndJot/issues)

[English README](https://github.com/SinyveZ/2ndJot/blob/v1.6.0/README.md#english) · [Verification record](https://github.com/SinyveZ/2ndJot/blob/v1.6.0/docs/launch/VERIFICATION.md) · [MIT License](https://github.com/SinyveZ/2ndJot/blob/v1.6.0/LICENSE)

<!-- RELEASE_BODY_END -->
