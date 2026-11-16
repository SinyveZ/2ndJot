# 2ndJot · 双轨记 1.6.0 发布说明审阅稿

当前为 **1.6.0（build 18）私有预览**，MIT；没有公开 Release。以下正文供将来确认公开时使用，不表示附件或标签已上线。

This is a review draft for **2ndJot 1.6.0 (build 18)**, currently a private preview under MIT. The public Release body below is for later publication; there is no public download yet.

## 编辑提示 / Editor notes

- 英文名 **2ndJot** 读作 **Second Jot**，中文“双轨记”和 D Logo 不变；本版支持 English 与简体中文，默认跟随系统。
- 建议标题：`2ndJot 1.6.0 · Stay on track. Jot it down. / 双轨记`；预期标签：`v1.6.0`。
- 当前只推进 `SinyveZ/2ndJot` 私有预览与 CI，不公开发布。公开需另行确认。
- 从 [VERIFICATION.md](VERIFICATION.md) 核对最终本地与 CI 结果、提交和运行链接；不将检查计划写成已通过，不宣称跨机首次安装已验证。
- 公开前核对下方附件名、build 18 双语截图与实际包内版本；更新两份 README 的私有预览说明，重新生成源码 ZIP 和 SHA-256。
- 正文中的绝对链接预期指向仓库、`v1.6.0` 标签及其文件；标签和附件就绪后逐项验证。只复制 `RELEASE_BODY_START` 与 `RELEASE_BODY_END` 之间的正文，标题单独填写。
- Publish only after separate confirmation. Verify the final build, CI record, assets, checksums, and public links; these editor notes are not part of the Release body.

## 可粘贴正文 / Release body

<!-- RELEASE_BODY_START -->

### English

**2ndJot · Stay on track. Jot it down.**

2ndJot (pronounced “Second Jot”; 中文名：双轨记) is a macOS menu bar utility for capturing a thought while staying with your current work. This is the first public version of my personal tool, **1.6.0 (build 18)**.

**One entry point, two destinations:** press **Control + Shift + Space** to capture. Return or the floppy-disk button saves a separate local Markdown file; the pin creates a desktop sticky note. The shortcut is configurable.

This version includes:

- English and Simplified Chinese UI. Follow the system language by default, or switch immediately in **Settings → General → App language** without restarting.
- Quick capture with native input methods, local drafts, and file read-back verification. If opening a saved note in Obsidian fails, the text stays available and retrying does not create another file.
- Multiple desktop sticky notes with moving, resizing, floating/background levels, and restoration on relaunch. Closing asks whether to save a Markdown copy by default.
- Separate glass settings for capture and sticky notes, with distinct default tints. The app icon, menu bar, and capture panel share the D mark of two offset tracks.
- Shared G3 corners, resize arcs following the window edge, and a stable diagonal resize cursor.

**Install:** download `2ndJot-1.6.0-arm64.zip` below, verify its SHA-256, unzip, and move `2ndJot.app` into `~/Applications`. Quit an existing version before upgrading. Open the app, right-click the menu bar icon, and choose **Settings → General → Save Location**. Select a local Obsidian vault or a folder inside it, then try the default shortcut.

**Language and data:** app-owned menus, settings, prompts, and errors switch between **System default**, **简体中文**, and **English**. Switching preserves note text, custom hints, shortcuts, save location, and glass settings. Native macOS dialogs follow the macOS language, and existing file/folder names remain unchanged.

**Obsidian requirement:** the save-location picker checks for the vault's `.obsidian` directory and does not accept arbitrary folders. Desktop sticky notes work without Obsidian; opening Obsidian after saving is optional.

