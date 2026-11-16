# Development · 开发与验证

## Quick start

2ndJot (双轨记, pronounced “Second Jot”) is an Objective-C / AppKit menu bar app. Version 1.6.0 (build 18) is a private preview. Use clang and Xcode Command Line Tools with a macOS 26+ SDK; Python 3 is also needed for checks and packaging.

```sh
./build.sh                       # /private/tmp/YinSu-build/2ndJot.app
./tools/check.sh                 # logged-in macOS GUI session required
./tools/preview.sh settings en   # disposable English settings preview
./tools/preview.sh settings zh-Hans
```

The check script covers 21 app scenarios per language (42 total), localization resources, and two independent geometry checks. CI performs a smaller build and bilingual save smoke check. Coverage is not a passing result: see [VERIFICATION.md](launch/VERIFICATION.md) for actual runs. Local development uses Apple Silicon, macOS 27.2.1, and SDK 27.2; do not infer SDK 26 or other-machine compatibility from that environment.

App-owned text switches immediately through **Settings → General → App language**. The selection is saved as `uiLanguage`; it does not modify system `AppleLanguages`. Native macOS dialogs keep the macOS language, and existing data and folder names remain unchanged.

## 构建

`./build.sh` 使用 clang / ARC / AppKit，默认产出本机架构，最低部署目标 macOS 13。编译需要 macOS 26+ SDK；macOS 27 的交互光效属性经公开 Objective-C selector 在运行时调用，避免要求编译机必须具备 27 SDK。较早系统运行时使用 NSVisualEffectView。设置 `YIN_SU_BUILD_DIR` 可将构建放到另一个临时目录。

连续曲率的几何定义、屏幕近似精度和应用范围见 [G3 轮廓](G3_CORNERS.md)。`tools/check-g3.sh` 在应用场景检查前独立验证几何；`--corner-check` 覆盖最小尺寸、竖向便签、玻璃裁切、拖动命中和无窗口阴影。

图标由 `tools/build-assets.sh` 以源码矢量生成，并由 `iconutil` 打包为 ICNS；源码构建也包含这一步。

目录：`src/` 是应用源码，`tools/check.sh` 是隔离自检，`.github/workflows/build.yml` 是构建和双语文件写入检查，`docs/launch/` 是公开前审阅材料。当前只进行私有预览与私有仓库验证，不公开发布。

## 双语资源

`src/YSLocalization.h` 负责语言选择与回退；`src/Resources/en.lproj/` 和 `zh-Hans.lproj/` 各含 182 条 `Localizable.strings` 应用文字及本地化应用名称 `InfoPlist.strings`。构建将两个语言目录和 MIT 许可复制进应用后签名。

默认 `system` 跟随系统偏好，在所支持语言中匹配，缺失翻译时回退到英文。“设置 → 通用 → 界面语言”提供跟随系统、简体中文、English；`uiLanguage` 可取 `system`、`zh-Hans`、`en`。菜单、设置、提示和错误即时更新，正文、自定义提示、快捷键、库路径和两组玻璃设置保持原样。

运行 `python3 tools/check-localization.py` 检查资源键、格式占位符与界面调用。`--localization-check` 检查切换后的正文／设置保留、布局、默认提示、偏好持久化及系统语言回退；是否通过以验证记录为准。

## 隔离自检

先构建，再运行 `./tools/check.sh`。需已登录的 macOS 图形会话。脚本先运行 G3、缩放弧线两组几何与本地化资源检查，再复制独立 bundle id 的临时应用；中英文各运行 21 个应用场景，共 42 个。假库、便签和草稿放在 `/private/tmp/YinSu-check.*` 的分语言目录，关闭剪贴板写入与 Obsidian 打开。`YIN_SU_ISOLATED=1` 使用每次运行独立的设置域，跳过旧设置迁移、全局快捷键注册和设置窗口位置保存。

测试保留临时目录供排查，不读写真实库。独立设置域名称为 `com.sinyve.YinSu.preview.<UUID>`，可能由系统保存在用户 Preferences 目录；不会覆盖 `com.sinyve.YinSu`。请勿在正式日常启动时设置这些变量。

内置检查：`--corner-check`、`--resize-check`、`--localization-check`、`--preview-isolation-check`、`--self-test`、`--settings-check`、`--layout-check`、`--ui-check --commit-check`、`--toggle-check`、`--open-failure-check`、`--confirm-check`、`--sticky-check`、`--sticky-restore-check`、`--draft-save-check`、`--draft-check`、`--pin-check`、`--glass-preferences-check`、`--glass-check`、`--save-button-check`、`--brand-check`。`--pin-check` 的减少动态效果变体另占一个场景。

图钉检查会验证最小尺寸下的左上位置、拖动命中和转换锚点、正文保留、动画中间帧与结束。脚本另用 `YIN_SU_REDUCE_MOTION=1`（仅隔离模式）验证减少动态效果；恢复便签检查同时验证状态标记存在且静止。

