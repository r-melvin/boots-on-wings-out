# FPS / Space Flight Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Godot 4.6 prototype where the player fights billboard-sprite enemies through a space station, boards a docked ship, activates the cockpit to enter X-series-style space flight with dogfighting, and lands back at the station.

**Architecture:** Three scenes (station, space flight, FPS player) bridged by a `GameState` autoload that survives `change_scene_to_file()` swaps. Everything except the two root `.tscn` files is built in code (`_ready()` constructs children), and all textures are generated PNGs loaded at runtime via `Image.load_from_file` — no editor-side scene editing or import pipeline dependency.

**Tech Stack:** Godot 4.6 (Forward+, Jolt physics), GDScript only, custom headless test harness, programmatically generated pixel-art sprites.

**Conventions (apply to every task):**
- **No `class_name` anywhere.** Cross-script references use `const XScript := preload("res://path.gd")`. This keeps headless `--script` runs independent of the editor's global class cache.
- Run commands from the project root: `/home/richard/Projects/fps-prototype`.
- `godot` is assumed on PATH (verify in Task 1).
- Test command: `godot --headless --path . --script res://tests/run_tests.gd`
- Smoke-test command pattern: `godot --headless --path . --quit-after 120 <scene>` (runs 120 frames, exits; expect no script errors in output).

**File structure (final):**

```
autoload/game_state.gd        # mode, health, hull, cleared flags, transitions
autoload/input_setup.gd       # registers InputMap actions at runtime
scripts/health.gd             # pure hp logic (enemies, fighters)
scripts/flight_model.gd       # pure throttle/velocity maths
scripts/tex_loader.gd         # runtime PNG -> ImageTexture cache
scenes/player/fps_player.gd   # CharacterBody3D controller + interaction ray
scenes/player/weapon.gd       # hitscan gun
scenes/player/fps_hud.gd      # FPS CanvasLayer HUD + gun viewmodel
scenes/station/station.tscn   # main scene (root Node3D + script only)
scenes/station/station.gd     # builds geometry, lights, navmesh, spawns
scenes/station/cockpit_seat.gd# interactable that triggers flight
scenes/enemies/grunt.gd       # billboard sprite enemy
scenes/flight/space_flight.tscn # root Node3D + script only
scenes/flight/space_flight.gd # space env, station exterior, pad, fighters
scenes/flight/player_ship.gd  # flight controller
scenes/flight/flight_hud.gd   # flight CanvasLayer HUD
scenes/flight/bolt.gd         # projectile
scenes/flight/enemy_fighter.gd# fighter AI
tools/gen_assets.gd           # generates all PNGs
tests/run_tests.gd            # harness entry point
tests/test_base.gd            # assert helpers
tests/test_health.gd
tests/test_flight_model.gd
tests/test_game_state.gd
docs/superpowers/manual-test-checklist.md
```

---

### Task 1: Test harness

**Files:**
- Create: `tests/test_base.gd`
- Create: `tests/run_tests.gd`

- [ ] **Step 1: Verify godot binary**

Run: `godot --version`
Expected: output starting `4.6` (any 4.6.x). If missing, stop and report — everything depends on it.

- [ ] **Step 2: Write the assert helper base**

Create `tests/test_base.gd`:

```gdscript
extends RefCounted

var failures: Array[String] = []
var current := ""

func assert_eq(got, expected, note := "") -> void:
	if got != expected:
		failures.append("%s: expected %s, got %s. %s" % [current, expected, got, note])

func assert_true(cond: bool, note := "") -> void:
	if not cond:
		failures.append("%s: expected true. %s" % [current, note])

func assert_almost(got: float, expected: float, eps := 0.001, note := "") -> void:
	if absf(got - expected) > eps:
		failures.append("%s: expected ~%s, got %s. %s" % [current, expected, got, note])
```

- [ ] **Step 3: Write the runner**

Create `tests/run_tests.gd`:

```gdscript
extends SceneTree

const TEST_SCRIPTS := [
	"res://tests/test_health.gd",
	"res://tests/test_flight_model.gd",
	"res://tests/test_game_state.gd",
]

func _init() -> void:
	var total := 0
	var failed := 0
	for path in TEST_SCRIPTS:
		if not ResourceLoader.exists(path):
			continue
		var test = load(path).new()
		for m in test.get_method_list():
			if not m.name.begins_with("test_"):
				continue
			total += 1
			test.current = m.name
			test.call(m.name)
		for f in test.failures:
			failed += 1
			printerr("FAIL " + f)
	print("%d tests, %d assertion failures" % [total, failed])
	quit(1 if failed > 0 else 0)
```

- [ ] **Step 4: Run the harness (no tests yet)**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: `0 tests, 0 assertion failures`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add tests/
git commit -m "test: add minimal headless GDScript test harness"
```

---

### Task 2: Health logic

**Files:**
- Create: `scripts/health.gd`
- Create: `tests/test_health.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_health.gd`:

```gdscript
extends "res://tests/test_base.gd"

const HealthScript := preload("res://scripts/health.gd")

