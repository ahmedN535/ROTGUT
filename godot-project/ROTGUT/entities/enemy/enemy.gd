class_name Enemy
extends CharacterBody3D

## Base for all enemies. Handles the shared guts: health, taking damage (the same
## take_damage contract the weapon calls on any target), the hit flash, and death.
## Movement and attack behavior live in subclasses (see melee_rusher.gd).
##
## Geometry (collision + mesh + material) lives in the entity's .tscn so it can be
## seen and placed in the editor. Each scene's mesh sets its own colour, which this
## base reads for the flash. The mesh material is resource_local_to_scene, so each
## instance flashes independently.

signal died

const GRAVITY: float = 24.0
const BloodPool = preload("res://entities/enemy/Bloodpool.tscn")  # adjust path

@export var max_health: float = 50.0

@onready var _mesh: MeshInstance3D = $Mesh

var _health: float = 0.0
var _alive: bool = true
var _player: Node3D
var _material: StandardMaterial3D
var _base_color: Color = Color.WHITE


func _ready() -> void:
	_health = max_health
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_material = _mesh.material_override as StandardMaterial3D
	_base_color = _material.albedo_color


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

	if _player and _player.has_method("reset_dash_cooldown"):
		_player.reset_dash_cooldown()

	_spawn_blood_pool()

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.2, 0.1, 1.2), 0.12)
	tween.tween_callback(queue_free)

func _spawn_blood_pool() -> void:
	var pool: Node3D = BloodPool.instantiate()
	get_tree().current_scene.add_child(pool)

	# Raycast straight down from the enemy centre to find the floor.
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.DOWN * 10.0
	)
	query.exclude = [self]  # don't hit our own collider
	var result := space.intersect_ray(query)

	if result:
		pool.global_position = result.position + Vector3.UP * 0.01
	else:
		# Fallback: just use feet position if ray misses
		pool.global_position = global_position + Vector3.UP * 0.01


# Helper for subclasses: flat (horizontal) direction toward the player.
func _dir_to_player() -> Vector3:
	if _player == null:
		return Vector3.ZERO
	var to := _player.global_position - global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.01 else Vector3.ZERO
