# Immersive English NPC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Windows 上交付一个 Godot 4.3+ 桌面程序：进入中性室内地图、行走并切换人称、锁定 NPC 后用豆包全双工英语口语对话，字幕实时显示，退出后历史里能看到模型总结标题 + 全文。

**Architecture:** Godot 工程在仓库 `game/`，四个模块只经窄接口通信：世界（场景/玩家/NPC）不知道协议与存档；互动（目标锁定）不知道 PCM/WebSocket；`VoiceSession` 接口负责开停会话、送麦、播音频、字幕与听/说状态；会话模块负责时间线、结束规则、标题、本地 JSON 与 HUD 数据。v1 语音实现是豆包 Strong Character 全双工 WebSocket；人设是 `PersonaResource`，换 `.tres` 即换角色。

**Tech Stack:** Godot 4.3+（GDScript）、`WebSocketPeer`、`AudioEffectCapture` + `AudioStreamMicrophone`、`AudioStreamGenerator` 流式播放、火山引擎豆包实时语音二进制协议（`wss://openspeech.bytedance.com/api/v3/realtime/dialogue`）、方舟 Chat Completions（标题）、`user://` 本地配置与存档。

**Spec:** `docs/superpowers/specs/2026-08-21-immersive-english-npc-design.md`

## Global Constraints

- Godot 4.3+ 桌面端，v1 只交付 Windows；游戏逻辑用 GDScript；工程放在 `game/`，与 `.agents/` 分离。
- 不编写测试。每个 task 的验证是 Godot 编辑器运行（F5）或命令行 `godot --path game --quit-after 1` 能打开工程，外加该 task 列出的手工检查项。不要引入 GUT/WAT 或任何测试框架。
- 密钥只读本机 `user://` 配置，不进 Git、不打进导出包。v1 不做短时 token 网关、账号、云同步。
- NPC 完全代入场景身份：不主动当英语老师、不打断纠错、不布置通关任务。人设资源必须约束 **只说英语**。
- 结束条件仅三项：点选另一个 NPC、卸载当前地图、退出程序。走路与切换人称不断连、不改锁定。
- 打断默认开。判停用豆包 `end_smooth_window_ms` 文档默认值 1500，不做自研 VAD。
- 错误：场景仍可走；已有字幕尽量保留；不向玩家展示堆栈。密钥与网络错误只写本地日志，不写入 `turns`。
- 字幕只使用接口返回的用户文本与 NPC 文本，游戏内不再跑一套 ASR。
- v1 不做：成品主题地图、手机包、录音回放、发音评分、多玩家、物品栏、任务系统。

## File Structure

```
game/
  project.godot
  default_bus_layout.tres
  export_presets.cfg
  README.md
  config/
    credentials.cfg.example          # 空模板，无真实密钥；不作为导出依赖
  autoload/
    app_config.gd                    # user:// 凭证 + settings.cfg
    game_log.gd                      # 本地日志，永不弹堆栈
    app_lifecycle.gd                 # 关窗 → 走同一套结束逻辑
    input_bindings.gd                # WASD / V / Alt / Esc 按键
  data/
    persona_resource.gd              # class_name PersonaResource
    personas/
      cashier_default.tres
      stock_clerk.tres               # 仅测试场景第二人，交付地图仍只用一个 NPC
  world/
    indoor_neutral.tscn
    indoor_neutral.gd                # scene_id = "indoor_neutral"
    indoor_neutral_two_npcs.tscn     # 测试换目标；不作为主菜单入口
    player.tscn
    player.gd
    npc.tscn
    npc.gd
  interaction/
    target_lock.gd
  voice/
    voice_session.gd                 # 接口：start/stop/retry + 信号
    doubao_protocol.gd               # 二进制编解码
    doubao_voice_session.gd          # VoiceSession 的 v1 实现
    mic_capture.gd
    pcm_player.gd
  session/
    conversation_session.gd          # 时间线
    conversation_store.gd            # user://conversations/*.json
    title_generator.gd               # 方舟 Chat，失败走后备标题
    session_orchestrator.gd          # 锁定/离图/退出的结束顺序
  ui/
    main_menu.tscn
    main_menu.gd
    history_list.tscn
    history_list.gd
    history_detail.tscn
    history_detail.gd
    subtitle_hud.tscn
    subtitle_hud.gd
    pause_menu.tscn
    pause_menu.gd
    status_banner.gd                 # 无密钥 / 断线 / 无麦 / 未保存
```

仓库根再补 `.gitignore`（忽略 `game/.godot/`、`build/`、任何本机填过的 `credentials.cfg`）。

---

### Task 1: Godot 工程脚手架与音频总线

**Files:**
- Create: `game/project.godot`
- Create: `game/default_bus_layout.tres`
- Create: `game/README.md`
- Create: `.gitignore`
- Create: `game/ui/main_menu.tscn`
- Create: `game/ui/main_menu.gd`
- Create: `game/autoload/game_log.gd`
- Create: `game/autoload/input_bindings.gd`

**Interfaces:**
- Consumes: 无（空仓库，尚无 `game/`）
- Produces: 可打开的 Godot 4.3 工程；Autoload `GameLog.log_line(message: String) -> void`；InputMap 动作名：`move_forward` `move_back` `move_left` `move_right` `toggle_camera` `release_mouse` `pause_menu` `interact_click`

- [ ] **Step 1: 安装 Godot 4.3 或更高（Windows）**

从 https://godotengine.org/download/windows/ 安装 **4.3+** 标准版（非 .NET 亦可）。确认命令行可用，例如：

```powershell
godot --version
```

Expected: 打印 `4.3` 或更高。若 `godot` 不在 PATH，后续命令用 Godot 可执行文件的绝对路径替换 `godot`。

- [ ] **Step 2: 写仓库 `.gitignore`**

```gitignore
game/.godot/
game/export/
build/
*.translation
user://
.DS_Store
Thumbs.db
```

- [ ] **Step 3: 写 `game/project.godot`**

```ini
; Engine configuration file.
config_version=5

[application]
config/name="Immersive English"
config/description="Immersive English speaking practice"
run/main_scene="res://ui/main_menu.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")
config/icon="res://icon.svg"

[audio]
driver/enable_input=true

[autoload]
GameLog="*res://autoload/game_log.gd"
InputBindings="*res://autoload/input_bindings.gd"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"

[rendering]
renderer/rendering_method="forward_plus"
```

若不想手绘 `icon.svg`，删掉 `config/icon` 那一行，Godot 会用默认图标。

- [ ] **Step 4: 写 `game/default_bus_layout.tres`**

Mic 总线 **mute=true**（避免回授），但保留 Capture 效果。Godot 在 mute 的 Record/Mic 总线上仍能 `AudioEffectCapture.get_buffer`。

```text
[gd_resource type="AudioBusLayout" format=3 uid="uid://buslayoutmic"]

[sub_resource type="AudioEffectCapture" id="AudioEffectCapture_mic"]
buffer_length = 0.5

[resource]
bus/1/name = "Mic"
bus/1/solo = false
bus/1/mute = true
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = &"Master"
bus/1/effect/0/effect = SubResource("AudioEffectCapture_mic")
bus/1/effect/0/enabled = true
```

- [ ] **Step 5: 写 `game/autoload/game_log.gd`**

```gdscript
extends Node

const LOG_PATH := "user://logs/game.log"

func log_line(message: String) -> void:
	var stamp := Time.get_datetime_string_from_system(false, true)
	var line := "%s %s\n" % [stamp, message]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://logs"))
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("GameLog open failed: %s" % FileAccess.get_open_error())
		return
	f.seek_end()
	f.store_string(line)
	f.close()
	print(line.strip_edges())
```

- [ ] **Step 6: 写 `game/autoload/input_bindings.gd`**

```gdscript
extends Node

func _ready() -> void:
	_ensure_key("move_forward", KEY_W)
	_ensure_key("move_back", KEY_S)
	_ensure_key("move_left", KEY_A)
	_ensure_key("move_right", KEY_D)
	_ensure_key("toggle_camera", KEY_V)
	_ensure_key("pause_menu", KEY_ESCAPE)
	_ensure_key("release_mouse", KEY_ALT)
	if not InputMap.has_action("interact_click"):
		InputMap.add_action("interact_click")
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("interact_click", mouse)

func _ensure_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
```

- [ ] **Step 7: 写占位主菜单**

`game/ui/main_menu.gd`：

```gdscript
extends Control

func _ready() -> void:
	$Center/VBox/QuitButton.pressed.connect(func() -> void:
		get_tree().quit()
	)
```

`game/ui/main_menu.tscn`：

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/main_menu.gd" id="1_script"]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_script")

[node name="Center" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="VBox" type="VBoxContainer" parent="Center"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="Title" type="Label" parent="Center/VBox"]
layout_mode = 2
text = "沉浸式英语口语陪练"
horizontal_alignment = 1

