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
const DASH_DURATION: float = 0.25  # window where ground friction is off so the burst carries

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

# --- Grapple (swing hook) ---
const GRAPPLE_RANGE: float = 40.0
const GRAPPLE_AIR_ACCEL: float = 35.0   # how hard you can pump the swing
const GRAPPLE_MIN_LENGTH: float = 2.0

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

# --- Speed -> damage ---
# Multiplier scales smoothly from MIN (standing) to MAX (flying). It's shown to
# one decimal (e.g. x3.5); the discrete TIER it falls into drives the visuals.
const DMG_MULT_MIN: float = 1.0
const DMG_MULT_MAX: float = 4.0
const DMG_SPEED_MIN: float = 8.0
const DMG_SPEED_MAX: float = 38.0

# --- Recoil (on the camera, not the weapon model) ---
const RECOIL_KICK: float = 0.045    # radians of upward pitch per shot
const RECOIL_RECOVER: float = 12.0
const RECOIL_FOV_PUNCH: float = 6.0

@onready var _head: Node3D = %Head
@onready var _camera: Camera3D = %PlayerCamera

var _pitch: float = 0.0
var _yaw: float = 0.0
var _jump_buffer: float = 0.0
var _just_jumped: bool = false
var _jumps_left: int = MAX_JUMPS
var _dash_cooldown: float = 0.0
var _dash_timer: float = 0.0
var _fov_dash_bonus: float = 0.0
var _bob_time: float = 0.0
var _speed_label: Label

var _is_sliding: bool = false
var _is_wall_riding: bool = false
var _wall_normal: Vector3 = Vector3.ZERO
var _wall_ride_cooldown: float = 0.0
var _head_base_y: float = 0.0

var _weapon: Weapon
var _recoil_pitch: float = 0.0

var _is_grappling: bool = false
var _grapple_anchor: Vector3 = Vector3.ZERO
var _rope_length: float = 0.0
var _rope_mesh: MeshInstance3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_head_base_y = _head.position.y
	_setup_hud()
	_setup_weapon()
	_setup_rope()


func _setup_hud() -> void:
	var canvas := CanvasLayer.new()

	_speed_label = Label.new()
	_speed_label.position = Vector2(16, 16)
	canvas.add_child(_speed_label)

	# Crosshair — a simple centered "+"
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	crosshair.anchor_left = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	canvas.add_child(crosshair)

	add_child(canvas)


func _setup_weapon() -> void:
	# Parented to the camera, so it always fires straight down the crosshair.
	_weapon = Weapon.new()
	_camera.add_child(_weapon)


func _setup_rope() -> void:
	# A line drawn in world space from the gun to the grapple anchor.
	_rope_mesh = MeshInstance3D.new()
	_rope_mesh.mesh = ImmediateMesh.new()
	_rope_mesh.top_level = true  # use world space, ignore the player's transform
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.95, 0.85, 0.4)
	_rope_mesh.material_override = mat
	_rope_mesh.visible = false
	add_child(_rope_mesh)


# Called by JumpPad when the player touches it — launch up, keep horizontal speed.
func apply_jump_pad(force: float) -> void:
	velocity.y = force
	_jumps_left = MAX_JUMPS
	_is_grappling = false
	_fov_dash_bonus = maxf(_fov_dash_bonus, 10.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(
			_pitch - event.relative.y * MOUSE_SENSITIVITY,
			deg_to_rad(-89.0),
			deg_to_rad(89.0)
		)
		transform.basis = Basis(Vector3.UP, _yaw)
		# Head pitch (with recoil) is rebuilt every physics frame, not here.
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	_jump_buffer -= delta
	_dash_cooldown -= delta
	_dash_timer -= delta
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

	# Grapple — hold to swing, release to fly off
	if Input.is_action_just_pressed("grapple"):
		_try_grapple()
	if _is_grappling and not Input.is_action_pressed("grapple"):
		_is_grappling = false

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

	if _is_grappling:
		_grapple_move(wish_dir, delta)
	elif is_on_floor() and not _just_jumped:
		_ground_move(wish_dir, ground_speed, delta)
	else:
		_air_move(wish_dir, WALK_SPEED, delta)

	move_and_slide()

	if _is_grappling:
		_constrain_rope_position()

	_update_wall_ride()
	_update_rope()

	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var is_crouching := crouch_held and is_on_floor() and not _is_sliding
	_update_camera_feel(delta, horiz_speed, is_crouching)

	# Shoot — damage is scaled by how fast you're moving right now
	var mult := _damage_multiplier(horiz_speed)
	var tier := _damage_tier(mult)
	if Input.is_action_just_pressed("fire") and _weapon.fire(mult, tier, get_rid()):
		_apply_recoil()

	var dash_status := "READY" if _dash_cooldown <= 0.0 else "%.1fs" % _dash_cooldown
	var hook_tag := "   [HOOK]" if _is_grappling else ""
	_speed_label.text = "Speed: %.1f   Dash: %s%s\nDMG x%.1f   %s" % [
		horiz_speed, dash_status, hook_tag, mult, _tier_name(tier)
	]
	_speed_label.modulate = _tier_color(tier)


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
	if _is_grappling or is_on_floor() or _wall_ride_cooldown > 0.0:
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
	# Friction is off during the dash window so the burst carries; otherwise low
	# while sliding, normal while walking.
	var friction := GROUND_FRICTION
	if _is_sliding:
		friction = SLIDE_FRICTION
	elif _dash_timer > 0.0:
		friction = 0.0

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
	_dash_timer = DASH_DURATION
	_fov_dash_bonus = FOV_DASH_BONUS


func _try_grapple() -> void:
	# Raycast from the camera; attach to whatever the crosshair is on, in range.
	var space := get_world_3d().direct_space_state
	var origin := _camera.global_position
	var dir := -_camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * GRAPPLE_RANGE)
	query.exclude = [get_rid()]
	var result := space.intersect_ray(query)
	if not result:
		return
	var anchor: Vector3 = result.position
	var length := global_position.distance_to(anchor)
	if length < GRAPPLE_MIN_LENGTH:
		return
	_grapple_anchor = anchor
	_rope_length = length
	_is_grappling = true


