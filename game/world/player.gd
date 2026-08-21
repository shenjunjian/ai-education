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

func _apply_camera_mode() -> void:
	_fp_camera.current = not _third_person
	_tp_camera.current = _third_person
	_mesh.visible = _third_person
	_spring.rotation = Vector3.ZERO
	if _third_person:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
