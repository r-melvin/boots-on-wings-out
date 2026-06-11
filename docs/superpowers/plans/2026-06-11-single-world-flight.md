# Single-World Flight + Web Mouse Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge the FPS station scene and space flight scene into one continuous world (walk → board ship → fly out → land → walk), and make mouse capture work on web exports via click-to-capture.

**Architecture:** A new `scenes/world/world.gd` procedurally builds interior rooms, an enclosing hull shell with a hangar opening to space, and all actors. The player ship gains PARKED/ACTIVE states; boarding hides/disables the FPS player and activates the ship — no scene change. A `mouse_capture` autoload owns pointer-lock logic (click captures, Esc releases) because browsers only grant pointer lock from a user gesture.

**Tech Stack:** Godot 4.6 (GDScript, Jolt physics). Tests run headless via `godot --headless --path . --script tests/run_tests.gd`. Spec: `docs/superpowers/specs/2026-06-11-single-world-flight-design.md`.

**Conventions:** All geometry is procedural (BoxMesh + StaticBody3D), no .tscn content beyond a root node with script. Tests are pure-logic only (RefCounted scripts, no scene tree). Run the full suite after every task; baseline is 15 tests, 0 assertion failures.

---

### Task 1: Web-safe mouse capture autoload

Browsers reject `Input.MOUSE_MODE_CAPTURED` outside a user gesture, so the captures in `_ready()` silently fail on web and the Esc *toggle* is the only thing that ever captures. Centralize: click captures, Esc releases.

**Files:**
- Create: `autoload/mouse_capture.gd`
- Modify: `project.godot` (autoload section)
- Modify: `scenes/player/fps_player.gd:37-45`
- Modify: `scenes/flight/player_ship.gd:28,46-51`

- [ ] **Step 1: Create the autoload**

Create `autoload/mouse_capture.gd`:

```gdscript
extends Node

func _ready() -> void:
	# Works on desktop; silently fails on web until the first click.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel") \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
```

No Esc-to-capture branch: browsers force-release pointer lock on Esc, so capture-on-Esc can never work on web.

- [ ] **Step 2: Register the autoload**

In `project.godot`, `[autoload]` section, add after `InputSetup`:

```ini
MouseCapture="*res://autoload/mouse_capture.gd"
```

- [ ] **Step 3: Remove per-script capture handling**

In `scenes/player/fps_player.gd`:
- Delete the line `Input.mouse_mode = Input.MOUSE_MODE_CAPTURED` at the end of `_ready()`.
- Replace `_unhandled_input` with (Esc branch removed, mouse-look kept):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * MOUSE_SENS, -1.5, 1.5)
```

In `scenes/flight/player_ship.gd`:
- Delete `Input.mouse_mode = Input.MOUSE_MODE_CAPTURED` at the end of `_ready()`.
- Replace `_unhandled_input` with:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_delta += event.relative
```

- [ ] **Step 4: Verify tests still pass and game boots**

Run: `godot --headless --path . --script tests/run_tests.gd`
Expected: `15 tests, 0 assertion failures`

Run: `timeout 30 godot --headless --path . --quit-after 120 2>&1 | grep -i "script error"; echo "exit ok"`
Expected: no SCRIPT ERROR lines, then `exit ok`

- [ ] **Step 5: Commit**

```bash
git add autoload/mouse_capture.gd project.godot scenes/player/fps_player.gd scenes/flight/player_ship.gd
git commit -m "fix: capture mouse on click so pointer lock works in web exports"
```

---

### Task 2: Landing-eligibility predicate in flight_model

**Files:**
- Modify: `scripts/flight_model.gd`
- Test: `tests/test_flight_model.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_flight_model.gd`:

```gdscript
func test_can_land_requires_zone_and_low_speed() -> void:
	assert_true(FM.can_land(true, 5.0, 8.0))
	assert_eq(FM.can_land(false, 5.0, 8.0), false, "must be in landing zone")
	assert_eq(FM.can_land(true, 9.0, 8.0), false, "too fast to land")
	assert_eq(FM.can_land(true, 8.0, 8.0), false, "boundary speed is not landable")
```

