extends RefCounted

const MAX_SPEED := 80.0
const REVERSE_FRACTION := 0.25
const THROTTLE_RATE := 0.8
const ACCEL_RESPONSE := 1.5
const BRAKE_RESPONSE := 3.0

static func update_throttle(throttle: float, axis: float, delta: float) -> float:
	return clampf(throttle + axis * THROTTLE_RATE * delta, -REVERSE_FRACTION, 1.0)

static func update_velocity(velocity: Vector3, forward: Vector3, throttle: float, braking: bool, delta: float) -> Vector3:
	var target := Vector3.ZERO if braking else forward * throttle * MAX_SPEED
	var response := BRAKE_RESPONSE if braking else ACCEL_RESPONSE
	return velocity.lerp(target, 1.0 - exp(-response * delta))
