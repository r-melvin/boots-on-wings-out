extends "res://tests/test_base.gd"

const HealthScript := preload("res://scripts/health.gd")

func test_starts_at_max() -> void:
	var h = HealthScript.new(30)
	assert_eq(h.hp, 30)
	assert_eq(h.max_hp, 30)
	assert_true(not h.is_dead())

func test_damage_reduces_hp() -> void:
	var h = HealthScript.new(30)
	assert_eq(h.take_damage(10), false, "non-lethal hit returns false")
	assert_eq(h.hp, 20)

func test_killing_blow_returns_true_once() -> void:
	var h = HealthScript.new(30)
	assert_eq(h.take_damage(30), true, "lethal hit returns true")
	assert_true(h.is_dead())
	assert_eq(h.take_damage(10), false, "already dead: no second kill report")
	assert_eq(h.hp, 0, "hp never goes negative")

func test_overkill_clamps_to_zero() -> void:
	var h = HealthScript.new(30)
	h.take_damage(999)
	assert_eq(h.hp, 0)