`--self-test` 单独调用默认会使用当前保存位置，必须传 `VOICE_NOTE_FOLDER_PATH`。`--settings-hotkey-check` / `--hotkey-switch-check` 会注册真实快捷键，不纳入常规隔离脚本。`--migrate-check` 会迁移设置，不要在真实设置上反复跑。

玻璃迁移读取实际持久化域，不依赖 `registerDefaults` 后的 `objectForKey:` 判断用户是否设置过。`quickGlassStyle` / `quickGlassInteractive` / `quickGlassTintStrength` 与 `stickyGlass…` 分别保存两组配置。旧共享键只在新快捷输入框键缺失时迁移，便签不会继承它们。

新增检查覆盖新默认差异、完整和部分旧配置迁移、重载和重复迁移、多张现有便签与新便签的外观作用范围、分别恢复默认、旧系统磨砂染色路径，以及两个入口和关闭便签另存。新增场景使用独立临时数据目录，避免干扰便签恢复检查。

## 界面预览

优先使用预览脚本，自动创建假库与独立应用：

```sh
./tools/preview.sh settings en
./tools/preview.sh settings zh-Hans
./tools/preview.sh editor en
./tools/preview.sh light zh-Hans
./tools/preview.sh dark en
```

省略第二个参数时跟随系统。`YIN_SU_UI_LANGUAGE` 仅在隔离模式下初始化独立设置；不要用它覆盖日常设置。

脚本对应 `--preview-settings`、`--preview-editor`、`--preview-stickies`。便签预览以独立浅／深背景窗检查圆角；预览正文写入隔离草稿，勿直接在日常版执行预览参数。`tools/isolate-app.sh` 把目录和所选语言写入临时应用的 `YinSuPreviewDirectory` / `YinSuPreviewLanguage`；重新打开时恢复隔离数据、外部副作用开关及 `YIN_SU_UI_LANGUAGE`。临时应用英文名为 `2ndJot Preview`，中文名为“双轨记预览”。`--preview-isolation-check` 在清空隔离环境变量后检查重开路径。

手动验收：

- 设置的两个页面、底部固定按钮、窄窗口与滚动；提示文字不截断、不压住控件。
- 中英文分别检查菜单、设置、保存／关闭提示与错误信息；切换后正文、自定义提示与偏好保持原样。系统对话框按 macOS 语言显示。
- 浅色／深色背景的玻璃、圆角、边缘；无黑色矩形阴影。
- 左上圆点拖动、图钉、便签缩放；输入法组合输入时回车先上屏。
- 自定义快捷键未变化；笔记落在原设置位置；打开失败保留正文。
- 首次用户选择库内文件夹，完成第一次保存与便签恢复。

UI 自检仅验证部分窗口与布局状态，不能证明液态玻璃的实际观感或输入法语音已通过。

## 私有仓库 CI

目标为 `SinyveZ/2ndJot`，保持私有。工作流使用只读仓库权限，记录实际主机、SDK 与架构，检查双语资源，构建并验证签名、许可与语言文件，再运行两组几何检查和中英文各一次假库 `--self-test`。它不运行完整 GUI 场景，不上传制品，也不发布 Release。

真实 Actions 运行链接、提交及结果只记在 [VERIFICATION.md](launch/VERIFICATION.md)。本地通过、工作流存在或 runner 配置正确都不能替代远端成功记录；CI 通过也不代表跨机首次下载安装或所有 macOS 版本通过。

## 发行

`./release.sh` 在 `dist/` 生成 `2ndJot-1.6.0-arm64.zip`、`2ndJot-1.6.0-source.zip` 和 `2ndJot-1.6.0-SHA256SUMS.txt`（应用架构后缀来自构建主机）。源码解压根为 `2ndJot-source`，保留 `src/Resources/`；白名单不包含 `.git`、历史发行物、本地设计探索或真实笔记。打包不等于公开发布。

测试和打包使用 Python 3。ZIP 由 `tools/zip-release.py` 写入 UTF-8 文件名标记并保留 Unix 可执行权限；构建时将 MIT 全文放入应用的 `Contents/Resources/LICENSE` 后再签名。

源码 ZIP 解压后应能直接运行 `./build.sh`。`./tools/prepare-public.sh` 另外生成 `.launch-work/` 下的干净目录，不包含旧 Git 历史与 dist，也不会上传或建库。物理应用包名为 `2ndJot.app`，应用内中文为“双轨记”、英文为“2ndJot”；可执行文件仍为 `YinSu`，设置域仍为 `com.sinyve.YinSu`，便签目录仍为 `~/Library/Application Support/YinSu`。更名不迁移或重命名用户笔记。

版本在 `src/Info.plist`，当前 1.6.0 / build 18。对外发布前更新 CHANGELOG、验证记录、双语截图与审阅材料，重新生成源码包及校验值，取得单独的公开授权后再发布。
