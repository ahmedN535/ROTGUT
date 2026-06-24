class_name JumpPad
extends Area3D

## A boost pad. When the player touches it, it launches them straight up while
## keeping their horizontal speed (spec: "launches the player upward with speed
## carry"). Built in code so it can be dropped into a level without a scene.

const SIZE: Vector3 = Vector3(3.0, 0.3, 3.0)
const LAUNCH_FORCE: float = 18.0
const COLOR: Color = Color(0.3, 0.8, 1.0)


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	add_child(shape)

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = SIZE
	mesh.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.emission_enabled = true
	mat.emission = COLOR
	mat.emission_energy_multiplier = 1.5
	mesh.material_override = mat
	add_child(mesh)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("apply_jump_pad"):
		body.apply_jump_pad(LAUNCH_FORCE)
