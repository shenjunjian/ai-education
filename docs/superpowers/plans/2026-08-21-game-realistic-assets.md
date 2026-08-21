# Game Realistic Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用一套可商用室内 glTF 替换 CSG 盒子房间，再用 Mixamo 写实人体替换胶囊/方块人，进场景后仍能走、能锁定 NPC、能开麦说话。

**Architecture:** 世界逻辑不动。`indoor_neutral` 只换房间外观（实例化 `assets/environments/indoor.tscn`，静态三角网格碰撞）；玩家/NPC 根节点仍是带胶囊碰撞的 `CharacterBody3D`，外观挂在 `Visual` 下，四态动画来自同一份 `AnimationLibrary`。`scene_id` 保持 `"indoor_neutral"`。场景过关而人物未过关（或反过来）也算进度：游戏必须仍能启动。

**Tech Stack:** Godot 4.7（工程已是 `Forward Plus`）、GDScript、Sketchfab glTF/GLB、Mixamo FBX（Godot 内置 ufbx，**不用** Mixamo 导入插件）、可选 Poly Haven HDRI。

**Spec:** `docs/superpowers/specs/2026-08-21-game-realistic-assets-design.md`

## Global Constraints

- Godot 4.7 桌面端（Windows）；游戏逻辑用 GDScript；工程在 `game/`。
- 不引入 GUT/WAT 或任何测试框架。每个 task 用 `godot --path game --headless -s res://tools/verify_realistic_assets.gd` 做场景树断言，外加该 task 列出的 F5 手工检查。
- 不改语音、会话、人设 Resource、锁定、字幕、暂停、`scene_id`、玩家 WASD/鼠标/切人称输入。
- 不为换皮新建第二张主菜单入口；`main_menu.gd` 仍进入 `res://world/indoor_neutral.tscn`。
- 不用 Kenney Mini Market、低模/卡通包、Ready Player Me、付费资源站、Mixamo 导入插件（MixaBridge 等一律不准加）。
- 不用照片扫描、口型、面部绑定、导航网格；不用一堆 CC0 小物件自建超市。
- Mixamo 动画必须 Without Skin、Walking 必须 In Place；位移由现有 `move_and_slide` 负责。
- CC-BY 必须写入 `game/assets/ATTRIBUTION.md`。署名漏写不挡画面，但合并前必须补上。
- 模型导入失败或动画名对不上：留下现有胶囊外观，游戏必须能启动。
- 成功标准三项坏了即失败：能走、能锁定 NPC、能开麦说话。

## File Structure

```
game/assets/
  ATTRIBUTION.md                         # CC-BY / Mixamo / HDRI 署名
  environments/
    indoor.glb                           # 或 indoor.gltf + bin + textures/
    indoor.tscn                          # 包装室内：缩放、地板对齐 y=0、静态碰撞
    small_empty_room_1_2k.hdr            # 仅当室内灯光不够时才加入
  characters/
    player.fbx                           # Mixamo 顾客，With Skin，T-pose
    npc.fbx                              # Mixamo 收银员气质，With Skin，T-pose
  animations/
    idle.fbx                             # Without Skin
    walk.fbx                             # Without Skin + In Place
    listen.fbx                           # 另一条站立 Idle，Without Skin
    talk.fbx                             # Without Skin
    humanoid_locomotion.tres             # 共用 AnimationLibrary：idle/walk/listen/talk
game/tools/
  verify_realistic_assets.gd             # headless SceneTree 断言（extends SceneTree）
  bake_indoor_collision.gd               # EditorScript：给室内所有 Mesh 生成 trimesh
  build_humanoid_library.gd              # EditorScript：四条 FBX → 一份 AnimationLibrary
game/world/
  indoor_neutral.tscn                    # 删 CSG Floor/Wall*，实例化 Indoor
  indoor_neutral_two_npcs.tscn           # 同一套 Indoor，禁止第二套皮
  npc.tscn                               # Visual 下挂 Mixamo NPC；AnimationPlayer 共用库
  npc.gd                                 # 只加 has_animation 防护；四态语义不变
  player.tscn                            # BodyMesh → Visual + Mixamo；保留 Head/SpringArm
  player.gd                              # 第三人称显示 Visual 并播 idle/walk
game/README.md                           # 更新视觉验收，删掉「不做主题地图」
```

不新建主菜单场景。不改 `game/voice/`、`game/session/`、`game/interaction/`、`game/data/`。

两个 EditorScript 只在 Godot 编辑器里用 **文件 → 运行**（或当前脚本打开时 Ctrl+Shift+X）执行，不要加 Autoload，不要在游戏运行时执行。

---

### Task 1: 资源目录、署名模板、headless 校验脚本

**Files:**
- Create: `game/assets/ATTRIBUTION.md`
- Create: `game/assets/environments/.gitkeep`
- Create: `game/assets/characters/.gitkeep`
- Create: `game/assets/animations/.gitkeep`
- Create: `game/tools/verify_realistic_assets.gd`

**Interfaces:**
- Consumes: 现有 `game/world/indoor_neutral.tscn`、`game/world/indoor_neutral_two_npcs.tscn`、`game/world/npc.tscn`、`game/world/player.tscn`、`game/world/indoor_neutral.gd` 的 `SCENE_ID := "indoor_neutral"`、`game/ui/main_menu.gd` 的 `change_scene_to_file("res://world/indoor_neutral.tscn")`
- Produces: `verify_realistic_assets.gd` 以退出码 0/1 报告；Task 1 只启用 `check_scaffold()` 与 `check_logic_untouched()`。后续 task 往同一脚本加 check 函数，不要另开测试框架。

- [ ] **Step 1: 写 `game/assets/ATTRIBUTION.md`**

```markdown
# Asset Attribution

Third-party 3D assets used by Immersive English. Do not add assets whose license forbids use in a game (Sketchfab Standard, View-only, CC BY-NC).

## Environments

| Work | Author | License | Source |
|------|--------|---------|--------|
| (pending) | | | |

## Characters and animations

| Work | Author | License | Source |
|------|--------|---------|--------|
| (pending) | Mixamo / Adobe | Mixamo terms | https://www.mixamo.com/ |

## HDRI

| Work | Author | License | Source |
|------|--------|---------|--------|
| (unused until lighting requires it) | Poly Haven | CC0 | |
```

- [ ] **Step 2: 写 `game/tools/verify_realistic_assets.gd`**

这是 `extends SceneTree` 的 headless 入口，**不要** `extends Node`。用 `instantiate()` 但不 `add_child`，这样不会跑 `_ready()`，也就不会连豆包。

