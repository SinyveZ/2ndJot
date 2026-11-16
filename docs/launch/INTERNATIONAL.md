# 2ndJot（双轨记）英文传播包 · 公开前审阅

英文品牌：**2ndJot**，读作 **Second Jot**；中文“双轨记”和 D“错位双轨”标志不变。

统一 tagline：**Stay on track. Jot it down.**

当前为 **1.6.0 (build 18) 私有预览**，支持 English 与简体中文；目标仓库 `https://github.com/SinyveZ/2ndJot` 保持私有。下方首发／社区正文仅在另行确认公开、下载可用后使用。对外发送前更新真实验证范围、最终截图和链接，不提前宣称已经开源。

## 1. One-line positioning

2ndJot (双轨记) is a macOS menu bar app for capturing a passing thought as a local Markdown note or desktop sticky, then returning to the task at hand.

## 2. GitHub About

A native macOS menu bar app for quick capture to local Markdown in Obsidian or desktop sticky notes. English and 简体中文. MIT.

## 3. Launch introduction

建议标题：**2ndJot — Stay on track. Jot it down.**

<!-- LAUNCH_INTRO_START -->

I built 2ndJot (pronounced “Second Jot”; 中文名：双轨记) for a familiar interruption: an idea arrives while I’m working on something else. I want to keep it without turning it into my next task.

A configurable shortcut opens a small capture panel. Press Return to save a local Markdown file in your Obsidian vault, or pin a desktop sticky note. The idea has somewhere to go; I can return to what I was doing.

This is my first public open source release, version 1.6.0 (build 18), under MIT. The UI supports English and Simplified Chinese, with an instant language switch in Settings. There’s no built-in account or analytics upload. Dictation comes from your input method.

The app download is Apple Silicon only. Local development uses macOS 27.2.1; other-machine installation remains unverified. The app is ad-hoc signed without Apple notarization. I’d welcome feedback on installation, the first capture, and sticky notes.

