# 写实游戏感场景与人物资源设计

日期：2026-08-21  
状态：待实现（本文件为已对齐的视觉资源 spec）  
前置：`docs/superpowers/specs/2026-08-21-immersive-english-npc-design.md`

本文件覆盖 v1 spec 里推迟的「用场景资源替换中性室内」，并把胶囊/方块占位换成写实人体。不改语音、会话、人设、锁定规则。

## 1. 目的与成功标准

当前 `indoor_neutral` 是 CSG 盒子房间，玩家是胶囊，NPC 是胶囊加两根方块手臂。目标是 **写实游戏感**（普通 3D 游戏那一档，不是照片扫描），让漫游和对话时看起来像在一个真实室内面对真人。

成功标准（本轮）：

- 场景和人物看起来明显比现在的方块房间 + 胶囊人更真实。
- 进场景仍能走、能锁定 NPC、能开麦说话。这三项坏了即失败，即使画面更好看。

## 2. 范围

### 2.1 做

- 用一套免费、可商用许可的完整室内 glTF/GLB 替换 CSG 房间。
- 优先超市/便利店；按搜索顺序找不到合格资源则改用咖啡馆、小店或办公室室内，不因此停工。
- 玩家和 NPC 都换成 Mixamo 写实人体，共用同一套骨骼和同一份四条动画库。
- 分两步接入：先换房间（胶囊人仍可玩），再换人体。
- 把资源放进固定目录，CC-BY 写进署名文件。

### 2.2 明确不做

- 照片级扫描、口型、面部表情绑定、导航网格。
- 用一堆 CC0 小物件自建超市。
- Kenney Mini Market 等低多边形/卡通包（与写实游戏感冲突）。
- Ready Player Me、付费资源站、Mixamo 导入插件。
- 改 `scene_id`、存档格式、玩家控制器输入、语音模块。
- 为换皮新建第二张主菜单入口场景。

## 3. 架构

世界逻辑不动。换的是两层外观：

```
玩家 / NPC（现有 CharacterBody3D 脚本）
  ├─ CollisionShape3D     保持胶囊，负责走路和点选
  └─ Visual               Mixamo 人体 + idle/walk/listen/talk

场景 indoor_neutral
  ├─ 逻辑节点（TargetLock、VoiceSession、HUD…） 不动
  └─ 房间：CSG 盒子 → 一套室内 glTF（静态网格碰撞）
```

资源目录：

| 路径 | 内容 |
|------|------|
| `game/assets/environments/` | 室内 glTF/GLB、贴图、可选 HDRI |
| `game/assets/characters/` | Mixamo 角色 FBX（带皮肤） |
| `game/assets/animations/` | Idle / Walk / Listen / Talk，FBX **Without Skin** |
| `game/assets/ATTRIBUTION.md` | CC-BY 作者、作品名、许可证、链接 |

玩家和 NPC 共用 Mixamo 骨骼与同一份 `AnimationLibrary`。NPC 的 `set_voice_phase("idle"|"walk"|"listen"|"talk")` 只改播放哪条动画。玩家在第三人称播放 `idle`/`walk`，第一人称仍隐藏身体。

`scene_id` 保持 `"indoor_neutral"`，即使实际房间变成咖啡馆。

## 4. 怎么找、什么叫能用

场景和人物分开搜，用同一套否决标准，不混卡通包。

### 4.1 场景（Sketchfab）

过滤器：Downloadable、CC0 或 CC Attribution、格式 glTF/GLB。

关键词顺序：`convenience store` → `grocery store` → `supermarket interior` → `mini mart`。全军覆没再换 `cafe interior`、`shop interior`、`office interior`。

打开页面后四关都过才下载：

1. **能走**：有连续地板和可绕行空间，不是柜台特写或外立面。
2. **比例**：门口/柜台高度能站下一个约 1.8m 的人。
3. **体量**：优先几十万三角以内；上百万仅当没有更轻替代且本机 Forward Plus 能流畅漫游。
4. **许可证**：允许放进游戏。CC-BY 必须写入 `ATTRIBUTION.md`。

否决：仅 View、Sketchfab Standard 许可、Unity/Unreal 工程包、标注 low poly / stylized / voxel 的资源、Kenney 超市包。