```gdscript
extends SceneTree

func _init() -> void:
	var errors: PackedStringArray = PackedStringArray()
	_check_scaffold(errors)
	_check_logic_untouched(errors)
	if errors.is_empty():
		print("VERIFY_OK")
		quit(0)
	else:
		for e in errors:
			push_error(e)
			print(e)
		print("VERIFY_FAIL count=%d" % errors.size())
		quit(1)


func _err(errors: PackedStringArray, msg: String) -> void:
	errors.append(msg)


func _check_scaffold(errors: PackedStringArray) -> void:
	var required := PackedStringArray([
		"res://assets/ATTRIBUTION.md",
		"res://assets/environments",
		"res://assets/characters",
		"res://assets/animations",
	])
	for p in required:
		if not (FileAccess.file_exists(p) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(p))):
			_err(errors, "missing " + p)
	var attr := FileAccess.get_file_as_string("res://assets/ATTRIBUTION.md")
	for heading in ["## Environments", "## Characters and animations", "## HDRI"]:
		if attr.find(heading) < 0:
			_err(errors, "ATTRIBUTION.md missing heading " + heading)


func _check_logic_untouched(errors: PackedStringArray) -> void:
	var indoor := _instantiate("res://world/indoor_neutral.tscn", errors)
	var two := _instantiate("res://world/indoor_neutral_two_npcs.tscn", errors)
	var npc := _instantiate("res://world/npc.tscn", errors)
	var player := _instantiate("res://world/player.tscn", errors)
	if indoor == null or two == null or npc == null or player == null:
		return
	_expect_children(indoor, errors, PackedStringArray([
		"WorldEnvironment", "Sun", "Player", "CashierNpc", "TargetLock",
		"VoiceSession", "SessionOrchestrator", "SubtitleHud", "PauseMenu",
	]))
	_expect_children(two, errors, PackedStringArray([
		"WorldEnvironment", "Sun", "Player", "CashierNpc", "StockClerkNpc",
		"TargetLock", "VoiceSession", "SessionOrchestrator",
	]))
	var orch: Node = indoor.get_node("SessionOrchestrator")
	if orch.get("scene_id") != "indoor_neutral":
		_err(errors, "indoor_neutral SessionOrchestrator.scene_id changed")
	var orch2: Node = two.get_node("SessionOrchestrator")
	if orch2.get("scene_id") != "indoor_neutral":
		_err(errors, "two_npcs SessionOrchestrator.scene_id changed")
	if npc.collision_layer != 2:
		_err(errors, "npc collision_layer must stay 2")
	if npc.get_node_or_null("CollisionShape3D") == null or npc.get_node_or_null("Visual") == null or npc.get_node_or_null("AnimationPlayer") == null:
		_err(errors, "npc must keep CollisionShape3D, Visual, AnimationPlayer")
	if player.get_node_or_null("Head/FirstPersonCamera") == null or player.get_node_or_null("SpringArm/ThirdPersonCamera") == null:
		_err(errors, "player cameras missing")
	var menu := FileAccess.get_file_as_string("res://ui/main_menu.gd")
	if menu.find("res://world/indoor_neutral.tscn") < 0:
		_err(errors, "main_menu no longer enters indoor_neutral.tscn")
	var world_script := FileAccess.get_file_as_string("res://world/indoor_neutral.gd")
	if world_script.find("indoor_neutral") < 0:
		_err(errors, "indoor_neutral.gd SCENE_ID changed")
	indoor.free()
	two.free()
	npc.free()
	player.free()


func _instantiate(path: String, errors: PackedStringArray) -> Node:
	if not ResourceLoader.exists(path):
		_err(errors, "cannot load " + path)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		_err(errors, "not a PackedScene: " + path)
		return null
	return packed.instantiate()


func _expect_children(root: Node, errors: PackedStringArray, names: PackedStringArray) -> void:
	for n in names:
		if root.get_node_or_null(NodePath(n)) == null:
			_err(errors, "%s missing child %s" % [root.name, n])
```

- [ ] **Step 3: 跑校验，确认通过**

在仓库根：

```powershell
godot --path game --headless -s res://tools/verify_realistic_assets.gd
```

Expected: 打印 `VERIFY_OK`，退出码 0。若 `godot` 不在 PATH，用 Godot 4.7 可执行文件绝对路径替换 `godot`。

- [ ] **Step 4: Commit**

```powershell
git add game/assets/ATTRIBUTION.md game/assets/environments/.gitkeep game/assets/characters/.gitkeep game/assets/animations/.gitkeep game/tools/verify_realistic_assets.gd
git commit -m "chore: add realistic-asset folders and headless scene checks"
```

---

### Task 2: 按否决标准下载室内 glTF 并写入署名

**Files:**
- Create: `game/assets/environments/indoor.glb` **或** `game/assets/environments/indoor.gltf`（外加同目录 `*.bin` 与 `textures/`，保持 Sketchfab 相对路径）
- Modify: `game/assets/ATTRIBUTION.md`（Environments 表）
- Modify: `game/tools/verify_realistic_assets.gd`（增加 `_check_indoor_file`）

**Interfaces:**
- Consumes: Task 1 目录；spec §4.1 搜索顺序与四关
- Produces: 固定入口路径 `res://assets/environments/indoor.glb` 或 `res://assets/environments/indoor.gltf`（二选一，校验脚本两者都认）；禁止 Kenney / low poly / stylized / voxel / CC BY-NC / Sketchfab Standard

本 task **不改** `indoor_neutral.tscn`。胶囊人继续走 CSG 房间。

- [ ] **Step 1: 把室内文件检查加进校验（此时应失败）**

在 `verify_realistic_assets.gd` 的 `_init` 里，`_check_logic_untouched` 之后调用 `_check_indoor_file(errors)`。追加：

```gdscript
func _indoor_source_path() -> String:
	if FileAccess.file_exists("res://assets/environments/indoor.glb"):
		return "res://assets/environments/indoor.glb"
	if FileAccess.file_exists("res://assets/environments/indoor.gltf"):
		return "res://assets/environments/indoor.gltf"
	return ""


func _check_indoor_file(errors: PackedStringArray) -> void:
	var p := _indoor_source_path()
	if p == "":
		_err(errors, "missing indoor.glb or indoor.gltf")
		return
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null or f.get_length() < 1024:
		_err(errors, "indoor file too small or unreadable")
		return
	f.close()
	var attr := FileAccess.get_file_as_string("res://assets/ATTRIBUTION.md")
	if attr.find("sketchfab.com") < 0 and attr.find("polyhaven.com") < 0:
		_err(errors, "ATTRIBUTION.md Environments row must include a source URL")
	if attr.find("(pending)") >= 0 and attr.find("## Environments") >= 0:
		var env_section := attr.substr(attr.find("## Environments"), 400)
		if env_section.find("(pending)") >= 0:
			_err(errors, "ATTRIBUTION.md Environments still pending")
```

- [ ] **Step 2: 跑校验，确认失败**

```powershell
godot --path game --headless -s res://tools/verify_realistic_assets.gd
```

Expected: 打印 `missing indoor.glb or indoor.gltf`，退出码 1。

- [ ] **Step 3: 按关键词顺序在 Sketchfab 搜索**

浏览器打开 Sketchfab，必须同时打开这些过滤器：**Downloadable**、许可证 **CC0 或 CC Attribution**（不要 CC BY-NC）、格式能下到 **glTF / GLB**。

关键词顺序（前一个全军覆没才换下一个）：

1. `convenience store`
2. `grocery store`
3. `supermarket interior`
4. `mini mart`
5. `cafe interior`
6. `shop interior`
7. `office interior`