[Source, setup, and release notes](https://github.com/SinyveZ/2ndJot)

<!-- LAUNCH_INTRO_END -->

## 4. Obsidian community introduction

建议标题：**2ndJot: capture a passing thought into your Obsidian vault**

<!-- OBSIDIAN_INTRO_START -->

I made 2ndJot (双轨记), a macOS menu bar app, to capture ideas while keeping my current work in view. A shortcut opens a panel; Return saves a local Markdown file in an Obsidian vault. Opening Obsidian after saving is optional. You can also pin a desktop sticky and return to it later.

This is a standalone app. The folder picker requires a vault with a `.obsidian` directory; sticky notes work independently. Version 1.6.0 (build 18) is under MIT, with English and Simplified Chinese UI. Downloads are Apple Silicon only; local development uses macOS 27.2.1. The app is ad-hoc signed and not notarized. Please read the installation and verification notes before trying it.

[Source and setup](https://github.com/SinyveZ/2ndJot)

<!-- OBSIDIAN_INTRO_END -->

## 5. macOS community introduction

建议标题：**2ndJot: a menu bar home for thoughts you’ll return to later**

<!-- MACOS_INTRO_START -->

I built 2ndJot (双轨记) for thoughts that arrive in the middle of another task. Open its capture panel with a shortcut, write the thought, then save local Markdown in an Obsidian vault or pin a desktop sticky.

Sticky notes restore on relaunch and work without Obsidian. Capture and sticky notes have separate glass settings. The UI supports English and Simplified Chinese, with instant switching and no restart.

Version 1.6.0 (build 18) is under MIT. The app download is Apple Silicon only; local development uses macOS 27.2.1. It is ad-hoc signed without Apple notarization, and installation from a fresh download on another Mac remains unverified. I’d appreciate feedback on the everyday capture flow.

[Source and setup](https://github.com/SinyveZ/2ndJot)

<!-- MACOS_INTRO_END -->

## 6. Optional HN title drafts

仅为备选标题；公开前查看所选社区当时的规则，确认适合的介绍方式，不在私有预览阶段发帖。

- `Show HN: 2ndJot – Capture a thought and return to your work`
- `Show HN: 2ndJot – macOS quick capture to Markdown or desktop stickies`
- `Show HN: 2ndJot – A place for ideas that can wait`

正文可从首发介绍缩短，保留作者身份、双语支持、Apple Silicon 范围、签名状态和真实可访问的使用入口。

## 7. English FAQ

以下为当前私有预览可使用的 FAQ。公开时将访问与下载说明改为当时的真实状态。

### What is 2ndJot for?

2ndJot gives a passing thought somewhere to go while you stay with your current task. Save it as local Markdown or pin a desktop sticky, then return to it when you choose. **Stay on track. Jot it down.**

### How is the name pronounced?

**Second Jot.** The ordinal abbreviation of “second” is **2nd**. The Chinese name is **双轨记**; the two offset tracks in the logo represent your current work and an idea saved for later.

### Is this already a public release?

No. **1.6.0 (build 18) is a private preview.** Earlier versions were used locally. The planned first public version is 1.6.0; public release and downloads require a separate confirmation.

### Is the application available in English?

Yes. It supports **English and Simplified Chinese** and follows your system language by default. In **Settings → General → App language** (中文：设置 → 通用 → 界面语言), choose **System default**, **简体中文**, or **English**. App-owned text updates immediately without restarting.

Switching leaves your notes, custom hint, shortcut, save location, and glass settings unchanged. Native macOS dialogs follow the macOS language. Existing folder names are not translated, and the app does not change system language preferences.

### What are the app and package filenames?

The physical app bundle is **`2ndJot.app`**. The package names are `2ndJot-1.6.0-arm64.zip`, `2ndJot-1.6.0-source.zip`, and `2ndJot-1.6.0-SHA256SUMS.txt`. The source ZIP extracts to `2ndJot-source`.

### How can I try the private preview?

Build from source if you have repository access, or use a shared preview package with its matching checksum file. There is no public download yet. The repository’s Releases page becomes a public download entry point only after public release.

### Which Macs are covered?

The app package is **Apple Silicon (arm64) only**. Local development uses **Apple Silicon / macOS 27.2.1 / SDK 27.2**. Intel, other macOS hardware environments, and installation from a fresh download on another Mac remain unverified. The macOS 13 deployment target does not certify every macOS version. Liquid Glass needs macOS 26; interactive effects need macOS 27.

### How do I open quick capture?

The default shortcut is **Control + Shift + Space** and can be changed in Settings. Existing users keep their configured shortcut. Left-click the menu bar icon to capture; right-click for the menu.

### Do I need Obsidian?

Desktop sticky notes work independently. For Markdown saving, the folder picker requires a local Obsidian vault or a folder inside it, checked through the vault’s `.obsidian` directory. Arbitrary folders are not accepted. Opening Obsidian after saving is optional.

### How do capture and sticky notes differ?

In quick capture, Return or the floppy-disk button saves a separate Markdown file. The pin creates a desktop sticky. In a sticky, Return inserts a line break and Command + Return saves a Markdown copy. Sticky text, position, and size restore on relaunch; closing asks whether to save a copy by default. Each window type has its own glass settings.

### Does 2ndJot include dictation or AI transcription?

Dictation comes from your current input method. 2ndJot does not record audio, include a speech service, or change input method settings. Any network processing used by the input method is controlled by that provider.

### Where does my data go?

Markdown goes to the selected local vault. Drafts and stickies stay in `~/Library/Application Support/YinSu/` without additional encryption. The existing executable `YinSu`, bundle ID `com.sinyve.YinSu`, and data directory are retained for upgrade compatibility; old notes are not moved. There is no built-in account or analytics upload. Input-method speech and Obsidian sync remain under those tools’ control. Copying saved text to the clipboard is on by default and can be disabled.

### Is the app signed and notarized?

It uses an **ad-hoc signature**, without Developer ID signing or Apple notarization. macOS may block a shared or downloaded copy. Verify its source and SHA-256, then follow the [installation notes](../../README.md#compatibility-and-first-launch) before deciding to open it, or build from source.

### What has been tested?

The local check script covers **22 application scenarios per language (44 total)**, localization resources, and two geometry checks. CI covers building, signature and bundled resources, geometry, and one isolated Markdown save per language. These are different scopes. Actual results, SDKs, commits, and CI run links belong in the [verification record](VERIFICATION.md); this FAQ does not claim that a pending run passed or replace cross-machine testing.

### What is the license?

[MIT](../../LICENSE). 2ndJot is independent of Obsidian, Apple, and input method providers.

### Where can I report a problem?

Preview testers with repository access can use [Issues](https://github.com/SinyveZ/2ndJot/issues). Otherwise, contact the person who shared the package. Include the app/macOS versions, chip, interface language, and reproduction steps. Redact notes and private paths. This is a personally maintained project without a guaranteed response schedule.

## 8. 公开前核对

统一英文 2ndJot、中文“双轨记”、build 18、D Logo 和制品名；主页为英文 `README.md`，中文为 `README.zh-CN.md`。应用支持双语，即时切换保留正文及偏好；AppKit 系统对话框仍遵循 macOS。

首发／社区正文采用公开后的口吻，私有阶段不发送。正式公开前核对双语实机截图、实际测试／CI 结果、跨机安装状态、签名与所有下载链接；有变化就更新正文，不沿用过期验证结论。

事实依据：[English README](../../README.md)、[中文 README](../../README.zh-CN.md)、[Release 审阅稿](RELEASE_v1.6.0.md)、[验证记录](VERIFICATION.md)、[MIT](../../LICENSE)。
