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
const DASH_SPEED: float = 45  # total speed the dash adds over its window (ramped, not instant)
const DASH_COOLDOWN: float = 1.0
const DASH_DURATION: float = 0.2  # window where ground friction is off so the burst carries


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

# --- Grapple (physics pull hook, Redliner-style) ---
const GRAPPLE_RANGE: float = 40.0
const GRAPPLE_MIN_LENGTH: float = 2.0        # auto-release once you reach the anchor
const GRAPPLE_PULL_ACCEL: float = 70.0      # pull toward anchor when slow (the yoink)
const GRAPPLE_PULL_FALLOFF: float = 30.0     # speed at which the pull fades to its minimum
const GRAPPLE_MIN_PULL: float = 0.2          # pull factor at high speed (pure redirection)
const GRAPPLE_AIR_CONTROL: float = 25.0      # light steering while hooked (no reel button)

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

# --- Health ---
const MAX_HEALTH: float = 100.0

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
var _rope_mesh: MeshInstance3D
var _grapple_release_timer: float = 0.0

var _health: float = MAX_HEALTH
var _spawn_position: Vector3 = Vector3.ZERO
var _health_label: Label
var _damage_overlay: ColorRect
var _combo_label: Label
var _combo_bar_bg: ColorRect
var _combo_bar_fill: ColorRect

var _glow_overlay: ColorRect
var _glow_mat: ShaderMaterial
var _glow_intensity: float = 0.0
var _glow_pulse: float = 0.0
var _rank_pop_label: Label
var _rank_pop_tween: Tween
var _last_rank: int = 0
var _dash_dir := Vector3.ZERO



func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_head_base_y = _head.position.y
	add_to_group("player")  # so enemies can find us via get_first_node_in_group
	_spawn_position = global_position
	_health = MAX_HEALTH
	_setup_hud()
	_setup_weapon()
	_setup_rope()
	Combo.rank_changed.connect(_on_rank_changed)  # drive the rank-up punch


func _setup_hud() -> void:
	var canvas := CanvasLayer.new()

	# Combo escalation — a screen-edge glow that ramps with rank. Behind the HUD
	# text (added first = drawn underneath). Center stays clear so it never
	# obscures the crosshair.
	_glow_overlay = ColorRect.new()
	_glow_overlay.anchor_right = 1.0
	_glow_overlay.anchor_bottom = 1.0
	_glow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_mat = ShaderMaterial.new()
	var glow_shader := Shader.new()
	glow_shader.code = "shader_type canvas_item;\n" \
		+ "uniform vec4 glow_color : source_color = vec4(1.0, 0.3, 0.2, 1.0);\n" \
		+ "uniform float intensity : hint_range(0.0, 1.0) = 0.0;\n" \
		+ "void fragment() {\n" \
		+ "	float d = distance(UV, vec2(0.5));\n" \
		+ "	float edge = smoothstep(0.30, 0.78, d);\n" \
		+ "	COLOR = vec4(glow_color.rgb, edge * intensity);\n" \
		+ "}\n"
	_glow_mat.shader = glow_shader
	_glow_overlay.material = _glow_mat
	canvas.add_child(_glow_overlay)

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

	# Health readout
	_health_label = Label.new()
	_health_label.position = Vector2(16, 72)
	_health_label.add_theme_font_size_override("font_size", 20)
	_health_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	canvas.add_child(_health_label)

	# Combo / style meter — rank name + a fill bar
	_combo_label = Label.new()
	_combo_label.position = Vector2(16, 104)
	_combo_label.add_theme_font_size_override("font_size", 26)
	canvas.add_child(_combo_label)

	_combo_bar_bg = ColorRect.new()
	_combo_bar_bg.position = Vector2(16, 140)
	_combo_bar_bg.size = Vector2(220, 14)
	_combo_bar_bg.color = Color(0.1, 0.1, 0.1, 0.55)
	canvas.add_child(_combo_bar_bg)

	_combo_bar_fill = ColorRect.new()
	_combo_bar_fill.position = Vector2(16, 140)
	_combo_bar_fill.size = Vector2(0, 14)
	canvas.add_child(_combo_bar_fill)

	# Full-screen red flash when hurt
	_damage_overlay = ColorRect.new()
	_damage_overlay.color = Color(0.8, 0.0, 0.0, 0.0)
	_damage_overlay.anchor_right = 1.0
	_damage_overlay.anchor_bottom = 1.0
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_damage_overlay)

	# Rank-up pop — big rank name that flashes center-screen on a new rank (top of stack)
	_rank_pop_label = Label.new()
	_rank_pop_label.add_theme_font_size_override("font_size", 64)
	_rank_pop_label.anchor_left = 0.5
	_rank_pop_label.anchor_top = 0.32
	_rank_pop_label.anchor_right = 0.5
	_rank_pop_label.anchor_bottom = 0.32
	_rank_pop_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_rank_pop_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_rank_pop_label.modulate.a = 0.0
	_rank_pop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_rank_pop_label)

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


