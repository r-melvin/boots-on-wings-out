extends "res://tests/test_base.gd"

const GS := preload("res://autoload/game_state.gd")

func test_initial_state() -> void:
	var gs = GS.new()
	assert_eq(gs.mode, GS.Mode.FPS)
	assert_eq(gs.player_health, GS.MAX_HEALTH)
	assert_eq(gs.ship_hull, GS.MAX_HULL)
	assert_eq(gs.spawn_at_cockpit, false)
	gs.free()

func test_enter_flight_and_land() -> void:
	var gs = GS.new()
	gs.enter_flight()
	assert_eq(gs.mode, GS.Mode.FLIGHT)
	gs.land()
	assert_eq(gs.mode, GS.Mode.FPS)
	assert_eq(gs.spawn_at_cockpit, false, "seamless landing needs no respawn flag")
	gs.free()

func test_damage_player_non_lethal() -> void:
	var gs = GS.new()
	assert_eq(gs.damage_player(30), false)
	assert_eq(gs.player_health, 70)
	gs.free()

func test_player_death_resets() -> void:
	var gs = GS.new()
	gs.spawn_at_cockpit = true
	assert_eq(gs.damage_player(999), true)
	assert_eq(gs.player_health, GS.MAX_HEALTH, "respawn with full health")
	assert_eq(gs.spawn_at_cockpit, false, "respawn at station entrance")
	assert_eq(gs.mode, GS.Mode.FPS)
	gs.free()

func test_ship_destroyed_resets_hull_and_docks() -> void:
	var gs = GS.new()
	gs.enter_flight()
	assert_eq(gs.damage_ship(999), true)
	assert_eq(gs.ship_hull, GS.MAX_HULL)
	assert_eq(gs.mode, GS.Mode.FPS)
	assert_eq(gs.spawn_at_cockpit, true, "ship loss respawns docked at cockpit")
	gs.free()

func test_cleared_enemies_persist() -> void:
	var gs = GS.new()
	assert_eq(gs.is_cleared("g1"), false)
	gs.mark_cleared("g1")
	assert_true(gs.is_cleared("g1"))
	assert_eq(gs.is_cleared("g2"), false)
	gs.free()
