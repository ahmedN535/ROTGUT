class_name Enemy
extends CharacterBody3D

## Base for all enemies. Handles the shared guts: health, taking damage (the same
## take_damage contract the weapon calls on any target), the hit flash, and death.
## Movement and attack behavior live in subclasses (see melee_rusher.gd) so adding
## a new enemy type is "extend Enemy + add a _physics_process".

signal died

const GRAVITY: float = 24.0

@export var max_health: float = 50.0

var _health: float = 0.0
var _alive: bool = true
var _player: Node3D
var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _base_color: Color = Color(0.35, 0.5, 0.3)


func _ready() -> void:
	_health = max_health
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_build_body()


# Subclasses can override to change shape/look; default is a sickly capsule.
func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	add_child(shape)

	_mesh = MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.4
	capsule_mesh.height = 1.8
	_mesh.mesh = capsule_mesh
	_material = StandardMaterial3D.new()
	_material.albedo_color = _base_color
	_mesh.material_override = _material
	add_child(_mesh)


# Same signature the weapon calls on any hittable thing.
func take_damage(amount: float, _multiplier: float, tier: int, hit_pos: Vector3) -> void:
	if not _alive:
		return
	_health -= amount
	CombatFX.spawn_damage_number(get_tree().current_scene, hit_pos, amount, tier)
	_flash()
	if _health <= 0.0:
		Combo.add_kill(tier)  # faster (higher-tier) kills feed more style
		_die()


func _flash() -> void:
	_material.albedo_color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_material, "albedo_color", _base_color, 0.12)


func _die() -> void:
	_alive = false
	died.emit()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.2, 0.1, 1.2), 0.12)
	tween.tween_callback(queue_free)


# Helper for subclasses: flat (horizontal) direction toward the player.
func _dir_to_player() -> Vector3:
	if _player == null:
		return Vector3.ZERO
	var to := _player.global_position - global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.01 else Vector3.ZERO
