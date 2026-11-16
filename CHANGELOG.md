# Changelog · 更新日志

## 1.6.0（私有预览，build 18，2026-11-17）

Private preview; no public release yet. Earlier versions were used locally.

- English and Simplified Chinese UI, following the system language by default. Switch immediately in Settings → General → App language without restarting.
- Language changes preserve note text, custom hints, shortcuts, save location, and glass settings. Native macOS dialogs keep the macOS language.
- The English brand is **2ndJot**, pronounced **Second Jot**; the Chinese name **双轨记** and D offset-track logo are retained. App and package filenames use `2ndJot`.
- Quick capture saves local Markdown to an Obsidian vault or becomes a desktop sticky note. Separate glass settings, shared G3 corners, matching resize arcs, and a stable diagonal resize cursor retain the existing design.
- Local drafts, save verification, failure recovery, and sticky-note restoration retain the existing storage identity and user settings.
- Preserve an existing capture draft when the app opens only Settings and then quits without showing the capture panel.
- Keep unreadable drafts intact; back up the original before saving new input. Language changes retain translated opening and retry prompts.

中文详细记录：

- 新增中英文界面，双语资源各 182 条；默认跟随系统，在“设置 → 通用 → 界面语言”中即时切换，无需重启
- 切换语言不改正文、自定义提示、快捷键、保存目录和玻璃设置；不修改系统 `AppleLanguages`，系统对话框遵循 macOS 语言
- 修复仅打开设置、未呼出速记框就退出时可能清空已有草稿的问题；双语检查覆盖后台启动与退出后的草稿保留
- 草稿读取失败时保留原文件，保存新输入前先备份原稿；切换语言后继续显示对应语言的打开中／回车重试提示
- 英文品牌统一为 **2ndJot**（读作 Second Jot）；应用包为 `2ndJot.app`，制品名为 `2ndJot-1.6.0-*`，中文名与 D Logo 保持不变

- 快捷输入框右上角新增软盘存盘按钮，与图钉并列；软盘与回车共用 Markdown 保存和失败重试流程
- 快捷输入框、桌面便签的玻璃风格、染色强度和交互光效分别设置，可分别恢复默认
- 默认输入框为标准玻璃、10% 染色；便签为标准玻璃、50% 染色，钉下后自动切换外观
- 旧版共享玻璃效果迁移给快捷输入框，保留原有效果；现有和新建便签使用独立配置

- 应用更名「双轨记」（2ndJot），保留原设置域、可执行文件和本机数据目录
- 统一采用 D「错位双轨」Logo：输入框左上圆点、菜单栏和应用图标共用原创实心矢量路径
- README、开源介绍、小红书文案与图解同步新名称和「主线继续，灵感先记」的定位
- 便签直接把左上 Logo 换为图钉，保留按住拖动；移除顶部中央状态签
- 转换便签时固定窗口上沿与左边缘，避免控件跳位
- 输入框、便签、设置分组卡片、应用图标与自绘图解统一连续曲率轮廓，直边与转角达到 G3 连接
- 玻璃、旧系统磨砂、染色与正文由同一条轮廓裁切，缩放和恢复时同步更新
- 右下两条缩放短弧沿窗口的真实 G3 轮廓等距内缩，避免独立小圆角与边缘弧度不一致
- 修复缩放区使用十字光标的问题，改为对角缩放光标；拖动期间保持同一光标，松开后交回系统管理
- 转换为便签时标记淡入并轻压，恢复旧便签时保持静止，尊重系统“减少动态效果”
- 增加图标资源、左上拖动命中、转换锚点、动画结束与正文保留检查

- 设置改为可缩放窗口与可滚动分组，底部“完成”按钮固定可见
- 顶部提示为图钉预留空间，保存位置增加明确的库检测提示
- 默认路径按当前用户主目录生成，保留原路径与所有已配置设置
- 新增独立设置与临时数据的自检脚本，构建明确以 macOS 13 为最低部署目标
- 修正源码包目录，增加架构标记、SHA-256、双语文档与贡献入口
- 准备双语开源材料、私有仓库验证流程与小红书文案；公开发布另行确认，实际本地及 CI 结果见验证记录

## 1.5.2（2026-10-30）

- 保存后先读回校验，再把已落盘的绝对文件路径直接交给 Obsidian，避免库名／相对路径查找失败和新文件索引时序问题
- 打开请求经系统确认后才清空速记正文；打开失败时保留正文，回车仅重试打开，不重复创建 Markdown
- 未保存的速记正文自动暂存，误关窗口或重启后可恢复；成功保存并打开后才清除草稿

## 1.5.1（2026-10-24）

- 修复便签缩放时左上拖动圆点跟随移动，现始终固定在左上角
- 设置页改用清晰的系统分段控件切换“通用／便签”，并恢复底部按钮和说明的完整留白

## 1.5.0（2026-10-24）

- 新增可持久化的多桌面便签：速记图钉转换、独立编辑、置顶／置底、右下缩放、重启恢复
- 快捷键继续呼出独立速记框；便签普通回车换行，Command + 回车另存速记
- 菜单栏新增空白便签与显示全部便签；设置新增便签 tab 和关闭策略
- 根视图圆角裁切修复液态玻璃四角矩形底色；保持无窗口阴影与左上圆点拖动

## 1.4.0（2026-10-23）

- 项目更名「音速」（YinSu），bundle id 改为 com.sinyve.YinSu，旧版设置自动迁移
- 项目迁移到独立仓库 `~/项目/音速`，建立 git 历史
- 内部符号前缀 VNB → YS，日志改为 /tmp/YinSu.log

## 1.3.0（语音速记）

- 设置中新增输入字体、字号（12–48）调节，立即生效

## 1.2.0（语音速记）

- 面板改为液态玻璃（macOS 26+ NSGlassEffectView），新增标准/通透、交互光效、轻灰染色设置
- 修复浅色背景下四角黑色直角（窗口阴影导致）

## 1.1.0（语音速记）

- 去除标题与快捷键标签；左上磨砂圆点内嵌 waveform 标志；灰字提示可自定义
- 菜单栏图标支持左键直接打开输入框

## 1.0.0（语音速记）

- 菜单栏应用、全局快捷键呼出、回车保存到 Obsidian、二次确认、自适应高度、拖动移位、设置窗口（保存路径 / 快捷键 / 冲突检测 / 登录启动）
