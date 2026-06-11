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
