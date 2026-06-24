class_name TargetDummy
extends StaticBody3D

## A shootable practice target. Geometry lives in target_dummy.tscn; on hit it
## flashes, spawns a tiered damage number, and respawns a moment after dying.
## The mesh material is resource_local_to_scene so each target flashes on its own.

const MAX_HEALTH: float = 100.0
const RESPAWN_TIME: float = 2.0
const BASE_COLOR: Color = Color(0.7, 0.2, 0.2)

@onready var _mesh: MeshInstance3D = $Mesh

var _health: float = MAX_HEALTH
var _alive: bool = true
var _material: StandardMaterial3D


func _ready() -> void:
	_material = _mesh.material_override as StandardMaterial3D


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