**Compatibility and verification:** the app asset is Apple Silicon (arm64) only. The local development environment is Apple Silicon / macOS 27.2.1 / SDK 27.2. The macOS 13 deployment target is not a claim of complete compatibility testing; Intel and other macOS versions have not been verified on hardware. Installation from a fresh download on another Mac remains unverified. Liquid Glass needs macOS 26, with native vibrancy on earlier systems; interactive glass effects need macOS 27. Actual local and CI results are in the [verification record](https://github.com/SinyveZ/2ndJot/blob/v1.6.0/docs/launch/VERIFICATION.md).

**Signing:** the app has an ad-hoc signature, without Developer ID signing or Apple notarization. macOS may block a download. Verify the source and SHA-256, consult [Apple's first-launch guidance](https://support.apple.com/en-us/102445), or build from source.

**Privacy and upgrades:** Markdown, drafts, and sticky notes are stored locally; drafts and sticky notes have no additional encryption. There is no built-in account or analytics upload. Dictation comes from your current input method: 2ndJot does not record audio, include AI speech recognition, or change input method settings. Your input method controls its speech service, and Obsidian controls its sync. Copying saved text to the clipboard is enabled by default and can be disabled. The rename retains `com.sinyve.YinSu`, the `YinSu` executable, existing data locations, and settings; old notes are not moved.

Report problems through [Issues](https://github.com/SinyveZ/2ndJot/issues) with the app/macOS versions, chip, interface language, and reproduction steps. Redact notes and private paths. [English README](https://github.com/SinyveZ/2ndJot/blob/v1.6.0/README.md) · [MIT License](https://github.com/SinyveZ/2ndJot/blob/v1.6.0/LICENSE).

### 中文

**双轨记 · 主线继续，灵感先记。**

双轨记（2ndJot，读作 Second Jot）是一款 macOS 菜单栏速记工具。这是我第一次公开分享自己的小工具，版本为 **1.6.0（build 18）**：正在做一件事时，先把突然冒出的想法记下来，稍后再处理。

**一个入口，两个去向：**按 **Control + Shift + Space** 呼出，回车或点软盘存成独立本地 Markdown；点击图钉则留为桌面便签。快捷键可以自定义。

这一版包含：

- 简体中文与英文界面，默认跟随系统；在 **设置 → 通用 → 界面语言** 中即时切换，无需重启。
- 快捷输入、原生输入法支持、草稿暂存与写入后读回校验；Obsidian 打开失败时保留正文，重试不重复创建文件。
- 多张桌面便签，支持移动、缩放、置顶／置底与重启恢复；关闭时默认询问是否另存 Markdown。
- 快捷框与便签分别设置玻璃外观，默认深浅有别；应用图标、菜单栏与输入框统一使用 D“错位双轨”。
- 共用 G3 连续曲率轮廓，右下缩放短弧沿窗口边缘内缩，对角缩放光标保持稳定。

**安装：**下载下方 `2ndJot-1.6.0-arm64.zip` 并核对 SHA-256，解压后将 `2ndJot.app` 放入 `~/Applications`，升级前先退出旧版。打开应用，右键菜单栏图标 → **设置 → 通用 → 保存位置**，选择本地 Obsidian 库或库内文件夹，再尝试默认快捷键。

**语言与内容：**可选跟随系统、简体中文或 English，应用自己的菜单、设置、提示和错误立即切换；不改笔记正文、自定义提示、快捷键、保存位置与玻璃设置。macOS 原生对话框遵循系统语言，已有文件与文件夹名称不变。

**Obsidian 的边界：**保存位置选择器检查库根目录的 `.obsidian`，不接受任意普通文件夹。桌面便签无需 Obsidian；“保存后在 Obsidian 中打开”可关闭。

**兼容与验证：**应用附件仅为 Apple Silicon（arm64）。本地开发环境为 Apple Silicon / macOS 27.2.1 / SDK 27.2；最低部署目标 macOS 13 不等于全部系统已验证，Intel 和其他 macOS 版本尚未经实机验证。另一台 Mac 从首次下载开始的安装尚未验证。液态玻璃需 macOS 26，较早系统走原生磨砂；交互光效需 macOS 27。实际本地及 CI 结果见[验证记录](https://github.com/SinyveZ/2ndJot/blob/v1.6.0/docs/launch/VERIFICATION.md)。

**签名：**当前为 ad-hoc，没有 Developer ID 签名，未经过 Apple 公证。macOS 可能拦截下载的应用；请核对来源和 SHA-256，参考 [Apple 首次打开说明](https://support.apple.com/en-us/102445)，或自行构建。

**隐私与升级：**Markdown、草稿和便签保存在本机，草稿和便签未额外加密；没有内置账号或统计上报。语音由当前输入法提供，双轨记不录音、不自带 AI 语音识别、不修改输入法配置；输入法的语音服务和 Obsidian 同步由它们各自控制。默认保存后复制正文，可在设置关闭。更名保留 `com.sinyve.YinSu`、`YinSu` 可执行文件、原数据位置及已有设置，不移动旧笔记。

反馈请用 [Issues](https://github.com/SinyveZ/2ndJot/issues)，附应用／系统版本、芯片、界面语言与复现步骤，隐藏真实笔记和私人路径。[中文说明](https://github.com/SinyveZ/2ndJot/blob/v1.6.0/README.zh-CN.md) · [MIT 许可证](https://github.com/SinyveZ/2ndJot/blob/v1.6.0/LICENSE)。

### Assets / 附件

| File / 文件 | Purpose / 用途 |
| --- | --- |
| `2ndJot-1.6.0-arm64.zip` | Apple Silicon app bundle `2ndJot.app` / Apple Silicon 应用 |
| `2ndJot-1.6.0-source.zip` | Source tree `2ndJot-source`; build it yourself / 完整源码，需自行构建 |
| `2ndJot-1.6.0-SHA256SUMS.txt` | SHA-256 checksums for both ZIPs / 两个 ZIP 的校验值 |

<!-- RELEASE_BODY_END -->
