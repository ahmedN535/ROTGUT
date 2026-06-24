extends Level

## A code-built level used to test movement and combat. Geometry is generated with
## CSG boxes; gameplay objects are instanced from their scenes (the same scenes Tom
## drags into hand-built maps). Sky + sun come from the Level base.

const COLOR_FLOOR := Color(0.22, 0.28, 0.22)
const COLOR_RAMP := Color(0.35, 0.30, 0.20)
const COLOR_PLATFORM := Color(0.28, 0.22, 0.18)
const COLOR_WALL := Color(0.18, 0.18, 0.22)

const MELEE_RUSHER := preload("res://entities/enemy/melee_rusher.tscn")
const JUMP_PAD := preload("res://entities/jump_pad/jump_pad.tscn")
const TARGET_DUMMY := preload("res://entities/target/target_dummy.tscn")

const ENEMY_RESPAWN_DELAY: float = 2.5
const ENEMY_SPAWNS := [
	Vector3(12, 1.2, 12),
	Vector3(-12, 1.2, 12),
	Vector3(0, 1.2, -20),
]


func _ready() -> void:
	super._ready()  # sky + sun from the Level base
	_add_floor()
	_add_ramps()
	_add_platforms()
	_add_walls()
	_add_grapple_points()
	_add_jump_pads()
	_add_targets()
	_add_enemies()


func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func _box(size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.use_collision = true
	b.position = pos
	b.rotation_degrees = rot_deg
	b.material = _make_mat(color)
	add_child(b)
	return b


func _add_floor() -> void:
	_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0), COLOR_FLOOR)


func _add_ramps() -> void:
	_box(Vector3(10, 0.5, 20), Vector3(12, 1.2, 0), COLOR_RAMP, Vector3(-12, 0, 0))
	_box(Vector3(8, 0.5, 14), Vector3(-14, 2.0, 5), COLOR_RAMP, Vector3(-25, 0, 0))
	_box(Vector3(6, 0.5, 6), Vector3(0, 0.4, -18), COLOR_RAMP, Vector3(-10, 0, 0))


func _add_platforms() -> void:
	_box(Vector3(7, 1, 7), Vector3(0, 3, 16), COLOR_PLATFORM)
	_box(Vector3(6, 1, 6), Vector3(10, 5, 24), COLOR_PLATFORM)
	_box(Vector3(5, 1, 5), Vector3(-8, 7, 30), COLOR_PLATFORM)
	_box(Vector3(4, 1, 4), Vector3(4, 10, 38), COLOR_PLATFORM)
	_box(Vector3(12, 1, 8), Vector3(-18, 4, -10), COLOR_PLATFORM)


func _add_walls() -> void:
	_box(Vector3(1, 10, 30), Vector3(22, 5, 0), COLOR_WALL)
	_box(Vector3(1, 10, 30), Vector3(-22, 5, 0), COLOR_WALL)
	_box(Vector3(14, 2, 1), Vector3(0, 1, -8), COLOR_WALL)


func _add_grapple_points() -> void:
	# Tall pylons + a high beam to swing from. You grapple any geometry, but the
	# swing only shines with high anchors, so the arena needs some overhead mass.
	_box(Vector3(1.5, 16, 1.5), Vector3(10, 8, -2), COLOR_WALL)
	_box(Vector3(1.5, 16, 1.5), Vector3(-10, 8, -2), COLOR_WALL)
	_box(Vector3(22, 1, 1.5), Vector3(0, 15, -2), COLOR_RAMP)   # beam between the pylons
	_box(Vector3(1.5, 22, 1.5), Vector3(0, 11, 34), COLOR_WALL)  # far pylon toward the platforms


func _add_jump_pads() -> void:
	var positions := [
		Vector3(6, 0.2, -14),
		Vector3(-6, 0.2, -14),
		Vector3(0, 0.2, 26),
	]
	for pos: Vector3 in positions:
		var pad := JUMP_PAD.instantiate() as JumpPad
		add_child(pad)
		pad.position = pos


func _add_targets() -> void:
	# Targets sit with their base on the surface (box is 2 tall, so center +1).
	var positions := [
		Vector3(0, 1, 14),       # straight ahead on the floor
		Vector3(10, 1, 8),
		Vector3(-10, 1, 8),
		Vector3(16, 1, -4),
		Vector3(-16, 1, -4),
		Vector3(0, 4.5, 16),     # on the first platform
		Vector3(-18, 5.5, -10),  # on the big platform
	]
	for pos: Vector3 in positions:
		var target := TARGET_DUMMY.instantiate() as TargetDummy
		add_child(target)
		target.position = pos


func _add_enemies() -> void:
	for pos: Vector3 in ENEMY_SPAWNS:
		_spawn_rusher(pos)


func _spawn_rusher(pos: Vector3) -> void:
	var rusher := MELEE_RUSHER.instantiate() as MeleeRusher
	add_child(rusher)
	rusher.position = pos
	# When it dies, queue a fresh one at the same spot — keeps the arena stocked.
	rusher.died.connect(_on_rusher_died.bind(pos))


func _on_rusher_died(pos: Vector3) -> void:
	get_tree().create_timer(ENEMY_RESPAWN_DELAY).timeout.connect(_spawn_rusher.bind(pos))
