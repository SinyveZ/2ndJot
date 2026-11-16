# 发布图片来源

本目录用于双轨记的 README、GitHub Social preview 和小红书首篇。品牌采用已批准的 D“错位双轨”；没有下载第三方商标或素材包。

- `2ndJotMark.svg`、`app-icon.png`：由 `src/YSBrandMark.h`／`src/YSBrandIcon.h` 的原创矢量生成，与应用内图标共用来源。
- `quick-capture.png`、`desktop-sticky.png` 及对应的 `.en.png`：2026-11-17 用原生界面工具捕获的 build 18 实际窗口。运行于独立预览身份和临时库，正文是虚构示例；没有个人桌面、真实笔记、用户名或通知。保留原始窗口像素，没有重画控件。
- `workflow-preview.png`、`workflow-preview.en.png`：分别使用中文和英文界面的原图编排，对应两种 README。
- `xhs-01.png` 至 `xhs-06.png`：1080×1440。第 2、4 张使用上述原图，其余为图解／虚构文件示例；页脚逐张注明。
- `contact-sheet.png`：六张小红书图的审阅总览。
- `github-social-preview.png`：1280×640，供仓库 Settings → Social preview 单独上传；`github-banner.png` 是另存的品牌横幅。
- `brand-approved.png`：原批准的品牌效果稿，作为历史设计参考；其中英文拼音早于 2ndJot 定名，不作为当前英文品牌。
- 其余品牌、圆角和状态图为代码绘制的设计说明，具体定义见对应文档。

重新生成排版：`./tools/render-media.sh`。该脚本读取已保存的窗口原图，绘制文字、原创图形和画布；不自动拍摄桌面，也不会修改窗口原图。窗口截图需要重新在隔离预览中取得，并同步系统和 build 标注。图像里的系统字体和控件来自 macOS；仓库不分发字体文件。

`settings.en.png`、`sticky-settings.en.png`、`settings.zh-CN.png` 为 build 18 设置界面检查原图，库路径来自隔离的 Demo Vault。
