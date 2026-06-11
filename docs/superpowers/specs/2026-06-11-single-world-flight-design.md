# Single-World Flight + Web Mouse Capture — Design

Date: 2026-06-11
Status: Approved (pending spec review)

## Goals

1. **Seamless ground-to-flight gameplay.** Remove the scene swap between station
   (FPS) and space (flight). One continuous world: walk to the ship in the
   hangar, sit in the cockpit, fly out into space, land back on the apron,
   step out — no loading cut at any point.
2. **Fix mouse capture on web exports.** Currently the mouse is not captured
   when the game starts in a browser and the player must press Esc to get it
   working. Capture must work from a click, the gesture browsers accept for
   pointer lock.

## Non-Goals

- Walking around inside the ship while it flies (no passenger physics).
- Landing anywhere other than the station pad/hangar.
- Multiplayer, save games, or persistence beyond the existing
  `cleared_enemies` dictionary.

## Current Architecture (before)

- `scenes/station/station.tscn` — FPS interior, built procedurally by
  `station.gd`. Contains a static box "ship shell" and a `cockpit_seat.gd`
  interactable that calls `GameState.enter_flight()`.
- `scenes/flight/space_flight.tscn` — space scene built by `space_flight.gd`:
  station exterior boxes, landing pad on the roof, `player_ship.gd` spawned
  already flying. Landing = hover over pad area slowly, press E, which calls
  `GameState.land()`.
- `autoload/game_state.gd` — mode enum, health/hull, and `change_scene_to_file`
  calls on every transition.
- Mouse capture is set in `_ready()` of `fps_player.gd` and `player_ship.gd`
  (fails silently on web), and Esc (`ui_cancel`) toggles capture in each
  script's `_unhandled_input`.

## New Architecture

### World scene

One scene, `scenes/world/world.tscn` + `world.gd`, replaces both
`station.tscn` and `space_flight.tscn`. It builds:

- **Interior** — the existing room/corridor/hangar layout from `station.gd`
  (geometry helpers move with it), grunts, navmesh, lights, kill plane.
- **Exterior** — station hull grown to enclose the interior footprint
  (interior spans roughly x −7..34, z −25..5, so the hull becomes ~90×20×90
  centered to cover it), tower, and a **landing apron** platform outside the
  hangar's east side at interior floor level. The roof pad is removed.
- **Hangar opening** — the hangar's east wall and the hull section behind it
  get a large opening (~8 wide × 5 high) so the ship can fly out to space.
- **Space** — starfield sky, sun, enemy fighters at their current spawn
  positions, bounds push-back at radius 4000. The space environment
  (starfield sky) is global; the interior keeps its omni lights.
- **Ship** — one flyable `player_ship.gd` instance parked in the hangar,
  replacing the static box ship shell.

`project.godot` main scene / `GameState` scene constants point at the world
scene.

### Ship states

`player_ship.gd` gains a simple two-state machine:

- **PARKED** — stationary in the hangar or on the apron. No flight input
  processing, velocity zero. Exposes the cockpit-seat interactable
  (`prompt_name = "Activate cockpit"`, `interact()` starts the handoff).
  The seat is a child Area3D/StaticBody3D of the ship so it moves with it.
- **ACTIVE** — current flight behavior (mouse steer, roll, throttle, brake,
  fire). Landing check: when the ship overlaps the apron/hangar landing zone
  and `velocity.length() < 8.0`, the flight HUD shows `[E] Exit ship`;
  pressing interact transitions to PARKED and runs the exit handoff.

The landing-eligibility predicate (`overlapping and speed < max`) lives in
`scripts/flight_model.gd` (or a small pure helper) so it stays unit-testable.

### Control handoff

Enter (seat interact while FPS):

1. Store player reference; `player.visible = false`; disable its collision
   shape and set `process_mode = PROCESS_MODE_DISABLED`.
2. Ship camera `current = true`; ship state → ACTIVE.
3. `GameState.enter_flight()` — sets `mode = FLIGHT` only, no scene change.
4. Flight HUD shown, FPS HUD hidden (each HUD is visible only in its mode).

Exit (interact while landed):

1. Ship state → PARKED; velocity zeroed.
2. Player placed at a fixed offset beside the ship (offset chosen to land on
   the apron/hangar floor), re-enabled, made visible; player camera
   `current = true`.
3. `GameState.land()` — sets `mode = FPS` only.

### GameState changes

- `enter_flight()` / `land()` no longer change scene; they only set `mode`.
- `_player_died()` and `_ship_destroyed()` reload the single world scene
  (`WORLD_SCENE` constant). `spawn_at_cockpit` keeps deciding the player
  spawn point; the ship always respawns PARKED in the hangar.
- `cleared_enemies` behavior unchanged.

### Mouse capture (web fix)

New autoload `autoload/mouse_capture.gd`:

- `_ready()`: attempt capture (works on desktop; silently fails on web —
  acceptable, the first click captures).
- `_unhandled_input()`: any `InputEventMouseButton` pressed while mouse is
  not captured → `Input.mouse_mode = MOUSE_MODE_CAPTURED`. Click is a user
  gesture, so this works in browsers.
- `ui_cancel` pressed while captured → release (`MOUSE_MODE_VISIBLE`).
  No toggle-to-capture on Esc: browsers force-release pointer lock on Esc,
  so capture-on-Esc can never work on web.

Remove `Input.mouse_mode = ...` from `_ready()` and the Esc toggles from
`fps_player.gd` and `player_ship.gd`. Gameplay scripts keep gating their
input handling on `Input.mouse_mode == MOUSE_MODE_CAPTURED` as they do now.

Note: clicking to recapture also fires the `fire` action. Acceptable for a
prototype; scripts already ignore fire while uncaptured, and the capturing
click itself arrives while still uncaptured, so it does not shoot.

## Error handling

- Exit placement: fixed offset beside the ship; if that spot is inside
  geometry the player capsule resolves via normal physics. The apron is flat
  and open, so in practice the offset is always clear.
- Ship destroyed mid-flight with player hidden: scene reload recreates both;
  no dangling references because everything is rebuilt.
- Kill plane stays interior-scoped (only affects the "player" group; the
  hidden player has collision disabled while flying, so it cannot trigger).

## Testing

- `tests/test_flight_model.gd` — unchanged; add cases for the new
  landing-eligibility predicate.
- `tests/test_game_state.gd` — update: `enter_flight()`/`land()` assert mode
  change without scene swap; death paths still reset health/hull and flags.
- Manual: desktop run (walk → sit → fly out → land → exit → walk), and web
  export check that the first click captures the mouse and Esc releases it.

## File changes

| File | Change |
|------|--------|
| `scenes/world/world.gd` (new) | Builds interior + exterior + space + ship |
| `scenes/world/world.tscn` (new) | Root scene |
| `scenes/station/station.gd` | Geometry/layout code absorbed into world.gd; file removed |
| `scenes/flight/space_flight.gd` | Exterior/bounds/landing code absorbed; file removed |
| `scenes/station/cockpit_seat.gd` | Folded into ship's seat child; file removed |
| `scenes/flight/player_ship.gd` | PARKED/ACTIVE states, seat, landing exit |
| `scenes/player/fps_player.gd` | Remove capture/Esc handling |
| `autoload/mouse_capture.gd` (new) | Web-safe capture autoload |
| `autoload/game_state.gd` | No scene swap on mode change; WORLD_SCENE reload on death |
| `scripts/flight_model.gd` | Landing-eligibility predicate |
| `project.godot` | Main scene → world.tscn; register mouse_capture autoload |
| `tests/*` | Updated per Testing section |
