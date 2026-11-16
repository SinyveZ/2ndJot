# 双轨记 · 2ndJot

**主线继续，灵感先记。**

[English](README.md) · [更新日志](CHANGELOG.md) · [参与贡献](CONTRIBUTING.md)

正在写东西、查资料，脑子里却冒出另一个想法？双轨记是一个 macOS 菜单栏速记工具：按快捷键记下来，存进本地 Markdown / Obsidian，或钉成桌面便签，再继续手头的事。

> **私有预览 · 1.6.0（build 18）**，暂未开放公开下载。可在获得仓库访问权限后从源码构建，或使用单独分享的体验包。

英文名 **2ndJot** 读作 **Second Jot**，中文名仍为“双轨记”。

![快捷输入框与桌面便签的真实窗口](docs/media/workflow-preview.png)

快捷输入框与桌面便签的窗口预览，正文为虚构示例。

## 一个入口，两个去向

默认按 **Control + Shift + Space（⌃⇧Space）** 呼出快捷输入框，可在设置中更改。

| 想法放在哪里 | 操作与结果 |
| --- | --- |
| 存进笔记库 | 按回车或点击右上软盘，生成独立的 UTF-8 `.md` 文件；保存后可自动打开 Obsidian。 |
| 留在桌面上 | 点击右上图钉，转为桌面便签；正文、位置和尺寸自动保存，重启后恢复。关闭时默认询问是否另存为 Markdown。 |

便签里回车换行，`⌘↩` 另存速记；左上圆点拖动，右下短弧调整大小。快捷输入框和便签分别设置玻璃外观，默认深浅有别。

文字由当前输入法输入；语音输入也依赖输入法提供的功能。双轨记不录音、不自带 AI 语音识别，也不修改输入法配置。

## 安装与首次使用

1. 获取单独分享的 `2ndJot-1.6.0-arm64.zip` 及配套校验文件，或[从源码构建](#开发与贡献)。[Releases](https://github.com/SinyveZ/2ndJot/releases) 仅在正式公开后提供下载入口。
2. 解压，将 `2ndJot.app` 放进 `~/Applications`（个人“应用程序”文件夹）；升级前先退出旧版。
3. 打开应用，右键菜单栏图标 → **设置 → 通用 → 保存位置**，选择一个本地 Obsidian 库或库内文件夹。
4. 按 **Control + Shift + Space**，输入一句话，回车保存；或点击图钉，留为便签。

**保存位置目前面向 Obsidian 库**：文件夹选择器会检查库根目录的 `.obsidian`，暂不接受任意普通文件夹。桌面便签可以独立使用，无需 Obsidian；设置中也可关闭“保存后在 Obsidian 中打开”，仅将速记写入选定的库。

菜单栏图标左键打开输入框，右键打开菜单。

## 界面语言

应用支持 **简体中文与 English**，默认跟随系统语言。在 **设置 → 通用 → 界面语言**（English：**Settings → General → App language**）中选择“跟随系统”“简体中文”或“English”，应用自己的菜单、设置、提示和错误信息立即切换，无需重启。

切换语言保留笔记正文、自定义提示、快捷键、保存位置与玻璃设置。macOS 原生对话框遵循 macOS 的语言，已有文件夹和文件名保持原样；应用不会修改系统语言偏好。

## 兼容性与首次打开

- 应用包仅提供 **Apple Silicon（arm64）**。本地实测为 **Apple Silicon / macOS 27.2.1**；Intel 与其他 macOS 版本尚未经实机验证。
- 最低部署目标为 macOS 13，不代表所有系统均已测试。macOS 26 起使用液态玻璃，较早系统走原生磨砂；交互光效需 macOS 27。
- 当前为 **ad-hoc 签名**，没有 Developer ID 签名，也未经过 Apple 公证。下载后可能被系统拦截；请先核对来源与校验值，再参考 [Apple 官方的首次打开说明](https://support.apple.com/en-us/102445)，或从源码构建。

核验应用 ZIP：在体验包所在目录运行以下命令，将结果与同一构建配套的 `2ndJot-1.6.0-SHA256SUMS.txt` 中同名文件的值比对。

```sh
shasum -a 256 "2ndJot-1.6.0-arm64.zip"
```

如果首次打开时提示“无法验证开发者”或“Apple 无法检查是否包含恶意软件”，仅在你已核对来源并决定信任该应用时，按 Apple 的方式手动处理：先尝试打开，再到 **系统设置 → 隐私与安全性 → 仍要打开**，确认提示。若提示应用损坏或会损坏电脑，请停止安装并反馈具体提示。

本地开发环境为 macOS 27.2.1、SDK 27.2；另一台 Mac 从首次下载开始的安装尚未验证。具体本地与 CI 结果、尚未覆盖的场景见[验证记录](docs/launch/VERIFICATION.md)。

## 数据与隐私

- Markdown 写入所选本地库；草稿和便签保存在 `~/Library/Application Support/YinSu/`，未额外加密。
- 没有内置账号、云端识别或统计上报。输入法的语音服务与 Obsidian 的同步由它们各自控制。
- 默认保存后复制正文到剪贴板，可在设置中关闭。诊断日志 `/tmp/YinSu.log` 可能含本机路径，分享前请脱敏。

更名沿用 `com.sinyve.YinSu`、`YinSu` 可执行文件及原数据位置，保留已有快捷键、保存位置与其他设置，不移动或重命名旧笔记。

## 开发与贡献

使用 Objective-C / AppKit 与 clang，无第三方运行时依赖。构建需要 Xcode Command Line Tools 和 macOS 26+ SDK；测试和打包另需 Python 3：

```sh
./build.sh        # 输出 /private/tmp/YinSu-build/2ndJot.app
./tools/check.sh  # 隔离自检，需要已登录的 macOS 图形会话
```

脚本为每种语言安排 21 个应用场景，共 42 个，另有本地化资源和两组几何检查；这是检查范围，实际结果以验证记录为准。可用 `./tools/preview.sh settings en` 或 `./tools/preview.sh settings zh-Hans` 打开独立的英文／中文设置预览。

构建与测试细节见[开发说明](docs/DEVELOPMENT.md)；D“错位双轨”与轮廓设计见[品牌设计](docs/BRAND_DESIGN.md)和 [G3 轮廓](docs/G3_CORNERS.md)。

有仓库访问权限的体验者可通过 [Issues](https://github.com/SinyveZ/2ndJot/issues) 反馈；否则请联系体验包的分享者。请附应用版本、macOS 版本、芯片、界面语言和复现步骤，勿附真实笔记或私人路径。提交修改前请阅读[贡献指南](CONTRIBUTING.md)，安全问题见[安全说明](SECURITY.md)。项目由个人维护，暂不承诺固定响应时间。

## 许可证

[MIT](LICENSE)。双轨记是独立项目，与 Obsidian、微信输入法及 Apple 无官方关联。
