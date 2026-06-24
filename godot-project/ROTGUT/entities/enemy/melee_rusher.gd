class_name MeleeRusher
extends Enemy

## The first enemy: sprints straight at the player and hits on contact. Forces you
## to keep moving — standing still gets you caught and chipped down.

const MOVE_SPEED: float = 8.0
const ATTACK_RANGE: float = 1.7
const ATTACK_DAMAGE: float = 12.0
const ATTACK_COOLDOWN: float = 0.8

var _attack_timer: float = 0.0


func _build_body() -> void:
	_base_color = Color(0.5, 0.2, 0.55)  # purple, distinct from the red target dummies
	super()


func _physics_process(delta: float) -> void:
	_attack_timer -= delta

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _alive and _player != null:
		var dir := _dir_to_player()
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED

		if global_position.distance_to(_player.global_position) <= ATTACK_RANGE and _attack_timer <= 0.0:
			_attack()
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()


func _attack() -> void:
	_attack_timer = ATTACK_COOLDOWN
	if _player.has_method("take_damage"):
		_player.take_damage(ATTACK_DAMAGE)
