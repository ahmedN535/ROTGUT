class_name JumpPad
extends Area3D

## A boost pad. When the player touches it, it launches them straight up while
## keeping horizontal speed (spec: "launches the player upward with speed carry").
## Geometry lives in jump_pad.tscn.

const LAUNCH_FORCE: float = 18.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("apply_jump_pad"):
		body.apply_jump_pad(LAUNCH_FORCE)