(`FM` is already defined at the top of that file: `const FM := preload("res://scripts/flight_model.gd")`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . --script tests/run_tests.gd`
Expected: FAIL — script error / nonexistent function `can_land`.

- [ ] **Step 3: Implement**

Append to `scripts/flight_model.gd`:

```gdscript
static func can_land(in_zone: bool, speed: float, max_speed: float) -> bool:
	return in_zone and speed < max_speed
```

- [ ] **Step 4: Run tests to verify pass**

Run: `godot --headless --path . --script tests/run_tests.gd`
Expected: `16 tests, 0 assertion failures`

- [ ] **Step 5: Commit**

```bash
git add scripts/flight_model.gd tests/test_flight_model.gd
git commit -m "feat: add landing-eligibility predicate to flight model"
```

---

### Task 3: GameState — mode changes without scene swaps

`enter_flight()`/`land()` become pure mode bookkeeping. Death paths reload the (upcoming) single world scene. Until Task 8 lands, death-reload points at a scene that doesn't exist yet — tests are pure-logic so they stay green; the game remains playable because nothing reaching `_change_scene` runs outside the tree in tests, and Tasks 3–8 land in quick succession.

**Files:**
- Modify: `autoload/game_state.gd`
- Test: `tests/test_game_state.gd`

- [ ] **Step 1: Update the test to the new contract**

In `tests/test_game_state.gd`, replace `test_enter_flight_and_land`:

```gdscript
func test_enter_flight_and_land() -> void:
	var gs = GS.new()
	gs.enter_flight()
	assert_eq(gs.mode, GS.Mode.FLIGHT)
	gs.land()
	assert_eq(gs.mode, GS.Mode.FPS)
	assert_eq(gs.spawn_at_cockpit, false, "seamless landing needs no respawn flag")
	gs.free()
```

All other tests (`test_player_death_resets`, `test_ship_destroyed_resets_hull_and_docks`, etc.) keep their existing assertions — death/destroy semantics are unchanged.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . --script tests/run_tests.gd`
Expected: 1 assertion failure — `land()` still sets `spawn_at_cockpit = true`.

- [ ] **Step 3: Update game_state.gd**

Replace the scene constants and the two transition methods in `autoload/game_state.gd`:

```gdscript
const WORLD_SCENE := "res://scenes/world/world.tscn"
```

(delete `STATION_SCENE` and `FLIGHT_SCENE`)

```gdscript
func enter_flight() -> void:
	mode = Mode.FLIGHT

func land() -> void:
	mode = Mode.FPS
```

In `_player_died()` and `_ship_destroyed()`, replace `_change_scene(STATION_SCENE)` with `_change_scene(WORLD_SCENE)`. Everything else (health/hull resets, flags) is unchanged.

- [ ] **Step 4: Run tests to verify pass**

Run: `godot --headless --path . --script tests/run_tests.gd`
Expected: `16 tests, 0 assertion failures`

- [ ] **Step 5: Commit**

```bash
git add autoload/game_state.gd tests/test_game_state.gd
git commit -m "feat: make flight transitions mode-only, reload single world on death"
```

---

### Task 4: FPS player control toggle

The world scene needs to switch the player off while flying (hidden, no physics, no collision, camera and HUD off) and back on at exit.

**Files:**
- Modify: `scenes/player/fps_player.gd`

- [ ] **Step 1: Keep a reference to the collision shape**

In `_ready()`, the local `var col := CollisionShape3D.new()` must be stored. Add a member `var collider: CollisionShape3D` next to the other vars, and after `add_child(col)` set `collider = col`.

- [ ] **Step 2: Add the toggle method**

Append to `scenes/player/fps_player.gd`:

```gdscript
func set_control_enabled(on: bool) -> void:
	visible = on
	collider.disabled = not on
	process_mode = PROCESS_MODE_INHERIT if on else PROCESS_MODE_DISABLED
	camera.current = on
	hud.visible = on
	if on:
		velocity = Vector3.ZERO
```

Notes for the implementer: `hud` is a CanvasLayer — it renders independently of 3D `visible`, hence the explicit `hud.visible`. Disabling `process_mode` stops `_physics_process` and `_unhandled_input` on the player and all children (weapon, HUD). Disabling the collider keeps the parked player capsule from blocking the departing ship and from being hit by grunt sight rays.

- [ ] **Step 3: Verify suite + smoke run**

Run: `godot --headless --path . --script tests/run_tests.gd`
Expected: `16 tests, 0 assertion failures`

- [ ] **Step 4: Commit**

```bash
git add scenes/player/fps_player.gd
git commit -m "feat: add control toggle to FPS player for ship handoff"
```

---

### Task 5: Cockpit seat as a signal-emitting ship part

The seat stops calling `GameState.enter_flight()` directly; it just emits. It also needs to hide/disable while the ship flies (a child StaticBody3D would otherwise collide with its own ship's `move_and_slide`).

**Files:**
- Create: `scenes/world/cockpit_seat.gd` (replaces `scenes/station/cockpit_seat.gd`, deleted in Task 8)

- [ ] **Step 1: Create the new seat script**

Create `scenes/world/cockpit_seat.gd`:

```gdscript
extends StaticBody3D

signal activated

var prompt_name := "Activate cockpit"
var col: CollisionShape3D

func _ready() -> void:
	add_to_group("interactable")
	col = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.9, 0.8)
	col.shape = shape
	col.position.y = 0.45
	add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.9, 0.8)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.3, 0.5)
	bm.material = mat
	mesh.mesh = bm
	mesh.position.y = 0.45
	add_child(mesh)

func set_enabled(on: bool) -> void:
	visible = on
	col.disabled = not on

func interact() -> void:
	activated.emit()
```

- [ ] **Step 2: Verify suite still green**

Run: `godot --headless --path . --script tests/run_tests.gd`
Expected: `16 tests, 0 assertion failures`

- [ ] **Step 3: Commit**

```bash
git add scenes/world/cockpit_seat.gd
git commit -m "feat: add signal-based cockpit seat for single-world boarding"
```

---

### Task 6: Player ship PARKED/ACTIVE states

**Files:**
- Modify: `scenes/flight/player_ship.gd` (full rewrite below)
- Modify: `scenes/flight/enemy_fighter.gd:40` (idle guard)

- [ ] **Step 1: Rewrite player_ship.gd**

Replace the entire contents of `scenes/flight/player_ship.gd` with:

```gdscript
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
```

Changes vs old file: PARKED/ACTIVE enum + early return in physics; seat child + `board_requested` signal; camera no longer `current = true` at `_ready` (only on `activate()`); `park()` levels, settles to ground, re-enables seat; no `Input.mouse_mode` writes (Task 1 moved those); initial `throttle` 0.0 instead of 0.2 so the parked ship doesn't creep on activation.

- [ ] **Step 2: Idle fighters while the player is on foot**

In `scenes/flight/enemy_fighter.gd`, at the top of `_physics_process`, before the player lookup, add:

```gdscript
	if GameState.mode != GameState.Mode.FLIGHT:
		return
```

Without this, fighters chase the parked ship's position, pile against the station hull, and shoot at it while the player walks around inside.

- [ ] **Step 3: Verify suite**

Run: `godot --headless --path . --script tests/run_tests.gd`
Expected: `16 tests, 0 assertion failures`

(The old `space_flight.tscn` is non-functional from this commit until Task 8 deletes it — the ship now spawns PARKED. Tests don't load scenes, so the suite stays green.)

- [ ] **Step 4: Commit**

```bash
git add scenes/flight/player_ship.gd scenes/flight/enemy_fighter.gd
git commit -m "feat: give player ship parked/active states for in-world boarding"
```

---

### Task 7: Flight HUD visibility guard

**Files:**
- Modify: `scenes/flight/flight_hud.gd:57-63`

- [ ] **Step 1: Guard _process**

In `scenes/flight/flight_hud.gd`, change the start of `_process` from `if ship == null:` to:

```gdscript
	if ship == null or not visible:
		return
```

The HUD now exists for the whole session and is toggled via `visible` by the world scene; no point unprojecting lead markers while hidden.

- [ ] **Step 2: Commit**

```bash
git add scenes/flight/flight_hud.gd
git commit -m "feat: skip flight HUD updates while hidden"
```

---

### Task 8: The world scene

One scene containing interior, hull shell with hangar opening, apron, space, all actors, and the boarding/exit handoff. Then switch the project to it and delete the old scenes.

**Geometry reference (all coordinates final):**

- Interior layout unchanged: spawn room (0,0) 8×8, north corridor (0,−7) 3×6, combat room (0,−16) 14×12, east corridor (10.5,−16) 7×3, hangar (24,−16) 20×18. Interior bounds: x −7..34, z −25..5, walls 3.5 high.
- Hangar is built with **no east wall** — its east side opens through the hull.
- Hull shell (replaces the old solid 60×20×60 box):
  - floor slab: center (12.5, −1.3, −10), size (47, 2, 38)  → top at y=−0.3
  - roof slab: center (12.5, 4.25, −10), size (47, 1.5, 38) → bottom at y=3.5
  - north wall: center (12.5, 1.35, −28.5), size (47, 7.3, 1)
  - south wall: center (12.5, 1.35, 8.5), size (47, 7.3, 1)
  - west wall: center (−10.5, 1.35, −10), size (1, 7.3, 38)
  - east wall at x=34..36 with a 10-wide × 3.5-high opening (z −21..−11, y 0..3.5) in front of the hangar:
    - north segment: center (35, 1.35, −25), size (2, 7.3, 8)
    - south segment: center (35, 1.35, −1), size (2, 7.3, 20)
    - lintel: center (35, 4.25, −16), size (2, 1.5, 10)
    - sill below opening: center (35, −1.15, −16), size (2, 2.3, 10) → top flush with hangar floor at y=0
- Apron (landing platform outside the opening): center (45, −0.15, −16), size (18, 0.3, 18) → top at y=0, walkable straight out of the hangar.
- Tower (cosmetic): center (50, 2, 10), size (10, 30, 10).
- Landing zone Area3D: center (34, 2.85, −16), size (40, 6, 18) — covers hangar interior and apron.
- Ship parked at (24, 0.8, −16) facing +x (out the opening). Cockpit spawn (19, 0.1, −16); entrance spawn (0, 0.1, 2). Kill plane unchanged at y=−10 (catches walking off the apron). Bounds radius 4000.

**Files:**
- Create: `scenes/world/world.gd`
- Create: `scenes/world/world.tscn`
- Modify: `project.godot` (main scene)
- Delete: `scenes/station/station.gd`, `scenes/station/station.tscn`, `scenes/station/cockpit_seat.gd`, `scenes/flight/space_flight.gd`, `scenes/flight/space_flight.tscn`

- [ ] **Step 1: Create world.gd**

Create `scenes/world/world.gd`:

```gdscript
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
	shape.size = Vector3(40, 6, 18)
	col.shape = shape
	landing_zone.add_child(col)
	landing_zone.position = Vector3(34, 2.85, -16)
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
	var out: Vector3 = ship.global_transform.basis.z
	out.y = 0.0
	out = out.normalized() if out.length() > 0.3 else Vector3(0, 0, 1)
	player.global_position = ship.global_position + out * 5.0 + Vector3(0, -0.7, 0)
	player.set_control_enabled(true)
	flight_hud.visible = false
	flight_hud.hide_prompt()
	GameState.land()

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
```

- [ ] **Step 2: Create world.tscn**

Create `scenes/world/world.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/world/world.gd" id="1_world"]

[node name="World" type="Node3D"]
script = ExtResource("1_world")
```

- [ ] **Step 3: Switch main scene and delete old scenes**

In `project.godot`: `run/main_scene="res://scenes/world/world.tscn"`.

```bash
git rm scenes/station/station.gd scenes/station/station.tscn scenes/station/cockpit_seat.gd scenes/flight/space_flight.gd scenes/flight/space_flight.tscn
```

(Also delete any stale `.uid` files Godot left next to them, if present.)

- [ ] **Step 4: Verify suite + smoke run**

Run: `godot --headless --path . --script tests/run_tests.gd`
Expected: `16 tests, 0 assertion failures`

Run: `timeout 60 godot --headless --path . --quit-after 300 2>&1 | grep -iE "script error|parse error|cannot"; echo "smoke done"`
Expected: no error lines, then `smoke done` (the world scene boots, builds geometry, spawns all actors, runs 300 frames).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: merge station and space into one seamless world scene"
```

---

### Task 9: Verification

- [ ] **Step 1: Full suite + smoke**

Run: `godot --headless --path . --script tests/run_tests.gd` → `16 tests, 0 assertion failures`
Run: `timeout 60 godot --headless --path . --quit-after 300 2>&1 | grep -iE "error" ; echo done` → no script/parse errors.

- [ ] **Step 2: Interactive desktop check (windowed run)**

Run `godot --path .` and verify the loop manually:
1. Mouse captured immediately (desktop); look/move works without pressing Esc.
2. Walk spawn room → corridor → combat room → hangar; grunts behave as before.
3. Glowing seat behind ship; `[E] Activate cockpit` → camera swaps to chase cam, FPS HUD replaced by flight HUD, no scene load.
4. Throttle up, fly out through the hangar opening into space; fighters engage.
5. Fly back, slow under SPD 8 over the apron/hangar → `[E] Exit ship` → ship settles level on the ground, player steps out behind it, FPS HUD back.
6. Esc releases mouse; click recaptures.
7. Walk off the apron edge → death → world reloads at entrance spawn.

- [ ] **Step 3: Web export check**

Export and serve (web export preset already exists):

```bash
mkdir -p build/web && godot --headless --path . --export-release "Web" build/web/index.html
python -m http.server 8060 -d build/web
```

In a browser at `http://localhost:8060`: mouse is NOT captured at load; the **first click captures it** (no Esc needed); Esc releases; click recaptures. Play the board→fly→land loop once.

- [ ] **Step 4: Final commit if anything was touched, then done**

Use superpowers:finishing-a-development-branch to wrap up.
