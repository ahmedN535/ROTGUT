class_name Weapon
extends Node3D

## Hitscan weapon. Knows nothing about the player's speed — it is handed a
## damage multiplier and tier when told to fire (spec: calls go DOWN).
## When it deals damage it reports back up via the target_hit signal.

signal target_hit(damage: float, multiplier: float, tier: int)

const RANGE: float = 200.0
const BASE_DAMAGE: float = 20.0
const FIRE_COOLDOWN: float = 0.35

# Viewmodel — the visible gun. The Weapon node itself stays at the camera's
# identity so the raycast fires from screen center; only the model is offset.
const VIEWMODEL_PATH: String = "res://weapons/revolver.glb"
const VIEWMODEL_POS: Vector3 = Vector3(0.18, -0.15, -0.45)
const VIEWMODEL_ROT: Vector3 = Vector3(0, 180, 0)  # glTF export faced the muzzle at +Z; flip it forward
const VIEWMODEL_SCALE: float = 1.0  # bump to ~1.2–1.4 for an oversized read

var _cooldown: float = 0.0
var _viewmodel: Node3D


func _ready() -> void:
	_setup_viewmodel()


func _setup_viewmodel() -> void:
	var scene := load(VIEWMODEL_PATH) as PackedScene
	if scene == null:
		push_warning("Weapon: viewmodel not found/imported at %s" % VIEWMODEL_PATH)
		return
	_viewmodel = scene.instantiate()
	add_child(_viewmodel)
	_viewmodel.position = VIEWMODEL_POS
	_viewmodel.rotation_degrees = VIEWMODEL_ROT
	_viewmodel.scale = Vector3.ONE * VIEWMODEL_SCALE
	_disable_shadows(_viewmodel)


# A viewmodel shouldn't cast shadows into the world. (Drawing it on top of
# geometry to avoid wall clipping needs a separate viewmodel camera — that's a
# later polish step, not needed for this blockout scale-test.)
func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)


func _physics_process(delta: float) -> void:
	_cooldown -= delta


func can_fire() -> bool:
	return _cooldown <= 0.0


## Fires from this node's own transform. Because the weapon is parented to the
## camera, that means it fires straight down the crosshair. Returns true if a
## shot actually went off (so the player knows to apply recoil).
func fire(multiplier: float, tier: int, exclude_rid: RID) -> bool:
	if _cooldown > 0.0:
		return false
	_cooldown = FIRE_COOLDOWN

	var space := get_world_3d().direct_space_state
	var origin := global_position
	var dir := -global_transform.basis.z  # -Z is forward in Godot
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * RANGE)
	query.exclude = [exclude_rid]  # don't hit ourselves

	var result := space.intersect_ray(query)
	if result:
		var collider: Object = result.collider
		var damage := BASE_DAMAGE * multiplier
		if collider.has_method("take_damage"):
			collider.take_damage(damage, multiplier, tier, result.position)
			target_hit.emit(damage, multiplier, tier)

	return true