func test_starts_at_max() -> void:
	var h = HealthScript.new(30)
	assert_eq(h.hp, 30)
	assert_eq(h.max_hp, 30)
	assert_true(not h.is_dead())

func test_damage_reduces_hp() -> void:
	var h = HealthScript.new(30)
	assert_eq(h.take_damage(10), false, "non-lethal hit returns false")
	assert_eq(h.hp, 20)

func test_killing_blow_returns_true_once() -> void:
	var h = HealthScript.new(30)
	assert_eq(h.take_damage(30), true, "lethal hit returns true")
	assert_true(h.is_dead())
	assert_eq(h.take_damage(10), false, "already dead: no second kill report")
	assert_eq(h.hp, 0, "hp never goes negative")

func test_overkill_clamps_to_zero() -> void:
	var h = HealthScript.new(30)
	h.take_damage(999)
	assert_eq(h.hp, 0)
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: parse/load error mentioning `scripts/health.gd` not found (preload of missing file), non-zero exit.

- [ ] **Step 3: Implement**

Create `scripts/health.gd`:

```gdscript
extends RefCounted

var max_hp: int
var hp: int

func _init(p_max: int) -> void:
	max_hp = p_max
	hp = p_max

func take_damage(amount: int) -> bool:
	if hp <= 0:
		return false
	hp = maxi(hp - amount, 0)
	return hp == 0

func is_dead() -> bool:
	return hp <= 0
```

- [ ] **Step 4: Run tests, verify pass**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: `4 tests, 0 assertion failures`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/health.gd tests/test_health.gd
git commit -m "feat: add health component with clamped damage"
```

---

### Task 3: Flight model maths

**Files:**
- Create: `scripts/flight_model.gd`
- Create: `tests/test_flight_model.gd`

The X-series feel: throttle is a setpoint; velocity exponentially chases (nose direction × throttle × max speed), so hard turns drift before velocity catches up. Brake chases zero faster.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_flight_model.gd`:

```gdscript
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
```

- [ ] **Step 2: Run tests, verify failure**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: load error for missing `scripts/flight_model.gd`, non-zero exit.

- [ ] **Step 3: Implement**

Create `scripts/flight_model.gd`:

```gdscript
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
```

- [ ] **Step 4: Run tests, verify pass**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: `9 tests, 0 assertion failures` (4 health + 5 flight), exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/flight_model.gd tests/test_flight_model.gd
git commit -m "feat: add X-style throttle/velocity flight model"
```

---

### Task 4: GameState + input setup autoloads

**Files:**
- Create: `autoload/game_state.gd`
- Create: `autoload/input_setup.gd`
- Create: `tests/test_game_state.gd`
- Modify: `project.godot` (add `[autoload]` section)

- [ ] **Step 1: Write the failing tests**

Create `tests/test_game_state.gd`:

```gdscript
extends "res://tests/test_base.gd"

const GS := preload("res://autoload/game_state.gd")

func test_initial_state() -> void:
	var gs = GS.new()
	assert_eq(gs.mode, GS.Mode.FPS)
	assert_eq(gs.player_health, GS.MAX_HEALTH)
	assert_eq(gs.ship_hull, GS.MAX_HULL)
	assert_eq(gs.spawn_at_cockpit, false)
	gs.free()

func test_enter_flight_and_land() -> void:
	var gs = GS.new()
	gs.enter_flight()
	assert_eq(gs.mode, GS.Mode.FLIGHT)
	gs.land()
	assert_eq(gs.mode, GS.Mode.FPS)
	assert_eq(gs.spawn_at_cockpit, true, "landing returns player to cockpit")
	gs.free()

func test_damage_player_non_lethal() -> void:
	var gs = GS.new()
	assert_eq(gs.damage_player(30), false)
	assert_eq(gs.player_health, 70)
	gs.free()

func test_player_death_resets() -> void:
	var gs = GS.new()
	gs.spawn_at_cockpit = true
	assert_eq(gs.damage_player(999), true)
	assert_eq(gs.player_health, GS.MAX_HEALTH, "respawn with full health")
	assert_eq(gs.spawn_at_cockpit, false, "respawn at station entrance")
	assert_eq(gs.mode, GS.Mode.FPS)
	gs.free()

func test_ship_destroyed_resets_hull_and_docks() -> void:
	var gs = GS.new()
	gs.enter_flight()
	assert_eq(gs.damage_ship(999), true)
	assert_eq(gs.ship_hull, GS.MAX_HULL)
	assert_eq(gs.mode, GS.Mode.FPS)
	assert_eq(gs.spawn_at_cockpit, true, "ship loss respawns docked at cockpit")
	gs.free()

func test_cleared_enemies_persist() -> void:
	var gs = GS.new()
	assert_eq(gs.is_cleared("g1"), false)
	gs.mark_cleared("g1")
	assert_true(gs.is_cleared("g1"))
	assert_eq(gs.is_cleared("g2"), false)
	gs.free()
```

- [ ] **Step 2: Run tests, verify failure**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: load error for missing `autoload/game_state.gd`, non-zero exit.

- [ ] **Step 3: Implement GameState**

Create `autoload/game_state.gd`:

```gdscript
extends Node

