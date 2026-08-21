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
