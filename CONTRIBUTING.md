# 参与贡献 · Contributing

欢迎反馈双轨记（2ndJot）真实使用中的问题，也欢迎小而清楚的修复。应用目前由个人维护，请给复现和讨论留一点时间。

## 报告问题

使用 Issue 模板提供应用版本、macOS 版本、芯片、复现步骤、预期与实际结果。保存相关问题请说明文件是否生成、Obsidian 是否打开。截图和日志中请移除笔记正文、用户名和私人路径。

For bug reports, include the app/macOS versions, chip, reproduction steps, and expected versus actual behavior. Redact notes and private paths. English reports and pull requests are welcome.

## 修改代码

1. 先构建现有代码；较大功能先开 Issue 说明使用场景。
2. 一次 PR 解决一个问题，说明可观察的行为变化。
3. 运行 `./build.sh` 与 `./tools/check.sh`；涉及 UI 时补充浅色／深色背景的真实截图，并注明系统版本。
4. 写入验证必须使用临时库、独立便签与草稿；不要拿真实笔记做测试。
5. 提交前检查差异，移除真实数据和二进制构建物。

Build first, keep changes focused, and explain the observable behavior. Run the existing isolated checks. UI changes need real light/dark screenshots and an OS version. Never test against personal notes.

## 设计边界

- 品牌统一为「双轨记 / 2ndJot」，采用 D“错位双轨”；理念为“主线继续，灵感先记。”长轨代表当前工作，短轨代表先记下、待处理的灵感。
- 仅左上磨砂圆点可拖动；面板保持 `hasShadow = NO`。
- 不修改输入法配置、不接管输入法语音快捷键。
- 保留现有用户的自定义快捷键、保存位置与数据。
- 兼容标识保持不变：可执行文件 `YinSu`、构建根 `/private/tmp/YinSu-build`、设置域 `com.sinyve.YinSu`、数据目录 `~/Library/Application Support/YinSu`、日志 `/tmp/YinSu.log` 及现有环境变量；旧笔记目录不改名或移动。统一 SVG 资源为 `docs/media/2ndJotMark.svg`。
- 使用 Objective-C / AppKit 和 clang。
- 保存失败必须保留正文；重试打开不能重复生成文件。

Use the brand name 2ndJot and the approved D mark of two offset tracks. Preserve the existing internal identifiers, environment variable names, and data locations. Respect the single upper-left drag handle, shadow-free panel, native input methods, existing preferences, and data retention on failure. The build remains Objective-C / AppKit with clang.

本项目采用 MIT 许可证；提交贡献表示你有权提交这些内容，并同意以本项目的 MIT 许可证提供。请保留相关版权声明。

Contributions are provided under the project's MIT License. Please ensure you have the right to contribute the submitted material.
