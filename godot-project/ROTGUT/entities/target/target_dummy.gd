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
	CombatFX.spawn_damage_number(get_tree().current_scene, hit_pos, amount, tier)
	_flash()
	if _health <= 0.0:
		_die()


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
