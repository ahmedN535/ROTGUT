class_name Level
extends Node3D

## Base for hand-built levels. Sets up the shared sky + sun so each map doesn't
## re-create them. A level scene then provides its own geometry and drags in
## gameplay objects (the enemy / jump_pad / target scenes) plus a Player spawn.
##
## To make a new map: duplicate level_base.tscn, build geometry, drop in entity
## scenes from the FileSystem dock, and move the Player node to the spawn point.

func _ready() -> void:
	_add_environment()
	_add_lighting()


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.4, 0.55, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.6)
	env.ambient_light_energy = 0.6

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _add_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)
