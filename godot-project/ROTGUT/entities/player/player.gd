class_name PlayerController
extends CharacterBody3D

# --- Base movement ---
const GRAVITY: float = 24.0
const WALK_SPEED: float = 8.0
const JUMP_VELOCITY: float = 8.5
const MOUSE_SENSITIVITY: float = 0.002

const GROUND_ACCEL: float = 120.0
const GROUND_FRICTION: float = 15.0
const AIR_ACCEL: float = 100.0

const JUMP_BUFFER_TIME: float = 0.12
const MAX_JUMPS: int = 2

# --- Dash ---
const DASH_SPEED: float = 28.0
const DASH_COOLDOWN: float = 1.0

# --- Crouch / Slide ---
const CROUCH_CAM_OFFSET: float = -0.35
const CROUCH_SPEED: float = 4.0
const SLIDE_FRICTION: float = 1.5
const SLIDE_MIN_SPEED: float = 5.0
const SLIDE_SPEED_BOOST: float = 4.0

# --- Wall ride ---
const WALL_RIDE_GRAVITY: float = 3.0
const WALL_FALL_CAP: float = -3.0
const WALL_JUMP_H: float = 9.0
const WALL_JUMP_V: float = 8.5
const WALL_RIDE_COOLDOWN: float = 0.3
const WALL_TILT_MAX: float = 8.0

# --- Camera feel ---
const FOV_BASE: float = 90.0
const FOV_MAX: float = 110.0
const FOV_SPEED_SCALE: float = 30.0
const FOV_DASH_BONUS: float = 15.0
const FOV_LERP: float = 8.0

const TILT_MAX: float = 3.0
const TILT_SPEED: float = 10.0

const BOB_FREQ: float = 1.8
const BOB_AMP: float = 0.025

@onready var _head: Node3D = %Head
@onready var _camera: Camera3D = %PlayerCamera

var _pitch: float = 0.0
var _yaw: float = 0.0
var _jump_buffer: float = 0.0
var _just_jumped: bool = false
var _jumps_left: int = MAX_JUMPS
var _dash_cooldown: float = 0.0
var _fov_dash_bonus: float = 0.0
var _bob_time: float = 0.0
var _speed_label: Label