# Called by enemies dealing damage.
func take_damage(amount: float) -> void:
	if _health <= 0.0:
		return
	_health -= amount
	_flash_damage()
	Combo.on_player_hurt()  # getting hit drains your style hard
	if _health <= 0.0:
		_die()


func _flash_damage() -> void:
	_damage_overlay.color.a = 0.5
	var tween := create_tween()
	tween.tween_property(_damage_overlay, "color:a", 0.0, 0.4)


func _die() -> void:
	# Simple respawn for now — back to spawn, full health, movement state cleared.
	global_position = _spawn_position
	velocity = Vector3.ZERO
	_health = MAX_HEALTH
	_is_grappling = false
	_is_sliding = false


func _on_rank_changed(rank: int) -> void:
	# Punch only when climbing to a new, higher rank.
	if rank > _last_rank and rank > 0:
		_rank_pop_label.text = Combo.get_rank_name()
		_rank_pop_label.add_theme_color_override("font_color", CombatFX.tier_color(mini(rank, 3)))
		_rank_pop_label.modulate.a = 1.0
		if _rank_pop_tween != null and _rank_pop_tween.is_valid():
			_rank_pop_tween.kill()
		_rank_pop_tween = create_tween()
		_rank_pop_tween.tween_property(_rank_pop_label, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
		_glow_pulse = 0.45                                # bright flash that settles
		_fov_dash_bonus = maxf(_fov_dash_bonus, 8.0)      # small FOV kick
	_last_rank = rank


func _update_escalation(delta: float) -> void:
	# Screen-edge glow ramps smoothly toward a per-rank target; the pulse adds a
	# transient spike on rank-up that decays back down.
	var rank := Combo.get_rank()
	var target := minf(rank * 0.16, 0.65)
	_glow_intensity = lerpf(_glow_intensity, target, 4.0 * delta)
	_glow_pulse = lerpf(_glow_pulse, 0.0, 6.0 * delta)
	_glow_mat.set_shader_parameter("intensity", clampf(_glow_intensity + _glow_pulse, 0.0, 1.0))
	_glow_mat.set_shader_parameter("glow_color", CombatFX.tier_color(mini(rank, 3)))


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
		
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0 and not _is_grappling:
		_do_dash(wish_dir)
		
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER_TIME

	# Gravity — suppressed while wall riding
	if not is_on_floor():
		var grav := WALL_RIDE_GRAVITY if _is_wall_riding else GRAVITY
		velocity.y -= grav * delta
		if _is_wall_riding:
			velocity.y = maxf(velocity.y, WALL_FALL_CAP)

	# Dash — accelerate along the locked direction over the dash window, easing in
	# so the burst builds up instead of popping flat (Tom's design). Friction is off
	# during this window (see _ground_move), so the speed carries. The merge had
	# dropped this block, so dashing did nothing — restored + corrected here.
	if _dash_timer > 0.0 and not _is_grappling:
		var dash_t := 1.0 - (_dash_timer / DASH_DURATION)   # 0 -> 1 across the window
		var dash_ease := 0.5 + dash_t * dash_t              # ramps up (0.5 -> 1.5)
		# Normalize by the ease integral (integral of 0.5+t^2 over 0..1 = 0.8333) so
		# the total speed gained equals DASH_SPEED regardless of the curve shape.
		var dash_accel := DASH_SPEED / (DASH_DURATION * 0.8333)
		velocity.x += _dash_dir.x * dash_accel * dash_ease * delta
		velocity.z += _dash_dir.z * dash_accel * dash_ease * delta
		

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

	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0:
		_do_dash(wish_dir)

	# Grapple — hold to swing, release to fly off
	if Input.is_action_just_pressed("grapple"):
		_try_grapple()
	if _is_grappling and not Input.is_action_pressed("grapple"):
		_is_grappling = false
		_grapple_release_timer = 2.0  # seconds of reduced friction

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
		_grapple_move(delta)
	elif is_on_floor() and not _just_jumped:
		_ground_move(wish_dir, ground_speed, delta)
	else:
		_air_move(wish_dir, WALK_SPEED, delta)

	move_and_slide()
	_update_wall_ride()
	_update_rope()

	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var is_crouching := crouch_held and is_on_floor() and not _is_sliding
	_update_camera_feel(delta, horiz_speed, is_crouching)
	_update_escalation(delta)

	# Shoot — damage is scaled by how fast you're moving right now
	var mult := _damage_multiplier(horiz_speed)
	var tier := _damage_tier(mult)
	
	if Input.is_action_just_pressed("fire") and _weapon.fire(mult, tier, get_rid()):
		_apply_recoil()

	if Input.is_action_just_pressed("reload"):
		_weapon.reload()

	var dash_status := "READY" if _dash_cooldown <= 0.0 else "%.1fs" % _dash_cooldown
	var hook_tag := "   [HOOK]" if _is_grappling else ""
	_speed_label.text = "Speed: %.1f   Dash: %s%s\nDMG x%.1f   %s" % [
		horiz_speed, dash_status, hook_tag, mult, CombatFX.tier_name(tier)
	]
	_speed_label.modulate = CombatFX.tier_color(tier)
	_health_label.text = "HP: %d" % roundi(_health)

	var combo_rank := Combo.get_rank()
	var combo_col := CombatFX.tier_color(mini(combo_rank, 3))
	_combo_label.text = Combo.get_rank_name()
	_combo_label.add_theme_color_override("font_color", combo_col)
	_combo_bar_fill.size.x = 220.0 * (Combo.get_points() / ComboSystem.MAX_POINTS)
	_combo_bar_fill.color = combo_col


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
	_grapple_release_timer -= delta  # tick it down here

	var friction := GROUND_FRICTION
	if _is_sliding:
		friction = SLIDE_FRICTION
	elif _dash_timer > 0.0:
		friction = 0.0
	elif _grapple_release_timer > 0.0:
		friction = GROUND_FRICTION * 0.15  # 15% friction for a couple secs after releasing

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
	_dash_dir = dash_dir # store direction for use in _process/_physics_process
	_dash_cooldown = DASH_COOLDOWN
	_dash_timer = DASH_DURATION
	_fov_dash_bonus = FOV_DASH_BONUS


func _try_grapple() -> void:
	var space := get_world_3d().direct_space_state
	var origin := _camera.global_position
	var dir := -_camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * GRAPPLE_RANGE)
	query.exclude = [get_rid()]
	var result := space.intersect_ray(query)
	if not result:
		return
	var length := global_position.distance_to(result.position)
	if length < GRAPPLE_MIN_LENGTH:
		return
	_grapple_anchor = result.position
	_is_grappling = true
	_dash_timer = 0.0
	_dash_cooldown = DASH_COOLDOWN  # lock dash while grappling


func _grapple_move(delta: float) -> void:
	var to_anchor := _grapple_anchor - global_position
	var dist := to_anchor.length()
	if dist < GRAPPLE_MIN_LENGTH:
		_is_grappling = false  # reached the anchor — let go so you fly off with the speed
		return
	var dir := to_anchor / dist

	# Pull toward the anchor, but the faster you already move the LESS it pulls:
	# slow = a big yoink that builds speed, fast = gentle redirection so you keep
	# your momentum and curve around the point. (Gravity still applies, from above.)
	var speed := velocity.length()
	var pull_factor := clampf(1.0 - speed / GRAPPLE_PULL_FALLOFF, GRAPPLE_MIN_PULL, 1.0)
	velocity += dir * GRAPPLE_PULL_ACCEL * pull_factor * delta

	# Light air control so you can steer the redirect — no reel button to hold.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if wish_dir != Vector3.ZERO:
		velocity += wish_dir * GRAPPLE_AIR_CONTROL * delta

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
