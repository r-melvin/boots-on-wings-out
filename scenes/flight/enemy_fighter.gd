extends CharacterBody3D

const HealthScript := preload("res://scripts/health.gd")
const BoltScript := preload("res://scenes/flight/bolt.gd")

const SPEED := 45.0
const TURN_RATE := 1.2
const FIRE_RANGE := 250.0
const FIRE_INTERVAL := 0.5
const AIM_DOT := 0.96
const BREAK_RANGE := 40.0

var health = HealthScript.new(30)
var fire_cd := 0.0
var wobble_phase := 0.0
var breaking_off := 0.0

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("enemy_fighter")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 1.5, 5)
	col.shape = shape
	add_child(col)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.25, 0.25)
	for def in [
		[Vector3(0, 0, 0), Vector3(1.6, 1.2, 5)],
		[Vector3(0, 0, 0.8), Vector3(5, 0.2, 1.6)],
	]:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = def[1]
		bm.material = mat
		m.mesh = bm
		m.position = def[0]
		add_child(m)

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player_ship")
	if player == null:
		return
	var to_p: Vector3 = player.global_position - global_position
	var dist := to_p.length()
	wobble_phase += delta
	breaking_off = maxf(breaking_off - delta, 0.0)
	if dist < BREAK_RANGE and breaking_off <= 0.0:
		breaking_off = 2.5
	var desired := to_p.normalized()
	if breaking_off > 0.0:
		desired = -desired
	desired = (desired + global_transform.basis.x * sin(wobble_phase * 1.7) * 0.15).normalized()
	var fwd := -global_transform.basis.z
	var new_fwd := fwd.slerp(desired, clampf(TURN_RATE * delta, 0.0, 1.0)).normalized()
	if absf(new_fwd.dot(Vector3.UP)) < 0.99:
		look_at(global_position + new_fwd)
	velocity = -global_transform.basis.z * SPEED
	move_and_slide()
	fire_cd = maxf(fire_cd - delta, 0.0)
	if breaking_off <= 0.0 and dist < FIRE_RANGE \
			and fwd.dot(to_p.normalized()) > AIM_DOT and fire_cd == 0.0:
		fire_cd = FIRE_INTERVAL
		var b = BoltScript.new()
		b.setup("enemy", global_transform.basis,
			global_position - global_transform.basis.z * 5.0, velocity)
		get_parent().add_child(b)

func take_ship_damage(dmg: int) -> void:
	if health.take_damage(dmg):
		Quips.fighter_kill()
		queue_free()
