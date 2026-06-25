class_name Weapon
extends Node3D

signal target_hit(damage: float, multiplier: float, tier: int)

const RANGE: float = 200.0
const BASE_DAMAGE: float = 20.0
const FIRE_COOLDOWN: float = 0.35
const MAX_BOUNCES: int = 3
const RICOCHET_DAMAGE_FALLOFF: float = 1.5
const MAX_AMMO: int = 6
const RELOAD_TIME: float = 0.5

const VIEWMODEL_PATH: String = "res://weapons/Revolver.tscn"
const VIEWMODEL_POS: Vector3 = Vector3(0.18, -0.15, -0.45)
const VIEWMODEL_ROT: Vector3 = Vector3(0, 180, 0)
const VIEWMODEL_SCALE: float = 1.0

const RECOIL_KICK_UP: float = 0.08
const RECOIL_KICK_BACK: float = 0.04
const RECOIL_RETURN_SPEED: float = 12.0

const TRACER_LIFETIME: float = 0.16
const TRACER_COLOR: Color = Color(0.741, 0.0, 0.2, 1.0)
const TRACER_RADIUS: float = 0.015

var _cooldown: float = 0.0
var _viewmodel: Node3D
var _recoil_offset: Vector3 = Vector3.ZERO

var _ammo: int = MAX_AMMO
var _is_reloading: bool = false
var _reload_timer: float = 0.0
var _reload_flip_dir: float = 1.0

var _tracers: Array = []

func _ready() -> void:
	_setup_viewmodel()

func _setup_viewmodel() -> void:
	var scene := load(VIEWMODEL_PATH) as PackedScene
	if scene == null:
		push_warning("Weapon: viewmodel not found at %s" % VIEWMODEL_PATH)
		return
	_viewmodel = scene.instantiate()
	add_child(_viewmodel)
	_viewmodel.position = VIEWMODEL_POS
	_viewmodel.rotation_degrees = VIEWMODEL_ROT
	_viewmodel.scale = Vector3.ONE * VIEWMODEL_SCALE
	_disable_shadows(_viewmodel)

func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)

func _physics_process(delta: float) -> void:
	_cooldown -= delta
	_tick_recoil(delta)
	_tick_reload(delta)
	_tick_tracers(delta)

func _tick_recoil(delta: float) -> void:
	if _viewmodel == null:
		return
	_recoil_offset = _recoil_offset.lerp(Vector3.ZERO, RECOIL_RETURN_SPEED * delta)
	_viewmodel.position = VIEWMODEL_POS + _recoil_offset

func _tick_reload(delta: float) -> void:
	if not _is_reloading:
		return
	_reload_timer -= delta
	if _viewmodel:
		var t: float = 1.0 - (_reload_timer / RELOAD_TIME)
		_viewmodel.rotation_degrees.x = _reload_flip_dir * t * 360.0
	if _reload_timer <= 0.0:
		_is_reloading = false
		_ammo = MAX_AMMO
		_reload_flip_dir *= -1.0
		if _viewmodel:
			_viewmodel.rotation_degrees.x = 0.0

func _tick_tracers(delta: float) -> void:
	for i in range(_tracers.size() - 1, -1, -1):
		var t: Dictionary = _tracers[i]
		t.timer -= delta
		if t.timer <= 0.0:
			if is_instance_valid(t.node):
				t.node.queue_free()
			_tracers.remove_at(i)
		else:
			if is_instance_valid(t.node):
				var alpha: float = t.timer / t.lifetime
				(t.node.material_override as StandardMaterial3D).albedo_color = Color(
					TRACER_COLOR.r, TRACER_COLOR.g, TRACER_COLOR.b, alpha
				)

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var seg := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = TRACER_RADIUS
	cyl.bottom_radius = TRACER_RADIUS
	cyl.height = length
	seg.mesh = cyl
	seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = TRACER_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = false
	seg.material_override = mat
	get_tree().current_scene.add_child(seg)
	seg.global_position = (from + to) * 0.5
	var direction := (to - from).normalized()
	var up := Vector3.UP if abs(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right := direction.cross(up).normalized()
	var true_up := right.cross(direction).normalized()
	seg.global_transform.basis = Basis(right, direction, -true_up).orthonormalized()
	_tracers.append({"node": seg, "timer": TRACER_LIFETIME, "lifetime": TRACER_LIFETIME})

func can_fire() -> bool:
	return _cooldown <= 0.0 and not _is_reloading and _ammo > 0

func reload() -> void:
	if _is_reloading or _ammo == MAX_AMMO:
		return
	_is_reloading = true
	_reload_timer = RELOAD_TIME

func fire(multiplier: float, tier: int, exclude_rid: RID) -> bool:
	if _cooldown > 0.0 or _is_reloading:
		return false
	if _ammo <= 0:
		reload()
		return false
	_cooldown = FIRE_COOLDOWN
	_ammo -= 1
	if _ammo == 0:
		reload()
	var space := get_world_3d().direct_space_state
	var muzzle: Node3D = _viewmodel.get_node_or_null("muzzle") if _viewmodel else null
	var muzzle_pos: Vector3 = muzzle.global_position if muzzle else global_position
	var ray_origin := global_position
	var dir := -global_transform.basis.z
	var current_damage := BASE_DAMAGE * multiplier
	var last_hit_rid := exclude_rid
	var is_first_segment := true
	for bounce in range(MAX_BOUNCES + 1):
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + dir * RANGE)
		query.exclude = [last_hit_rid]
		var result := space.intersect_ray(query)
		var end_point: Vector3 = result.position if result else ray_origin + dir * RANGE
		var tracer_from: Vector3 = muzzle_pos if is_first_segment else ray_origin
		_spawn_tracer(tracer_from, end_point)
		is_first_segment = false
		if not result:
			break
		var collider: Object = result.collider
		if collider.has_method("take_damage"):
			collider.take_damage(current_damage, multiplier, tier, result.position)
			target_hit.emit(current_damage, multiplier, tier)
			break
		else:
			dir = dir.bounce(result.normal)
			ray_origin = result.position + result.normal * 0.001
			last_hit_rid = result.rid
			current_damage *= RICOCHET_DAMAGE_FALLOFF
	_recoil_offset += Vector3(0.0, RECOIL_KICK_UP, RECOIL_KICK_BACK)
	return true

func get_ammo() -> int:
	return _ammo

func is_reloading() -> bool:
	return _is_reloading

func _exit_tree() -> void:
	for t in _tracers:
		if is_instance_valid(t.node):
			t.node.queue_free()
