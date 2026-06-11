extends Node3D

const FpsPlayerScript := preload("res://scenes/player/fps_player.gd")
const PlayerShipScript := preload("res://scenes/flight/player_ship.gd")
const FlightHudScript := preload("res://scenes/flight/flight_hud.gd")
const GruntScript := preload("res://scenes/enemies/grunt.gd")
const EnemyFighterScript := preload("res://scenes/flight/enemy_fighter.gd")
const TexLoaderScript := preload("res://scripts/tex_loader.gd")
const FM := preload("res://scripts/flight_model.gd")

const WALL_H := 3.5
const WALL_T := 0.3
const DOOR_W := 2.0
const DOOR_H := 2.2
const SPAWN_POINT := Vector3(0, 0.1, 2)
const COCKPIT_SPAWN := Vector3(19, 0.1, -16)
const SHIP_PARK := Vector3(24, 0.8, -16)
const LANDING_SPEED_MAX := 8.0
const BOUNDS_RADIUS := 4000.0

# Surfaces a disembarking player can stand on: hangar floor, apron, opening sill (x/z rects).
const WALKABLE_RECTS: Array[Rect2] = [
	Rect2(14, -25, 20, 18),
	Rect2(36, -25, 18, 18),
	Rect2(34, -21, 2, 10),
]

var player: CharacterBody3D
var ship: CharacterBody3D
var flight_hud: CanvasLayer
var landing_zone: Area3D

func _ready() -> void:
	_environment()
	_layout()
	_hull_shell()
	_lights()
	_navmesh()
	_kill_plane()
	_landing_zone()
	_spawn_ship()
	_spawn_player()
	_spawn_grunts()
	_spawn_fighters()
	flight_hud = FlightHudScript.new()
	flight_hud.setup(ship)
	flight_hud.visible = false
	add_child(flight_hud)

func _environment() -> void:
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = TexLoaderScript.get_tex("res://assets/sprites/starfield.png")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.35, 0.45)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 1.2
	add_child(sun)

func _layout() -> void:
	var grey := Color(0.45, 0.48, 0.55)
	var blue := Color(0.35, 0.42, 0.6)
	var rust := Color(0.55, 0.4, 0.35)
	_room(Vector2(0, 0), Vector2(8, 8), grey, ["n"])           # spawn room
	_corridor(Vector2(0, -7), Vector2(3, 6), grey)             # north corridor
	_room(Vector2(0, -16), Vector2(14, 12), blue, ["s", "e"])  # combat room
	_corridor(Vector2(10.5, -16), Vector2(7, 3), grey)         # east corridor
	_room(Vector2(24, -16), Vector2(20, 18), rust, ["w", "-e"]) # hangar, east open to space

func _hull_shell() -> void:
	var hull := Color(0.4, 0.42, 0.5)
	_box(Vector3(12.5, -1.3, -10), Vector3(47, 2, 38), hull)    # floor slab
	_box(Vector3(12.5, 4.25, -10), Vector3(47, 1.5, 38), hull)  # roof slab
	_box(Vector3(12.5, 1.35, -28.5), Vector3(47, 7.3, 1), hull) # north wall
	_box(Vector3(12.5, 1.35, 8.5), Vector3(47, 7.3, 1), hull)   # south wall
	_box(Vector3(-10.5, 1.35, -10), Vector3(1, 7.3, 38), hull)  # west wall
	# east wall with hangar opening (z -21..-11, y 0..3.5)
	_box(Vector3(35, 1.35, -25), Vector3(2, 7.3, 8), hull)      # north of opening
	_box(Vector3(35, 1.35, -1), Vector3(2, 7.3, 20), hull)      # south of opening
	_box(Vector3(35, 4.25, -16), Vector3(2, 1.5, 10), hull)     # lintel
	_box(Vector3(35, -1.15, -16), Vector3(2, 2.3, 10), hull)    # sill, top flush with floor
	_box(Vector3(45, -0.15, -16), Vector3(18, 0.3, 18), Color(0.6, 0.6, 0.3)) # landing apron
	_box(Vector3(50, 2, 10), Vector3(10, 30, 10), Color(0.35, 0.37, 0.45))    # tower

