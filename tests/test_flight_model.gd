extends "res://tests/test_base.gd"

const FM := preload("res://scripts/flight_model.gd")

func test_throttle_clamps_high() -> void:
	assert_almost(FM.update_throttle(0.9, 1.0, 1.0), 1.0)

func test_throttle_clamps_reverse() -> void:
	assert_almost(FM.update_throttle(-0.2, -1.0, 1.0), -FM.REVERSE_FRACTION)

func test_velocity_converges_to_target() -> void:
	var v := Vector3.ZERO
	for i in 600:
		v = FM.update_velocity(v, Vector3.FORWARD, 1.0, false, 1.0 / 60.0)
	assert_true(v.distance_to(Vector3.FORWARD * FM.MAX_SPEED) < 1.0,
		"after 10s at full throttle, near max speed; got %s" % v)

func test_brake_decays_speed() -> void:
	var v := Vector3.FORWARD * 50.0
	var v2 := FM.update_velocity(v, Vector3.FORWARD, 1.0, true, 1.0 / 60.0)
	assert_true(v2.length() < v.length(), "braking shrinks speed")

func test_drift_on_turn() -> void:
	# at max speed, snap nose 90 degrees: one frame later velocity still mostly old direction
	var v := Vector3.FORWARD * FM.MAX_SPEED
	var v2 := FM.update_velocity(v, Vector3.RIGHT, 1.0, false, 1.0 / 60.0)
	assert_true(v2.normalized().dot(Vector3.FORWARD) > 0.9, "velocity lags the nose (drift)")

func test_can_land_requires_zone_and_low_speed() -> void:
	assert_true(FM.can_land(true, 5.0, 8.0))
	assert_eq(FM.can_land(false, 5.0, 8.0), false, "must be in landing zone")
	assert_eq(FM.can_land(true, 9.0, 8.0), false, "too fast to land")
	assert_eq(FM.can_land(true, 8.0, 8.0), false, "boundary speed is not landable")
