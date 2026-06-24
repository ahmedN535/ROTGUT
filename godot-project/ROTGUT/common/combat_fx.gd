class_name CombatFX
extends RefCounted

## Shared combat feedback: speed-tier colors/names and floating damage numbers.
## Tiers come from the player's speed -> damage multiplier. All static — call as
## CombatFX.tier_color(t), no instance needed.


static func tier_color(tier: int) -> Color:
	match tier:
		0: return Color(0.85, 0.85, 0.85)
		1: return Color(1.0, 0.9, 0.3)
		2: return Color(1.0, 0.55, 0.15)
		_: return Color(1.0, 0.25, 0.2)


static func tier_name(tier: int) -> String:
	match tier:
		0: return "COLD"
		1: return "WARM"
		2: return "HOT"
		_: return "BLAZING"


## Spawns a rising, fading damage number at a world position. `parent` should be
## a live node in the current scene (the number lives independently of whatever
## was hit, so it survives that thing dying).
static func spawn_damage_number(parent: Node, world_pos: Vector3, amount: float, tier: int) -> void:
	var label := Label3D.new()
	label.text = str(roundi(amount))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true        # draws over geometry so it never hides
	label.fixed_size = true           # same screen size at any range
	label.font_size = 32 + tier * 18  # bigger hits at higher tiers
	label.outline_size = 10
	label.outline_modulate = Color.BLACK
	label.modulate = tier_color(tier)

	parent.add_child(label)
	label.global_position = world_pos + Vector3(0.0, 0.3, 0.0)

	var rise_to := label.global_position + Vector3(0.0, 1.4, 0.0)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", rise_to, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