func _lights() -> void:
	for pos in [Vector3(0, 3, 0), Vector3(0, 3, -7), Vector3(0, 3, -16),
			Vector3(10.5, 3, -16), Vector3(20, 3, -12), Vector3(28, 3, -20)]:
		var light := OmniLight3D.new()
		light.position = pos
		light.omni_range = 14.0
		light.light_energy = 1.2
		add_child(light)

func _navmesh() -> void:
	var region := NavigationRegion3D.new()
	var navmesh := NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	navmesh.geometry_source_group_name = "navsource"
	navmesh.agent_radius = 0.5
	region.navigation_mesh = navmesh
	add_child(region)
	region.bake_navigation_mesh.call_deferred()

func _kill_plane() -> void:
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(300, 2, 300)
	col.shape = shape
	area.add_child(col)
	area.position = Vector3(0, -10, 0)
	area.body_entered.connect(_on_kill_plane)
	add_child(area)

func _on_kill_plane(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameState.damage_player(9999)

func _landing_zone() -> void:
	landing_zone = Area3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40, 4, 18)
	col.shape = shape
	landing_zone.add_child(col)
	landing_zone.position = Vector3(34, 1.85, -16)
	add_child(landing_zone)

func _spawn_ship() -> void:
	ship = PlayerShipScript.new()
	ship.position = SHIP_PARK
	add_child(ship)
	ship.look_at(SHIP_PARK + Vector3(1, 0, 0))
	ship.board_requested.connect(_board_ship)

func _spawn_player() -> void:
	player = FpsPlayerScript.new()
	player.position = COCKPIT_SPAWN if GameState.spawn_at_cockpit else SPAWN_POINT
	add_child(player)
	if GameState.spawn_at_cockpit:
		player.rotation.y = -PI / 2  # face the parked ship
	GameState.spawn_at_cockpit = false
	if GameState.just_died:
		GameState.just_died = false
		Quips.say("Walk it off.")

func _spawn_grunts() -> void:
	var placements := [
		["grunt_b1", Vector3(-3, 0.1, -18)],
		["grunt_b2", Vector3(3, 0.1, -13)],
		["grunt_h1", Vector3(20, 0.1, -10)],
	]
	for p in placements:
		if GameState.is_cleared(p[0]):
			continue
		var g = GruntScript.new()
		g.enemy_id = p[0]
		g.position = p[1]
		add_child(g)

func _spawn_fighters() -> void:
	for pos in [Vector3(300, 60, -250), Vector3(-280, -40, -350), Vector3(150, -80, -450)]:
		var f = EnemyFighterScript.new()
		f.position = pos
		add_child(f)

func _board_ship() -> void:
	Quips.say("Wings out, baby.")
	player.set_control_enabled(false)
	ship.activate()
	flight_hud.visible = true
	GameState.enter_flight()

func _exit_ship() -> void:
	Quips.say("Boots on.")
	ship.park()
	Input.action_release("interact")  # same press must not re-trigger seat interact
	player.global_position = _exit_spot()
	var to_ship: Vector3 = ship.global_position - player.global_position
	player.rotation.y = atan2(-to_ship.x, -to_ship.z)
	player.set_control_enabled(true)
	flight_hud.visible = false
	flight_hud.hide_prompt()
	GameState.land()

func _exit_spot() -> Vector3:
	# Try behind, then either side, then ahead of the ship; first clear spot wins.
	var b := ship.global_transform.basis
	for dir in [b.z, -b.x, b.x, -b.z]:
		var d: Vector3 = dir
		d.y = 0.0
		if d.length() < 0.3:
			continue
		var spot: Vector3 = ship.global_position + d.normalized() * 5.0
		spot.y = ship.global_position.y - 0.7
		if _spot_clear(spot):
			return spot
	return COCKPIT_SPAWN  # guaranteed-walkable fallback

