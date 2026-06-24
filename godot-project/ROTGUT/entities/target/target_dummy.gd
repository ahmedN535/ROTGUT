class_name TargetDummy
extends StaticBody3D

## A shootable practice target. Builds its own collision + mesh in code so it
## can be spawned anywhere without a scene. On hit it flashes, spawns a rising
## damage number colored by tier, and respawns a moment after dying.

const MAX_HEALTH: float = 100.0
const RESPAWN_TIME: float = 2.0
const SIZE: Vector3 = Vector3(1.2, 2.0, 1.2)
const BASE_COLOR: Color = Color(0.7, 0.2, 0.2)

var _health: float = MAX_HEALTH
var _alive: bool = true
var _mesh: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	add_child(shape)

	_mesh = MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = SIZE
	_mesh.mesh = box_mesh
	_material = StandardMaterial3D.new()
	_material.albedo_color = BASE_COLOR
	_mesh.material_override = _material
	add_child(_mesh)


func take_damage(amount: float, _multiplier: float, tier: int, hit_pos: Vector3) -> void:
	if not _alive:
		return
	_health -= amount
	_spawn_damage_number(amount, tier, hit_pos)
	_flash()
	if _health <= 0.0:
		_die()


func _spawn_damage_number(amount: float, tier: int, hit_pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = str(roundi(amount))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true        # draws over geometry so it never hides
	label.fixed_size = true           # stays the same screen size at any range
	label.font_size = 32 + tier * 18  # bigger hits at higher tiers
	label.outline_size = 10
	label.outline_modulate = Color.BLACK
	label.modulate = _tier_color(tier)

	get_tree().current_scene.add_child(label)
	label.global_position = hit_pos + Vector3(0.0, 0.3, 0.0)

	var rise_to := label.global_position + Vector3(0.0, 1.4, 0.0)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", rise_to, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func _flash() -> void:
	_material.albedo_color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_material, "albedo_color", BASE_COLOR, 0.15)


func _die() -> void:
	_alive = false
	_mesh.visible = false
	set_deferred("collision_layer", 0)  # rays pass through while dead
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(_respawn)


func _respawn() -> void:
	_health = MAX_HEALTH
	_alive = true
	_mesh.visible = true
	collision_layer = 1
	_material.albedo_color = BASE_COLOR


func _tier_color(tier: int) -> Color:
	match tier:
		0: return Color(0.85, 0.85, 0.85)
		1: return Color(1.0, 0.9, 0.3)
		2: return Color(1.0, 0.55, 0.15)
		_: return Color(1.0, 0.25, 0.2)
