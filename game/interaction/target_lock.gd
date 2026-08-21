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
	var world: World3D = null
	if player != null:
		world = player.get_world_3d()
	if world == null:
		world = cam.get_world_3d()
	if world == null:
		world = get_tree().root.get_world_3d()
	if world == null:
		return null
	var hit := world.direct_space_state.intersect_ray(q)
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
