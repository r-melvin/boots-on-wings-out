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
- [ ] Lead marker [ ] floats ahead of nearest fighter; shooting at it lands hits
- [ ] Green bolts kill fighters in ~3 hits
- [ ] Hull 0: respawn at cockpit in station, hull restored
- [ ] Beyond ~4 km: RETURN TO STATION warning, pushed back

## Landing + loop
- [ ] Pad prompt appears only inside pad zone below speed 8
- [ ] E lands: back in station at cockpit, facing the ship exit
- [ ] Cleared grunts still dead after a full loop
- [ ] Second full loop works (station -> fly -> land -> station)

## Known prototype quirks
- E is both interact and roll-right: rolling right inside the pad zone at low speed can trigger landing
- Bolt hits on steep vertical approaches may occasionally miss (discrete collision)
