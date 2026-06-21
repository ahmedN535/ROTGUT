class_name PlayerController
extends CharacterBody3D

const GRAVITY: float = 24.0
const WALK_SPEED: float = 8.0
const SPRINT_SPEED: float = 14.0
const JUMP_VELOCITY: float = 8.5
const MOUSE_SENSITIVITY: float = 0.002

const GROUND_ACCEL: float = 120.0
const GROUND_FRICTION: float = 15.0
const AIR_ACCEL: float = 100.0

const JUMP_BUFFER_TIME: float = 0.12

@onready var _head: Node3D = %Head
@onready var _camera: Camera3D = %PlayerCamera

var _pitch: float = 0.0
var _yaw: float = 0.0
var _jump_buffer: float = 0.0
var _just_jumped: bool = false
var _speed_label: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_speed_hud()


func _setup_speed_hud() -> void:
	var canvas := CanvasLayer.new()
	_speed_label = Label.new()
	_speed_label.position = Vector2(16, 16)
	canvas.add_child(_speed_label)
	add_child(canvas)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clamp(
			_pitch - event.relative.y * MOUSE_SENSITIVITY,
			deg_to_rad(-89.0),
			deg_to_rad(89.0)
		)
		transform.basis = Basis(Vector3.UP, _yaw)
		_head.transform.basis = Basis(Vector3.RIGHT, _pitch)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	_jump_buffer -= delta
	_just_jumped = false

	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER_TIME

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _jump_buffer > 0.0 and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_just_jumped = true

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var wish_speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED

	if is_on_floor() and not _just_jumped:
		_ground_move(wish_dir, wish_speed, delta)
	else:
		_air_move(wish_dir, wish_speed, delta)

	move_and_slide()

	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	_speed_label.text = "Speed: %.1f" % horiz_speed


func _ground_move(wish_dir: Vector3, wish_speed: float, delta: float) -> void:
	# Friction always runs first — this is what bounds ground speed near wish_speed
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd > 0.5:
		var new_spd := maxf(spd - spd * GROUND_FRICTION * delta, 0.0)
		velocity.x = velocity.x / spd * new_spd
		velocity.z = velocity.z / spd * new_spd
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# Then accelerate toward wish_speed — if already above it, add_speed = 0
	# so bhop speed landing is preserved for the 1-2 frames before you jump again
	if wish_dir != Vector3.ZERO:
		var current_speed := velocity.dot(wish_dir)
		var add_speed := clampf(wish_speed - current_speed, 0.0, GROUND_ACCEL * delta)
		velocity += wish_dir * add_speed


func _air_move(wish_dir: Vector3, wish_speed: float, delta: float) -> void:
	var current_speed := velocity.dot(wish_dir)
	var add_speed := clampf(wish_speed - current_speed, 0.0, AIR_ACCEL * delta)
	if add_speed <= 0.0:
		return
	var prev_hspeed := Vector2(velocity.x, velocity.z).length()
	velocity += wish_dir * add_speed
	# Never let air movement reduce horizontal speed — only redirect or boost
	var new_hspeed := Vector2(velocity.x, velocity.z).length()
	if new_hspeed < prev_hspeed:
		var scale := prev_hspeed / maxf(new_hspeed, 0.001)
		velocity.x *= scale
		velocity.z *= scale