func _spot_clear(spot: Vector3) -> bool:
	# Must be over a walkable surface and have open space for the player capsule.
	var on_floor := false
	for r in WALKABLE_RECTS:
		if r.has_point(Vector2(spot.x, spot.z)):
			on_floor = true
			break
	if not on_floor:
		return false
	var space := get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.height = 1.8
	shape.radius = 0.35
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), spot + Vector3(0, 0.95, 0))
	params.exclude = [ship.get_rid(), ship.seat.get_rid()]
	return space.intersect_shape(params, 1).is_empty()

func _physics_process(delta: float) -> void:
	if ship.state != PlayerShipScript.State.ACTIVE:
		return
	_check_exit_prompt()
	_check_bounds(delta)

func _check_exit_prompt() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		flight_hud.hide_prompt()
		return
	if FM.can_land(landing_zone.overlaps_body(ship), ship.velocity.length(), LANDING_SPEED_MAX):
		flight_hud.show_prompt("[E] Exit ship")
		if Input.is_action_just_pressed("interact"):
			_exit_ship()
	else:
		flight_hud.hide_prompt()

func _check_bounds(delta: float) -> void:
	var out := ship.global_position.length() > BOUNDS_RADIUS
	flight_hud.set_warning(out)
	if out:
		ship.velocity -= ship.global_position.normalized() * 120.0 * delta

# --- geometry helpers ---

func _room(center: Vector2, size: Vector2, color: Color, doors: Array) -> void:
	# doors: "n"/"s"/"e"/"w" puts a doorway in that wall; "-e" etc. omits the wall.
	_floor_box(center, size, color.darkened(0.4))
	var hx := size.x / 2.0
	var hz := size.y / 2.0
	if not doors.has("-n"):
		_wall(Vector3(center.x, 0, center.y - hz), size.x, true, color, doors.has("n"))
	if not doors.has("-s"):
		_wall(Vector3(center.x, 0, center.y + hz), size.x, true, color, doors.has("s"))
	if not doors.has("-w"):
		_wall(Vector3(center.x - hx, 0, center.y), size.y, false, color, doors.has("w"))
	if not doors.has("-e"):
		_wall(Vector3(center.x + hx, 0, center.y), size.y, false, color, doors.has("e"))

func _corridor(center: Vector2, size: Vector2, color: Color) -> void:
	# corridors draw only side walls; the rooms they join own the door walls
	_floor_box(center, size, color.darkened(0.4))
	if size.x < size.y:
		_wall(Vector3(center.x - size.x / 2.0, 0, center.y), size.y, false, color, false)
		_wall(Vector3(center.x + size.x / 2.0, 0, center.y), size.y, false, color, false)
	else:
		_wall(Vector3(center.x, 0, center.y - size.y / 2.0), size.x, true, color, false)
		_wall(Vector3(center.x, 0, center.y + size.y / 2.0), size.x, true, color, false)

func _floor_box(center: Vector2, size: Vector2, color: Color) -> void:
	var m := _box(Vector3(center.x, -0.15, center.y), Vector3(size.x, 0.3, size.y), color)
	m.add_to_group("navsource")

func _wall(base: Vector3, length: float, along_x: bool, color: Color, door: bool) -> void:
	if not door:
		_wall_seg(base, length, along_x, WALL_H / 2.0, WALL_H, color)
		return
	var seg := (length - DOOR_W) / 2.0
	var off := (DOOR_W + seg) / 2.0
	var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	_wall_seg(base + axis * off, seg, along_x, WALL_H / 2.0, WALL_H, color)
	_wall_seg(base - axis * off, seg, along_x, WALL_H / 2.0, WALL_H, color)
	_wall_seg(base, DOOR_W, along_x, DOOR_H + (WALL_H - DOOR_H) / 2.0, WALL_H - DOOR_H, color)

func _wall_seg(base: Vector3, length: float, along_x: bool, y_center: float, height: float, color: Color) -> void:
	var size := Vector3(length, height, WALL_T) if along_x else Vector3(WALL_T, height, length)
	_box(base + Vector3(0, y_center, 0), size, color)

func _box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
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
	return mesh
