extends Node3D

const PlayerShipScript := preload("res://scenes/flight/player_ship.gd")
const FlightHudScript := preload("res://scenes/flight/flight_hud.gd")
const TexLoaderScript := preload("res://scripts/tex_loader.gd")
const EnemyFighterScript := preload("res://scenes/flight/enemy_fighter.gd")

const LANDING_SPEED_MAX := 8.0
const BOUNDS_RADIUS := 4000.0

var ship: CharacterBody3D
var hud: CanvasLayer
var pad_area: Area3D

func _ready() -> void:
	_environment()
	_station_exterior()
	_spawn_ship()
	hud = FlightHudScript.new()
	hud.setup(ship)
	add_child(hud)
	_spawn_fighters()

func _environment() -> void:
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = TexLoaderScript.get_tex("res://assets/sprites/starfield.png")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.25, 0.35)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 1.2
	add_child(sun)

func _station_exterior() -> void:
	_big_box(Vector3(0, 0, 0), Vector3(60, 20, 60), Color(0.4, 0.42, 0.5))    # main hull
	_big_box(Vector3(0, 11, 0), Vector3(20, 2, 20), Color(0.6, 0.6, 0.3))     # landing pad
	_big_box(Vector3(35, 5, 0), Vector3(10, 30, 10), Color(0.35, 0.37, 0.45)) # tower
	pad_area = Area3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(18, 8, 18)
	col.shape = shape
	pad_area.add_child(col)
	pad_area.position = Vector3(0, 16, 0)
	add_child(pad_area)

func _spawn_ship() -> void:
	ship = PlayerShipScript.new()
	ship.position = Vector3(0, 15, 60)
	add_child(ship)
	ship.look_at(Vector3(0, 15, 500))

func _physics_process(delta: float) -> void:
	_check_landing()
	_check_bounds(delta)

func _check_landing() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		hud.hide_prompt()
		return
	var can_land: bool = pad_area.overlaps_body(ship) \
		and ship.velocity.length() < LANDING_SPEED_MAX
	if can_land:
		hud.show_prompt("[E] Land")
		if Input.is_action_just_pressed("interact"):
			GameState.land()
	else:
		hud.hide_prompt()

func _check_bounds(delta: float) -> void:
	var out := ship.global_position.length() > BOUNDS_RADIUS
	hud.set_warning(out)
	if out:
		ship.velocity -= ship.global_position.normalized() * 120.0 * delta

func _big_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mesh.mesh = bm
	mesh.position = pos
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	mesh.add_child(body)
	add_child(mesh)

func _spawn_fighters() -> void:
	for pos in [Vector3(300, 60, -250), Vector3(-280, -40, -350), Vector3(150, -80, -450)]:
		var f = EnemyFighterScript.new()
		f.position = pos
		add_child(f)
