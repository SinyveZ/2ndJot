# GitHub 页面文案 · 公开前审阅稿

2026-11-17，1.6.0（build 18）。英文 **2ndJot**（读作 Second Jot），中文“双轨记”，D“错位双轨”Logo 保持不变。目标仓库为 `SinyveZ/2ndJot`；当前阶段为私有预览。以下公开页面与首发文案须在另行确认公开后使用，实际 CI 状态见 [VERIFICATION.md](VERIFICATION.md)。

## About

仓库名：`2ndJot`

Description：

> A native macOS menu bar app for quick capture to local Markdown in Obsidian or desktop sticky notes. English and 简体中文. MIT.

Topics：`macos` · `obsidian` · `markdown` · `menubar` · `note-taking` · `sticky-notes` · `objective-c` · `appkit`

Social preview：[github-social-preview.png](../media/github-social-preview.png)，1280×640 PNG，小于 1 MB。公开前核对图片中的名称和网址。它是分享仓库链接时的预览图；README 的图片不自动替代此设置。

仓库首页为[双语 README](../../README.md)，中文在前，分割线后为[英文](../../README.md#english)。另有[中文单页](../../README.zh-CN.md)。中英文实机图分别使用 [workflow-preview.png](../media/workflow-preview.png) 和 [workflow-preview.en.png](../media/workflow-preview.en.png)。

## 将来的首个 Release

标题：`双轨记 · 2ndJot 1.6.0`

预期标签：`v1.6.0`，指向检查过的发布提交。首轮可标为 Pre-release，收集安装和兼容反馈。当前候选为 1.6.0（build 18），支持 English 与简体中文。

正文唯一版本见 [RELEASE_v1.6.0.md](RELEASE_v1.6.0.md)，只复制标记之间的正文。里面的公开链接在标签和附件就绪后逐项检查。

预定附件：

- `2ndJot-1.6.0-arm64.zip`：Apple Silicon 应用，内含 `2ndJot.app`。
- `2ndJot-1.6.0-source.zip`：源码，解压根为 `2ndJot-source`。
- `2ndJot-1.6.0-SHA256SUMS.txt`：两个 ZIP 的校验值。

公开前取得单独确认，更新真实本地／CI 结果及跨机试装状态，将两份 README 的私有预览说明替换为真实下载说明，再重新生成源码 ZIP 和校验文件。当前不创建公开 Release、不切换仓库可见性。

## 将来的置顶反馈 Issue

标题：`Getting started with 2ndJot / 第一次使用双轨记`

正文：

Welcome! I'd like to hear whether you could install 2ndJot, save your first Markdown note, and switch from quick capture to a desktop sticky note.

Please include:

- App version, macOS version, chip, and interface language.
- The step that caused trouble, what you expected, and what happened.
- Optional screenshots or logs, with notes, usernames, and private paths redacted.

For a reproducible bug, please open a separate issue using the Bug report template. For a feature request, start with the situation you want to improve. English and Chinese are welcome. This is a personally maintained project; replies may take time.

欢迎反馈第一次使用的体验：是否顺利安装、存下第一条 Markdown，以及快捷框转换便签是否顺手。请附应用／macOS 版本、芯片、界面语言、步骤、预期和实际结果，截图或日志请隐藏私人信息。可复现的问题单独使用 Bug report 模板；功能建议先说使用场景。中英文都可以，个人维护不承诺固定响应时间。

## 首轮维护设置

使用现有 Issue 模板；公开时检查私密漏洞报告的适用条件及 Security 设置，`SECURITY.md` 本身不会启用该功能。先用 Issues 接收反馈，持续出现非缺陷讨论后再考虑 Discussions。

标签按实际问题使用：`bug`、`documentation`、`enhancement`、`help wanted`；`good first issue` 留给边界清楚、有人愿意协助的任务。

设置说明参考：[GitHub Topics](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics)、[Social preview](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview)、[Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)。