导入 Godot 后再验收一次：角色胶囊不陷地、不飞天；生成静态碰撞后能从出生点走到 NPC 附近。灯光不够则加 Poly Haven 室内 HDRI，不改玩法脚本。

### 4.2 人物（Mixamo）

选两个偏写实角色：一个收银员气质（NPC），一个普通顾客（玩家）。不要 robot / cartoon / stylized。遵守 Mixamo 使用条款。

动画导出 FBX、**Without Skin**，去掉 Root Motion（位移由脚本负责）。只这四条，名称与现有状态机对齐：

| 游戏状态 | Mixamo 来源 |
|----------|-------------|
| `idle` | Idle |
| `walk` | Walking |
| `talk` | Talking |
| `listen` | 另一个站立 Idle（姿势与 `idle` 可区分即可） |

两个角色必须是 Mixamo 骨骼，以便共用 AnimationLibrary。

否决：带 Skin 的动画文件、Root Motion 走路、口型/面部动画包。

场景过关而人物未过关（或反过来）也算进度：先把过关的一半放进对应目录，另一半继续按关键词降级。

## 5. 接到现有场景

### 5.1 绝对不动

语音、会话、人设 Resource、锁定、字幕、暂停、`scene_id`、玩家移动与切镜头的输入逻辑。

### 5.2 第一步：只换房间

改 `game/world/indoor_neutral.tscn`：

- 从场景树移除 `Floor` 与四面 `Wall*` CSG，不要留作隐形碰撞（新室内自己提供碰撞）。
- 实例化 `assets/environments/` 内的室内模型，做成静态碰撞。
- 保留 `WorldEnvironment` 与 `Sun`；必要时换室内 HDRI。
- `Player`、`CashierNpc` 及全部逻辑子节点留在原处。
- 按新地板高度和走道重标出生点与 `patrol_points`。

`game/world/indoor_neutral_two_npcs.tscn` 使用同一套室内，避免两张地图两套皮。

此步结束：看起来是真实室内，人仍是胶囊，对话全链路可用。

### 5.3 第二步：换人体

`game/world/npc.tscn`：

- 根仍是 `CharacterBody3D`，`collision_layer = 2`，胶囊尺寸不变。
- 节点名保持 `Visual` 与 `AnimationPlayer`，`npc.gd` 的职责不变。
- 去掉胶囊网格和方块手臂，在 `Visual` 下挂 Mixamo NPC 模型。
- `AnimationPlayer` 动画名仍为 `idle` / `walk` / `listen` / `talk`。

`game/world/player.tscn`：

- `Head`、第一/第三人称相机、`SpringArm` 不动。
- 用 Mixamo 玩家模型替换 `BodyMesh`。导入结果是带 `Skeleton3D` 的场景，不是单张 `MeshInstance3D`；外观根节点改为 `Visual`（`Node3D`），`player.gd` 对 `Visual` 做第一人称隐藏 / 第三人称显示。
- 第三人称移动时播 `walk`，静止播 `idle`。不另做一套骨骼。

`npc.gd` 不改四态语义。`player.gd` 只增加外观网格引用和 idle/walk 播放，不改 WASD、鼠标、切人称。

## 6. 失败处理

- 超市搜不到或导入后不能走：改用下一档室内，不回退去搭低模超市。
- 室内能用、人物未过关：只换房间，胶囊人留下。反过来也成立。
- 模型导入失败或动画名对不上：继续用现有胶囊外观，游戏必须能启动。
- 署名漏写不挡「看起来更真实」，但合并前应补上 `ATTRIBUTION.md`。

## 7. 验收

在 Windows 上用 Godot 4.7 打开 `game/`，从主菜单进入场景：

1. 房间不再是纯色盒子，人物不再是胶囊/方块手臂（若某一步尚未换上，已换的那一半仍须明显更真实）。
2. 能走、能锁定 NPC、能开麦说话。
3. 第三人称能看见玩家人体（人体已接入时）；第一人称身体隐藏。
4. NPC 巡逻播 walk、停下播 idle；对话时 listen/talk 切换（人体已接入时）。

口型、表情、第二套付费资源不在本轮验收内。
