extends Node

enum Mode { FPS, FLIGHT }

const WORLD_SCENE := "res://scenes/world/world.tscn"
const MAX_HEALTH := 100
const MAX_HULL := 100

var mode: Mode = Mode.FPS
var player_health: int = MAX_HEALTH
var ship_hull: int = MAX_HULL
var spawn_at_cockpit := false
var just_died := false
var cleared_enemies: Dictionary = {}

func enter_flight() -> void:
	mode = Mode.FLIGHT

func land() -> void:
	mode = Mode.FPS

func damage_player(amount: int) -> bool:
	player_health = maxi(player_health - amount, 0)
	if player_health == 0:
		_player_died()
		return true
	return false

func damage_ship(amount: int) -> bool:
	ship_hull = maxi(ship_hull - amount, 0)
	if ship_hull == 0:
		_ship_destroyed()
		return true
	return false

func mark_cleared(enemy_id: String) -> void:
	cleared_enemies[enemy_id] = true

func is_cleared(enemy_id: String) -> bool:
	return cleared_enemies.has(enemy_id)

func _player_died() -> void:
	player_health = MAX_HEALTH
	spawn_at_cockpit = false
	just_died = true
	mode = Mode.FPS
	_change_scene(WORLD_SCENE)

func _ship_destroyed() -> void:
	ship_hull = MAX_HULL
	spawn_at_cockpit = true
	mode = Mode.FPS
	_change_scene(WORLD_SCENE)

func _change_scene(path: String) -> void:
	# No-op outside the tree so pure-logic tests can instantiate this script.
	if is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(path)