enum Mode { FPS, FLIGHT }

const STATION_SCENE := "res://scenes/station/station.tscn"
const FLIGHT_SCENE := "res://scenes/flight/space_flight.tscn"
const MAX_HEALTH := 100
const MAX_HULL := 100

var mode: Mode = Mode.FPS
var player_health: int = MAX_HEALTH
var ship_hull: int = MAX_HULL
var spawn_at_cockpit := false
var cleared_enemies: Dictionary = {}

func enter_flight() -> void:
	mode = Mode.FLIGHT
	_change_scene(FLIGHT_SCENE)

func land() -> void:
	mode = Mode.FPS
	spawn_at_cockpit = true
	_change_scene(STATION_SCENE)

func damage_player(amount: int) -> bool:
	player_health = maxi(player_health - amount, 0)
	if player_health == 0:
		_player_died()
		return true
	return false

func damage_ship(amount: int) -> bool:
	ship_hull = maxi(ship_hull - amount, 0)
	if ship_hull == 0:
		_ship_destroyed()
		return true
	return false

func mark_cleared(enemy_id: String) -> void:
	cleared_enemies[enemy_id] = true

func is_cleared(enemy_id: String) -> bool:
	return cleared_enemies.has(enemy_id)

func _player_died() -> void:
	player_health = MAX_HEALTH
	spawn_at_cockpit = false
	mode = Mode.FPS
	_change_scene(STATION_SCENE)

func _ship_destroyed() -> void:
	ship_hull = MAX_HULL
	spawn_at_cockpit = true
	mode = Mode.FPS
	_change_scene(STATION_SCENE)

func _change_scene(path: String) -> void:
	# No-op outside the tree so pure-logic tests can instantiate this script.
	if is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(path)
```

- [ ] **Step 4: Run tests, verify pass**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: `15 tests, 0 assertion failures`, exit 0.

- [ ] **Step 5: Implement input setup**

Create `autoload/input_setup.gd`. Note shared keys across modes is intentional (W = walk forward in FPS, throttle up in flight; E = interact / used only in FPS-side prompts and landing).

```gdscript
extends Node

func _enter_tree() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("jump", KEY_SPACE)
	_key("sprint", KEY_SHIFT)
	_key("interact", KEY_E)
	_key("roll_left", KEY_Q)
	_key("roll_right", KEY_E)
	_key("throttle_up", KEY_W)
	_key("throttle_down", KEY_S)
	_key("brake", KEY_SPACE)
	_mouse("fire", MOUSE_BUTTON_LEFT)

func _key(action: String, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _mouse(action: String, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
```

- [ ] **Step 6: Register autoloads**

Add to `project.godot` (new section, after `[application]` block):

```
[autoload]

InputSetup="*res://autoload/input_setup.gd"
GameState="*res://autoload/game_state.gd"
```

- [ ] **Step 7: Re-run tests (must still pass — autoloads don't affect harness)**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: `15 tests, 0 assertion failures`, exit 0.

- [ ] **Step 8: Commit**

```bash
git add autoload/ tests/test_game_state.gd project.godot
git commit -m "feat: add GameState and InputSetup autoloads"
```

---

### Task 5: Asset generator + texture loader

**Files:**
- Create: `tools/gen_assets.gd`
- Create: `scripts/tex_loader.gd`
- Create (generated): `assets/sprites/grunt.png`, `assets/sprites/gun.png`, `assets/sprites/gun_flash.png`, `assets/sprites/starfield.png`

- [ ] **Step 1: Write the generator**

Create `tools/gen_assets.gd`:

```gdscript
extends SceneTree

const SPRITE_DIR := "res://assets/sprites"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SPRITE_DIR))
	_gen_grunt()
	_gen_gun()
	_gen_starfield()
	print("assets generated OK")
	quit(0)

