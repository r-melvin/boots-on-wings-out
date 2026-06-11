extends CharacterBody3D

const FM := preload("res://scripts/flight_model.gd")
const BoltScript := preload("res://scenes/flight/bolt.gd")
const SeatScript := preload("res://scenes/world/cockpit_seat.gd")

enum State { PARKED, ACTIVE }

const ROLL_SPEED := 1.8
const MOUSE_SENS := 0.0015
const FIRE_INTERVAL := 0.15
const PARK_HEIGHT := 0.8

signal board_requested

var state := State.PARKED
var throttle := 0.0
var mouse_delta := Vector2.ZERO
var fire_cd := 0.0
var cam: Camera3D
var seat: StaticBody3D

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("player_ship")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5, 1.5, 6.0)
	col.shape = shape
	add_child(col)
	_build_mesh()
	cam = Camera3D.new()
	cam.position = Vector3(0, 2.2, 7.0)
	cam.far = 8000.0
	add_child(cam)
	seat = SeatScript.new()
	seat.position = Vector3(0, -0.8, 3.2)
	add_child(seat)
	seat.activated.connect(func(): board_requested.emit())

func _build_mesh() -> void:
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.7, 0.7, 0.75)
	for def in [
		[Vector3(0, 0, 0), Vector3(2, 1.4, 6)],
		[Vector3(0, 0, 0.5), Vector3(6, 0.2, 2)],
		[Vector3(0, 0.6, -1.5), Vector3(1, 0.6, 1.5)],
	]:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = def[1]
		bm.material = hull_mat
		m.mesh = bm
		m.position = def[0]
		add_child(m)

func activate() -> void:
	state = State.ACTIVE
	throttle = 0.0
	cam.current = true
	seat.set_enabled(false)

func park() -> void:
	state = State.PARKED
	velocity = Vector3.ZERO
	mouse_delta = Vector2.ZERO
	throttle = 0.0
	cam.current = false
	_level_out()
	_settle_to_ground()
	seat.set_enabled(true)

func _level_out() -> void:
	# Keep yaw, zero pitch/roll, so the seat ends up at floor level.
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() > 0.1:
		look_at(global_position + fwd.normalized())

func _settle_to_ground() -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position, global_position + Vector3.DOWN * 12.0)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit:
		global_position.y = hit.position.y + PARK_HEIGHT

func _unhandled_input(event: InputEvent) -> void:
	if state == State.ACTIVE and event is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_delta += event.relative

func _physics_process(delta: float) -> void:
	if state != State.ACTIVE:
		return
	rotate_object_local(Vector3.RIGHT, -mouse_delta.y * MOUSE_SENS)
	rotate_object_local(Vector3.UP, -mouse_delta.x * MOUSE_SENS)
	mouse_delta = Vector2.ZERO
	var roll := Input.get_action_strength("roll_left") - Input.get_action_strength("roll_right")
	rotate_object_local(Vector3(0, 0, -1), roll * ROLL_SPEED * delta)
	orthonormalize()
	var axis := Input.get_action_strength("throttle_up") - Input.get_action_strength("throttle_down")
	throttle = FM.update_throttle(throttle, axis, delta)
	var braking := Input.is_action_pressed("brake")
	if braking:
		throttle = move_toward(throttle, 0.0, delta)
	velocity = FM.update_velocity(velocity, -global_transform.basis.z, throttle, braking, delta)
	move_and_slide()
	fire_cd = maxf(fire_cd - delta, 0.0)
	if Input.is_action_pressed("fire") and fire_cd == 0.0 \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		fire_cd = FIRE_INTERVAL
		_fire()

func _fire() -> void:
	for offset in [Vector3(-1.8, 0, 0), Vector3(1.8, 0, 0)]:
		var b = BoltScript.new()
		b.setup("player", global_transform.basis,
			global_position + global_transform.basis * offset - global_transform.basis.z * 4.0,
			velocity)
		get_parent().add_child(b)

func take_ship_damage(dmg: int) -> void:
	GameState.damage_ship(dmg)
