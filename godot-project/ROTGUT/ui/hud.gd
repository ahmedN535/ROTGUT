class_name HUD
extends CanvasLayer

## All on-screen feedback, split out of the player. Layout lives in hud.tscn
## (editable in the editor); this script fills in the live values, runs the combo
## glow + rank-up punch, and the hurt flash. The player just instances it and
## calls set_stats()/flash_damage(); combo state is read straight from the Combo
## autoload.

const COMBO_BAR_WIDTH: float = 220.0

@onready var _glow: ColorRect = $Glow
@onready var _speed_label: Label = $SpeedLabel
@onready var _crosshair: Label = $Crosshair
@onready var _health_label: Label = $HealthLabel
@onready var _combo_label: Label = $ComboLabel
@onready var _combo_bar_fill: ColorRect = $ComboBarFill
@onready var _damage_overlay: ColorRect = $DamageOverlay
@onready var _rank_pop_label: Label = $RankPop

var _glow_mat: ShaderMaterial
var _glow_intensity: float = 0.0
var _glow_pulse: float = 0.0
var _rank_pop_tween: Tween
var _last_rank: int = 0


func _ready() -> void:
	_style()
	_setup_glow()
	Combo.rank_changed.connect(_on_rank_changed)


func _style() -> void:
	_crosshair.add_theme_font_size_override("font_size", 28)
	_crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_health_label.add_theme_font_size_override("font_size", 20)
	_health_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	_combo_label.add_theme_font_size_override("font_size", 26)
	_rank_pop_label.add_theme_font_size_override("font_size", 64)


func _setup_glow() -> void:
	# Screen-edge glow shader, built in code and assigned to the Glow rect.
	_glow_mat = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\n" \
		+ "uniform vec4 glow_color : source_color = vec4(1.0, 0.3, 0.2, 1.0);\n" \
		+ "uniform float intensity : hint_range(0.0, 1.0) = 0.0;\n" \
		+ "void fragment() {\n" \
		+ "	float d = distance(UV, vec2(0.5));\n" \
		+ "	float edge = smoothstep(0.30, 0.78, d);\n" \
		+ "	COLOR = vec4(glow_color.rgb, edge * intensity);\n" \
		+ "}\n"
	_glow_mat.shader = shader
	_glow.material = _glow_mat


func _process(delta: float) -> void:
	# Combo escalation, driven straight off the Combo autoload.
	var rank := Combo.get_rank()
	var col := CombatFX.tier_color(mini(rank, 3))

	var target := minf(rank * 0.16, 0.65)
	_glow_intensity = lerpf(_glow_intensity, target, 4.0 * delta)
	_glow_pulse = lerpf(_glow_pulse, 0.0, 6.0 * delta)
	_glow_mat.set_shader_parameter("intensity", clampf(_glow_intensity + _glow_pulse, 0.0, 1.0))
	_glow_mat.set_shader_parameter("glow_color", col)

	_combo_label.text = Combo.get_rank_name()
	_combo_label.add_theme_color_override("font_color", col)
	_combo_bar_fill.size.x = COMBO_BAR_WIDTH * (Combo.get_points() / ComboSystem.MAX_POINTS)
	_combo_bar_fill.color = col


# Player pushes its own stats here each physics frame.
func set_stats(speed: float, dash_status: String, is_grappling: bool, mult: float, tier: int, health: float) -> void:
	var hook_tag := "   [HOOK]" if is_grappling else ""
	_speed_label.text = "Speed: %.1f   Dash: %s%s\nDMG x%.1f   %s" % [
		speed, dash_status, hook_tag, mult, CombatFX.tier_name(tier)
	]
	_speed_label.modulate = CombatFX.tier_color(tier)
	_health_label.text = "HP: %d" % roundi(health)


func flash_damage() -> void:
	_damage_overlay.color.a = 0.5
	var tween := create_tween()
	tween.tween_property(_damage_overlay, "color:a", 0.0, 0.4)


func _on_rank_changed(rank: int) -> void:
	# Punch only when climbing to a new, higher rank.
	if rank > _last_rank and rank > 0:
		_rank_pop_label.text = Combo.get_rank_name()
		_rank_pop_label.add_theme_color_override("font_color", CombatFX.tier_color(mini(rank, 3)))
		_rank_pop_label.modulate.a = 1.0
		if _rank_pop_tween != null and _rank_pop_tween.is_valid():
			_rank_pop_tween.kill()
		_rank_pop_tween = create_tween()
		_rank_pop_tween.tween_property(_rank_pop_label, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
		_glow_pulse = 0.45
	_last_rank = rank