# Grunt sheet: 8 frames of 48x48, horizontal strip.
# 0 idle | 1,2 walk | 3 attack | 4 pain | 5,6,7 death
func _gen_grunt() -> void:
	var f := 48
	var img := Image.create_empty(f * 8, f, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body := Color(0.75, 0.2, 0.2)
	var head := Color(0.9, 0.75, 0.6)
	var dark := Color(0.4, 0.1, 0.1)
	_humanoid(img, 0 * f, body, head, 0)
	_humanoid(img, 1 * f, body, head, -3)
	_humanoid(img, 2 * f, body, head, 3)
	_humanoid(img, 3 * f, Color(1.0, 0.5, 0.1), head, 0)
	_humanoid(img, 4 * f, Color(1.0, 1.0, 1.0), head, 0)
	_humanoid(img, 5 * f, dark, head, 0)
	img.fill_rect(Rect2i(6 * f + 8, 34, 32, 10), dark)
	img.fill_rect(Rect2i(7 * f + 8, 42, 32, 4), dark)
	img.save_png(ProjectSettings.globalize_path(SPRITE_DIR + "/grunt.png"))

func _humanoid(img: Image, x0: int, body: Color, head: Color, leg_off: int) -> void:
	img.fill_rect(Rect2i(x0 + 18, 4, 12, 10), head)
	img.fill_rect(Rect2i(x0 + 14, 14, 20, 16), body)
	img.fill_rect(Rect2i(x0 + 10, 14, 4, 12), body)
	img.fill_rect(Rect2i(x0 + 34, 14, 4, 12), body)
	img.fill_rect(Rect2i(x0 + 16 + leg_off, 30, 6, 14), body)
	img.fill_rect(Rect2i(x0 + 26 - leg_off, 30, 6, 14), body)

func _gen_gun() -> void:
	for variant in ["gun", "gun_flash"]:
		var img := Image.create_empty(160, 120, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		img.fill_rect(Rect2i(60, 60, 40, 60), Color(0.25, 0.27, 0.3))
		img.fill_rect(Rect2i(70, 20, 20, 50), Color(0.35, 0.37, 0.4))
		img.fill_rect(Rect2i(66, 14, 28, 8), Color(0.2, 0.5, 0.8))
		if variant == "gun_flash":
			img.fill_rect(Rect2i(58, 0, 44, 16), Color(1.0, 0.9, 0.4))
		img.save_png(ProjectSettings.globalize_path(SPRITE_DIR + "/%s.png" % variant))

func _gen_starfield() -> void:
	var img := Image.create_empty(1024, 512, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.01, 0.01, 0.03))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 700:
		var b := rng.randf_range(0.3, 1.0)
		img.set_pixel(rng.randi_range(0, 1023), rng.randi_range(0, 511), Color(b, b, b))
	img.save_png(ProjectSettings.globalize_path(SPRITE_DIR + "/starfield.png"))
```

- [ ] **Step 2: Run the generator**

Run: `godot --headless --path . --script res://tools/gen_assets.gd`
Expected: `assets generated OK`, exit 0.

- [ ] **Step 3: Verify files exist**

Run: `ls -la assets/sprites/`
Expected: `grunt.png`, `gun.png`, `gun_flash.png`, `starfield.png`, all non-zero size.

- [ ] **Step 4: Write the runtime texture loader**

Create `scripts/tex_loader.gd`. Bypasses the import pipeline: PNGs are loaded from disk at runtime, so headless runs and fresh checkouts never hit "resource not imported" errors.

```gdscript
extends RefCounted

static var _cache: Dictionary = {}

static func get_tex(path: String) -> ImageTexture:
	if not _cache.has(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		_cache[path] = ImageTexture.create_from_image(img)
	return _cache[path]
```

- [ ] **Step 5: Keep generated PNGs out of Godot's importer**

Create `assets/sprites/.gdignore` (empty file). This stops the editor generating `.import` files for textures we load manually.

Run: `touch assets/sprites/.gdignore`

- [ ] **Step 6: Commit (including generated PNGs so checkouts work without regenerating)**

```bash
git add tools/gen_assets.gd scripts/tex_loader.gd assets/
git commit -m "feat: add programmatic sprite/starfield generation and runtime texture loader"
```

---

### Task 6: FPS player, weapon, HUD scripts

**Files:**
- Create: `scenes/player/fps_player.gd`
- Create: `scenes/player/weapon.gd`
- Create: `scenes/player/fps_hud.gd`

No scene runs these yet — Task 7 instantiates them. Verification here is parse-level only.

- [ ] **Step 1: Write the HUD**

Create `scenes/player/fps_hud.gd`:

```gdscript
extends CanvasLayer

const TexLoaderScript := preload("res://scripts/tex_loader.gd")

var health_label: Label
var prompt_label: Label
var hit_marker: Label
var gun_rect: TextureRect
var gun_tex: Texture2D
var flash_tex: Texture2D
var flash_timer := 0.0
var marker_timer := 0.0

func _ready() -> void:
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	add_child(crosshair)

	health_label = Label.new()
	health_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	health_label.position += Vector2(16, -40)
	add_child(health_label)

	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.position += Vector2(0, 60)
	prompt_label.visible = false
	add_child(prompt_label)

	hit_marker = Label.new()
	hit_marker.text = "x"
	hit_marker.set_anchors_preset(Control.PRESET_CENTER)
	hit_marker.position += Vector2(10, -10)
	hit_marker.visible = false
	add_child(hit_marker)

	gun_tex = TexLoaderScript.get_tex("res://assets/sprites/gun.png")
	flash_tex = TexLoaderScript.get_tex("res://assets/sprites/gun_flash.png")
	gun_rect = TextureRect.new()
	gun_rect.texture = gun_tex
	gun_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gun_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gun_rect.custom_minimum_size = Vector2(320, 240)
	gun_rect.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	gun_rect.position += Vector2(-160, -240)
	add_child(gun_rect)

func _process(delta: float) -> void:
	health_label.text = "HP %d" % GameState.player_health
	flash_timer = maxf(flash_timer - delta, 0.0)
	gun_rect.texture = flash_tex if flash_timer > 0.0 else gun_tex
	marker_timer = maxf(marker_timer - delta, 0.0)
	hit_marker.visible = marker_timer > 0.0

func flash_muzzle() -> void:
	flash_timer = 0.07

func show_hit_marker() -> void:
	marker_timer = 0.15

func show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = true

func hide_prompt() -> void:
	prompt_label.visible = false
```

- [ ] **Step 2: Write the weapon**

Create `scenes/player/weapon.gd`:

```gdscript
extends Node

const DAMAGE := 10
const FIRE_INTERVAL := 0.18
const RANGE := 100.0

var camera: Camera3D
var hud: CanvasLayer
var cooldown := 0.0

func setup(p_camera: Camera3D, p_hud: CanvasLayer) -> void:
	camera = p_camera
	hud = p_hud

func _process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	if Input.is_action_pressed("fire") and cooldown == 0.0 \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cooldown = FIRE_INTERVAL
		_fire()

func _fire() -> void:
	hud.flash_muzzle()
	var space := camera.get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_parent().get_rid()]
	var hit := space.intersect_ray(query)
	if hit and hit.collider.has_method("take_hit"):
		hit.collider.take_hit(DAMAGE)
		hud.show_hit_marker()
```

- [ ] **Step 3: Write the player controller**

Create `scenes/player/fps_player.gd`:

```gdscript
extends CharacterBody3D

const WeaponScript := preload("res://scenes/player/weapon.gd")
const FpsHudScript := preload("res://scenes/player/fps_hud.gd")

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.5
const JUMP_VELOCITY := 4.5
const MOUSE_SENS := 0.002
const INTERACT_RANGE := 2.6

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var head: Node3D
var camera: Camera3D
var hud: CanvasLayer

func _ready() -> void:
	add_to_group("player")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 1.8
	cap.radius = 0.35
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	head = Node3D.new()
	head.position = Vector3(0, 1.6, 0)
	add_child(head)
	camera = Camera3D.new()
	camera.current = true
	head.add_child(camera)
	hud = FpsHudScript.new()
	add_child(hud)
	var weapon = WeaponScript.new()
	weapon.setup(camera, hud)
	add_child(weapon)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * MOUSE_SENS, -1.5, 1.5)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE \
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	if dir:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	move_and_slide()
	_update_interact()

func _update_interact() -> void:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * INTERACT_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit and hit.collider.is_in_group("interactable"):
		hud.show_prompt("[E] " + hit.collider.prompt_name)
		if Input.is_action_just_pressed("interact"):
			hit.collider.interact()
	else:
		hud.hide_prompt()
```

- [ ] **Step 4: Parse-check all three scripts**

Run: `for f in scenes/player/*.gd; godot --headless --path . --check-only --script "res://$f"; echo "$f -> $status"; end`
(fish shell syntax.) Expected: exit status 0 for each, no parse errors printed.

- [ ] **Step 5: Commit**

```bash
git add scenes/player/
git commit -m "feat: add FPS player controller, hitscan weapon, and HUD"
```

---

### Task 7: Station scene

**Files:**
- Create: `scenes/station/station.tscn`
- Create: `scenes/station/station.gd`
- Create: `scenes/station/cockpit_seat.gd`
- Modify: `project.godot` (set main scene)

Layout (top-down, +x east, -z north): spawn room → corridor north → combat room → corridor east → hangar containing the ship (open rear, cockpit seat at front).

- [ ] **Step 1: Write the cockpit seat interactable**

Create `scenes/station/cockpit_seat.gd`:

```gdscript
extends StaticBody3D

var prompt_name := "Activate cockpit"

func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
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

func interact() -> void:
	GameState.enter_flight()
```

- [ ] **Step 2: Write the station builder**

Create `scenes/station/station.gd`:

```gdscript
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
```

- [ ] **Step 3: Create the scene file**

Create `scenes/station/station.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/station/station.gd" id="1_station"]

[node name="Station" type="Node3D"]
script = ExtResource("1_station")
```

- [ ] **Step 4: Set main scene**

In `project.godot`, inside the existing `[application]` section, add:

```
run/main_scene="res://scenes/station/station.tscn"
```

- [ ] **Step 5: Smoke test**

Run: `godot --headless --path . --quit-after 120 2>&1 | tail -20`
Expected: exits 0; no `SCRIPT ERROR` lines. Navigation bake warnings are acceptable; script errors are not.

- [ ] **Step 6: Manual check**

Run: `godot --path .`
Verify: spawn in a lit grey room; walk through corridor to blue combat room, east corridor to rust hangar; enter ship from its rear (south side); look at glowing blue seat → "[E] Activate cockpit" prompt appears (pressing E will error — flight scene doesn't exist until Task 9; that's expected). Esc releases mouse.

- [ ] **Step 7: Commit**

```bash
git add scenes/station/ project.godot
git commit -m "feat: build station interior with docked ship and cockpit interactable"
```

---

### Task 8: Grunt enemy

**Files:**
- Create: `scenes/enemies/grunt.gd`
- Modify: `scenes/station/station.gd` (spawn grunts)

- [ ] **Step 1: Write the grunt**

Create `scenes/enemies/grunt.gd`:

```gdscript
extends CharacterBody3D

const HealthScript := preload("res://scripts/health.gd")
const TexLoaderScript := preload("res://scripts/tex_loader.gd")

enum State { IDLE, CHASE, PAIN, DEAD }

const SPEED := 3.2
const SIGHT_RANGE := 22.0
const ATTACK_RANGE := 11.0
const ATTACK_DAMAGE := 8
const ATTACK_INTERVAL := 1.3
const HIT_CHANCE := 0.65

var enemy_id := ""
var health = HealthScript.new(30)
var state := State.IDLE
var attack_cd := 0.0
var windup := 0.0
var pain_timer := 0.0
var death_timer := 0.0
var anim_time := 0.0
var sprite: Sprite3D
var agent: NavigationAgent3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.height = 1.8
	cap.radius = 0.4
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	sprite = Sprite3D.new()
	sprite.texture = TexLoaderScript.get_tex("res://assets/sprites/grunt.png")
	sprite.hframes = 8
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = 0.04
	sprite.position.y = 1.0
	add_child(sprite)
	agent = NavigationAgent3D.new()
	add_child(agent)

func _physics_process(delta: float) -> void:
	anim_time += delta
	attack_cd = maxf(attack_cd - delta, 0.0)
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0 and state == State.CHASE and _can_see_player():
			if randf() < HIT_CHANCE:
				GameState.damage_player(ATTACK_DAMAGE)
	if not is_on_floor():
		velocity.y -= gravity * delta
	match state:
		State.DEAD:
			death_timer += delta
			sprite.frame = 5 + mini(int(death_timer / 0.15), 2)
			velocity.x = 0.0
			velocity.z = 0.0
			if death_timer > 1.2:
				queue_free()
		State.PAIN:
			sprite.frame = 4
			pain_timer -= delta
			velocity.x = 0.0
			velocity.z = 0.0
			if pain_timer <= 0.0:
				state = State.CHASE
		State.IDLE:
			sprite.frame = 0
			if _can_see_player():
				state = State.CHASE
		State.CHASE:
			_chase()
	move_and_slide()

func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player")

func _can_see_player() -> bool:
	var p := _player()
	if p == null:
		return false
	if (p.global_position - global_position).length() > SIGHT_RANGE:
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.5, p.global_position + Vector3.UP * 1.2)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	return hit and hit.collider == p

func _chase() -> void:
	var p := _player()
	if p == null:
		return
	var dist := (p.global_position - global_position).length()
	if dist <= ATTACK_RANGE and _can_see_player():
		velocity.x = 0.0
		velocity.z = 0.0
		sprite.frame = 3
		if attack_cd == 0.0:
			attack_cd = ATTACK_INTERVAL
			windup = 0.35  # telegraph: flash shows before damage lands
		return
	agent.target_position = p.global_position
	var dir := agent.get_next_path_position() - global_position
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = p.global_position - global_position  # navmesh fallback: straight line
		dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	sprite.frame = 1 + (int(anim_time * 4.0) % 2)

func take_hit(dmg: int) -> void:
	if state == State.DEAD:
		return
	if health.take_damage(dmg):
		state = State.DEAD
		death_timer = 0.0
		GameState.mark_cleared(enemy_id)
		set_collision_layer_value(1, false)
	else:
		state = State.PAIN
		pain_timer = 0.25
```

- [ ] **Step 2: Spawn grunts in the station**

In `scenes/station/station.gd`, add the preload at the top with the others:

```gdscript
const GruntScript := preload("res://scenes/enemies/grunt.gd")
```

Add `_spawn_grunts()` as the last line of `_ready()`, then add the function:

```gdscript
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
```

- [ ] **Step 3: Smoke test**

Run: `godot --headless --path . --quit-after 120 2>&1 | tail -20`
Expected: exit 0, no `SCRIPT ERROR` lines.

- [ ] **Step 4: Run tests (regression)**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: `15 tests, 0 assertion failures`.

- [ ] **Step 5: Manual check**

Run: `godot --path .`
Verify: two red sprite enemies in the combat room, one in the hangar. They stand idle until you're visible, then walk at you (legs animate), stop in range, flash orange, and your HP drops over time. Shooting one (LMB): white pain flash; 3 hits kills it (collapse frames, then gone). Die on purpose: screen resets to spawn room with 100 HP, killed grunts stay dead.

- [ ] **Step 6: Commit**

```bash
git add scenes/enemies/ scenes/station/station.gd
git commit -m "feat: add billboard grunt enemy with chase/attack AI"
```

---

### Task 9: Flight scene — player ship, HUD, space environment

**Files:**
- Create: `scenes/flight/player_ship.gd`
- Create: `scenes/flight/flight_hud.gd`
- Create: `scenes/flight/space_flight.gd`
- Create: `scenes/flight/space_flight.tscn`

- [ ] **Step 1: Write the flight HUD**

Create `scenes/flight/flight_hud.gd`:

```gdscript
extends CanvasLayer

var ship: Node3D
var speed_label: Label
var hull_label: Label
var throttle_bar: ProgressBar
var prompt_label: Label
var warn_label: Label

func setup(p_ship: Node3D) -> void:
	ship = p_ship

func _ready() -> void:
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	add_child(crosshair)

	speed_label = Label.new()
	speed_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	speed_label.position += Vector2(16, -70)
	add_child(speed_label)

	hull_label = Label.new()
	hull_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hull_label.position += Vector2(16, -40)
	add_child(hull_label)

	throttle_bar = ProgressBar.new()
	throttle_bar.min_value = -0.25
	throttle_bar.max_value = 1.0
	throttle_bar.show_percentage = false
	throttle_bar.custom_minimum_size = Vector2(160, 12)
	throttle_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	throttle_bar.position += Vector2(16, -100)
	add_child(throttle_bar)

	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.position += Vector2(0, 60)
	prompt_label.visible = false
	add_child(prompt_label)

	warn_label = Label.new()
	warn_label.text = "RETURN TO STATION"
	warn_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	warn_label.position += Vector2(0, 40)
	warn_label.visible = false
	add_child(warn_label)

func _process(_delta: float) -> void:
	if ship == null:
		return
	speed_label.text = "SPD %d" % int(ship.velocity.length())
	hull_label.text = "HULL %d" % GameState.ship_hull
	throttle_bar.value = ship.throttle

func show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = true

func hide_prompt() -> void:
	prompt_label.visible = false

func set_warning(on: bool) -> void:
	warn_label.visible = on
```

- [ ] **Step 2: Write the player ship**

Create `scenes/flight/player_ship.gd`:

```gdscript
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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_mesh() -> void:
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.7, 0.7, 0.75)
	for def in [
		[Vector3(0, 0, 0), Vector3(2, 1.4, 6)],     # fuselage
		[Vector3(0, 0, 0.5), Vector3(6, 0.2, 2)],   # wings
		[Vector3(0, 0.6, -1.5), Vector3(1, 0.6, 1.5)],  # canopy hump
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
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE \
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

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
```

Note: `player_ship.gd` preloads `bolt.gd`, which is written in Task 10. Until then, create a stub so the scene parses — `scenes/flight/bolt.gd`:

```gdscript
extends Area3D

func setup(_team: String, _basis: Basis, _pos: Vector3, _inherit_vel: Vector3) -> void:
	queue_free()  # stub until Task 10
```

- [ ] **Step 3: Write the flight scene builder**

Create `scenes/flight/space_flight.gd`:

```gdscript
extends Node3D

const PlayerShipScript := preload("res://scenes/flight/player_ship.gd")
const FlightHudScript := preload("res://scenes/flight/flight_hud.gd")
const TexLoaderScript := preload("res://scripts/tex_loader.gd")

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

func _physics_process(_delta: float) -> void:
	_check_landing()
	_check_bounds()

func _check_landing() -> void:
	var can_land: bool = pad_area.overlaps_body(ship) \
		and ship.velocity.length() < LANDING_SPEED_MAX
	if can_land:
		hud.show_prompt("[E] Land")
		if Input.is_action_just_pressed("interact"):
			GameState.land()
	else:
		hud.hide_prompt()

func _check_bounds() -> void:
	var out := ship.global_position.length() > BOUNDS_RADIUS
	hud.set_warning(out)
	if out:
		ship.velocity -= ship.global_position.normalized() * 2.0

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
```

- [ ] **Step 4: Create the scene file**

Create `scenes/flight/space_flight.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/flight/space_flight.gd" id="1_flight"]

[node name="SpaceFlight" type="Node3D"]
script = ExtResource("1_flight")
```

- [ ] **Step 5: Smoke test the flight scene directly**

Run: `godot --headless --path . --quit-after 120 res://scenes/flight/space_flight.tscn 2>&1 | tail -20`
Expected: exit 0, no `SCRIPT ERROR`.

- [ ] **Step 6: Manual check — the full transition**

Run: `godot --path .`
Verify: fight/sneak to the hangar, enter ship, press E on the seat → space scene loads with starfield, station exterior below, your ship drifting forward. Mouse pitches/yaws, Q/E rolls, W/S throttle (bar moves), Space brakes, speed reads out. Fly down to the yellow pad slowly → "[E] Land" → E returns you to the station standing at the cockpit. Cleared grunts are still dead.

- [ ] **Step 7: Commit**

```bash
git add scenes/flight/
git commit -m "feat: add space flight scene with X-style ship controls and landing"
```

---

### Task 10: Bolts and enemy fighters

**Files:**
- Modify: `scenes/flight/bolt.gd` (replace stub)
- Create: `scenes/flight/enemy_fighter.gd`
- Modify: `scenes/flight/space_flight.gd` (spawn fighters)

- [ ] **Step 1: Replace the bolt stub**

Replace the full contents of `scenes/flight/bolt.gd`:

```gdscript
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
```

- [ ] **Step 2: Write the enemy fighter**

Create `scenes/flight/enemy_fighter.gd`:

```gdscript
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
		queue_free()
```

- [ ] **Step 3: Spawn fighters in the flight scene**

In `scenes/flight/space_flight.gd`, add the preload at the top with the others:

```gdscript
const EnemyFighterScript := preload("res://scenes/flight/enemy_fighter.gd")
```

Add `_spawn_fighters()` at the end of `_ready()`, then add the function:

```gdscript
func _spawn_fighters() -> void:
	for pos in [Vector3(300, 60, -250), Vector3(-280, -40, -350), Vector3(150, -80, -450)]:
		var f = EnemyFighterScript.new()
		f.position = pos
		add_child(f)
```

- [ ] **Step 4: Add the lead reticle to the flight HUD**

In `scenes/flight/flight_hud.gd`, add a member with the others:

```gdscript
var lead_marker: Label
```

At the end of `_ready()`:

```gdscript
	lead_marker = Label.new()
	lead_marker.text = "[ ]"
	lead_marker.visible = false
	add_child(lead_marker)
```

At the end of `_process()` add `_update_lead()`, then add the functions:

```gdscript
func _update_lead() -> void:
	var cam := ship.get_viewport().get_camera_3d()
	var target := _nearest_fighter()
	if cam == null or target == null:
		lead_marker.visible = false
		return
	var dist: float = (target.global_position - ship.global_position).length()
	# 200.0 = bolt speed: aim where the target will be when the bolt arrives
	var predicted: Vector3 = target.global_position + target.velocity * (dist / 200.0)
	if cam.is_position_behind(predicted):
		lead_marker.visible = false
		return
	lead_marker.position = cam.unproject_position(predicted) - Vector2(12, 12)
	lead_marker.visible = true

func _nearest_fighter() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for f in get_tree().get_nodes_in_group("enemy_fighter"):
		var d: float = (f.global_position - ship.global_position).length()
		if d < best_d:
			best_d = d
			best = f
	return best
```

- [ ] **Step 5: Smoke test**

Run: `godot --headless --path . --quit-after 120 res://scenes/flight/space_flight.tscn 2>&1 | tail -20`
Expected: exit 0, no `SCRIPT ERROR`.

- [ ] **Step 6: Run unit tests (regression)**

Run: `godot --headless --path . --script res://tests/run_tests.gd`
Expected: `15 tests, 0 assertion failures`.

- [ ] **Step 7: Manual check**

Run: `godot --path .` and fly out.
Verify: three red fighters converge on you, weaving slightly; red bolts streak past and hits drop HULL on the HUD. A `[ ]` lead marker floats ahead of the nearest fighter — shooting at it lands hits. Your green bolts fire from wing tips (LMB); ~3 hits pops a fighter. Fighters that get close break off then re-engage. Let hull hit 0: you respawn in the station at the cockpit, hull restored.

- [ ] **Step 8: Commit**

```bash
git add scenes/flight/
git commit -m "feat: add projectile bolts and enemy fighter dogfighting AI"
```

---

### Task 11: Full-loop verification and manual test checklist

**Files:**
- Create: `docs/superpowers/manual-test-checklist.md`

- [ ] **Step 1: Write the checklist**

Create `docs/superpowers/manual-test-checklist.md`:

```markdown
# Manual Test Checklist

Run `godot --path .` and verify each item. Date and initial each run.

## FPS mode
- [ ] Spawn in grey room; mouse look smooth; WASD/sprint/jump work; Esc toggles mouse capture
- [ ] HUD shows HP 100, crosshair, gun viewmodel
- [ ] Grunts idle until seen, then chase with walk animation
- [ ] Grunt in attack range: orange flash, HP drops over time
- [ ] Shooting grunt: muzzle flash, hit marker, white pain flash; 3 hits = death animation, body disappears
- [ ] Player death: respawn at entrance, HP 100, dead grunts stay dead
- [ ] Falling out of map (if achievable) triggers death handling

## Transition
- [ ] Cockpit seat shows "[E] Activate cockpit" prompt only when looked at up close
- [ ] E in cockpit loads space scene without errors

## Flight mode
- [ ] Starfield sky, station exterior with yellow pad visible
- [ ] Mouse pitch/yaw, Q/E roll, W/S throttle (bar), Space brake, speed readout
- [ ] Velocity drifts on hard turns (nose moves before velocity follows)
- [ ] Fighters attack; red bolts; HULL drops when hit
- [ ] Green bolts kill fighters in ~3 hits
- [ ] Hull 0: respawn at cockpit in station, hull restored
- [ ] Beyond ~4 km: RETURN TO STATION warning, pushed back

## Landing + loop
- [ ] Pad prompt appears only inside pad zone below speed 8
- [ ] E lands: back in station at cockpit, facing the ship exit
- [ ] Cleared grunts still dead after a full loop
- [ ] Second full loop works (station -> fly -> land -> station)
```

- [ ] **Step 2: Run the full automated suite one final time**

Run: `godot --headless --path . --script res://tests/run_tests.gd && godot --headless --path . --quit-after 120 2>&1 | tail -5 && godot --headless --path . --quit-after 120 res://scenes/flight/space_flight.tscn 2>&1 | tail -5`
Expected: 15 tests 0 failures; both smoke tests exit clean.

- [ ] **Step 3: Execute the manual checklist**

Run: `godot --path .` and work through every checklist item. Fix anything broken before proceeding (use superpowers:systematic-debugging for failures).

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/manual-test-checklist.md
git commit -m "docs: add manual test checklist"
```
