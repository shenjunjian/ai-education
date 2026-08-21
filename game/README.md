# Immersive English（Godot）

## 要求

- Godot 4.3 或更高（Windows）
- 麦克风
- 火山引擎豆包实时语音与方舟文本模型凭证（见 `config/credentials.cfg.example`）

## 凭证

1. 运行一次游戏（或编辑器播放），会在 Godot 用户目录生成 `credentials.cfg`。
2. Windows 用户目录通常是 `%APPDATA%\Godot\app_userdata\Immersive English\credentials.cfg`。
3. 填写火山控制台的 `app_id`、`access_key`。标题生成另填方舟 `api_key` 与 `model`（接入点 ID）。
4. 不要把填好的文件拷回仓库。

## 打开

用 Godot 导入本目录（`game/`），主场景为 `ui/main_menu.tscn`。
