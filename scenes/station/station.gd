extends Node3D

const FpsPlayerScript := preload("res://scenes/player/fps_player.gd")
const CockpitSeatScript := preload("res://scenes/station/cockpit_seat.gd")

const WALL_H := 3.5
const WALL_T := 0.3
const DOOR_W := 2.0
const DOOR_H := 2.2
const SPAWN_POINT := Vector3(0, 0.1, 2)
const COCKPIT_SPAWN := Vector3(26, 0.1, -17)

func _ready() -> void:
	_environment()
	_layout()
	_ship()
	_lights()
	_navmesh()
	_kill_plane()
	_spawn_player()

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.45, 0.55)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _layout() -> void:
	var grey := Color(0.45, 0.48, 0.55)
	var blue := Color(0.35, 0.42, 0.6)
	var rust := Color(0.55, 0.4, 0.35)
	_room(Vector2(0, 0), Vector2(8, 8), grey, ["n"])          # spawn room
	_corridor(Vector2(0, -7), Vector2(3, 6), grey)            # north corridor
	_room(Vector2(0, -16), Vector2(14, 12), blue, ["s", "e"]) # combat room
	_corridor(Vector2(10.5, -16), Vector2(7, 3), grey)        # east corridor
	_room(Vector2(24, -16), Vector2(20, 18), rust, ["w"])     # hangar

func _ship() -> void:
	var hull := Color(0.7, 0.7, 0.75)
	# ship shell inside the hangar, rear (south, +z) open; walk in at z=-12
	_box(Vector3(23.5, 1.25, -16), Vector3(0.3, 2.5, 8), hull)   # west wall
	_box(Vector3(28.5, 1.25, -16), Vector3(0.3, 2.5, 8), hull)   # east wall
	_box(Vector3(26, 2.65, -16), Vector3(5.6, 0.3, 8), hull)     # roof
	_box(Vector3(26, 1.25, -20), Vector3(5, 2.5, 0.3), hull)     # front wall
	var seat = CockpitSeatScript.new()
	seat.position = Vector3(26, 0, -19)
	add_child(seat)

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

func _spawn_player() -> void:
	var player = FpsPlayerScript.new()
	player.position = COCKPIT_SPAWN if GameState.spawn_at_cockpit else SPAWN_POINT
	add_child(player)
	if GameState.spawn_at_cockpit:
		player.rotation.y = PI  # face the ship's open rear
	GameState.spawn_at_cockpit = false

# --- geometry helpers ---

func _room(center: Vector2, size: Vector2, color: Color, doors: Array) -> void:
	_floor_box(center, size, color.darkened(0.4))
	var hx := size.x / 2.0
	var hz := size.y / 2.0
	_wall(Vector3(center.x, 0, center.y - hz), size.x, true, color, doors.has("n"))
	_wall(Vector3(center.x, 0, center.y + hz), size.x, true, color, doors.has("s"))
	_wall(Vector3(center.x - hx, 0, center.y), size.y, false, color, doors.has("w"))
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
