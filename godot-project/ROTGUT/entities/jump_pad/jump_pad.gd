class_name JumpPad
extends Area3D
## A boost pad. Launches the player in the direction the pad is facing,
## defaulting to straight up (rotate the node in the editor to aim it).
## Geometry lives in jump_pad.tscn.

const LAUNCH_FORCE: float = 30

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("apply_jump_pad"):
		var direction := global_transform.basis.y
		body.apply_jump_pad(LAUNCH_FORCE, direction)
