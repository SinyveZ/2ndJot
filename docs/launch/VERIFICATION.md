# 2ndJot v1.6.0 发布前验证记录

日期：2026-11-17。验证版本：**1.6.0（build 18）**。中文名“双轨记”，英文名 **2ndJot**，读作 Second Jot。以下记录来自公开前的私有测试阶段。

## 本地环境与检查

主机为 Apple Silicon / macOS 27.2.1，clang / macOS SDK 27.2；应用包为 arm64，最低部署目标 macOS 13。ad-hoc 签名，无 Developer ID／Apple 公证。

- `tools/check-localization.py`：中英文各 **182 条资源**，键、非空值、NSString 格式参数和应用名检查通过。
- `tools/check.sh`：中文和英文各 **22 个应用场景，共 44 项**通过。覆盖保存、失败重试、草稿、便签恢复、外观配置、图钉动效、品牌、G3 遮罩、缩放及语言切换。
- 新增语言切换检查：正文、便签对象／位置、原设置、自定义提示保持不变；默认提示随语言更新；最窄设置窗口两页布局、偏好持久化与系统回退通过。便签层级按钮的辅助标签同步切换也纳入检查。
- 两种语言均额外确认：仅启动后台／设置、未呼出速记框就退出后，已有草稿仍完整保留。
- 新增非法 UTF-8 草稿检查，确认空编辑器不删除原稿，保存新输入前保留原始字节备份；另在中英文各做一次文件权限为 `000` 的实际读取失败检查，退出设置后原稿完整。语言切换检查同时覆盖打开中与回车重试提示。
- G3：803,142 项断言、378 个矩形、23,050 个三次片段；最大认证误差 0.001994230 点，低于 0.003 点限制。
- 缩放短弧：16,291 项断言、6,168 个采样点；最大偏移误差 0.000189336 点、间距误差 0.000093613 点。
- 原生界面工具实际查看英文快捷框、便签、通用设置、便签设置，操作 English → 简体中文；英文示例正文在切换后保持不变。已导出 build 18 的中英文真实窗口原图。
- 已安装 build 18，并在实际安装包中切换到英文体验。升级前后比较确认：原快捷键、保存位置、字体、提示、玻璃设置、草稿及便签内容均保留；仅新增语言偏好，设置窗口位置按正常操作保存。登录启动状态仍启用。

应用默认跟随系统，设置中可即时切换简体中文或 English。不更改系统 AppleLanguages。系统原生文件选择器、文件夹名等仍遵循 macOS 自身语言。

## 打包与兼容

标准包名 `2ndJot.app`；保留执行文件 `YinSu`、bundle id `com.sinyve.YinSu`、设置域、草稿／便签目录和已有笔记位置。标准 MIT 全文随应用资源一起签名。

制品名为 `2ndJot-1.6.0-arm64.zip`、`2ndJot-1.6.0-source.zip` 与 `2ndJot-1.6.0-SHA256SUMS.txt`。源码采用白名单，不包含旧 Git 历史、历史 dist、本地设计探索、真实笔记或用户设置；ZIP 保留 UTF-8 文件名、可执行权限与符号链接。归档完整性、可执行权限与 SHA-256 校验通过；源码包解压重建、严格签名验证及中英文临时库保存检查通过。

## GitHub 与验证边界

公开前，[SinyveZ/2ndJot](https://github.com/SinyveZ/2ndJot) 已推送白名单源码，并通过 GitHub API 确认可见性为 private。

2026-11-17，[GitHub Actions 第一次运行](https://github.com/SinyveZ/2ndJot/actions/runs/44022113186) **通过**，对应源码提交 [`8823915`](https://github.com/SinyveZ/2ndJot/commit/8823915941ec3a7f5c48bb0633c22cd7a170a027)。实际日志确认：

| 项目 | 实际结果 |
| --- | --- |
| 云端环境 | `macos-26`；macOS 26.7.2；macOS SDK 26.5；arm64 |
| 本地化资源 | 中英文各 182 条资源、两种应用名称，键／值／格式参数检查通过 |
| 构建与签名 | clang 构建成功；严格签名验证通过；MIT 与两套语言资源和源码逐文件一致 |
| 几何 | G3 连续曲率与内缩缩放短弧两组检查通过 |
| 双语保存 | en 显示 2ndJot、zh-Hans 显示双轨记；两种语言均在各自临时库成功写入 Markdown |

**English summary:** All 44 local application scenarios passed across English and Simplified Chinese. The linked GitHub Actions run also passed on macOS 26.7.2 / SDK 26.5 / arm64: build, signature and bundled resources, both geometry checks, and one isolated Markdown save per language. Full GUI interactions and live language switching were tested locally, rather than in CI. These checks were performed before public release.

另一台 Mac 从实际下载开始的首次安装尚未验证，当前 ad-hoc 包不能声称默认通过 Gatekeeper。Intel、macOS 13–26 的实际 GUI、输入法真实语音／组合输入及长期使用仍需实机验证。所有自动写入检查均使用隔离临时库，不操作真实笔记或输入法配置。