var _is_sliding: bool = false
var _is_wall_riding: bool = false
var _wall_normal: Vector3 = Vector3.ZERO
var _wall_ride_cooldown: float = 0.0
var _head_base_y: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_head_base_y = _head.position.y
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
		_pitch = clampf(
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
	_dash_cooldown -= delta
	_wall_ride_cooldown -= delta
	_just_jumped = false

	if is_on_floor() and not _just_jumped:
		_jumps_left = MAX_JUMPS

	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER_TIME

	# Gravity — suppressed while wall riding
	if not is_on_floor():
		var grav := WALL_RIDE_GRAVITY if _is_wall_riding else GRAVITY
		velocity.y -= grav * delta
		if _is_wall_riding:
			velocity.y = maxf(velocity.y, WALL_FALL_CAP)

	# Jump — three cases: ground, wall, double
	if _jump_buffer > 0.0 and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_jumps_left -= 1
		_just_jumped = true
		_is_sliding = false
	elif _jump_buffer > 0.0 and _is_wall_riding:
		velocity.x += _wall_normal.x * WALL_JUMP_H
		velocity.z += _wall_normal.z * WALL_JUMP_H
		velocity.y = WALL_JUMP_V
		_jump_buffer = 0.0
		_jumps_left = MAX_JUMPS - 1
		_just_jumped = true
		_wall_ride_cooldown = WALL_RIDE_COOLDOWN
		_is_wall_riding = false
	elif Input.is_action_just_pressed("jump") and not is_on_floor() and not _is_wall_riding and _jumps_left > 0:
		velocity.y = JUMP_VELOCITY
		_jumps_left -= 1

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0:
		_do_dash(wish_dir)

	# Slide — crouch while moving fast on the ground
	var crouch_held := Input.is_action_pressed("crouch")
	var pre_horiz_speed := Vector2(velocity.x, velocity.z).length()

	if crouch_held and is_on_floor() and pre_horiz_speed > SLIDE_MIN_SPEED and not _is_sliding:
		_start_slide()
	elif _is_sliding and (not crouch_held or not is_on_floor() or pre_horiz_speed < SLIDE_MIN_SPEED):
		# Slide bottomed out (or you let go) — drop into a normal crouch so you can move again
		_is_sliding = false

	# Crouch-walk is capped below slide-entry speed, so you can never self-trigger a
	# slide just by walking — a new slide needs an external boost (bhop, dash, ramp).
	var ground_speed := CROUCH_SPEED if (crouch_held and not _is_sliding) else WALK_SPEED

	if is_on_floor() and not _just_jumped:
		_ground_move(wish_dir, ground_speed, delta)
	else:
		_air_move(wish_dir, WALK_SPEED, delta)

	move_and_slide()

	_update_wall_ride()

	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var is_crouching := crouch_held and is_on_floor() and not _is_sliding
	_update_camera_feel(delta, horiz_speed, is_crouching)

	var dash_status := "READY" if _dash_cooldown <= 0.0 else "%.1fs" % _dash_cooldown
	_speed_label.text = "Speed: %.1f  |  Dash: %s" % [horiz_speed, dash_status]


func _start_slide() -> void:
	_is_sliding = true
	var hvel := Vector2(velocity.x, velocity.z)
	if hvel.length() > 0.1:
		var slide_dir := Vector3(hvel.x, 0.0, hvel.y).normalized()
		velocity.x += slide_dir.x * SLIDE_SPEED_BOOST
		velocity.z += slide_dir.z * SLIDE_SPEED_BOOST


func _update_wall_ride() -> void:
	_is_wall_riding = false
	_wall_normal = Vector3.ZERO
	if is_on_floor() or _wall_ride_cooldown > 0.0:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var normal := col.get_normal()
		# Normal is roughly vertical = floor/ceiling. Nearly horizontal = wall.
		if abs(normal.y) < 0.3:
			_is_wall_riding = true
			_wall_normal = normal
			_jumps_left = MAX_JUMPS
			break


func _ground_move(wish_dir: Vector3, wish_speed: float, delta: float) -> void:
	var friction := SLIDE_FRICTION if _is_sliding else GROUND_FRICTION
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd > 0.5:
		var new_spd := maxf(spd - spd * friction * delta, 0.0)
		velocity.x = velocity.x / spd * new_spd
		velocity.z = velocity.z / spd * new_spd
	elif not _is_sliding:
		velocity.x = 0.0
		velocity.z = 0.0

	# No steering input during a slide — direction is locked on entry
	if not _is_sliding and wish_dir != Vector3.ZERO:
		var current_speed := velocity.dot(wish_dir)
		var add_speed := clampf(wish_speed - current_speed, 0.0, GROUND_ACCEL * delta)
		velocity += wish_dir * add_speed


func _do_dash(wish_dir: Vector3) -> void:
	var dash_dir := wish_dir if wish_dir != Vector3.ZERO else -transform.basis.z
	dash_dir = Vector3(dash_dir.x, 0.0, dash_dir.z).normalized()
	velocity.x += dash_dir.x * DASH_SPEED
	velocity.z += dash_dir.z * DASH_SPEED
	_dash_cooldown = DASH_COOLDOWN
	_fov_dash_bonus = FOV_DASH_BONUS


func _air_move(wish_dir: Vector3, wish_speed: float, delta: float) -> void:
	var current_speed := velocity.dot(wish_dir)
	var add_speed := clampf(wish_speed - current_speed, 0.0, AIR_ACCEL * delta)
	if add_speed <= 0.0:
		return
	var prev_hspeed := Vector2(velocity.x, velocity.z).length()
	velocity += wish_dir * add_speed
	var new_hspeed := Vector2(velocity.x, velocity.z).length()
	if new_hspeed < prev_hspeed:
		var scale := prev_hspeed / maxf(new_hspeed, 0.001)
		velocity.x *= scale
		velocity.z *= scale


func _update_camera_feel(delta: float, horiz_speed: float, is_crouching: bool) -> void:
	# FOV — scales with speed, spikes on dash
	var speed_t := clampf(horiz_speed / FOV_SPEED_SCALE, 0.0, 1.0)
	var target_fov := lerpf(FOV_BASE, FOV_MAX, speed_t) + _fov_dash_bonus
	_camera.fov = lerpf(_camera.fov, target_fov, FOV_LERP * delta)
	_fov_dash_bonus = lerpf(_fov_dash_bonus, 0.0, 10.0 * delta)

	# Tilt — strafe on ground, wall lean while wall riding
	var target_tilt: float
	if _is_wall_riding:
		var wall_side := _wall_normal.dot(-transform.basis.x)
		target_tilt = wall_side * WALL_TILT_MAX
	else:
		var strafe := Input.get_axis("move_left", "move_right")
		target_tilt = -strafe * TILT_MAX
	_camera.rotation_degrees.z = lerpf(_camera.rotation_degrees.z, target_tilt, TILT_SPEED * delta)

	# Head height — drops when crouching or sliding
	var head_y_target := _head_base_y + (CROUCH_CAM_OFFSET if (is_crouching or _is_sliding) else 0.0)
	_head.position.y = lerpf(_head.position.y, head_y_target, 12.0 * delta)

	# Head bob — off while sliding
	if is_on_floor() and horiz_speed > 1.0 and not _is_sliding:
		_bob_time += delta * horiz_speed * BOB_FREQ
		_camera.position.y = sin(_bob_time) * BOB_AMP * clampf(horiz_speed / WALK_SPEED, 0.0, 1.0)
	else:
		_camera.position.y = lerpf(_camera.position.y, 0.0, 10.0 * delta)
