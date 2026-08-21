# Immersive English（Godot）

## 要求

- Godot 4.3 或更高（Windows）
- 麦克风
- 火山引擎豆包实时语音与方舟文本模型凭证（见 `config/credentials.cfg.example`）

## 凭证

1. 运行一次游戏（或编辑器 F5），会在 Godot 用户目录生成 `credentials.cfg`。
2. Windows 用户目录通常是 `%APPDATA%\Godot\app_userdata\Immersive English\credentials.cfg`（导出 exe 后路径相同，即 `user://credentials.cfg`）。
3. 对照 `config/credentials.cfg.example` 填写火山控制台的 `app_id`、`access_key`。标题生成另填方舟 `api_key` 与 `model`（接入点 ID）。
4. 不要把填好的文件拷回仓库。导出包内仅含 example（空字段）；运行时只读 `user://`，不读工程目录里的 `config/credentials.cfg`。

## 打开

用 Godot 导入本目录（`game/`），主场景为 `ui/main_menu.tscn`。

## 导出 Windows

1. 用 Godot 4.3+ 打开 `game/` 工程。
2. **项目 → 导出**；预设 **Windows Desktop** 已写在 `export_presets.cfg`，可执行文件输出为 `../build/windows/ImmersiveEnglish.exe`（相对 `game/`，即仓库根下的 `build/windows/`）。
3. 若首次导出，按提示下载 Windows 导出模板；然后点 **导出项目**。
4. 导出预设不含任何 `app_id` / `access_key`；`exclude_filter` 会排除工程内误放的 `config/credentials.cfg`，`credentials.cfg.example` 可随包发布供对照。
5. 首次运行导出的 exe 后，在用户目录填写 `credentials.cfg`（见上文）。

## 换目标测试场景

在 Godot 中临时将主场景改为 `world/indoor_neutral_two_npcs.tscn`，可验证鼠标点选换锁定与两段独立历史记录。

## v1 成功标准（手工核对）

- [ ] 1. Windows 打开导出的 exe 或编辑器 F5
- [ ] 2. 主菜单进入中性室内
- [ ] 3. WASD 走路，V 切换第一/第三人称
- [ ] 4. 进场景自动锁定收银员 NPC
- [ ] 5. 英语语音对话（全双工，默认可打断），字幕实时出现
- [ ] 6. 退出场景或关窗后，历史里有「标题 + 全文」
- [ ] 7. 无密钥时仍能走，HUD 提示填 `user://credentials.cfg`

核对提示：字幕位置与打断开关应在重启后仍保留；双 NPC 测试场景应产生两条历史。

## v1 不包含

- 超市 / 教室 / 商场等成品主题地图
- 手机包（Android / iOS）
- 账号、云同步、语音网关、应用商店上架
- 录音回放、发音评分、语法纠错老师模式
- 多玩家、物品栏、任务系统