搜索入口（先用第 1 个词）：[Sketchfab downloadable search](https://sketchfab.com/search?type=models&features=downloadable&q=convenience%20store)

打开每个候选页面后，**四关都过才下载**：

1. **能走**：连续地板 + 可绕行走道。柜台特写、外立面、只有货架散件的 → 否决。
2. **比例**：门口或柜台大约能站下一个 1.8m 的人（相对货架/门框目测）。
3. **体量**：优先几十万三角以内。上百万仅当本关键词及更早关键词没有更轻的写实替代。
4. **许可证**：CC0 或 CC Attribution。View-only、Sketchfab Standard、Unity/Unreal 工程包、标注 low poly / stylized / voxel、Kenney Mini Market → 否决。CC BY-NC 否决（不能放进游戏）。

第一个应打开核对的便利店候选（CC Attribution，完整室内，1.3M 三角，只有在同序搜索找不到更轻写实室内时才用）：

https://sketchfab.com/3d-models/convenience-store-scene-4412572fdd664fa08e07d4b9f6ce67a1

作者 Katydid，许可证必须仍显示 **CC Attribution** 才准用。若页面改成 NC / Standard / 不能下载，丢掉它，继续搜。

- [ ] **Step 4: 下载 glTF 并放进固定路径**

登录 Sketchfab → Download → 选 **glTF**。解压 zip。

- 若得到单个 `.glb`：复制为 `game/assets/environments/indoor.glb`。
- 若得到 `scene.gltf` + `scene.bin` + `textures/`：把 `scene.gltf` 重命名为 `indoor.gltf`，`scene.bin` 若 gltf 内部引用了该文件名则 **不要改 bin 文件名**（改 gltf 文件名后打开 `indoor.gltf` 文本，确认 `"uri"` 仍指向现有 bin 与 `textures/...`）。最终目录示例：

```
game/assets/environments/indoor.gltf
game/assets/environments/scene.bin
game/assets/environments/textures/...
```

不要把贴图挪到别的目录。单文件体积若超过 90MB、GitHub 可能拒绝时，改选更轻的下一个合格候选，不要上 Git LFS（本仓库没有 LFS）。

- [ ] **Step 5: 填写 Environments 署名行**

把 `ATTRIBUTION.md` 的 Environments 表 `(pending)` 换成真实一行。例子（仅当实际用了 Katydid 那套时照抄；用了别的模型就改成那一页上的作品名、作者、许可证、URL）：

```markdown
| convenience-store scene | Katydid | CC BY 4.0 | https://sketchfab.com/3d-models/convenience-store-scene-4412572fdd664fa08e07d4b9f6ce67a1 |
```

- [ ] **Step 6: 再跑校验，确认通过**

```powershell
godot --path game --headless -s res://tools/verify_realistic_assets.gd
```

Expected: `VERIFY_OK`，退出码 0。

- [ ] **Step 7: Commit**

把室内模型、贴图、`.import`（若 Godot 已生成）和署名一起提交：

```powershell
git add game/assets/environments game/assets/ATTRIBUTION.md game/tools/verify_realistic_assets.gd
git commit -m "feat: add licensed indoor glTF for realistic scene swap"
```

---

### Task 3: 室内接入 CSG 房间、静态碰撞、重标出生点

**Files:**
- Create: `game/tools/bake_indoor_collision.gd`
- Create: `game/assets/environments/indoor.tscn`
- Modify: `game/world/indoor_neutral.tscn`（删除 `Floor`/`WallN`/`WallS`/`WallW`/`WallE` 及 `StandardMaterial3D_floor`；实例化 Indoor）
- Modify: `game/world/indoor_neutral_two_npcs.tscn`（同一套 Indoor，禁止第二套皮）
- Modify: `game/tools/verify_realistic_assets.gd`（增加 `_check_csg_removed`）
- Optional create: `game/assets/environments/small_empty_room_1_2k.hdr`

**Interfaces:**
- Consumes: `_indoor_source_path()` 指向的 glTF；现有 `Player`/`CashierNpc` 胶囊碰撞；`WorldEnvironment` 与 `Sun` 节点名不变
- Produces: `res://assets/environments/indoor.tscn` 根节点名 `Indoor`（`Node3D`）；其下网格带 `StaticBody3D` + trimesh；走道地板对齐世界 `y=0`；两张世界场景都 `instance=ExtResource` 该 tscn。逻辑节点名单与 Task 1 相同。

- [ ] **Step 1: 先写失败的房间断言**

在 `_init` 里 `_check_indoor_file` 之后调用 `_check_csg_removed(errors)`：

```gdscript
func _check_csg_removed(errors: PackedStringArray) -> void:
	if not ResourceLoader.exists("res://assets/environments/indoor.tscn"):
		_err(errors, "missing res://assets/environments/indoor.tscn")
		return
	for scene_path in ["res://world/indoor_neutral.tscn", "res://world/indoor_neutral_two_npcs.tscn"]:
		var root := _instantiate(scene_path, errors)
		if root == null:
			continue
		for banned in ["Floor", "WallN", "WallS", "WallW", "WallE"]:
			if root.get_node_or_null(NodePath(banned)) != null:
				_err(errors, "%s still has CSG node %s" % [scene_path, banned])
		var indoor := root.get_node_or_null("Indoor")
		if indoor == null:
			_err(errors, "%s missing Indoor instance" % scene_path)
		elif indoor.scene_file_path != "res://assets/environments/indoor.tscn":
			_err(errors, "%s Indoor must instance indoor.tscn, got %s" % [scene_path, indoor.scene_file_path])
		var has_static := false
		for n in indoor.find_children("*", "StaticBody3D", true, false):
			has_static = true
			break
		if not has_static:
			_err(errors, "Indoor has no StaticBody3D collision")
		root.free()
```

- [ ] **Step 2: 跑校验，确认失败**

```powershell
godot --path game --headless -s res://tools/verify_realistic_assets.gd
```

Expected: `missing res://assets/environments/indoor.tscn` 或 `still has CSG node Floor`，退出码 1。

- [ ] **Step 3: 用编辑器导入室内并量比例**

1. 用 Godot 4.7 打开 `game/`，等 `indoor.glb`/`indoor.gltf` 导入结束。
2. 新建空场景 `Node3D`，把导入的室内拖进去。
3. 再拖一个 `MeshInstance3D`，Mesh 用 `CapsuleMesh`，`radius=0.35`，`height=1.8`，放在走道上。
4. 调整室内根节点 `scale` / `position` / `rotation`，直到：胶囊脚在地板上（不要陷进去、不要飘）、门或柜台高度看起来像给 1.8m 的人用的。
5. 把这组 Transform 记下来，后面写进 `indoor.tscn` 的 `Model` 节点。Godot 默认 `-Z` 为前方，不要为了「好看」去改玩家脚本。

若角色相对房间巨大或只有蚂蚁大：选中 glTF → 导入坞 → `Root Scale` 改成 `0.01` 或 `100`（只改这一侧），点 **重新导入**，再量一次胶囊。

- [ ] **Step 4: 写碰撞烘焙 EditorScript**

`game/tools/bake_indoor_collision.gd`：

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var src := ""
	if FileAccess.file_exists("res://assets/environments/indoor.glb"):
		src = "res://assets/environments/indoor.glb"
	elif FileAccess.file_exists("res://assets/environments/indoor.gltf"):
		src = "res://assets/environments/indoor.gltf"
	else:
		push_error("no indoor.glb/gltf")
		return
	var packed := load(src) as PackedScene
	var model := packed.instantiate() as Node
	_bake(model)
	var root := Node3D.new()
	root.name = "Indoor"
	root.add_child(model)
	model.owner = root
	_set_owner_recursive(model, root)
	# 把 Step 3 量到的 transform 填在这里。下面这组是「地板已在 y=0、无需缩放」的初值；
	# 若你在编辑器里改过 Model，以编辑器 Inspector 里的 position/rotation/scale 为准覆盖这三行。
	model.name = "Model"
	model.position = Vector3.ZERO
	model.rotation_degrees = Vector3.ZERO
	model.scale = Vector3.ONE
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		push_error("pack failed: %s" % err)
		root.free()
		return
	err = ResourceSaver.save(scene, "res://assets/environments/indoor.tscn")
	if err != OK:
		push_error("save indoor.tscn failed: %s" % err)
	else:
		print("Wrote res://assets/environments/indoor.tscn")
	root.free()


func _bake(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null and mi.find_child("StaticBody3D", false, false) == null:
			mi.create_trimesh_collision()
	for c in n.get_children():
		_bake(c)


func _set_owner_recursive(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		_set_owner_recursive(c, owner)
```

在 Godot 中打开该脚本 → **文件 → 运行**（Ctrl+Shift+X）。输出应有 `Wrote res://assets/environments/indoor.tscn`。

打开 `indoor.tscn`，确认走道地板大约在 `y=0`。若不是，只改 `Model` 的 `position.y`（或 scale），再保存。不要把旧 CSG `Floor` 留作隐形碰撞。

- [ ] **Step 5: 改 `indoor_neutral.tscn`：删 CSG，实例化 Indoor**

在文件头 `ext_resource` 列表末尾增加（id 用文件里还没占用的下一个数字；下面假设现有最大是 15，用 16）：

```
[ext_resource type="PackedScene" path="res://assets/environments/indoor.tscn" id="16"]
```

删除整个 `StandardMaterial3D_floor` subresource。

删除这五个节点整块：`Floor`、`WallN`、`WallS`、`WallW`、`WallE`。

在 `Sun` 节点之后、`Player` 之前插入：

```
[node name="Indoor" parent="." instance=ExtResource("16")]
```

**保留** `WorldEnvironment`、`Sun`、`Player`、`CashierNpc` 以及全部逻辑子节点（TargetLock、VoiceSession、HUD、SessionOrchestrator 等）。`scene_id = "indoor_neutral"` 一行不准改。

把 `load_steps` 改成与 `ext_resource` + `sub_resource` 实际数量一致。

- [ ] **Step 6: 同样改 `indoor_neutral_two_npcs.tscn`**

删除同一套 CSG 与地板材质。实例化 **同一个** `res://assets/environments/indoor.tscn`。保留 `StockClerkNpc`。不要做第二套室内皮。

- [ ] **Step 7: 按新走道重标出生点与巡逻点**

F5 从主菜单进场景（或编辑器直接运行 `indoor_neutral.tscn`）。

1. 若一出生就掉进虚空：Indoor 地板低于胶囊。把 `indoor.tscn` 里 `Model.position.y` 上移，或把 Player/NPC 的 `transform` 的 y 改到脚刚贴地（通常 `y` 在 `0.0`～`0.15`）。
2. 若卡在货架里：在编辑器里把 `Player` 拖到一条开阔走道。Inspector 复制它的 `Transform`。
3. 把 `CashierNpc` 放在同一条走道、距离玩家大约 3～6m 的地方。
4. `CashierNpc` 的 `patrol_points` 填三个 **同一高度、间距 ≥ 2m、线段不穿货架** 的点。y 与 NPC 当前 `transform.origin.y` 相同。格式保持：

```
patrol_points = Array[Vector3]([Vector3(x0, y, z0), Vector3(x1, y, z1), Vector3(x2, y, z2)])
```

5. `indoor_neutral_two_npcs.tscn` 的 Player / CashierNpc / patrol_points 必须与主场景同一组数字。`StockClerkNpc` 放到另一处走道空地，不要叠进收银员巡逻线。

不要改 `npc.gd` 的巡逻算法。

- [ ] **Step 8: 灯光不够则加 Poly Haven HDRI（够亮就跳过本步）**

F5 第三人称看室内。若全黑或灰成一团，下载 Poly Haven **Small Empty Room 1** 的 2K HDR：

https://polyhaven.com/a/small_empty_room_1

存为 `game/assets/environments/small_empty_room_1_2k.hdr`（CC0）。在 `ATTRIBUTION.md` 的 HDRI 表写成：

```markdown
| Small Empty Room 1 | Poly Haven | CC0 | https://polyhaven.com/a/small_empty_room_1 |
```

两张世界场景里，把 `Environment_indoor` 改成天空（不要删 `WorldEnvironment` 节点）：

```
[sub_resource type="PanoramaSkyMaterial" id="PanoramaSkyMaterial_indoor"]
panorama = ExtResource("hdr")

[sub_resource type="Sky" id="Sky_indoor"]
sky_material = SubResource("PanoramaSkyMaterial_indoor")

[sub_resource type="Environment" id="Environment_indoor"]
background_mode = 2
sky = SubResource("Sky_indoor")
ambient_light_source = 2
ambient_light_color = Color(0.85, 0.85, 0.88, 1)
ambient_light_energy = 0.7
```

`ext_resource` 增加：

```
[ext_resource type="Texture2D" path="res://assets/environments/small_empty_room_1_2k.hdr" id="hdr"]
```

id 换成文件中未占用的数字。`Sun` 保留。不要改玩法脚本。

- [ ] **Step 9: 跑校验，确认通过**

```powershell
godot --path game --headless -s res://tools/verify_realistic_assets.gd
godot --path game --quit-after 1
```

Expected: 先 `VERIFY_OK`；后一命令能打开工程并退出码 0。

- [ ] **Step 10: 手工验收（胶囊人 + 真室内）**

F5 → 主菜单进入场景：

1. 房间不再是纯色盒子。
2. WASD 能从出生点走到 NPC 附近，不陷地、不飞天、不穿过货架（撞上货架停下是对的）。
3. 进场景仍自动锁定收银员；左键点选仍有效。
4. 若已填密钥：开麦说话仍通（本步不改语音）。无密钥时仍能走，HUD 提示填凭证。

人物此时仍是胶囊，这是 spec 允许的中间态。

- [ ] **Step 11: Commit**

```powershell
git add game/tools/bake_indoor_collision.gd game/tools/verify_realistic_assets.gd game/assets/environments game/assets/ATTRIBUTION.md game/world/indoor_neutral.tscn game/world/indoor_neutral_two_npcs.tscn
git commit -m "feat: replace CSG room with colliding indoor glTF"
```

---

### Task 4: 下载两个 Mixamo 写实角色和四条无 Skin 动画

**Files:**
- Create: `game/assets/characters/player.fbx`
- Create: `game/assets/characters/npc.fbx`
- Create: `game/assets/animations/idle.fbx`
- Create: `game/assets/animations/walk.fbx`
- Create: `game/assets/animations/listen.fbx`
- Create: `game/assets/animations/talk.fbx`
- Modify: `game/assets/ATTRIBUTION.md`（Characters 表）
- Modify: `game/tools/verify_realistic_assets.gd`（增加 `_check_mixamo_files`）

**Interfaces:**
- Consumes: Mixamo 网页（需 Adobe 登录）；两个角色必须都是 Mixamo 自动骨骼，才能共用 AnimationLibrary
- Produces: 上述六个 **固定文件名**。动画全部 Without Skin。`walk.fbx` 必须 In Place。不要带口型/面部动画包。

若 Mixamo 登录或下载失败：不要删 Task 3 的室内；跳过 Task 5–6，直接做 Task 7 的房间-only 验收。胶囊人留下算进度。

- [ ] **Step 1: 先写失败的文件断言**

`_init` 在 `_check_csg_removed` 之后调用 `_check_mixamo_files(errors)`：

```gdscript
func _check_mixamo_files(errors: PackedStringArray) -> void:
	var files := PackedStringArray([
		"res://assets/characters/player.fbx",
		"res://assets/characters/npc.fbx",
		"res://assets/animations/idle.fbx",
		"res://assets/animations/walk.fbx",
		"res://assets/animations/listen.fbx",
		"res://assets/animations/talk.fbx",
	])
	for p in files:
		if not FileAccess.file_exists(p):
			_err(errors, "missing " + p)
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null or f.get_length() < 1024:
			_err(errors, "too small: " + p)
		else:
			f.close()
	var attr := FileAccess.get_file_as_string("res://assets/ATTRIBUTION.md")
	if attr.find("mixamo.com") < 0:
		_err(errors, "ATTRIBUTION.md must cite mixamo.com")
```

- [ ] **Step 2: 跑校验，确认失败**

```powershell
godot --path game --headless -s res://tools/verify_realistic_assets.gd
```

Expected: `missing res://assets/characters/player.fbx`（或其它缺失 FBX），退出码 1。

- [ ] **Step 3: 下载两个写实角色（With Skin，T-pose）**

打开 https://www.mixamo.com/ → 登录 → **Characters**。

否决：Y Bot、X Bot、Mousey、任何 robot / cartoon / stylized / mutant / ninja / paladin / vampire。

指定选择（角色被下架则用括号里的备选，仍要写实、服装能区分玩家/店员）：

1. NPC（收银员气质）：搜 **Jasper**（夹克成人）。没有则搜 **Leonard**，再没有则搜 `business`，取第一个写实、有领衬衫或外套的成人。
2. 玩家（顾客）：搜 **Liam**。没有则 **James**。必须和 NPC **不是**同一个角色。

每个角色 Download：

- Format: **FBX for Unity (.fbx)**
- Pose: **T-pose**
- Skin: **With Skin**

下载后立刻改名：

- 收银员 → `game/assets/characters/npc.fbx`
- 顾客 → `game/assets/characters/player.fbx`

- [ ] **Step 4: 下载四条动画（Without Skin）**

切到 Mixamo **Animations**。预览可以停在 NPC 角色上，这样能看出姿势，但导出必须 Without Skin。

| 目标文件 | Mixamo 搜索 | 选取 | Download |
|----------|-------------|------|----------|
| `idle.fbx` | `Idle` | 就叫 **Idle** 的站立（不要跳舞） | FBX for Unity，Skin = **Without Skin**，30 fps |
| `walk.fbx` | `Walking` | **Walking** | 同上，并且勾上 **In Place** |
| `talk.fbx` | `Talking` | **Talking** | Without Skin；不要口型包 |
| `listen.fbx` | `Standing Idle` | **Standing Idle**；没有则 **Happy Idle** | Without Skin；姿势必须能和 Idle 分开 |

全部放到 `game/assets/animations/` 下，文件名必须是上表左列。Mixamo 默认名类似 `Jasper@Walking.fbx`，下载后马上改名。

Walking **没勾 In Place** 就删掉重下，不要用根骨骼位移走路。

- [ ] **Step 5: 填写 Characters 署名**

```markdown
| Jasper (NPC mesh) | Mixamo / Adobe | Mixamo terms | https://www.mixamo.com/ |
| Liam (player mesh) | Mixamo / Adobe | Mixamo terms | https://www.mixamo.com/ |
| Idle, Walking (In Place), Talking, Standing Idle | Mixamo / Adobe | Mixamo terms | https://www.mixamo.com/ |
```

角色名改成你实际下载的那个。

- [ ] **Step 6: 再跑校验，确认通过**

```powershell
godot --path game --headless -s res://tools/verify_realistic_assets.gd
```

Expected: `VERIFY_OK`。

- [ ] **Step 7: Commit**

```powershell
git add game/assets/characters game/assets/animations game/assets/ATTRIBUTION.md game/tools/verify_realistic_assets.gd
git commit -m "feat: add Mixamo character and in-place animation FBX files"
```

---

### Task 5: 共用 AnimationLibrary + NPC 换成 Mixamo 人体

**Files:**
- Create: `game/tools/build_humanoid_library.gd`
- Create: `game/assets/animations/humanoid_locomotion.tres`
- Modify: `game/world/npc.tscn`（去掉 Body/ArmL/ArmR 胶囊手臂；`Visual` 下实例化 `npc.fbx`；`AnimationPlayer` 改用共用库）
- Modify: `game/world/npc.gd`（仅 `_play_phase` 加 `has_animation`；四态 if/elif 不变）
- Modify: `game/tools/verify_realistic_assets.gd`（增加 `_check_npc_humanoid`）

**Interfaces:**
- Consumes: `res://assets/characters/npc.fbx`；四条 `res://assets/animations/{idle,walk,listen,talk}.fbx`；现有 `NpcActor.set_voice_phase(phase: String) -> void`，合法值仍是 `"idle"|"walk"|"listen"|"talk"`
- Produces: `res://assets/animations/humanoid_locomotion.tres` 类型 `AnimationLibrary`，动画名恰好 `idle`、`walk`、`listen`、`talk`，全部 `loop_mode = Animation.LOOP_LINEAR`。`npc.tscn` 保持根 `CharacterBody3D`、`collision_layer = 2`、胶囊 `radius=0.35` `height=1.8`、节点名 `Visual` 与 `AnimationPlayer`。`AnimationPlayer.root_node = NodePath("Visual/NpcModel")`。`session_orchestrator.gd` / `target_lock.gd` 不改。

- [ ] **Step 1: 先写失败的人体断言**

`_init` 在 mixamo 文件检查之后调用 `_check_npc_humanoid(errors)`：

```gdscript
func _check_npc_humanoid(errors: PackedStringArray) -> void:
	if not ResourceLoader.exists("res://assets/animations/humanoid_locomotion.tres"):
		_err(errors, "missing humanoid_locomotion.tres")
		return
	var lib := load("res://assets/animations/humanoid_locomotion.tres") as AnimationLibrary
	if lib == null:
		_err(errors, "humanoid_locomotion.tres is not AnimationLibrary")
		return
	for clip in ["idle", "walk", "listen", "talk"]:
		if not lib.has_animation(clip):
			_err(errors, "library missing clip " + clip)
		else:
			var a := lib.get_animation(clip)
			if a.loop_mode != Animation.LOOP_LINEAR:
				_err(errors, clip + " must LOOP_LINEAR")
	var npc := _instantiate("res://world/npc.tscn", errors)
	if npc == null:
		return
	if npc.get_node_or_null("Visual/Body") != null or npc.get_node_or_null("Visual/ArmL") != null or npc.get_node_or_null("Visual/ArmR") != null:
		_err(errors, "npc still has capsule/box meshes")
	if npc.get_node_or_null("Visual/NpcModel") == null:
		_err(errors, "npc missing Visual/NpcModel")
	else:
		var skel := npc.get_node("Visual/NpcModel").find_child("Skeleton3D", true, false)
		if skel == null:
			_err(errors, "NpcModel has no Skeleton3D")
	var ap := npc.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		_err(errors, "npc AnimationPlayer missing")
	else:
		for clip in ["idle", "walk", "listen", "talk"]:
			if not ap.has_animation(clip):
				_err(errors, "npc AnimationPlayer missing " + clip)
		if str(ap.root_node) != "Visual/NpcModel" and str(ap.root_node) != NodePath("Visual/NpcModel"):
			_err(errors, "npc AnimationPlayer.root_node must be Visual/NpcModel")
	var shape_node := npc.get_node("CollisionShape3D") as CollisionShape3D
	var cap := shape_node.shape as CapsuleShape3D
	if cap == null or abs(cap.radius - 0.35) > 0.001 or abs(cap.height - 1.8) > 0.001:
		_err(errors, "npc capsule size changed")
	if npc.collision_layer != 2:
		_err(errors, "npc collision_layer changed")
	npc.free()
```

- [ ] **Step 2: 跑校验，确认失败**

```powershell
godot --path game --headless -s res://tools/verify_realistic_assets.gd
```

Expected: `missing humanoid_locomotion.tres` 或 `npc still has capsule/box meshes`，退出码 1。

- [ ] **Step 3: 角色 FBX 导入设置（不要导入角色自带动画）**

在 Godot 文件系统选中 `npc.fbx` 与 `player.fbx`，导入坞：

- Import As: **Scene**
- Animation → Import：**关**（角色只提供皮肤和骨骼）
- 不要生成 StaticBody / trimesh（人的网格碰撞会挡住玩家，点选靠胶囊 layer 2）

点 **Reimport**。打开 `npc.fbx` 预览：应能看到 `Skeleton3D` 和蒙皮 `MeshInstance3D`。若人有楼高，Root Scale 设 `0.01` 后 Reimport；若只有手掌大，试 `1.0` 或 `100`。最终站在胶囊旁边时头顶应大约 1.8m。

动画四个 FBX：导入坞 **Import As: Animation Library**，然后 Reimport。

- [ ] **Step 4: 写并运行 AnimationLibrary 合并脚本**

`game/tools/build_humanoid_library.gd`：

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var lib := AnimationLibrary.new()
	_add(lib, "res://assets/animations/idle.fbx", "idle")
	_add(lib, "res://assets/animations/walk.fbx", "walk")
	_add(lib, "res://assets/animations/listen.fbx", "listen")
	_add(lib, "res://assets/animations/talk.fbx", "talk")
	var err := ResourceSaver.save(lib, "res://assets/animations/humanoid_locomotion.tres")
	if err != OK:
		push_error("save library failed: %s" % err)
	else:
		print("Wrote humanoid_locomotion.tres clips=%s" % ",".join(lib.get_animation_list()))


func _add(lib: AnimationLibrary, path: String, clip_name: String) -> void:
	var src := load(path)
	var anim: Animation = null
	if src is AnimationLibrary:
		var names: PackedStringArray = src.get_animation_list()
		if names.is_empty():
			push_error("no clips in " + path)
			return
		anim = src.get_animation(names[0]).duplicate(true) as Animation
	elif src is Animation:
		anim = src.duplicate(true) as Animation
	else:
		push_error("unsupported anim resource " + path)
		return
	anim.loop_mode = Animation.LOOP_LINEAR
	_zero_hips_xz(anim)
	if lib.has_animation(clip_name):
		lib.remove_animation(clip_name)
	lib.add_animation(clip_name, anim)


func _zero_hips_xz(anim: Animation) -> void:
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var p := str(anim.track_get_path(i))
		if p.findn("Hips") < 0:
			continue
		for k in anim.track_get_key_count(i):
			var v: Vector3 = anim.track_get_key_value(i, k)
			v.x = 0.0
			v.z = 0.0
			anim.track_set_key_value(i, k, v)
```

打开该脚本 → **文件 → 运行**。输出须包含 `clips=idle,walk,listen,talk`（顺序可变，四个名字必须齐）。

- [ ] **Step 5: 改 `npc.gd` 的 `_play_phase`（只加防护）**

把 `_play_phase` **整函数**换成下面这份。`set_voice_phase` 的合法值检查、`_physics_process` 里 idle/walk/listen/talk 的判定 **一行都不要改**。

```gdscript
func _play_phase() -> void:
	var clip := "idle"
	if _engaged and _voice_phase == "listen":
		clip = "listen"
	elif _engaged and _voice_phase == "talk":
		clip = "talk"
	elif not _engaged and _voice_phase == "walk":
		clip = "walk"
	if not _anim.has_animation(clip):
		return
	if _anim.current_animation != clip:
		_anim.play(clip)
```

- [ ] **Step 6: 重写 `npc.tscn` 外观，保留碰撞与脚本**

目标结构：

```
Npc (CharacterBody3D, collision_layer=2, script=npc.gd)
  CollisionShape3D          # 仍在 y=0.9，Capsule 0.35/1.8
  Visual                    # Node3D；若人物面朝 +Z 而走路看起来倒退，则 rotation_degrees.y = 180
    NpcModel                # instance=res://assets/characters/npc.fbx
  AnimationPlayer           # root_node=Visual/NpcModel；libraries 只有 humanoid_locomotion；autoplay=idle
```

把文件写成（`uid` 行若 Godot 自动生成可保留；`load_steps` 按实际 ext_resource 数）：

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://world/npc.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/characters/npc.fbx" id="2"]
[ext_resource type="AnimationLibrary" path="res://assets/animations/humanoid_locomotion.tres" id="3"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_npc"]
radius = 0.35
height = 1.8

[node name="Npc" type="CharacterBody3D"]
collision_layer = 2
collision_mask = 1
script = ExtResource("1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
shape = SubResource("CapsuleShape3D_npc")

[node name="Visual" type="Node3D" parent="."]
transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 0)

[node name="NpcModel" parent="Visual" instance=ExtResource("2")]

[node name="AnimationPlayer" type="AnimationPlayer" parent="."]
root_node = NodePath("Visual/NpcModel")
autoplay = "idle"
libraries = {
"": ExtResource("3")
}
```

`Visual` 的 transform 是绕 Y 转 180°（Mixamo 常朝 +Z，Godot 角色朝向 -Z）。若 F5 后 NPC 面朝移动方向是对的，但模型背对行走方向，保留这 180°；若已经正面朝前，改回单位矩阵：

```
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
```

删掉旧的 `CapsuleMesh` / `BoxMesh` / 四段手臂 Animation subresource。不要改 `persona` 在世界场景里的赋值。

- [ ] **Step 7: 编辑器里确认动画绑定**

打开 `npc.tscn`，选 AnimationPlayer，下拉应看到 `idle` `walk` `listen` `talk`。点 Play：骨骼应动，人不要滑出胶囊。脚陷进地就把 `NpcModel.position.y` 微调（例如 `0.0` 改成 `-0.05` 或 `0.05`），**不要**改胶囊尺寸。

F5：未锁定时巡逻应播 walk，停下播 idle。锁定后对着玩家；说话时 talk、听时 listen（有密钥时开麦验证；无密钥至少在远程调试器里对 CashierNpc 调 `set_voice_phase("talk")` 能切动画）。

- [ ] **Step 8: 跑校验，确认通过**

```powershell
godot --path game --headless -s res://tools/verify_realistic_assets.gd
```

Expected: `VERIFY_OK`。

- [ ] **Step 9: Commit**

```powershell
git add game/tools/build_humanoid_library.gd game/assets/animations/humanoid_locomotion.tres game/world/npc.tscn game/world/npc.gd game/tools/verify_realistic_assets.gd game/assets/characters
git commit -m "feat: swap NPC capsule for Mixamo mesh and shared clips"
```

---

### Task 6: 玩家换成同一套骨骼的 Mixamo 人体并播 idle/walk

**Files:**
- Modify: `game/world/player.tscn`（`BodyMesh` → `Visual` + `PlayerModel`；增加 `AnimationPlayer`；保留 `Head`/`SpringArm`）
- Modify: `game/world/player.gd`（`_visual` 替代 `_mesh`；`move_and_slide` 之后播 idle/walk；不改 WASD/鼠标/切人称）
- Modify: `game/tools/verify_realistic_assets.gd`（增加 `_check_player_humanoid`）

**Interfaces:**
- Consumes: `res://assets/characters/player.fbx`；同一份 `res://assets/animations/humanoid_locomotion.tres`；现有 `is_third_person() -> bool`、`SPEED := 4.5`、`toggle_camera` / `release_mouse`
- Produces: 外观根节点名为 `Visual`（`Node3D`）。第一人称 `_visual.visible = false`，第三人称 `true`。第三人称移动播 `walk`，静止播 `idle`。不播 listen/talk。不另做一套骨骼。

- [ ] **Step 1: 先写失败的玩家断言**

`_init` 最后调用 `_check_player_humanoid(errors)`：

```gdscript
func _check_player_humanoid(errors: PackedStringArray) -> void:
	var player := _instantiate("res://world/player.tscn", errors)
	if player == null:
		return
	if player.get_node_or_null("BodyMesh") != null:
		_err(errors, "player still has BodyMesh")
	if player.get_node_or_null("Visual") == null:
		_err(errors, "player missing Visual")
	if player.get_node_or_null("Visual/PlayerModel") == null:
		_err(errors, "player missing Visual/PlayerModel")
	else:
		var skel := player.get_node("Visual/PlayerModel").find_child("Skeleton3D", true, false)
		if skel == null:
			_err(errors, "PlayerModel has no Skeleton3D")
	if player.get_node_or_null("Head/FirstPersonCamera") == null or player.get_node_or_null("SpringArm/ThirdPersonCamera") == null:
		_err(errors, "player camera rig changed")
	var ap := player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		_err(errors, "player missing AnimationPlayer")
	else:
		if not ap.has_animation("idle") or not ap.has_animation("walk"):
			_err(errors, "player AnimationPlayer needs idle and walk")
		if str(ap.root_node) != "Visual/PlayerModel" and str(ap.root_node) != NodePath("Visual/PlayerModel"):
			_err(errors, "player AnimationPlayer.root_node must be Visual/PlayerModel")
	var src := FileAccess.get_file_as_string("res://world/player.gd")
	if src.find("$BodyMesh") >= 0:
		_err(errors, "player.gd still references BodyMesh")
	if src.find("_visual.visible") < 0:
		_err(errors, "player.gd must toggle Visual visibility")
	player.free()
```

- [ ] **Step 2: 跑校验，确认失败**

```powershell
godot --path game --headless -s res://tools/verify_realistic_assets.gd
```

Expected: `player still has BodyMesh` 或 `player missing Visual`，退出码 1。

- [ ] **Step 3: 把 `player.gd` 换成下面完整文件**

不要改 `SPEED`、`MOUSE_SENS`、`_unhandled_input` 里的转向与 `toggle_camera`、鼠标捕获逻辑。只是把网格引用改成 `Visual`，并在物理帧末尾播动画。

```gdscript
extends CharacterBody3D

const SPEED := 4.5
const MOUSE_SENS := 0.0025

@onready var _head: Node3D = $Head
@onready var _fp_camera: Camera3D = $Head/FirstPersonCamera
@onready var _spring: SpringArm3D = $SpringArm
@onready var _tp_camera: Camera3D = $SpringArm/ThirdPersonCamera
@onready var _visual: Node3D = $Visual
@onready var _anim: AnimationPlayer = $AnimationPlayer

var _third_person := false

func _ready() -> void:
	add_to_group("player")
	_apply_camera_mode()
	_spring.rotation_degrees = Vector3(-12.0, 0.0, 0.0)

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
	_play_locomotion()

func _play_locomotion() -> void:
	if _anim == null:
		return
	var moving := Vector2(velocity.x, velocity.z).length() > 0.05
	var clip := "walk" if moving else "idle"
	if not _anim.has_animation(clip):
		return
	if _anim.current_animation != clip:
		_anim.play(clip)

func _apply_camera_mode() -> void:
	_fp_camera.current = not _third_person
	_tp_camera.current = _third_person
	_visual.visible = _third_person
	if _third_person:
		_spring.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_spring.rotation = Vector3.ZERO
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
```

- [ ] **Step 4: 重写 `player.tscn`**

删除 `CapsuleMesh_player` 和 `BodyMesh` 节点。加入 `Visual`、`PlayerModel`、`AnimationPlayer`。`Head` 仍在 `y=1.6`，`SpringArm` 仍在 `y=1.4`、`spring_length = 3.2`。

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://world/player.gd" id="1"]
[ext_resource type="PackedScene" path="res://assets/characters/player.fbx" id="2"]
[ext_resource type="AnimationLibrary" path="res://assets/animations/humanoid_locomotion.tres" id="3"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_player"]
radius = 0.35
height = 1.8

[node name="Player" type="CharacterBody3D"]
collision_layer = 1
collision_mask = 1
script = ExtResource("1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
shape = SubResource("CapsuleShape3D_player")

[node name="Visual" type="Node3D" parent="."]
transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 0)

[node name="PlayerModel" parent="Visual" instance=ExtResource("2")]

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

[node name="AnimationPlayer" type="AnimationPlayer" parent="."]
root_node = NodePath("Visual/PlayerModel")
autoplay = "idle"
libraries = {
"": ExtResource("3")
}
```

`Visual` 的 180° 与 NPC 同一规则：第三人称按 W 时，人必须朝移动方向走。走反了就保留/去掉 Y180。

- [ ] **Step 5: 跑校验，确认通过**

```powershell
godot --path game --headless -s res://tools/verify_realistic_assets.gd
```

Expected: `VERIFY_OK`。

- [ ] **Step 6: 手工验收人称与动画**

F5：

1. 默认第一人称：看不见自己的身体网格。
2. 按 `V` 切第三人称：能看见写实人体；走动播 walk，停下播 idle。
3. 再按 `V` 回到第一人称：身体再次隐藏。WASD 与鼠标手感与换皮前相同。
4. 点选 NPC 仍走胶囊 layer 2，不依赖皮肤网格碰撞。

- [ ] **Step 7: Commit**

```powershell
git add game/world/player.tscn game/world/player.gd game/tools/verify_realistic_assets.gd
git commit -m "feat: swap player capsule for Mixamo mesh with idle/walk"
```

---

### Task 7: 全链路验收与 README

**Files:**
- Modify: `game/README.md`
- Modify: `game/assets/ATTRIBUTION.md`（合并前补齐所有实际用到的行；未用 HDRI 则写明 unused）

**Interfaces:**
- Consumes: Tasks 3–6 的室内与人体；现有主菜单、锁定、语音
- Produces: README 成功标准包含写实室内/人体；`scene_id` 仍为 `"indoor_neutral"`（即使房间其实是咖啡馆）

- [ ] **Step 1: 跑全部自动校验**

```powershell
godot --path game --headless -s res://tools/verify_realistic_assets.gd
godot --path game --quit-after 1
```

Expected: `VERIFY_OK`；工程可打开。若 Task 4–6 因 Mixamo 跳过，校验里的 mixamo/humanoid 检查不要留在脚本里——删掉 `_check_mixamo_files` / `_check_npc_humanoid` / `_check_player_humanoid` 的调用，只保留房间检查，然后本 task 按「只换房间」验收。

- [ ] **Step 2: Windows 上按 spec §7 手工过一遍**

从主菜单进入 `indoor_neutral`：

1. 房间不是纯色盒子；人物不是胶囊/方块手臂（若只完成一半，已换的那一半必须明显更真实）。
2. 能走、能锁定 NPC、能开麦说话。三项缺一即失败。
3. 人体已接入时：第三人称看见玩家人体；第一人称隐藏身体。
4. 人体已接入时：NPC 巡逻 walk、停下 idle；对话 listen/talk 切换。
5. 不要验收口型、表情、第二套付费资源。

把 `indoor_neutral_two_npcs.tscn` 临时设为主场景跑一次：两个 Mixamo 人、同一套室内、点选换目标仍结束上一会话（不改锁定脚本）。验完改回 `ui/main_menu.tscn`。

- [ ] **Step 3: 更新 `game/README.md`**

在「v1 成功标准」清单追加：

```markdown
- [ ] 8. 室内是 glTF 场景而不是纯色 CSG 盒子
- [ ] 9. 玩家与 NPC 是写实人体（若本机构建跳过 Mixamo，则至少室内已替换）
- [ ] 10. 第三人称可见玩家身体，第一人称隐藏
```

把「v1 不包含」里的这一行删掉：

```markdown
- 超市 / 教室 / 商场等成品主题地图
```

不要宣称做了口型、导航网格或第二张主菜单。

- [ ] **Step 4: 合并前再读 `ATTRIBUTION.md`**

每一份实际进仓库的 CC-BY 资源都必须有作者、作品名、许可证、链接。Mixamo 角色名与动画名与文件一致。没用 HDRI 就不要留假链接。

- [ ] **Step 5: Commit**

```powershell
git add game/README.md game/assets/ATTRIBUTION.md
git commit -m "docs: record realistic-asset attribution and visual acceptance"
```

---

## Self-Review

**1. Spec coverage**

| Spec | Task |
|------|------|
| §1 看起来更真实；能走/锁定/开麦 | Task 3、5、6 外观；Task 7 三项验收 |
| §2.1 免费可商用室内 glTF；超市优先、可降级；Mixamo 共用骨骼与四动画；先房间后人体；固定目录 + CC-BY | Task 2 搜索顺序；Task 3 房间；Task 4–6 人体；Task 1/2/4 署名 |
| §2.2 不做扫描/口型/NavMesh/自建超市/Kenney/RPM/付费/导入插件；不改 scene_id/存档/输入/语音；不新建主菜单入口 | Global Constraints；校验 `_check_logic_untouched`；Task 7 README |
| §3 胶囊碰撞保留；Visual + 四动画；资源路径表；第一人称藏身体；`set_voice_phase` 只换clip | Task 3 碰撞；Task 5–6 Visual/AnimationPlayer；player.gd `_visual.visible` |
| §4.1 Sketchfab 过滤器、关键词、四关、否决、HDRI 补光 | Task 2、Task 3 Step 8 |
| §4.2 Mixamo 两角色、四条 Without Skin、In Place、否决带 Skin/根运动/口型 | Task 4；`build_humanoid_library.gd` 清 Hips XZ |
| §5.1 绝对不动语音/会话/人设/锁定/字幕/暂停/scene_id/输入 | Task 1 校验；未把那些目录列入 Files |
| §5.2 删 CSG、实例化室内、留逻辑节点、两张地图同一套皮、重标出生点 | Task 3 |
| §5.3 npc 根/layer/胶囊/Visual/AnimationPlayer 名；去掉胶囊手臂；player Head/相机不动；BodyMesh→Visual | Task 5–6 |
| §6 降级室内；一半失败另一半留下；导入失败保留胶囊；署名合并前补 | Task 2 降级；Task 4 可跳过 5–6；`has_animation` 防护；Task 7 署名 |
| §7 Windows Godot 4.7 四条验收 | Task 7 |

**2. Placeholder scan:** 无 TBD/TODO/implement later。室内坐标用编辑器量测步骤写出，不用占位 Vector3。HDRI 有明确 URL 与「够亮则跳过」。Mixamo 角色有主选/备选名单与否决名单。

**3. Type consistency:** `set_voice_phase(phase: String)` 仍只接受 `idle|walk|listen|talk`；AnimationLibrary 动画名与之相同；`AnimationPlayer.root_node` 在 NPC/玩家都是 `Visual/NpcModel` 或 `Visual/PlayerModel`；`collision_layer` NPC=2 玩家=1；`scene_id` / `SCENE_ID` 恒为 `"indoor_neutral"`；校验脚本函数名 `_check_scaffold` `_check_logic_untouched` `_check_indoor_file` `_check_csg_removed` `_check_mixamo_files` `_check_npc_humanoid` `_check_player_humanoid` 在后续 task 中引用一致。
