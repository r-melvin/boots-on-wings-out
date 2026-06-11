# FPS / Space Flight Prototype — Design

**Date:** 2026-06-11
**Engine:** Godot 4.6 (Forward+, Jolt Physics)
**Status:** Approved

## Overview

A first-person shooter prototype with a mode switch into space flight. The player
fights through a space station, boards a docked ship, walks to its cockpit, and
activates it to enter an X-series-style flight mode. They dogfight enemy ships in
space, then land back at the station pad to return to FPS mode. The loop repeats.

Transitions are scene swaps (no seamless world simulation). Characters and enemies
in FPS mode are billboarded sprites; environments and ships are low-poly geometry.
All assets are generated in-project — no external downloads.

## Game loop

1. Spawn in station interior.
2. Fight through billboard-sprite enemies (one hitscan gun).
3. Reach the docked ship, walk through its interior to the cockpit.
4. Interact with the cockpit seat → scene swap to flight mode.
5. Fly 6DOF, dogfight 2–4 enemy fighters.
6. Approach the station landing pad slowly → prompt → land.
7. Scene swap back to station, player at the cockpit seat. Loop.

Linear demo loop: no objectives UI, no win screen.

## Architecture

Three scenes plus one autoload singleton:

| Unit | Type | Responsibility |
|------|------|----------------|
| `game_state.gd` | Autoload | Player health, ship hull, current mode, spawn point id, enemies-cleared flags, `enter_flight()` / `land()` transition functions. Owns nothing visual. |
| `scenes/station/station.tscn` | Scene | Station interior + docked ship interior as one walkable map. Contains enemies, the cockpit interactable, kill-plane. |
| `scenes/flight/space_flight.tscn` | Scene | Player ship, space skybox, station exterior model, enemy fighters, landing pad trigger zone, soft flight boundary. |
| `scenes/player/fps_player.tscn` | Scene (instanced) | First-person CharacterBody3D controller, weapon, interaction raycast, FPS HUD. Reusable in any walkable map. |

Transitions use `change_scene_to_packed()`. `GameState` carries all data that must
survive a scene swap. No save files; state is per-session.

## FPS mode

- **Player controller:** CharacterBody3D with capsule collider. Mouse look, WASD,
  sprint, jump. Mouse captured; Esc releases.
- **Weapon:** Single hitscan gun. Raycast from camera centre; fire-rate limited.
  Rendered as a first-person 2D sprite on a CanvasLayer with a muzzle-flash frame.
- **Enemies:** Sprite3D billboards using generated sprite sheets with idle, walk,
  attack, pain, and death frames. AI state machine:
  - *Idle* → *Alert* when the player enters line of sight (raycast check).
  - *Alert/Chase*: pathfind toward player via NavigationAgent3D.
  - *Attack*: when in range, telegraphed hitscan shot with spread.
  - On damage: pain flash; at zero health: death animation, then `queue_free()`.
- **Interaction:** Camera raycast against an `interactable` group shows a
  "Press E" prompt. The cockpit seat is an interactable that triggers
  `GameState.enter_flight()`.
- **HUD:** Health, crosshair, hit marker.

## Flight mode

- **Flight model:** X-series arcade-Newtonian blend. Mouse steers the nose
  (pitch/yaw), Q/E roll. Throttle is a setpoint adjusted by W/S or scroll wheel.
  Velocity lerps toward (nose direction × throttle), producing drift on hard
  turns. Speed capped; spacebar brake. Body type (RigidBody3D vs. directly
  integrated) is decided during implementation by feel.
- **Weapons:** Forward-fixed blasters firing visible fast projectile bolts on LMB.
- **Enemy fighters:** 2–4 low-poly mesh ships. AI: steer toward the player with
  an offset wobble, fire when the nose is roughly aligned, break off when too
  close.
- **HUD:** Speed, throttle bar, crosshair with lead reticle, hull integrity,
  landing prompt when near the pad.
- **Landing:** A trigger zone at the station pad. When the player is inside it
  below a speed threshold, show a prompt; pressing E lands immediately and calls
  `GameState.land()` (no alignment animation — prototype cut).

## Assets (all generated)

- **Environments:** CSG/primitive meshes with flat colours or simple generated
  textures. Station layout: corridors, a few rooms, and a hangar holding the ship.
- **Enemy sprites:** Programmatically generated pixel-art sprite sheets (PNG),
  4–8 frames per state.
- **Ships:** Low-poly meshes assembled from primitives or ArrayMesh.
- **Audio:** Stretch goal only; silence is acceptable.

## Error handling and edge cases

- **Player death (FPS):** Fade out, respawn at station spawn with full health.
  Enemy state persists as-is.
- **Ship destroyed:** Fade out, respawn docked at the station (back in FPS mode at
  the cockpit, ship hull restored).
- **Out of map:** Kill-plane Area3D below the station map triggers death handling.
- **Flight bounds:** Soft boundary at ~5 km from origin: nudge the ship back and
  show a HUD warning.

## Testing

- **Unit tests (minimal custom GDScript harness):** Pure logic only — GameState
  transitions, damage/health math, throttle/velocity model maths. A small
  `run_tests.gd` script run via `godot --headless --script`; avoids the GUT
  addon download and its headless setup.
- **Smoke tests:** Each scene instantiates headless without script errors.
- **Manual checklist:** Feel, AI behaviour, and the full loop verified by hand
  against a documented checklist (movement feel, enemy reactions, transition
  integrity, landing flow).

## Out of scope

- Seamless station/space transition, origin shifting, moving interiors.
- Multiple landing destinations, trading, docking computers.
- Weapon variety beyond one gun (FPS) and one blaster set (flight).
- Save/load, menus beyond a pause/quit, audio (stretch).