[node name="QuitButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "退出"
```

- [ ] **Step 8: 写 `game/README.md`**

```markdown
# Immersive English（Godot）

## 要求

- Godot 4.3 或更高（Windows）
- 麦克风
- 火山引擎豆包实时语音与方舟文本模型凭证（见 `config/credentials.cfg.example`）

## 打开

用 Godot 导入本目录（`game/`），主场景为 `ui/main_menu.tscn`。
```

- [ ] **Step 9: 用 Godot 导入并运行**

```powershell
godot --path game --editor
```

按 F5。Expected: 1280×720 窗口，标题「沉浸式英语口语陪练」，点「退出」关闭。编辑器里 Audio 面板能看到 `Master` 与 `Mic` 总线，`Mic` 静音且有 Capture。

- [ ] **Step 10: Commit**

```bash
git add .gitignore game/project.godot game/default_bus_layout.tres game/README.md game/ui/main_menu.tscn game/ui/main_menu.gd game/autoload/game_log.gd game/autoload/input_bindings.gd
git commit -m "chore: scaffold Godot 4.3 project with mic bus and main menu"
```

---

### Task 2: 本机凭证与设置（AppConfig）

**Files:**
- Create: `game/config/credentials.cfg.example`
- Create: `game/autoload/app_config.gd`
- Modify: `game/project.godot` — 在 `[autoload]` 的 `GameLog` 之上加入 `AppConfig="*res://autoload/app_config.gd"`（其它 Autoload 可依赖它）

**Interfaces:**
- Consumes: `GameLog.log_line(message: String) -> void`
- Produces: Autoload `AppConfig`：
  - `func has_voice_credentials() -> bool`
  - `func get_voice_app_id() -> String`
  - `func get_voice_access_key() -> String`
  - `func get_voice_app_key() -> String`（缺省 `PlgvMymc7f3tQnJ6`）
  - `func get_voice_resource_id() -> String`（缺省 `volc.speech.dialog`）
  - `func get_realtime_model() -> String`（缺省 `2.2.0.0`，Strong Character 2.0）
  - `func get_ark_api_key() -> String`
  - `func get_ark_model() -> String`
  - `func get_ark_chat_url() -> String`（缺省 `https://ark.cn-beijing.volces.com/api/v3/chat/completions`）
  - `func is_interrupt_enabled() -> bool`
  - `func set_interrupt_enabled(enabled: bool) -> void`
  - `func get_subtitle_anchor() -> String` 返回 `"top_right"` 或 `"bottom_center"`
  - `func set_subtitle_anchor(anchor: String) -> void`
  - `func save_settings() -> void`
  - `func credentials_user_path() -> String` 返回 `user://credentials.cfg`

- [ ] **Step 1: 写空模板 `game/config/credentials.cfg.example`**

真实密钥禁止写入此文件或任何 `res://` 文件。

```ini
[volc]
app_id=""
access_key=""
app_key="PlgvMymc7f3tQnJ6"
resource_id="volc.speech.dialog"
realtime_model="2.2.0.0"

[ark]
api_key=""
model=""
chat_url="https://ark.cn-beijing.volces.com/api/v3/chat/completions"
```

- [ ] **Step 2: 写 `game/autoload/app_config.gd`**

首次运行：若 `user://credentials.cfg` 不存在，把 example 拷过去。设置写 `user://settings.cfg`。

```gdscript
extends Node

const CREDENTIALS_EXAMPLE := "res://config/credentials.cfg.example"
const CREDENTIALS_USER := "user://credentials.cfg"
const SETTINGS_USER := "user://settings.cfg"
const DEFAULT_APP_KEY := "PlgvMymc7f3tQnJ6"
const DEFAULT_RESOURCE_ID := "volc.speech.dialog"
const DEFAULT_MODEL := "2.2.0.0"
const DEFAULT_CHAT_URL := "https://ark.cn-beijing.volces.com/api/v3/chat/completions"

var _credentials := ConfigFile.new()
var _settings := ConfigFile.new()

func _ready() -> void:
	_ensure_user_credentials()
	var cred_err := _credentials.load(CREDENTIALS_USER)
	if cred_err != OK:
		GameLog.log_line("credentials load failed err=%s" % cred_err)
	var set_err := _settings.load(SETTINGS_USER)
	if set_err != OK:
		_settings.set_value("voice", "interrupt_enabled", true)
		_settings.set_value("hud", "subtitle_anchor", "top_right")
		save_settings()

func credentials_user_path() -> String:
	return CREDENTIALS_USER

func has_voice_credentials() -> bool:
	return not get_voice_app_id().is_empty() and not get_voice_access_key().is_empty()

func get_voice_app_id() -> String:
	return str(_credentials.get_value("volc", "app_id", "")).strip_edges()

func get_voice_access_key() -> String:
	return str(_credentials.get_value("volc", "access_key", "")).strip_edges()

func get_voice_app_key() -> String:
	var v := str(_credentials.get_value("volc", "app_key", DEFAULT_APP_KEY)).strip_edges()
	return DEFAULT_APP_KEY if v.is_empty() else v

func get_voice_resource_id() -> String:
	var v := str(_credentials.get_value("volc", "resource_id", DEFAULT_RESOURCE_ID)).strip_edges()
	return DEFAULT_RESOURCE_ID if v.is_empty() else v

func get_realtime_model() -> String:
	var v := str(_credentials.get_value("volc", "realtime_model", DEFAULT_MODEL)).strip_edges()
	return DEFAULT_MODEL if v.is_empty() else v

func get_ark_api_key() -> String:
	return str(_credentials.get_value("ark", "api_key", "")).strip_edges()

func get_ark_model() -> String:
	return str(_credentials.get_value("ark", "model", "")).strip_edges()

func get_ark_chat_url() -> String:
	var v := str(_credentials.get_value("ark", "chat_url", DEFAULT_CHAT_URL)).strip_edges()
	return DEFAULT_CHAT_URL if v.is_empty() else v

func is_interrupt_enabled() -> bool:
	return bool(_settings.get_value("voice", "interrupt_enabled", true))

func set_interrupt_enabled(enabled: bool) -> void:
	_settings.set_value("voice", "interrupt_enabled", enabled)
	save_settings()

func get_subtitle_anchor() -> String:
	var v := str(_settings.get_value("hud", "subtitle_anchor", "top_right"))
	if v != "bottom_center":
		return "top_right"
	return v

func set_subtitle_anchor(anchor: String) -> void:
	if anchor != "bottom_center":
		anchor = "top_right"
	_settings.set_value("hud", "subtitle_anchor", anchor)
	save_settings()

func save_settings() -> void:
	var err := _settings.save(SETTINGS_USER)
	if err != OK:
		GameLog.log_line("settings save failed err=%s" % err)

func _ensure_user_credentials() -> void:
	if FileAccess.file_exists(CREDENTIALS_USER):
		return
	var src := FileAccess.open(CREDENTIALS_EXAMPLE, FileAccess.READ)
	if src == null:
		GameLog.log_line("missing credentials example")
		return
	var dst := FileAccess.open(CREDENTIALS_USER, FileAccess.WRITE)
	if dst == null:
		GameLog.log_line("cannot create user credentials err=%s" % FileAccess.get_open_error())
		src.close()
		return
	dst.store_string(src.get_as_text())
	src.close()
	dst.close()
```

- [ ] **Step 3: 在 `game/project.godot` 的 `[autoload]` 加入 AppConfig（必须排在 GameLog 前）**

```ini
[autoload]
AppConfig="*res://autoload/app_config.gd"
GameLog="*res://autoload/game_log.gd"
InputBindings="*res://autoload/input_bindings.gd"
```

- [ ] **Step 4: 更新 `game/README.md`，在「打开」之前加入：**

```markdown
## 凭证

1. 运行一次游戏（或编辑器播放），会在 Godot 用户目录生成 `credentials.cfg`。
2. Windows 用户目录通常是 `%APPDATA%\Godot\app_userdata\Immersive English\credentials.cfg`。
3. 填写火山控制台的 `app_id`、`access_key`。标题生成另填方舟 `api_key` 与 `model`（接入点 ID）。
4. 不要把填好的文件拷回仓库。
```

- [ ] **Step 5: 验证**

F5 运行一次后退出。确认 `%APPDATA%\Godot\app_userdata\Immersive English\credentials.cfg` 存在且字段为空；`settings.cfg` 含 `interrupt_enabled=true` 与 `subtitle_anchor="top_right"`。把 `app_id` 临时写成 `x` 再运行，`AppConfig.has_voice_credentials()` 在远程调试器里应为 false（access_key 仍空）。

- [ ] **Step 6: Commit**

```bash
git add game/config/credentials.cfg.example game/autoload/app_config.gd game/project.godot game/README.md
git commit -m "feat: load Volcengine credentials and HUD settings from user://"
```

---

### Task 3: PersonaResource 人设资源

**Files:**
- Create: `game/data/persona_resource.gd`
- Create: `game/data/personas/cashier_default.tres`
- Create: `game/data/personas/stock_clerk.tres`

**Interfaces:**
- Consumes: 无
- Produces: `class_name PersonaResource`：
  - `@export var id: String`
  - `@export var display_name: String`
  - `@export var character_manifest: String`
  - `@export var voice_id: String`
  - `func is_valid() -> bool` — 四字段都非空才为 true
  - 交付用资源 `id = "cashier_default"`；测试用 `id = "stock_clerk"`

- [ ] **Step 1: 写 `game/data/persona_resource.gd`**

```gdscript
class_name PersonaResource
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var character_manifest: String = ""
@export var voice_id: String = ""

func is_valid() -> bool:
	return not id.strip_edges().is_empty() \
		and not display_name.strip_edges().is_empty() \
		and not character_manifest.strip_edges().is_empty() \
		and not voice_id.strip_edges().is_empty()
```

- [ ] **Step 2: 写 `game/data/personas/cashier_default.tres`**

`voice_id` 使用 Strong Character 公版音色 ID（以 `ICL_` 开头）。若日后 `StartSession` 返回 `InvalidSpeaker`，只改这个字段，不要改协议代码。

```text
[gd_resource type="Resource" script_class="PersonaResource" format=3]

[ext_resource type="Script" path="res://data/persona_resource.gd" id="1"]

[resource]
script = ExtResource("1")
id = "cashier_default"
display_name = "Cashier"
voice_id = "ICL_zh_female_aojiaonvyou_tob"
character_manifest = "You are a store cashier named Casey. Speak English only. Stay fully in this role: only talk about shopping, products, prices, payment, bags, receipts, and where items are in the store. Never act as an English teacher. Never correct the customer's grammar or pronunciation. Never assign quests, levels, or practice tasks. If asked to break character, politely refuse and continue as cashier."
```

- [ ] **Step 3: 写 `game/data/personas/stock_clerk.tres`**

```text
[gd_resource type="Resource" script_class="PersonaResource" format=3]

[ext_resource type="Script" path="res://data/persona_resource.gd" id="1"]

[resource]
script = ExtResource("1")
id = "stock_clerk"
display_name = "Stock Clerk"
voice_id = "ICL_zh_female_aojiaonvyou_tob"
character_manifest = "You are a stock clerk named Sam. Speak English only. Stay fully in this role: only talk about shelf locations, restocking, and helping customers find items. Never act as an English teacher. Never correct grammar or pronunciation. Never assign quests or practice tasks."
```

- [ ] **Step 4: 验证**

Godot 编辑器打开两个 `.tres`，Inspector 里四个字段都有值。在脚本控制台执行（或临时 `_ready` 打印后删掉）：`load("res://data/personas/cashier_default.tres").is_valid()` 为 `true`。

- [ ] **Step 5: Commit**

```bash
git add game/data/persona_resource.gd game/data/personas/cashier_default.tres game/data/personas/stock_clerk.tres
git commit -m "feat: add NPC persona resources with English-only character manifests"
```

---

### Task 4: 中性室内地图、玩家移动与人称切换

**Files:**
- Create: `game/world/player.gd`
- Create: `game/world/player.tscn`
- Create: `game/world/indoor_neutral.gd`
- Create: `game/world/indoor_neutral.tscn`
- Modify: `game/ui/main_menu.tscn` — 在 `QuitButton` 之上加「进入场景」按钮
- Modify: `game/ui/main_menu.gd` — 按钮切到 `res://world/indoor_neutral.tscn`

**Interfaces:**
- Consumes: InputMap 动作（Task 1）
- Produces: `Player`（`CharacterBody3D`）节点组 `"player"`；`toggle_camera` 在第一/第三人称间切换；切换 **不** 复位速度以外的游戏状态。`IndoorNeutral.SCENE_ID = "indoor_neutral"`。第一人称默认 `Input.MOUSE_MODE_CAPTURED`；按住 `release_mouse`（Alt）时 `MOUSE_MODE_VISIBLE`；第三人称默认显示鼠标。

- [ ] **Step 1: 写 `game/world/player.gd`**

```gdscript
extends CharacterBody3D

const SPEED := 4.5
const MOUSE_SENS := 0.0025

@onready var _head: Node3D = $Head
@onready var _fp_camera: Camera3D = $Head/FirstPersonCamera
@onready var _spring: SpringArm3D = $SpringArm
@onready var _tp_camera: Camera3D = $SpringArm/ThirdPersonCamera
@onready var _mesh: MeshInstance3D = $BodyMesh

var _third_person := false

func _ready() -> void:
	add_to_group("player")
	_apply_camera_mode()

func is_third_person() -> bool:
	return _third_person

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		_third_person = not _third_person
		_apply_camera_mode()
		get_viewport().set_input_as_handled()
		return
	if not _third_person and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		_head.rotate_x(-event.relative.y * MOUSE_SENS)
		_head.rotation.x = clampf(_head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))

func _physics_process(delta: float) -> void:
	if not _third_person:
		if Input.is_action_pressed("release_mouse"):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	move_and_slide()

func _apply_camera_mode() -> void:
	_fp_camera.current = not _third_person
	_tp_camera.current = _third_person
	_mesh.visible = _third_person
	_spring.rotation = Vector3.ZERO
	if _third_person:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
```

- [ ] **Step 2: 写 `game/world/player.tscn`**

胶囊高约 1.8m，相机在 `Head` y=1.6。碰撞层 1，掩码 1。

```text
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://world/player.gd" id="1"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_player"]
radius = 0.35
height = 1.8

[sub_resource type="CapsuleMesh" id="CapsuleMesh_player"]
radius = 0.35
height = 1.8

[node name="Player" type="CharacterBody3D"]
collision_layer = 1
collision_mask = 1
script = ExtResource("1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
shape = SubResource("CapsuleShape3D_player")

[node name="BodyMesh" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
mesh = SubResource("CapsuleMesh_player")

[node name="Head" type="Node3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.6, 0)

[node name="FirstPersonCamera" type="Camera3D" parent="Head"]
current = true

[node name="SpringArm" type="SpringArm3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.4, 0)
spring_length = 3.2
collision_mask = 1

[node name="ThirdPersonCamera" type="Camera3D" parent="SpringArm"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
```

第三人称弹簧臂默认朝向 -Z，Godot 的 `SpringArm3D` 沿自己的 -Z 拉长。给 `SpringArm` 加旋转使相机在身后：在编辑器把 `SpringArm` 的 rotation_degrees.x 设为 -12。在 tscn 的 SpringArm `transform` 换成略微抬头的矩阵，或在 `player.gd` `_ready` 加 `_spring.rotation_degrees = Vector3(-12, 0, 0)`。

在 `player.gd` 的 `_ready` 末尾追加：

```gdscript
	_spring.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
```

- [ ] **Step 3: 写 `game/world/indoor_neutral.gd`**

```gdscript
extends Node3D

const SCENE_ID := "indoor_neutral"
```

- [ ] **Step 4: 写 `game/world/indoor_neutral.tscn`**

8×8 地面、四面墙、一盏灯、出生点把 Player 放在 `(0, 0.1, 2)`。用 CSG，无需外部模型。

```text
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://world/indoor_neutral.gd" id="1"]
[ext_resource type="PackedScene" path="res://world/player.tscn" id="2"]

[sub_resource type="Environment" id="Environment_indoor"]
background_mode = 1
background_color = Color(0.62, 0.66, 0.7, 1)
ambient_light_source = 2
ambient_light_color = Color(0.85, 0.85, 0.88, 1)
ambient_light_energy = 0.7

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_floor"]
albedo_color = Color(0.76, 0.74, 0.7, 1)

[node name="IndoorNeutral" type="Node3D"]
script = ExtResource("1")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_indoor")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866, -0.354, 0.354, 0, 0.707, 0.707, -0.5, -0.612, 0.612, 0, 6, 0)
shadow_enabled = true

[node name="Floor" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.1, 0)
use_collision = true
size = Vector3(12, 0.2, 12)
material = SubResource("StandardMaterial3D_floor")

[node name="WallN" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.5, -6)
use_collision = true
size = Vector3(12, 3, 0.2)

[node name="WallS" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.5, 6)
use_collision = true
size = Vector3(12, 3, 0.2)

[node name="WallW" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -6, 1.5, 0)
use_collision = true
size = Vector3(0.2, 3, 12)

[node name="WallE" type="CSGBox3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 6, 1.5, 0)
use_collision = true
size = Vector3(0.2, 3, 12)

[node name="Player" parent="." instance=ExtResource("2")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.1, 2)
```

- [ ] **Step 5: 主菜单加入「进入场景」**

`main_menu.tscn` 在 `QuitButton` 前插入：

```text
[node name="EnterButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "进入场景"
```

`main_menu.gd` 改为：

```gdscript
extends Control

func _ready() -> void:
	$Center/VBox/EnterButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://world/indoor_neutral.tscn")
	)
	$Center/VBox/QuitButton.pressed.connect(func() -> void:
		get_tree().quit()
	)
```

- [ ] **Step 6: 验证**

F5 → 进入场景。WASD 走路；第一人称鼠标转向且看不见自己的胶囊；Alt 放出鼠标；V 切第三人称能看见胶囊且鼠标可见；再按 V 回到第一人称。Expected: 人不掉出房间；切换人称时位置连续。

- [ ] **Step 7: Commit**

```bash
git add game/world/player.gd game/world/player.tscn game/world/indoor_neutral.gd game/world/indoor_neutral.tscn game/ui/main_menu.tscn game/ui/main_menu.gd
git commit -m "feat: add indoor scene with first and third person walking"
```

---

### Task 5: NPC 巡逻与四态动画

**Files:**
- Create: `game/world/npc.gd`
- Create: `game/world/npc.tscn`
- Modify: `game/world/indoor_neutral.tscn` — 实例化一个 NPC，人设指向 `cashier_default.tres`

**Interfaces:**
- Consumes: `PersonaResource.is_valid()`
- Produces: `class_name NpcActor`（脚本挂在 NPC 根节点）：
  - `@export var persona: PersonaResource`
  - `@export var patrol_points: Array[Vector3]`
  - `func get_persona() -> PersonaResource`
  - `func set_engaged(engaged: bool) -> void` — true 时停下并 `look_at` 玩家（只转 Y）
  - `func set_voice_phase(phase: String) -> void` — 仅接受 `"idle"` `"walk"` `"listen"` `"talk"`
  - 节点加入组 `"npc"`；`collision_layer = 2`（可点选），`collision_mask = 1`（与地面碰撞）
  - 未 engaged 且 `patrol_points.size() >= 2` 时在点间走动，相位为 walk；停下时 idle。engaged 时：listen/talk 优先于 idle，不走路。

- [ ] **Step 1: 写 `game/world/npc.gd`**

```gdscript
class_name NpcActor
extends CharacterBody3D

const WALK_SPEED := 1.4

@export var persona: PersonaResource
@export var patrol_points: Array[Vector3] = []

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _visual: Node3D = $Visual

var _engaged := false
var _voice_phase := "idle"
var _patrol_index := 0

func _ready() -> void:
	add_to_group("npc")

func get_persona() -> PersonaResource:
	return persona

func set_engaged(engaged: bool) -> void:
	_engaged = engaged
	if _engaged:
		velocity = Vector3.ZERO

func set_voice_phase(phase: String) -> void:
	if phase not in ["idle", "walk", "listen", "talk"]:
		return
	_voice_phase = phase
	_play_phase()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	if _engaged:
		velocity.x = 0.0
		velocity.z = 0.0
		_face_player()
		move_and_slide()
		_play_phase()
		return
	_patrol(delta)
	move_and_slide()
	if Vector2(velocity.x, velocity.z).length() > 0.05:
		_voice_phase = "walk"
	elif _voice_phase != "listen" and _voice_phase != "talk":
		_voice_phase = "idle"
	_play_phase()

func _face_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var target: Node3D = players[0]
	var p := target.global_position
	p.y = global_position.y
	if p.distance_to(global_position) > 0.01:
		look_at(p, Vector3.UP)

func _patrol(_delta: float) -> void:
	if patrol_points.size() < 2:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var goal: Vector3 = patrol_points[_patrol_index]
	goal.y = global_position.y
	var offset := goal - global_position
	offset.y = 0.0
	if offset.length() < 0.25:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir := offset.normalized()
	velocity.x = dir.x * WALK_SPEED
	velocity.z = dir.z * WALK_SPEED
	look_at(global_position + dir, Vector3.UP)

func _play_phase() -> void:
	var clip := "idle"
	if _engaged and _voice_phase == "listen":
		clip = "listen"
	elif _engaged and _voice_phase == "talk":
		clip = "talk"
	elif not _engaged and _voice_phase == "walk":
		clip = "walk"
	if _anim.current_animation != clip:
		_anim.play(clip)
```

- [ ] **Step 2: 写 `game/world/npc.tscn`，含四段循环动画**

用 `Visual` 下的胶囊 + 两个 `BoxMesh` 手臂。`AnimationPlayer` 库：

- `idle`：手臂微垂，1.5s 循环
- `walk`：手臂前后摆
- `listen`：略前倾
- `talk`：右手上下摆（通用手势）

在编辑器创建更稳。最小可用 tscn：根 `CharacterBody3D` 脚本 `npc.gd`，`CollisionShape3D` 胶囊（layer 2），`Visual/Body`、`Visual/ArmL`、`Visual/ArmR`，`AnimationPlayer` 四条动画。手臂节点路径必须是 `Visual/ArmR`，talk 轨道旋转 `rotation_degrees.x` 在 -10 与 50 之间。

若手写 tscn 动画块易错：用编辑器做完后保存 `npc.tscn`，不要用空 AnimationPlayer 提交。

碰撞：根节点 `collision_layer = 2`，`collision_mask = 1`。

- [ ] **Step 3: 把 NPC 放进 `indoor_neutral.tscn`**

实例 `npc.tscn`，放在 `(-1.5, 0.1, -2)`。Inspector：

- `persona` = `res://data/personas/cashier_default.tres`
- `patrol_points` = `(-1.5, 0.1, -2)`, `(2.5, 0.1, -2)`, `(2.5, 0.1, 1.5)`

- [ ] **Step 4: 验证**

F5 进场景。Expected: NPC 在三点间走动并播 walk；到达附近停下再去下一点。临时在 `npc.gd` `_ready` 末尾加 `set_engaged(true); set_voice_phase("listen")` 应停下并朝向玩家；验证完删掉这两行。

- [ ] **Step 5: Commit**

```bash
git add game/world/npc.gd game/world/npc.tscn game/world/indoor_neutral.tscn
git commit -m "feat: add patrolling NPC with idle walk listen talk animations"
```

---

### Task 6: 目标锁定与点选（按 N 个 NPC 实现）

**Files:**
- Create: `game/interaction/target_lock.gd`
- Create: `game/world/indoor_neutral_two_npcs.tscn`（复制室内场景，再放 `stock_clerk` NPC）
- Modify: `game/world/indoor_neutral.tscn` — 根节点挂 `TargetLock`
- Modify: `game/world/player.gd` — 第一人称准星射线由 `TargetLock` 调用，不要在 player 里写锁定业务
- Create: `game/ui/crosshair.tscn` — 第一人称屏幕中心一个 8px 方块；第三人称隐藏

**Interfaces:**
- Consumes: 组 `"npc"`、`"player"`；`NpcActor.set_engaged(bool)`
- Produces: `class_name TargetLock`：
  - `signal target_changed(previous: NpcActor, current: NpcActor)` — `current` 可为 `null`
  - `func get_current() -> NpcActor`
  - `func try_lock(npc: NpcActor) -> void` — 点选已锁定对象：直接 return；点选另一 NPC：先 `target_changed(old, new)`（监听方负责结束旧会话），再锁定
  - `_ready` 结束时锁定距离玩家最近的 NPC；没有 NPC 则不锁定
  - 走路不改锁定

点选规则：

- 第一人称且鼠标捕获：准星中心射线 + `interact_click`
- 第一人称 Alt 放出鼠标，或第三人称：鼠标左键点 NPC 网格（`PhysicsRayQueryParameters3D`，`collision_mask = 2`）

- [ ] **Step 1: 写 `game/interaction/target_lock.gd`**

```gdscript
class_name TargetLock
extends Node

signal target_changed(previous: NpcActor, current: NpcActor)

var _current: NpcActor = null

func get_current() -> NpcActor:
	return _current

func _ready() -> void:
	call_deferred("_lock_nearest")

func _lock_nearest() -> void:
	var player := _player()
	if player == null:
		return
	var best: NpcActor = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("npc"):
		if node is NpcActor:
			var d: float = player.global_position.distance_to(node.global_position)
			if d < best_d:
				best_d = d
				best = node
	if best != null:
		_set_current(best)

func try_lock(npc: NpcActor) -> void:
	if npc == null:
		return
	if npc == _current:
		return
	_set_current(npc)

func _set_current(npc: NpcActor) -> void:
	var previous := _current
	if previous != null:
		previous.set_engaged(false)
		previous.set_voice_phase("idle")
	_current = npc
	if _current != null:
		_current.set_engaged(true)
	target_changed.emit(previous, _current)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact_click"):
		return
	var npc := _pick_npc()
	if npc != null:
		try_lock(npc)
		get_viewport().set_input_as_handled()

func _pick_npc() -> NpcActor:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var player := _player()
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var from: Vector3
	var to: Vector3
	if captured and player != null and not player.is_third_person():
		from = cam.project_ray_origin(get_viewport().get_visible_rect().size / 2.0)
		to = from + cam.project_ray_normal(get_viewport().get_visible_rect().size / 2.0) * 40.0
	else:
		var mouse := get_viewport().get_mouse_position()
		from = cam.project_ray_origin(mouse)
		to = from + cam.project_ray_normal(mouse) * 40.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 2
	q.collide_with_areas = false
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var collider: Object = hit["collider"]
	if collider is NpcActor:
		return collider
	return null

func _player() -> CharacterBody3D:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0]
```

注意：`player.gd` 必须保留 `is_third_person() -> bool`（Task 4 已有）。

- [ ] **Step 2: 准星 HUD**

`game/ui/crosshair.tscn`：全屏 `Control` + 中心 `ColorRect` 8×8 白色。脚本：

```gdscript
extends Control

func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		visible = false
		return
	visible = not players[0].is_third_person()
```

把 Crosshair 和 TargetLock 都挂到 `indoor_neutral.tscn` 根下。TargetLock 是普通 Node。

- [ ] **Step 3: 双 NPC 测试场景**

复制 `indoor_neutral.tscn` 为 `indoor_neutral_two_npcs.tscn`。第二个 NPC 放 `(2.5, 0.1, 2.0)`，`persona = stock_clerk.tres`，`patrol_points` 可留空（原地 idle）。主菜单 **不要** 默认进这个场景。在 `game/README.md` 加一句：换目标测试用 Godot 把主场景临时改成 `indoor_neutral_two_npcs.tscn`。

- [ ] **Step 4: 验证**

单 NPC 场景：进图后收银员应停下并转向玩家（自动锁定）。走路，NPC 保持面向、不恢复巡逻。双 NPC 场景：点另一个 NPC，前者恢复走动，后者停下。再点当前锁定对象：无切换。V 切换人称后锁定对象不变。

- [ ] **Step 5: Commit**

```bash
git add game/interaction/target_lock.gd game/ui/crosshair.tscn game/world/indoor_neutral.tscn game/world/indoor_neutral_two_npcs.tscn game/README.md game/world/player.gd
git commit -m "feat: auto-lock nearest NPC and click-to-retarget"
```

---

### Task 7: 会话时间线与本地 JSON 存档（后备标题）

**Files:**
- Create: `game/session/conversation_session.gd`
- Create: `game/session/conversation_store.gd`
- Create: `game/session/title_generator.gd` — 本 task 只实现后备标题；HTTP 在 Task 13 补上，但 **函数签名本 task 就定死**，内部先走后备路径

**Interfaces:**
- Consumes: 无语音依赖
- Produces:
  - `class_name ConversationSession`：
    - `signal turns_changed(turns: Array)`
    - `func begin(scene_id: String, persona_id: String) -> void`
    - `func append_turn(role: String, text: String) -> void` — `role` 仅 `"user"` 或 `"npc"`；`text.strip_edges()` 为空则忽略；`at` 为 `Time.get_unix_time_from_system() * 1000` 取整
    - `func get_turns() -> Array` — 元素为 `{ "role": String, "text": String, "at": int }`
    - `func has_non_empty_turns() -> bool`
    - `func clear() -> void`
    - `func get_scene_id() -> String`
    - `func get_persona_id() -> String`
    - `func get_started_at() -> int`
  - `class_name ConversationStore`：
    - `static func save_record(record: Dictionary) -> String` — 成功返回 `user://conversations/<id>.json`，失败返回 `""` 并 `GameLog.log_line`
    - `static func load_all() -> Array` — 按 `ended_at` 降序
    - `static func load_by_id(id: String) -> Dictionary`
  - `class_name TitleGenerator`：
    - `func generate_title(turns: Array) -> String` — 本 task 实现为同步后备：首条非空 user 文本按 Unicode 截到 20 字；否则 `对话 YYYY-MM-DD HH:MM`（本地时间）。Task 13 把此函数改为先 await Chat，失败再调用同一套后备。为让签名稳定，本 task 写成 `func generate_title(turns: Array) -> String` 且可被 `await`（用 `await get_tree().process_frame` 一次后返回后备，这样 Task 13 改成 HTTP 后调用方仍写 `await title_gen.generate_title(turns)`）。

JSON 记录形状必须与 spec 一致：

```json
{
  "id": "uuid",
  "title": "在货架前问牛奶在哪",
  "started_at": 0,
  "ended_at": 0,
  "scene_id": "indoor_neutral",
  "persona_id": "cashier_default",
  "turns": []
}
```

无非空 `turns` 不写文件。标题失败不得丢正文（本 task 的后备路径即满足）。

- [ ] **Step 1: 写 `game/session/conversation_store.gd`**

```gdscript
class_name ConversationStore
extends RefCounted

const DIR := "user://conversations"

static func save_record(record: Dictionary) -> String:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var id := str(record.get("id", ""))
	if id.is_empty():
		GameLog.log_line("save_record missing id")
		return ""
	var path := "%s/%s.json" % [DIR, id]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		GameLog.log_line("conversation write failed err=%s" % FileAccess.get_open_error())
		return ""
	f.store_string(JSON.stringify(record, "\t"))
	f.close()
	return path

static func load_all() -> Array:
	var out: Array = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json"):
			var rec := load_by_id(name.get_basename())
			if not rec.is_empty():
				out.append(rec)
		name = dir.get_next()
	out.sort_custom(func(a, b) -> bool:
		return int(a.get("ended_at", 0)) > int(b.get("ended_at", 0))
	)
	return out

static func load_by_id(id: String) -> Dictionary:
	var path := "%s/%s.json" % [DIR, id]
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
```

- [ ] **Step 2: 写 `game/session/title_generator.gd`**

```gdscript
class_name TitleGenerator
extends Node

func generate_title(turns: Array) -> String:
	await get_tree().process_frame
	return fallback_title(turns)

static func fallback_title(turns: Array) -> String:
	for turn in turns:
		if str(turn.get("role", "")) == "user":
			var t := str(turn.get("text", "")).strip_edges()
			if not t.is_empty():
				return _clip20(t)
	var dt := Time.get_datetime_dict_from_system()
	return "对话 %04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]

static func _clip20(text: String) -> String:
	if text.length() <= 20:
		return text
	return text.substr(0, 20)
```

- [ ] **Step 3: 写 `game/session/conversation_session.gd`**

```gdscript
class_name ConversationSession
extends Node

signal turns_changed(turns: Array)

var _scene_id := ""
var _persona_id := ""
var _started_at := 0
var _turns: Array = []

func begin(scene_id: String, persona_id: String) -> void:
	_scene_id = scene_id
	_persona_id = persona_id
	_started_at = int(Time.get_unix_time_from_system() * 1000.0)
	_turns = []
	turns_changed.emit(_turns)

func append_turn(role: String, text: String) -> void:
	if role != "user" and role != "npc":
		return
	var cleaned := text.strip_edges()
	if cleaned.is_empty():
		return
	_turns.append({
		"role": role,
		"text": cleaned,
		"at": int(Time.get_unix_time_from_system() * 1000.0),
	})
	turns_changed.emit(_turns)

func get_turns() -> Array:
	return _turns.duplicate(true)

func has_non_empty_turns() -> bool:
	return not _turns.is_empty()

func clear() -> void:
	_turns = []
	_scene_id = ""
	_persona_id = ""
	_started_at = 0
	turns_changed.emit(_turns)

func get_scene_id() -> String:
	return _scene_id

func get_persona_id() -> String:
	return _persona_id

func get_started_at() -> int:
	return _started_at
```

- [ ] **Step 4: 验证（编辑器一次性脚本，验证完删除）**

在 `indoor_neutral.gd` 临时 `_ready`：

```gdscript
	var s := ConversationSession.new()
	add_child(s)
	s.begin(SCENE_ID, "cashier_default")
	s.append_turn("user", "Where is the milk?")
	var gen := TitleGenerator.new()
	add_child(gen)
	var title: String = await gen.generate_title(s.get_turns())
	var rec := {
		"id": "debug-save-1",
		"title": title,
		"started_at": s.get_started_at(),
		"ended_at": int(Time.get_unix_time_from_system() * 1000.0),
		"scene_id": s.get_scene_id(),
		"persona_id": s.get_persona_id(),
		"turns": s.get_turns(),
	}
	print(ConversationStore.save_record(rec))
```

F5 后应在 `%APPDATA%\Godot\app_userdata\Immersive English\conversations\debug-save-1.json` 看到英文正文与标题 `Where is the milk?`。然后 **删掉** 这段临时代码。

- [ ] **Step 5: Commit**

```bash
git add game/session/conversation_session.gd game/session/conversation_store.gd game/session/title_generator.gd
git commit -m "feat: save conversation JSON with fallback Chinese or clipped titles"
```

---

### Task 8: 字幕 HUD 与设置项

**Files:**
- Create: `game/ui/subtitle_hud.gd`
- Create: `game/ui/subtitle_hud.tscn`
- Modify: `game/world/indoor_neutral.tscn` — 加入 SubtitleHud CanvasLayer
- Modify: `game/ui/pause_menu` 尚未存在；本 task 在字幕 HUD 上放两个设置控件（打断、字幕位置），写入 `AppConfig`。暂停菜单 Task 9 再收纳这些控件；若已做在 HUD 上，Task 9 把同一套控件移到暂停菜单并删除 HUD 上的设置行。

为避免来回搬，**本 task 就把设置放在暂停菜单场景里一起做完**，字幕 HUD 只渲染时间线。

**Files (revised):**
- Create: `game/ui/subtitle_hud.gd` / `subtitle_hud.tscn`
- Create: `game/ui/pause_menu.gd` / `pause_menu.tscn`（本 task 只做设置 + 继续；「退出场景」在 Task 9 接线）

**Interfaces:**
- Consumes: `AppConfig.get_subtitle_anchor()` / `set_subtitle_anchor`；`ConversationSession.turns_changed`；`VoiceSession` 的 `transcript` 在 Task 12 才接。本 task HUD 提供：
  - `func bind_session(session: ConversationSession) -> void`
  - `func show_live(role: String, text: String) -> void` — 显示未定稿的流式行，不写盘
  - `func clear_live() -> void`
- Produces: 默认贴右上角；`subtitle_anchor == "bottom_center"` 时底中。只渲染最近 8 条 + 可滚动看本段全文。设置写入 `user://settings.cfg`。

- [ ] **Step 1: 写 `game/ui/subtitle_hud.gd`**

```gdscript
extends CanvasLayer

const MAX_VISIBLE := 8

@onready var _panel: PanelContainer = $Root/Panel
@onready var _list: VBoxContainer = $Root/Panel/Margin/Scroll/List
@onready var _live: Label = $Root/Panel/Margin/Scroll/List/LiveLabel

var _session: ConversationSession

func bind_session(session: ConversationSession) -> void:
	if _session != null and _session.turns_changed.is_connected(_on_turns):
		_session.turns_changed.disconnect(_on_turns)
	_session = session
	_session.turns_changed.connect(_on_turns)
	_on_turns(_session.get_turns())
	_apply_anchor()

func show_live(role: String, text: String) -> void:
	var prefix := "You" if role == "user" else "NPC"
	_live.text = "%s: %s" % [prefix, text]
	_live.visible = not text.strip_edges().is_empty()

func clear_live() -> void:
	_live.text = ""
	_live.visible = false

func _ready() -> void:
	_apply_anchor()

func _apply_anchor() -> void:
	var root: Control = $Root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if AppConfig.get_subtitle_anchor() == "bottom_center":
		_panel.anchor_left = 0.2
		_panel.anchor_right = 0.8
		_panel.anchor_top = 0.72
		_panel.anchor_bottom = 0.98
		_panel.offset_left = 0.0
		_panel.offset_top = 0.0
		_panel.offset_right = 0.0
		_panel.offset_bottom = -16.0
	else:
		_panel.anchor_left = 0.62
		_panel.anchor_right = 0.98
		_panel.anchor_top = 0.04
		_panel.anchor_bottom = 0.42
		_panel.offset_left = 0.0
		_panel.offset_top = 0.0
		_panel.offset_right = 0.0
		_panel.offset_bottom = 0.0

func _on_turns(turns: Array) -> void:
	for child in _list.get_children():
		if child != _live:
			child.queue_free()
	var start := maxi(0, turns.size() - MAX_VISIBLE)
	for i in range(start, turns.size()):
		var turn: Dictionary = turns[i]
		var lab := Label.new()
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var prefix := "You" if turn["role"] == "user" else "NPC"
		lab.text = "%s: %s" % [prefix, turn["text"]]
		_list.add_child(lab)
	_list.move_child(_live, _list.get_child_count() - 1)
```

`subtitle_hud.tscn`：`CanvasLayer` → `Root` Control 全屏 → `Panel` PanelContainer → Margin → ScrollContainer（竖滚）→ VBox `List` → 子节点 `LiveLabel`（默认 visible=false）。

- [ ] **Step 2: 写暂停菜单设置**

`pause_menu.gd`：

```gdscript
extends CanvasLayer

signal resume_pressed
signal exit_scene_pressed

@onready var _interrupt: CheckBox = $Center/Panel/VBox/InterruptCheck
@onready var _anchor: OptionButton = $Center/Panel/VBox/AnchorOption

func _ready() -> void:
	visible = false
	_interrupt.text = "允许打断 NPC 说话"
	_interrupt.button_pressed = AppConfig.is_interrupt_enabled()
	_interrupt.toggled.connect(func(v: bool) -> void:
		AppConfig.set_interrupt_enabled(v)
	)
	_anchor.clear()
	_anchor.add_item("字幕：右上角", 0)
	_anchor.add_item("字幕：底部居中", 1)
	_anchor.select(0 if AppConfig.get_subtitle_anchor() == "top_right" else 1)
	_anchor.item_selected.connect(func(index: int) -> void:
		AppConfig.set_subtitle_anchor("top_right" if index == 0 else "bottom_center")
		var hud := get_tree().get_first_node_in_group("subtitle_hud")
		if hud != null and hud.has_method("_apply_anchor"):
			hud._apply_anchor()
	)
	$Center/Panel/VBox/ResumeButton.pressed.connect(func() -> void:
		resume_pressed.emit()
	)
	$Center/Panel/VBox/ExitButton.pressed.connect(func() -> void:
		exit_scene_pressed.emit()
	)

func show_pause() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_pause() -> void:
	visible = false
```

`subtitle_hud.gd` 的 `_ready` 加 `add_to_group("subtitle_hud")`。

暂停菜单 tscn：按钮文案「继续」「退出场景」。Esc 在 Task 9 的 orchestrator 里打开它。

- [ ] **Step 3: 把 SubtitleHud 与 PauseMenu 放进室内场景**

- [ ] **Step 4: 验证**

临时 `bind_session` 并 `append_turn` 两条，字幕出现在右上。暂停里改底部居中，面板移到下方；重启游戏设置仍在。验证完去掉临时 append。

- [ ] **Step 5: Commit**

```bash
git add game/ui/subtitle_hud.gd game/ui/subtitle_hud.tscn game/ui/pause_menu.gd game/ui/pause_menu.tscn game/world/indoor_neutral.tscn
git commit -m "feat: add subtitle HUD and persist interrupt plus caption position"
```

---

### Task 9: 结束编排、历史列表、关窗与退出场景

**Files:**
- Create: `game/session/session_orchestrator.gd`
- Create: `game/autoload/app_lifecycle.gd`
- Create: `game/ui/history_list.gd` / `history_list.tscn`
- Create: `game/ui/history_detail.gd` / `history_detail.tscn`
- Create: `game/ui/status_banner.gd`（本 task 先能显示「未保存」；其它文案 Task 13 用同一组件）
- Modify: `game/project.godot` — Autoload `AppLifecycle`
- Modify: `game/ui/main_menu.tscn` — 「对话历史」按钮
- Modify: `game/world/indoor_neutral.tscn` — 挂 SessionOrchestrator、ConversationSession、TitleGenerator、VoiceSession 占位节点
- Create: `game/voice/voice_session.gd` — 空实现，供编排调用

**Interfaces:**
- Consumes: `TargetLock.target_changed`、`ConversationSession`、`ConversationStore.save_record`、`TitleGenerator.generate_title`、`VoiceSession.start`/`stop`、`IndoorNeutral.SCENE_ID`
- Produces:
  - `VoiceSession`：
    - `signal transcript(role: String, text: String, is_final: bool)`
    - `signal listen_state_changed(is_listening: bool)`
    - `signal talk_state_changed(is_talking: bool)`
    - `signal connection_state_changed(state: String)` — `state` 为 `connecting` `connected` `disconnected` `no_credentials` `no_microphone`
    - `signal playback_stalled()`
    - `func start(persona: PersonaResource) -> void`
    - `func stop() -> void`
    - `func retry() -> void`
    - `func set_interrupt_enabled(enabled: bool) -> void`
  - `SessionOrchestrator`：
    - 结束顺序 **固定**：`voice.stop()` → 若 `has_non_empty_turns()` 则 `await` 标题并 `ConversationStore.save_record` → `session.clear()`。磁盘失败：`StatusBanner.show_message("未保存")` 且保留内存 turns，允许 `retry_save()` 再写一次。
    - 换 NPC：对 previous 走结束顺序，再 `session.begin` + `voice.start(new.persona)`（人设 `is_valid()` 为 false 则不开麦，banner 不伪装在听）
    - 进场景：等 TargetLock 首次锁定后 begin+start
    - 卸载地图 / 暂停「退出场景」/ 关窗：同一套结束逻辑
  - 历史：只读，按 `ended_at` 倒序，点开看标题与全文；不提供编辑删除、不存音频
  - `AppLifecycle`：`get_tree().set_auto_accept_quit(false)`；`NOTIFICATION_WM_CLOSE_REQUEST` 时 `await` 编排结束再 `get_tree().quit()`

没有「仅挂断但仍留在场景」按钮。

- [ ] **Step 1: 写占位 `game/voice/voice_session.gd`**

```gdscript
class_name VoiceSession
extends Node

signal transcript(role: String, text: String, is_final: bool)
signal listen_state_changed(is_listening: bool)
signal talk_state_changed(is_talking: bool)
signal connection_state_changed(state: String)
signal playback_stalled()

var _last_persona: PersonaResource

func start(persona: PersonaResource) -> void:
	_last_persona = persona

func stop() -> void:
	pass

func retry() -> void:
	if _last_persona != null:
		start(_last_persona)

func set_interrupt_enabled(_enabled: bool) -> void:
	pass
```

- [ ] **Step 2: 写 `game/ui/status_banner.gd`**

```gdscript
extends CanvasLayer

@onready var _label: Label = $Root/HBox/Message
@onready var _retry: Button = $Root/HBox/RetryButton

func _ready() -> void:
	add_to_group("status_banner")
	visible = false
	_retry.text = "重试"
	_retry.visible = false

func show_message(text: String, show_retry: bool = false) -> void:
	_label.text = text
	_retry.visible = show_retry
	visible = not text.is_empty()

func hide_banner() -> void:
	visible = false
	_label.text = ""
	_retry.visible = false

func get_retry_button() -> Button:
	return _retry
```

文案常量（后续 task 必须原样使用）：

- 无密钥：`请在本机配置中填写火山引擎凭证（user://credentials.cfg）`
- 断线：`连接断开`
- 无麦：`需要麦克风权限或可用的麦克风设备`
- 未保存：`未保存`

- [ ] **Step 3: 写 `game/session/session_orchestrator.gd`**

生成 UUID：

```gdscript
func _uuid() -> String:
	var c := Crypto.new()
	var b := c.generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var hex := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
```

编排核心（完整文件）：

```gdscript
class_name SessionOrchestrator
extends Node

@export var scene_id: String = "indoor_neutral"

@onready var _lock: TargetLock = get_parent().get_node("TargetLock")
@onready var _session: ConversationSession = get_parent().get_node("ConversationSession")
@onready var _titles: TitleGenerator = get_parent().get_node("TitleGenerator")
@onready var _voice: VoiceSession = get_parent().get_node("VoiceSession")
@onready var _hud: Node = get_parent().get_node("SubtitleHud")
@onready var _pause: Node = get_parent().get_node("PauseMenu")
@onready var _banner: Node = get_parent().get_node("StatusBanner")

var _ending := false
var _last_failed_record: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("session_orchestrator")
	_hud.bind_session(_session)
	_lock.target_changed.connect(_on_target_changed)
	_pause.resume_pressed.connect(func() -> void:
		_pause.hide_pause()
		get_tree().paused = false
	)
	_pause.exit_scene_pressed.connect(_exit_to_menu)
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_banner.get_retry_button().pressed.connect(_retry_save_or_voice)
	if _lock.get_current() != null:
		_start_for(_lock.get_current())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		if _pause.visible:
			_pause.hide_pause()
			get_tree().paused = false
		else:
			get_tree().paused = true
			_pause.show_pause()
		get_viewport().set_input_as_handled()

func end_current_and_save() -> void:
	if _ending:
		return
	_ending = true
	_voice.stop()
	if _session.has_non_empty_turns():
		var title: String = await _titles.generate_title(_session.get_turns())
		var rec := {
			"id": _uuid(),
			"title": title,
			"started_at": _session.get_started_at(),
			"ended_at": int(Time.get_unix_time_from_system() * 1000.0),
			"scene_id": _session.get_scene_id(),
			"persona_id": _session.get_persona_id(),
			"turns": _session.get_turns(),
		}
		var path := ConversationStore.save_record(rec)
		if path.is_empty():
			_last_failed_record = rec
			_banner.show_message("未保存", true)
		else:
			_last_failed_record = {}
	_session.clear()
	_hud.clear_live()
	_ending = false

func retry_save() -> void:
	if _last_failed_record.is_empty():
		return
	var path := ConversationStore.save_record(_last_failed_record)
	if path.is_empty():
		_banner.show_message("未保存", true)
	else:
		_last_failed_record = {}
		_banner.hide_banner()

func _on_target_changed(previous: NpcActor, current: NpcActor) -> void:
	if previous != null:
		await end_current_and_save()
	if current != null:
		_start_for(current)

func _start_for(npc: NpcActor) -> void:
	var persona := npc.get_persona()
	var pid := ""
	if persona != null and persona.is_valid():
		pid = persona.id
	_session.begin(scene_id, pid)
	_hud.bind_session(_session)
	if persona == null or not persona.is_valid():
		GameLog.log_line("persona invalid; not starting voice")
		return
	_voice.set_interrupt_enabled(AppConfig.is_interrupt_enabled())
	_voice.start(persona)

func _exit_to_menu() -> void:
	get_tree().paused = false
	await end_current_and_save()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

func _retry_save_or_voice() -> void:
	if not _last_failed_record.is_empty():
		retry_save()
		return
	_voice.retry()

func _exit_tree() -> void:
	if not _ending:
		end_current_and_save()
```

`_exit_tree` 不能可靠 `await`。关窗走 `AppLifecycle`；切场景前暂停菜单已 `await end_current_and_save()`。`_exit_tree` 改为：若 `_session.has_non_empty_turns()` 仍在，调用 **同步后备标题** `TitleGenerator.fallback_title` 立刻写盘（避免丢档），不要在 `_exit_tree` 里 HTTP。

把 `_exit_tree` 换成：

```gdscript
func _exit_tree() -> void:
	_voice.stop()
	if _session.has_non_empty_turns():
		var rec := {
			"id": _uuid(),
			"title": TitleGenerator.fallback_title(_session.get_turns()),
			"started_at": _session.get_started_at(),
			"ended_at": int(Time.get_unix_time_from_system() * 1000.0),
			"scene_id": _session.get_scene_id(),
			"persona_id": _session.get_persona_id(),
			"turns": _session.get_turns(),
		}
		ConversationStore.save_record(rec)
		_session.clear()
```

暂停「退出场景」与关窗使用带 `await generate_title` 的路径。

- [ ] **Step 4: 写 `game/autoload/app_lifecycle.gd` 并注册 Autoload**

```gdscript
extends Node

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var orch := get_tree().get_first_node_in_group("session_orchestrator")
		if orch != null:
			await orch.end_current_and_save()
		get_tree().quit()
```

`SessionOrchestrator._ready` 已加入 `session_orchestrator` 组与 `PROCESS_MODE_ALWAYS`（否则暂停时 Esc 无法恢复）。

`project.godot` autoload 增加 `AppLifecycle="*res://autoload/app_lifecycle.gd"`。

室内场景节点顺序建议：`TargetLock`、`ConversationSession`、`TitleGenerator`、`VoiceSession`（脚本 `voice_session.gd`）、`SubtitleHud`、`PauseMenu`、`StatusBanner`、`SessionOrchestrator`。`ConversationSession` 与 `TitleGenerator` 用对应脚本。`scene_id` 导出为 `indoor_neutral`。

`VoiceSession` 信号在 orchestrator `_ready` 连接：

```gdscript
	_voice.transcript.connect(func(role: String, text: String, is_final: bool) -> void:
		if is_final:
			_session.append_turn(role, text)
			_hud.clear_live()
		else:
			_hud.show_live(role, text)
	)
	_voice.listen_state_changed.connect(func(on: bool) -> void:
		var npc := _lock.get_current()
		if npc == null:
			return
		npc.set_voice_phase("listen" if on else "idle")
	)
	_voice.talk_state_changed.connect(func(on: bool) -> void:
		var npc := _lock.get_current()
		if npc == null:
			return
		npc.set_voice_phase("talk" if on else "idle")
	)
	_voice.playback_stalled.connect(func() -> void:
		var npc := _lock.get_current()
		if npc != null:
			npc.set_voice_phase("idle")
	)
```

暂停菜单切换打断时同步 `_voice.set_interrupt_enabled(AppConfig.is_interrupt_enabled())`（在 CheckBox 回调后加一行）。

- [ ] **Step 5: 历史 UI**

`history_list.gd`：`ConversationStore.load_all()` 填 `ItemList`（显示 `title` + 本地时间）。点选切到 `history_detail.tscn`，用 `FileAccess` 或静态变量传 id。

用 Autoload 太重。用：

```gdscript
# history_list.gd
func _on_item_selected(index: int) -> void:
	var rec: Dictionary = _records[index]
	HistoryDetail.pending_record = rec
	get_tree().change_scene_to_file("res://ui/history_detail.tscn")
```

`history_detail.gd`：

```gdscript
extends Control

static var pending_record: Dictionary = {}

func _ready() -> void:
	$BackButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://ui/history_list.tscn")
	)
	$TitleLabel.text = str(pending_record.get("title", ""))
	var body := ""
	for turn in pending_record.get("turns", []):
		var prefix := "You" if turn["role"] == "user" else "NPC"
		body += "%s: %s\n\n" % [prefix, turn["text"]]
	$Scroll/Text.text = body
```

主菜单加「对话历史」→ `history_list.tscn`。列表空时显示「暂无对话」。详情只读，无删除按钮。

- [ ] **Step 6: 验证**

1. 用 Task 7 的 debug JSON 或在 orchestrator 临时 `append_turn` 后点「退出场景」，历史里出现该段。
2. 无 turns 退出：`conversations/` 不新增长文件。
3. Esc 暂停，继续后鼠标模式恢复（第一人称应重新捕获）。
4. 双 NPC 场景换目标：应保存上一段（若有文本）。

删掉所有临时 append。

- [ ] **Step 7: Commit**

```bash
git add game/session/session_orchestrator.gd game/autoload/app_lifecycle.gd game/voice/voice_session.gd game/ui/status_banner.gd game/ui/history_list.gd game/ui/history_list.tscn game/ui/history_detail.gd game/ui/history_detail.tscn game/ui/main_menu.tscn game/ui/main_menu.gd game/project.godot game/world/indoor_neutral.tscn game/world/indoor_neutral_two_npcs.tscn
git commit -m "feat: end conversations on retarget, leave map, or quit and show history"
```

---

### Task 10: 豆包全双工二进制协议编解码

**Files:**
- Create: `game/voice/doubao_protocol.gd`

**Interfaces:**
- Consumes: 无
- Produces: `class_name DoubaoProtocol` 静态方法：
  - `const EVENT_START_CONNECTION := 1`
  - `const EVENT_FINISH_CONNECTION := 2`
  - `const EVENT_START_SESSION := 100`
  - `const EVENT_FINISH_SESSION := 102`
  - `const EVENT_TASK_REQUEST := 200`
  - `const EVENT_CLIENT_INTERRUPT := 515`
  - `const EVENT_CONNECTION_STARTED := 50`
  - `const EVENT_CONNECTION_FAILED := 51`
  - `const EVENT_SESSION_STARTED := 150`
  - `const EVENT_SESSION_FAILED := 153`
  - `const EVENT_TTS_SENTENCE_START := 350`
  - `const EVENT_TTS_RESPONSE := 352`
  - `const EVENT_TTS_ENDED := 359`
  - `const EVENT_ASR_INFO := 450`
  - `const EVENT_ASR_RESPONSE := 451`
  - `const EVENT_ASR_ENDED := 459`
  - `const EVENT_CHAT_RESPONSE := 550`
  - `const EVENT_CHAT_ENDED := 559`
  - `const EVENT_DIALOG_ERROR := 599`
  - `static func encode_json_event(event: int, session_id: String, payload: Dictionary) -> PackedByteArray`
  - `static func encode_audio_event(event: int, session_id: String, pcm: PackedByteArray) -> PackedByteArray`
  - `static func decode(frame: PackedByteArray) -> DoubaoFrame`

`class_name DoubaoFrame extends RefCounted` 字段：`event: int`、`session_id: String`、`payload: PackedByteArray`、`msg_type: int`、`error_code: int`、`compression: int`。

帧格式（大端，flag 带 event=`0x04`）：

- byte0 = `0x11`（version=1, header size nibble=1 → 4 字节头）
- byte1 = `(msg_type_high_nibble << 4) | 0x04`；客户端文本 `msg_type=0x1` → byte1=`0x14`；客户端音频 `0x2` → `0x24`
- byte2 = 序列化高 4 位 | 压缩低 4 位；JSON 无压缩 = `0x10`；原始音频无压缩 = `0x00`
- byte3 = `0x00`
- 随后：event int32 BE
- 若 event ∉ {1,2,50,51,52}：uint32 BE 长度 + UTF-8 session_id
- 若 event ∈ {50,51,52}：uint32 BE 长度 + UTF-8 connect_id（解码必须跳过）
- 若 msg_type 为 error（高 4 位 `0xF`）：在 event 之前读 uint32 BE `error_code`
- 最后：uint32 BE payload 长度 + payload
- 若 compression 低 4 位为 `1`，payload 用 `Compression.decompress(..., Compression.MODE_GZIP)`；缓冲大小用 `payload.size() * 16` 与至少 `256` 的较大值，失败则 `GameLog` 并返回空 payload

连接事件 1/2 **不写 session_id**。StartConnection payload 用 `{}`。

已知夹具（验证用）：`encode_json_event(1, "", {})` 的 hex 必须是：

`1114100000000001000000027b7d`

即 `11 14 10 00 | 00 00 00 01 | 00 00 00 02 | 7b 7d`。

- [ ] **Step 1: 写 `game/voice/doubao_protocol.gd` 全文**

```gdscript
class_name DoubaoProtocol
extends RefCounted

const EVENT_START_CONNECTION := 1
const EVENT_FINISH_CONNECTION := 2
const EVENT_START_SESSION := 100
const EVENT_FINISH_SESSION := 102
const EVENT_TASK_REQUEST := 200
const EVENT_CLIENT_INTERRUPT := 515
const EVENT_CONNECTION_STARTED := 50
const EVENT_CONNECTION_FAILED := 51
const EVENT_SESSION_STARTED := 150
const EVENT_SESSION_FAILED := 153
const EVENT_TTS_SENTENCE_START := 350
const EVENT_TTS_RESPONSE := 352
const EVENT_TTS_ENDED := 359
const EVENT_ASR_INFO := 450
const EVENT_ASR_RESPONSE := 451
const EVENT_ASR_ENDED := 459
const EVENT_CHAT_RESPONSE := 550
const EVENT_CHAT_ENDED := 559
const EVENT_DIALOG_ERROR := 599

const MSG_FULL_CLIENT := 0x10
const MSG_AUDIO_CLIENT := 0x20
const MSG_FULL_SERVER := 0x90
const MSG_AUDIO_SERVER := 0xB0
const MSG_ERROR := 0xF0
const FLAG_EVENT := 0x04
const SERIAL_JSON := 0x10
const SERIAL_RAW := 0x00
const COMPRESS_NONE := 0x00
const COMPRESS_GZIP := 0x01

static func encode_json_event(event: int, session_id: String, payload: Dictionary) -> PackedByteArray:
	var body := JSON.stringify(payload)
	if body.is_empty():
		body = "{}"
	return _encode(MSG_FULL_CLIENT, SERIAL_JSON, event, session_id, body.to_utf8_buffer())

static func encode_audio_event(event: int, session_id: String, pcm: PackedByteArray) -> PackedByteArray:
	return _encode(MSG_AUDIO_CLIENT, SERIAL_RAW, event, session_id, pcm)

static func _encode(msg_type: int, serial: int, event: int, session_id: String, payload: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append(0x11)
	out.append(msg_type | FLAG_EVENT)
	out.append(serial | COMPRESS_NONE)
	out.append(0x00)
	_append_u32_be(out, event)
	if event != 1 and event != 2 and event != 50 and event != 51 and event != 52:
		var sid := session_id.to_utf8_buffer()
		_append_u32_be(out, sid.size())
		out.append_array(sid)
	_append_u32_be(out, payload.size())
	out.append_array(payload)
	return out

static func decode(frame: PackedByteArray) -> DoubaoFrame:
	var result := DoubaoFrame.new()
	if frame.size() < 4:
		return result
	var offset := 4 * (frame[0] & 0x0f)
	if offset < 4:
		offset = 4
	result.msg_type = frame[1] & 0xf0
	var flags := frame[1] & 0x0f
	result.compression = frame[2] & 0x0f
	if result.msg_type == MSG_ERROR:
		if frame.size() < offset + 4:
			return result
		result.error_code = _read_u32_be(frame, offset)
		offset += 4
	var has_seq := (flags & 0x01) == 0x01
	if has_seq and (result.msg_type == MSG_AUDIO_CLIENT or result.msg_type == MSG_AUDIO_SERVER):
		offset += 4
	if (flags & FLAG_EVENT) == FLAG_EVENT:
		if frame.size() < offset + 4:
			return result
		result.event = _read_s32_be(frame, offset)
		offset += 4
	if result.event != 1 and result.event != 2 and result.event != 50 and result.event != 51 and result.event != 52:
		if frame.size() < offset + 4:
			return result
		var sid_len := _read_u32_be(frame, offset)
		offset += 4
		if sid_len > 0:
			if frame.size() < offset + sid_len:
				return result
			result.session_id = frame.slice(offset, offset + sid_len).get_string_from_utf8()
			offset += sid_len
	if result.event == 50 or result.event == 51 or result.event == 52:
		if frame.size() < offset + 4:
			return result
		var cid_len := _read_u32_be(frame, offset)
		offset += 4
		offset += cid_len
	if frame.size() < offset + 4:
		return result
	var plen := _read_u32_be(frame, offset)
	offset += 4
	if frame.size() < offset + plen:
		return result
	var raw := frame.slice(offset, offset + plen)
	if result.compression == COMPRESS_GZIP:
		var buf_size: int = maxi(256, raw.size() * 16)
		var dec := Compression.decompress(raw, buf_size, Compression.MODE_GZIP)
		if dec.is_empty():
			GameLog.log_line("gzip payload decompress failed")
			result.payload = PackedByteArray()
		else:
			result.payload = dec
	else:
		result.payload = raw
	return result

static func _append_u32_be(buf: PackedByteArray, value: int) -> void:
	buf.append((value >> 24) & 0xff)
	buf.append((value >> 16) & 0xff)
	buf.append((value >> 8) & 0xff)
	buf.append(value & 0xff)

static func _read_u32_be(buf: PackedByteArray, offset: int) -> int:
	return (buf[offset] << 24) | (buf[offset + 1] << 16) | (buf[offset + 2] << 8) | buf[offset + 3]

static func _read_s32_be(buf: PackedByteArray, offset: int) -> int:
	var u := _read_u32_be(buf, offset)
	if u >= 0x80000000:
		return u - 0x100000000
	return u
```

同文件底部或另建 `game/voice/doubao_frame.gd`：

```gdscript
class_name DoubaoFrame
extends RefCounted

var event: int = -1
var session_id: String = ""
var payload: PackedByteArray = PackedByteArray()
var msg_type: int = 0
var error_code: int = 0
var compression: int = 0

func payload_text() -> String:
	return payload.get_string_from_utf8()
```

- [ ] **Step 2: 用远程调试或临时 print 核夹具**

在任意 `_ready` 临时：

```gdscript
	var hex := DoubaoProtocol.encode_json_event(1, "", {}).hex_encode()
	print(hex)
	assert(hex == "1114100000000001000000027b7d")
```

Expected: 打印该 hex，无 assert。删掉临时代码。

- [ ] **Step 3: Commit**

```bash
git add game/voice/doubao_protocol.gd game/voice/doubao_frame.gd
git commit -m "feat: encode and decode Doubao realtime binary frames"
```

---

### Task 11: DoubaoVoiceSession WebSocket 建连与 StartSession

**Files:**
- Create: `game/voice/doubao_voice_session.gd`
- Modify: `game/world/indoor_neutral.tscn` — 将 `VoiceSession` 节点脚本改为 `doubao_voice_session.gd`（该类 `extends VoiceSession`）
- Modify: `game/world/indoor_neutral_two_npcs.tscn` — 同样改脚本

**Interfaces:**
- Consumes: `DoubaoProtocol`、`AppConfig` 语音字段、`PersonaResource`、`VoiceSession` 信号
- Produces: `class_name DoubaoVoiceSession extends VoiceSession`。`start(persona)`：无凭证则 `connection_state_changed.emit("no_credentials")` 且 **不重连循环**；有凭证则连

`wss://openspeech.bytedance.com/api/v3/realtime/dialogue`

握手头（`WebSocketPeer.handshake_headers`，每条 `"Key: Value"`）：

- `X-Api-App-ID: <app_id>`
- `X-Api-Access-Key: <access_key>`
- `X-Api-Resource-Id: <resource_id>`
- `X-Api-App-Key: <app_key>`
- `X-Api-Connect-Id: <uuid>`

流程：`STATE_OPEN` → 发送 StartConnection → 等到 event 50 → 发送 StartSession（自生成 `session_id` uuid）→ 等到 event 150 → `connection_state_changed.emit("connected")`。

StartSession JSON（Strong Character，**不要**填 `system_role`；人设只放 `character_manifest`）：

```json
{
  "asr": {
    "audio_info": { "format": "pcm", "sample_rate": 16000, "channel": 1 },
    "extra": { "end_smooth_window_ms": 1500 }
  },
  "tts": {
    "speaker": "<persona.voice_id>",
    "audio_config": { "format": "pcm_s16le", "sample_rate": 24000, "channel": 1, "bits": 16 }
  },
  "dialog": {
    "character_manifest": "<persona.character_manifest>",
    "extra": { "model": "<AppConfig.get_realtime_model()>" }
  }
}
```

`stop()`：停麦（Task 12 才有麦，本 task 调空函数）→ 若已 open，发 FinishSession(102) 再 FinishConnection(2) → `close()`。不要在失败时自动重连；`retry()` 才再次 `start(_last_persona)`。

`_process` 里 `peer.poll()`；`get_available_packet_count()` 读二进制包交给 decode。event 51/153/599/`MSG_ERROR`：`GameLog.log_line`（含 error payload 文本），`connection_state_changed.emit("disconnected")`，停播停麦，**不**把错误写入 turns。

- [ ] **Step 1: 写 `game/voice/doubao_voice_session.gd` 的连接部分**

关键骨架（完整实现须含 packet 循环；麦/播放在 Task 12 填 `_mic` `_player` 调用，本 task 先留空函数 `_start_mic()` `_stop_mic()` `_push_pcm(pcm: PackedByteArray)` `_clear_playback()`）：

```gdscript
class_name DoubaoVoiceSession
extends VoiceSession

const WS_URL := "wss://openspeech.bytedance.com/api/v3/realtime/dialogue"

var _peer: WebSocketPeer
var _session_id := ""
var _active_persona: PersonaResource
var _interrupt_enabled := true
var _talking := false
var _want_run := false

func set_interrupt_enabled(enabled: bool) -> void:
	_interrupt_enabled = enabled

func start(persona: PersonaResource) -> void:
	stop()
	_last_persona = persona
	_active_persona = persona
	if not AppConfig.has_voice_credentials():
		connection_state_changed.emit("no_credentials")
		return
	_want_run = true
	_session_id = _make_id()
	_peer = WebSocketPeer.new()
	_peer.handshake_headers = PackedStringArray([
		"X-Api-App-ID: %s" % AppConfig.get_voice_app_id(),
		"X-Api-Access-Key: %s" % AppConfig.get_voice_access_key(),
		"X-Api-Resource-Id: %s" % AppConfig.get_voice_resource_id(),
		"X-Api-App-Key: %s" % AppConfig.get_voice_app_key(),
		"X-Api-Connect-Id: %s" % _make_id(),
	])
	connection_state_changed.emit("connecting")
	var err := _peer.connect_to_url(WS_URL)
	if err != OK:
		GameLog.log_line("ws connect err=%s" % err)
		connection_state_changed.emit("disconnected")
		_want_run = false

func stop() -> void:
	_want_run = false
	_stop_mic()
	_clear_playback()
	_talking = false
	talk_state_changed.emit(false)
	listen_state_changed.emit(false)
	if _peer != null:
		if _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_peer.put_packet(DoubaoProtocol.encode_json_event(DoubaoProtocol.EVENT_FINISH_SESSION, _session_id, {}))
			_peer.put_packet(DoubaoProtocol.encode_json_event(DoubaoProtocol.EVENT_FINISH_CONNECTION, "", {}))
		_peer.close()
	_peer = null

func retry() -> void:
	if _last_persona != null:
		start(_last_persona)

func _process(_delta: float) -> void:
	if _peer == null:
		return
	_peer.poll()
	var state := _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if _handshake_stage == 0:
			_peer.put_packet(DoubaoProtocol.encode_json_event(DoubaoProtocol.EVENT_START_CONNECTION, "", {}))
			_handshake_stage = 1
		while _peer.get_available_packet_count() > 0:
			_handle_frame(_peer.get_packet())
	elif state == WebSocketPeer.STATE_CLOSED and _want_run:
		_want_run = false
		_stop_mic()
		_clear_playback()
		connection_state_changed.emit("disconnected")
		GameLog.log_line("ws closed code=%s" % _peer.get_close_code())

var _handshake_stage := 0

func _handle_frame(bytes: PackedByteArray) -> void:
	var frame := DoubaoProtocol.decode(bytes)
	match frame.event:
		DoubaoProtocol.EVENT_CONNECTION_STARTED:
			var payload := _start_session_payload()
			_peer.put_packet(DoubaoProtocol.encode_json_event(DoubaoProtocol.EVENT_START_SESSION, _session_id, payload))
		DoubaoProtocol.EVENT_SESSION_STARTED:
			connection_state_changed.emit("connected")
			_start_mic()
		DoubaoProtocol.EVENT_CONNECTION_FAILED, DoubaoProtocol.EVENT_SESSION_FAILED, DoubaoProtocol.EVENT_DIALOG_ERROR:
			GameLog.log_line("dialog error event=%s body=%s code=%s" % [frame.event, frame.payload_text(), frame.error_code])
			connection_state_changed.emit("disconnected")
			_stop_mic()
			_clear_playback()
		_:
			_handle_media_event(frame)

func _start_session_payload() -> Dictionary:
	return {
		"asr": {
			"audio_info": {"format": "pcm", "sample_rate": 16000, "channel": 1},
			"extra": {"end_smooth_window_ms": 1500},
		},
		"tts": {
			"speaker": _active_persona.voice_id,
			"audio_config": {"format": "pcm_s16le", "sample_rate": 24000, "channel": 1, "bits": 16},
		},
		"dialog": {
			"character_manifest": _active_persona.character_manifest,
			"extra": {"model": AppConfig.get_realtime_model()},
		},
	}

func _handle_media_event(_frame: DoubaoFrame) -> void:
	pass

func _start_mic() -> void:
	pass

func _stop_mic() -> void:
	pass

func _push_pcm(_pcm: PackedByteArray) -> void:
	pass

func _clear_playback() -> void:
	pass

func _make_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()
```

`start()` 开头把 `_handshake_stage = 0`。error 帧 `frame.msg_type == DoubaoProtocol.MSG_ERROR` 同样记日志并发 `disconnected`。

- [ ] **Step 2: StatusBanner 接 `no_credentials` / `disconnected`**

在 `SessionOrchestrator._ready`：

```gdscript
	_voice.connection_state_changed.connect(func(state: String) -> void:
		match state:
			"no_credentials":
				_banner.show_message("请在本机配置中填写火山引擎凭证（user://credentials.cfg）", false)
			"disconnected":
				_banner.show_message("连接断开", true)
			"connected", "connecting":
				if _last_failed_record.is_empty():
					_banner.hide_banner()
	)
```

无密钥时 **禁止** 用 Timer 自动 `start()`。

- [ ] **Step 3: 验证**

不填密钥进场景：可走、可点选，HUD 出现凭证提示，日志无刷屏。填真实 `app_id`/`access_key` 后进场景：日志出现连接；若 `InvalidSpeaker`，只改 `.tres` 的 `voice_id`。断网应显示「连接断开」+「重试」，点重试走 `retry()`，**同一段** `ConversationSession` 不要 `begin()` 清 turns（`retry` 只重启语音）。

为此：`connection_state_changed == disconnected` 时 orchestrator **不要** `session.clear()`。只有结束条件三条才 save+clear。

- [ ] **Step 4: Commit**

```bash
git add game/voice/doubao_voice_session.gd game/session/session_orchestrator.gd game/world/indoor_neutral.tscn game/world/indoor_neutral_two_npcs.tscn
git commit -m "feat: connect Doubao Strong Character realtime WebSocket on NPC lock"
```

---

### Task 12: 麦克风 PCM、流式播放、字幕事件与打断

**Files:**
- Create: `game/voice/mic_capture.gd`
- Create: `game/voice/pcm_player.gd`
- Modify: `game/voice/doubao_voice_session.gd` — 实现 `_start_mic` `_handle_media_event` 打断
- Modify: `game/world/player.tscn` 或室内场景 — 增加 `AudioStreamPlayer` 名为 `MicInput`（stream=`AudioStreamMicrophone`，bus=`Mic`）以及 `NpcVoice`（stream=`AudioStreamGenerator`，`mix_rate=24000`，`buffer_length=0.3`）

**Interfaces:**
- Consumes: `AudioEffectCapture`（Mic 总线 index 1 的 effect 0）、`DoubaoProtocol.encode_audio_event(200, session_id, pcm)`
- Produces:
  - `MicCapture`：`func start() -> bool` 失败（无输入设备）返回 false；`func stop() -> void`；`signal pcm_ready(pcm: PackedByteArray)` 每包 **640 字节**（16 kHz s16le mono，20ms，320 样本）
  - `PcmPlayer`：`func play_pcm_s16le(pcm: PackedByteArray) -> void`（24 kHz）；`func stop_and_clear() -> void`；`func is_playing_voice() -> bool`
  - 锁定期间持续送麦。用户停顿由服务端 1500ms 窗口判断。
  - ASR：`event 450` 若打断开启 → `stop_and_clear` + 发送 event `515` + `talk_state_changed(false)` + `listen_state_changed(true)`
  - ASR `451`：解析 `results[0].text` 与 `is_interim`；interim → `transcript.emit("user", text, false)`；final → `transcript.emit("user", text, true)`
  - Chat `550`：payload JSON 的 `content` 或 `text` 字段（哪个非空用哪个）→ `transcript.emit("npc", text, false)`；`559` 或 `350` 的最终句 → `transcript.emit("npc", full_or_sentence, true)`。不要把同一句 final 追加两次：以 `550` 流式、`559` 发一次 final 为准；若只有 `350.text` 而无 `550`，则在 `351`/`359` 发 final。
  - TTS `352`：payload 为 PCM，写入 `PcmPlayer`；同时 `talk_state_changed(true)`
  - `359`：本轮 TTS 结束，若播放缓冲耗尽则 `talk_state_changed(false)`
  - 打断 **关闭** 且 `_talking`：不把麦克风 PCM 发给模型（可丢弃包）。打断开启：照常上行。
  - 无麦克风：`connection_state_changed.emit("no_microphone")`，不 `listen_state_changed(true)`
  - 卡顿：`PcmPlayer` 在 talk 期间连续 2 秒 `get_skips()` 增加且收不到 352 → `playback_stalled.emit()`，相位回 idle/listen；打断开启时用户仍可说话

- [ ] **Step 1: 写 `game/voice/mic_capture.gd`**

```gdscript
class_name MicCapture
extends Node

signal pcm_ready(pcm: PackedByteArray)

const TARGET_RATE := 16000
const PACKET_SAMPLES := 320

var _capture: AudioEffectCapture
var _player: AudioStreamPlayer
var _accum := PackedByteArray()
var _running := false
var _phase := 0.0

func start() -> bool:
	if AudioServer.get_input_device_list().is_empty():
		return false
	var bus := AudioServer.get_bus_index("Mic")
	_capture = AudioServer.get_bus_effect(bus, 0)
	_player = get_parent().get_node("MicInput")
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = "Mic"
	_player.playing = true
	_capture.clear_buffer()
	_accum = PackedByteArray()
	_phase = 0.0
	_running = true
	return true

func stop() -> void:
	_running = false
	if _player != null:
		_player.playing = false

func _process(_delta: float) -> void:
	if not _running or _capture == null:
		return
	var frames := _capture.get_frames_available()
	if frames <= 0:
		return
	var buf: PackedVector2Array = _capture.get_buffer(frames)
	var src_rate := int(AudioServer.get_mix_rate())
	_accum.append_array(_resample_to_s16le(buf, src_rate))
	while _accum.size() >= PACKET_SAMPLES * 2:
		var packet := _accum.slice(0, PACKET_SAMPLES * 2)
		_accum = _accum.slice(PACKET_SAMPLES * 2)
		pcm_ready.emit(packet)

func _resample_to_s16le(frames: PackedVector2Array, src_rate: int) -> PackedByteArray:
	var out := PackedByteArray()
	if frames.is_empty():
		return out
	var step := float(src_rate) / float(TARGET_RATE)
	var i := 0.0
	while i < frames.size():
		var idx := int(i)
		if idx >= frames.size():
			idx = frames.size() - 1
		var s: float = (frames[idx].x + frames[idx].y) * 0.5
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		out.append(v & 0xff)
		out.append((v >> 8) & 0xff)
		i += step
	return out
```

把 `MicCapture` 与 `MicInput` 都作为 `DoubaoVoiceSession` 的兄弟或子节点。`start()` 里 `get_parent().get_node("MicInput")` 要求室内根节点有 `MicInput`。改为 `@export` 或 `get_node("../MicInput")`。计划规定：室内根下：

- `MicInput` : `AudioStreamPlayer`
- `NpcVoice` : `AudioStreamPlayer`
- `VoiceSession` 子节点 `MicCapture`、`PcmPlayer`

`MicCapture.start` 用 `get_node("../../MicInput")` 易碎。改成 `MicCapture` 导出：

```gdscript
@export var mic_player_path: NodePath
```

在编辑器指到 `MicInput`。

- [ ] **Step 2: 写 `game/voice/pcm_player.gd`**

```gdscript
class_name PcmPlayer
extends Node

@export var player_path: NodePath

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _active := false

func _ready() -> void:
	_player = get_node(player_path)
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 24000
	gen.buffer_length = 0.3
	_player.stream = gen

func play_pcm_s16le(pcm: PackedByteArray) -> void:
	if not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback()
	_active = true
	var frames := PackedVector2Array()
	var i := 0
	while i + 1 < pcm.size():
		var lo := pcm[i]
		var hi := pcm[i + 1]
		var u := lo | (hi << 8)
		if u >= 32768:
			u -= 65536
		var f := float(u) / 32768.0
		frames.append(Vector2(f, f))
		i += 2
	if _playback != null:
		_playback.push_buffer(frames)

func stop_and_clear() -> void:
	_active = false
	if _playback != null:
		_playback.clear_buffer()
	if _player != null:
		_player.stop()

func is_playing_voice() -> bool:
	return _active and _player != null and _player.playing
```

- [ ] **Step 3: 填 `DoubaoVoiceSession` 媒体路径**

`_start_mic`：

```gdscript
	if not $MicCapture.start():
		connection_state_changed.emit("no_microphone")
		return
	if not $MicCapture.pcm_ready.is_connected(_on_mic_pcm):
		$MicCapture.pcm_ready.connect(_on_mic_pcm)
```

`_on_mic_pcm`：

```gdscript
func _on_mic_pcm(pcm: PackedByteArray) -> void:
	if _peer == null or _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if not _interrupt_enabled and _talking:
		return
	_peer.put_packet(DoubaoProtocol.encode_audio_event(DoubaoProtocol.EVENT_TASK_REQUEST, _session_id, pcm))
```

`_handle_media_event`：

```gdscript
func _handle_media_event(frame: DoubaoFrame) -> void:
	match frame.event:
		DoubaoProtocol.EVENT_ASR_INFO:
			listen_state_changed.emit(true)
			if _interrupt_enabled and _talking:
				$PcmPlayer.stop_and_clear()
				_talking = false
				talk_state_changed.emit(false)
				_peer.put_packet(DoubaoProtocol.encode_json_event(DoubaoProtocol.EVENT_CLIENT_INTERRUPT, _session_id, {}))
		DoubaoProtocol.EVENT_ASR_RESPONSE:
			var parsed: Variant = JSON.parse_string(frame.payload_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				var results: Array = parsed.get("results", [])
				if not results.is_empty():
					var text := str(results[0].get("text", ""))
					var interim := bool(results[0].get("is_interim", true))
					transcript.emit("user", text, not interim)
		DoubaoProtocol.EVENT_ASR_ENDED:
			listen_state_changed.emit(false)
		DoubaoProtocol.EVENT_CHAT_RESPONSE:
			var parsed2: Variant = JSON.parse_string(frame.payload_text())
			var npc_text := ""
			if typeof(parsed2) == TYPE_DICTIONARY:
				npc_text = str(parsed2.get("content", parsed2.get("text", "")))
			transcript.emit("npc", npc_text, false)
		DoubaoProtocol.EVENT_CHAT_ENDED:
			var parsed3: Variant = JSON.parse_string(frame.payload_text())
			var final_text := ""
			if typeof(parsed3) == TYPE_DICTIONARY:
				final_text = str(parsed3.get("content", parsed3.get("text", "")))
			if not final_text.strip_edges().is_empty():
				transcript.emit("npc", final_text, true)
		DoubaoProtocol.EVENT_TTS_RESPONSE:
			_talking = true
			talk_state_changed.emit(true)
			$PcmPlayer.play_pcm_s16le(frame.payload)
			_last_audio_ms = Time.get_ticks_msec()
		DoubaoProtocol.EVENT_TTS_ENDED:
			_talking = false
			talk_state_changed.emit(false)
		_:
			pass
```

在 `_process` 末尾：若 `_talking` 且 `Time.get_ticks_msec() - _last_audio_ms > 2000`：`playback_stalled.emit()`；`_talking=false`；`talk_state_changed(false)`。收到 352 时更新 `_last_audio_ms`。

`SessionOrchestrator` 对 `no_microphone`：

```gdscript
			"no_microphone":
				_banner.show_message("需要麦克风权限或可用的麦克风设备", false)
```

- [ ] **Step 4: 验证**

填密钥，进场景说话。Expected: 右上角先出用户英语转写，再出 NPC 英语字幕并听到声音；NPC 切 listen/talk。默认打断开：NPC 说话时你开口，播放立即停。设置关掉打断：NPC 说话时上行停止，句末再恢复。走路、按 V：不断线。无麦设备：提示文案，NPC 不进入 listen。

- [ ] **Step 5: Commit**

```bash
git add game/voice/mic_capture.gd game/voice/pcm_player.gd game/voice/doubao_voice_session.gd game/world/indoor_neutral.tscn game/world/indoor_neutral_two_npcs.tscn game/session/session_orchestrator.gd
git commit -m "feat: stream mic PCM and NPC audio with default barge-in"
```

---

### Task 13: 方舟标题生成与错误表收口

**Files:**
- Modify: `game/session/title_generator.gd` — `generate_title` 先 HTTP，失败再用 `fallback_title`
- Modify: `game/session/session_orchestrator.gd` — 确认错误文案与重试语义
- Modify: `game/ui/pause_menu.gd` — 打断开关变化时调用当前 `VoiceSession.set_interrupt_enabled`

**Interfaces:**
- Consumes: `AppConfig.get_ark_api_key()` `get_ark_model()` `get_ark_chat_url()`
- Produces: `TitleGenerator.generate_title(turns)`：
  - 缺 `api_key` 或 `model` → 直接后备，不打 HTTP
  - POST JSON：`{"model":"<ark_model>","stream":false,"messages":[{"role":"system","content":"只输出不超过20个汉字的中文标题，不要引号和解释。"},{"role":"user","content":"<turns 格式化>"}]}`
  - Header：`Content-Type: application/json`，`Authorization: Bearer <ark_api_key>`
  - 超时 8 秒（`HTTPRequest.timeout = 8`）或非 200 或解析失败 → 后备
  - 成功：`choices[0].message.content` strip，去掉首尾引号，长度 >20 则 `substr(0,20)`
  - 正文照写：`save_record` 在标题返回之后调用，标题失败只影响 `title` 字段

用户消息格式：

```
user: Where is the milk?
npc: It is in aisle three.
```

- [ ] **Step 1: 改 `generate_title`**

`TitleGenerator` 增加子节点或自身挂 `HTTPRequest`（`title_generator.tscn` 不必单独建，室内场景里 TitleGenerator 节点加 HTTPRequest 子节点名为 `Http`）。

```gdscript
func generate_title(turns: Array) -> String:
	if AppConfig.get_ark_api_key().is_empty() or AppConfig.get_ark_model().is_empty():
		return fallback_title(turns)
	var http := $Http as HTTPRequest
	http.timeout = 8
	var body := JSON.stringify({
		"model": AppConfig.get_ark_model(),
		"stream": false,
		"messages": [
			{"role": "system", "content": "只输出不超过20个汉字的中文标题，不要引号和解释。"},
			{"role": "user", "content": _format_turns(turns)},
		],
	})
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % AppConfig.get_ark_api_key(),
	])
	var err := http.request(AppConfig.get_ark_chat_url(), headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		GameLog.log_line("title http request err=%s" % err)
		return fallback_title(turns)
	var completed: Array = await http.request_completed
	var result: int = completed[0]
	var code: int = completed[1]
	var response_body: PackedByteArray = completed[3]
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		GameLog.log_line("title http failed result=%s code=%s" % [result, code])
		return fallback_title(turns)
	var parsed: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return fallback_title(turns)
	var choices: Array = parsed.get("choices", [])
	if choices.is_empty():
		return fallback_title(turns)
	var content := str(choices[0].get("message", {}).get("content", "")).strip_edges()
	content = content.trim_prefix("“").trim_prefix("\"").trim_suffix("”").trim_suffix("\"")
	if content.is_empty():
		return fallback_title(turns)
	if content.length() > 20:
		content = content.substr(0, 20)
	return content

func _format_turns(turns: Array) -> String:
	var lines: PackedStringArray = []
	for turn in turns:
		lines.append("%s: %s" % [turn["role"], turn["text"]])
	return "\n".join(lines)
```

- [ ] **Step 2: 核对错误表（对照 spec §7，缺的补上）**

| 情况 | 实现落点 |
| 无密钥 | `no_credentials` banner，不自动重连 |
| 连不上/中途断 | 停播停麦，`连接断开`+重试，重试成功同一时间线继续 |
| 无麦 | `no_microphone`，不 listen |
| 音频卡顿 | `playback_stalled` → idle/listen |
| 标题失败 | 后备标题，turns 仍保存 |
| 写盘失败 | `未保存` + 再试一次 `retry_save` |
| 误打断 | 豆包判停；设置可关打断 |

- [ ] **Step 3: 验证**

说两句后退出场景：历史标题为中文且 ≤20 字，正文仍是英语。把 `ark` 段留空再试：标题为首句用户文本截断或 `对话 ...`，正文仍在。把 `conversations` 目录设为只读或把 `save_record` 临时改错路径：出现「未保存」，点重试在恢复权限后成功（或用错误路径验证 banner，再还原代码）。

- [ ] **Step 4: Commit**

```bash
git add game/session/title_generator.gd game/session/session_orchestrator.gd game/ui/pause_menu.gd game/world/indoor_neutral.tscn
git commit -m "feat: generate conversation titles via Ark Chat with fallbacks"
```

---

### Task 14: Windows 导出、README 收口与成功标准核对

**Files:**
- Create: `game/export_presets.cfg`
- Modify: `game/README.md` — 导出步骤、凭证路径、双 NPC 测试场景、成功标准清单
- Modify: 根 `README.md` — 一行指向 `game/README.md`

**Interfaces:**
- Consumes: 全部前序模块
- Produces: 可用 Godot 导出 Windows 桌面包；导出预设 **不包含** 任何密钥。`credentials.cfg.example` 不要放进用户可误当真实密钥的导出附加文件；用户目录运行时再生成。

- [ ] **Step 1: 写 `game/export_presets.cfg`**

在 Godot 编辑器：项目 → 导出 → 添加 Windows Desktop。可执行文件路径 `../build/windows/ImmersiveEnglish.exe`。导出后打开 `export_presets.cfg` 确认没有 `app_id`/`access_key`。`exclude_filter` 设为 `config/credentials.cfg.example` 之外的本机文件即可；example 可以进包（全空字段），方便 README 对照，但运行时仍只读 `user://`。

最小预设字段（Godot 4.3 生成后提交；若手写，用编辑器点一次导出生成再 git add）：

```ini
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
dedicated_server=false
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="../build/windows/ImmersiveEnglish.exe"
```

- [ ] **Step 2: 更新 `game/README.md` 成功标准**

清单必须可勾：

1. Windows 打开导出的 exe 或编辑器 F5
2. 主菜单进入中性室内
3. WASD 走路，V 切换第一/第三人称
4. 进场景自动锁定收银员 NPC
5. 英语语音对话（全双工，默认可打断），字幕实时出现
6. 退出场景或关窗后，历史里有「标题 + 全文」
7. 无密钥时仍能走，HUD 提示填 `user://credentials.cfg`

并写明：超市/教室地图、手机包、纠错老师模式 **不在 v1**。

根 `README.md` 改为：

```markdown
# AI 辅助教育

沉浸式英语口语陪练。Godot 工程在 [`game/`](game/README.md)。

产品设计：`docs/superpowers/specs/2026-08-21-immersive-english-npc-design.md`
```

- [ ] **Step 3: 手工走通成功标准**

用导出 exe（或 F5）按上表走一遍。Expected: 七条全部满足。字幕设置与打断开关重启仍在。换目标测试场景：两段历史两条记录。

- [ ] **Step 4: Commit**

```bash
git add game/export_presets.cfg game/README.md README.md
git commit -m "chore: add Windows export preset and v1 success-criteria runbook"
```

---

## Self-Review

**1. Spec coverage**

| Spec | Task |
|------|------|
| §1 成功标准 | Task 14 清单；链路 4–13 |
| §2.1 范围 | 全程；双 NPC 仅测试场景 Task 6 |
| §2.2 不做 | Task 14 README 写明；未做主题地图/网关/手机/评分 |
| §3 四模块、`game/`、PersonaResource、VoiceSession 接口、user:// 密钥 | Tasks 1–3, 9–11 |
| §4.1 中性室内 | Task 4 |
| §4.2 玩家与鼠标点选 | Tasks 4, 6 |
| §4.3 锁定规则 | Task 6, 9 |
| §4.4 NPC 巡逻/四态/人设字段 | Tasks 3, 5, 12 |
| §5.1 开停连 | Tasks 9, 11 |
| §5.2 全双工、打断、字幕来源 | Task 12 |
| §5.3 PCM 与凭证 | Tasks 2, 12 |
| §6.1 时间线与 HUD 位置 | Tasks 7, 8 |
| §6.2 三项结束与顺序 | Task 9 |
| §6.3 JSON、标题、后备、空会话不写 | Tasks 7, 13 |
| §6.4 只读历史 | Task 9 |
| §7 错误表 | Tasks 9, 11–13 |
| §8 不编写测试 | Global Constraints；每 task 手工验证 |
| §9 以后 | 未实现 |

**2. Placeholder scan:** 无 TBD/TODO/implement later。协议夹具、文案、JSON 字段、事件 ID 均写死。

**3. Type consistency:** `VoiceSession.start(persona: PersonaResource)` / `stop` / `retry` / `set_interrupt_enabled`；`transcript(role, text, is_final)` role 为 `"user"`\|`"npc"`；`ConversationSession.append_turn` 同 role；`get_subtitle_anchor` 仅 `"top_right"`\|`"bottom_center"`；`scene_id` 恒为 `"indoor_neutral"`；`persona_id` 来自资源 `id`；结束顺序 stop → save → clear 在 `SessionOrchestrator.end_current_and_save`。

**Note on `_exit_tree`:** 切场景若已在暂停退出里 await 保存，可能二次保存。实现时在 `end_current_and_save` 用 `_session.has_non_empty_turns()` 短路；clear 后 `_exit_tree` 不再写第二份。
