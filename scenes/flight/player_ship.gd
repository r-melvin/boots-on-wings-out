extends CharacterBody3D

const FM := preload("res://scripts/flight_model.gd")
const BoltScript := preload("res://scenes/flight/bolt.gd")

const ROLL_SPEED := 1.8
const MOUSE_SENS := 0.0015
const FIRE_INTERVAL := 0.15

var throttle := 0.2
var mouse_delta := Vector2.ZERO
var fire_cd := 0.0

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("player_ship")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5, 1.5, 6.0)
	col.shape = shape
	add_child(col)
	_build_mesh()
	var cam := Camera3D.new()
	cam.current = true
	cam.position = Vector3(0, 2.2, 7.0)
	cam.far = 8000.0
	add_child(cam)

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_delta += event.relative

func _physics_process(delta: float) -> void:
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
