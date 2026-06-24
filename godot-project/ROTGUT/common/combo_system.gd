class_name ComboSystem
extends Node

## Global style/combo meter — Pillar 3. Style builds from kills (more for faster,
## higher-tier kills) and is sustained by moving fast; it decays when you're slow
## and idle, and drains hard when you take a hit. The rank it produces is the seed
## of the game's escalating visual feedback; v1 surfaces it on the HUD.
##
## Registered as the "Combo" autoload, so any script can call Combo.add_kill(),
## Combo.on_player_hurt(), Combo.get_rank() etc. without wiring node references.

signal rank_changed(rank: int)

const MAX_POINTS: float = 120.0
const KILL_POINTS: float = 30.0      # base style per kill — kills are the driver
const TIER_BONUS: float = 12.0       # extra per speed tier at the moment of the kill
const DECAY_PER_SEC: float = 12.0    # bleed-off when slow and not killing
const DAMAGE_DRAIN: float = 40.0     # style lost per hit taken
const FAST_SPEED: float = 18.0       # at/above this, speed SUSTAINS the combo (halts decay)

# Points needed for each rank, with ROTGUT-flavored names (rank 0 shows nothing).
# First kill (>= KILL_POINTS) should land you at rank 1 for instant feedback.
const RANK_POINTS: Array[float] = [0.0, 20.0, 50.0, 85.0, 110.0]
const RANK_NAMES: Array[String] = ["", "RILED", "WIRED", "RABID", "ROTTEN"]

var _points: float = 0.0
var _rank: int = 0
var _player: CharacterBody3D


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D

	# Moving fast SUSTAINS the combo (halts decay) but no longer builds it — kills
	# are the only thing that climbs rank. Stops you maxing out by just falling or
	# bhopping in circles.
	var flowing := _player != null and _horizontal_speed() >= FAST_SPEED
	if not flowing:
		_points = maxf(_points - DECAY_PER_SEC * delta, 0.0)

	_recalc_rank()


func add_kill(tier: int) -> void:
	_add(KILL_POINTS + TIER_BONUS * tier)
	_recalc_rank()


func on_player_hurt() -> void:
	_points = maxf(_points - DAMAGE_DRAIN, 0.0)
	_recalc_rank()


func get_points() -> float:
	return _points


func get_rank() -> int:
	return _rank


func get_rank_name() -> String:
	return RANK_NAMES[_rank]


func _add(amount: float) -> void:
	_points = clampf(_points + amount, 0.0, MAX_POINTS)


func _horizontal_speed() -> float:
	var v := _player.velocity
	return Vector2(v.x, v.z).length()


func _recalc_rank() -> void:
	var new_rank := 0
	for i in RANK_POINTS.size():
		if _points >= RANK_POINTS[i]:
			new_rank = i
	if new_rank != _rank:
		_rank = new_rank
		rank_changed.emit(_rank)