func _grapple_move(wish_dir: Vector3, delta: float) -> void:
	# Gravity was already applied this frame — that's the energy that drives the
	# swing. Here we (1) let the player pump with air control, then (2) apply the
	# rope constraint that keeps only the tangential (swinging) motion.
	if wish_dir != Vector3.ZERO:
		velocity += wish_dir * GRAPPLE_AIR_ACCEL * delta

	var to_anchor := _grapple_anchor - global_position
	var dist := to_anchor.length()
	if dist < 0.01:
		return
	var dir := to_anchor / dist  # unit vector pointing at the anchor

	# When the rope is taut, cancel any velocity pulling AWAY from the anchor.
	# That converts "falling away" into "swinging around" — the pendulum.
	if dist >= _rope_length:
		var radial := velocity.dot(dir)  # + toward anchor, - away from it
		if radial < 0.0:
			velocity -= dir * radial


func _constrain_rope_position() -> void:
	# Soft-correct any drift so the rope length stays honest (move_and_slide can
	# nudge us slightly off the swing arc each frame).
	var to_anchor := _grapple_anchor - global_position
	var dist := to_anchor.length()
	if dist > _rope_length:
		var dir := to_anchor / dist
		var target := _grapple_anchor - dir * _rope_length
		global_position = global_position.lerp(target, 0.5)


func _update_rope() -> void:
	if not _is_grappling:
		_rope_mesh.visible = false
		return
	_rope_mesh.visible = true
	var im: ImmediateMesh = _rope_mesh.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(_weapon.global_position)
	im.surface_add_vertex(_grapple_anchor)
	im.surface_end()


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
	# Recoil — kick recovers toward 0; head pitch is rebuilt here every frame
	_recoil_pitch = lerpf(_recoil_pitch, 0.0, RECOIL_RECOVER * delta)
	_head.transform.basis = Basis(Vector3.RIGHT, _pitch + _recoil_pitch)

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


func _apply_recoil() -> void:
	_recoil_pitch += RECOIL_KICK
	_fov_dash_bonus = maxf(_fov_dash_bonus, RECOIL_FOV_PUNCH)


func _damage_multiplier(speed: float) -> float:
	var t := clampf((speed - DMG_SPEED_MIN) / (DMG_SPEED_MAX - DMG_SPEED_MIN), 0.0, 1.0)
	return lerpf(DMG_MULT_MIN, DMG_MULT_MAX, t)


func _damage_tier(mult: float) -> int:
	if mult < 1.5:
		return 0
	elif mult < 2.5:
		return 1
	elif mult < 3.5:
		return 2
	return 3


func _tier_name(tier: int) -> String:
	match tier:
		0: return "COLD"
		1: return "WARM"
		2: return "HOT"
		_: return "BLAZING"


func _tier_color(tier: int) -> Color:
	match tier:
		0: return Color(0.85, 0.85, 0.85)
		1: return Color(1.0, 0.9, 0.3)
		2: return Color(1.0, 0.55, 0.15)
		_: return Color(1.0, 0.25, 0.2)
