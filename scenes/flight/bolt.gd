extends Area3D

const SPEED := 200.0
const DAMAGE := 10
const LIFETIME := 3.0

var team := "player"
var dir := Vector3.FORWARD
var speed := SPEED
var age := 0.0

func setup(p_team: String, p_basis: Basis, pos: Vector3, inherit_vel: Vector3) -> void:
	team = p_team
	dir = -p_basis.z
	position = pos
	speed = SPEED + inherit_vel.dot(dir)

func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	col.shape = shape
	add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.15, 0.15, 2.0)
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.2) if team == "enemy" else Color(0.3, 1.0, 0.4)
	mat.albedo_color = mat.emission
	bm.material = mat
	mesh.mesh = bm
	add_child(mesh)
	if absf(dir.dot(Vector3.UP)) < 0.99:
		look_at(global_position + dir)
	body_entered.connect(_on_hit)

func _physics_process(delta: float) -> void:
	position += dir * speed * delta
	age += delta
	if age > LIFETIME:
		queue_free()

func _on_hit(body: Node3D) -> void:
	if _friendly(body):
		return
	if body.has_method("take_ship_damage"):
		body.take_ship_damage(DAMAGE)
	queue_free()

func _friendly(body: Node) -> bool:
	return (team == "player" and body.is_in_group("player_ship")) \
		or (team == "enemy" and body.is_in_group("enemy_fighter"))
