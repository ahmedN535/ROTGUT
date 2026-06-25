class_name BloodPool
extends Node3D

@export var radius_min: float = 0.4
@export var radius_max: float = 0.9
@export var fade_in_time: float = 0.35
@export var heal_amount: float = 10.0

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _area: Area3D = $Area

func _ready() -> void:
	var r := randf_range(radius_min, radius_max)
	scale = Vector3(r, 1.0, r)
	rotation.y = randf_range(0.0, TAU)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.0, 0.0, 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	_mesh.material_override = mat

	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.85, fade_in_time) \
		 .set_ease(Tween.EASE_OUT)

	_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body._health < body.MAX_HEALTH:
			body.heal(heal_amount)
			_fade_out_and_free()

func _fade_out_and_free() -> void:
	var mat := _mesh.material_override as StandardMaterial3D
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
