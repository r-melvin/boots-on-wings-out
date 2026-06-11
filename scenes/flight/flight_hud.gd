extends CanvasLayer

var ship: Node3D
var speed_label: Label
var hull_label: Label
var throttle_bar: ProgressBar
var prompt_label: Label
var warn_label: Label
var lead_marker: Label

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

	lead_marker = Label.new()
	lead_marker.text = "[ ]"
	lead_marker.visible = false
	add_child(lead_marker)

func _process(_delta: float) -> void:
	if ship == null:
		return
	speed_label.text = "SPD %d" % int(ship.velocity.length())
	hull_label.text = "HULL %d" % GameState.ship_hull
	throttle_bar.value = ship.throttle
	_update_lead()

func show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = true

func hide_prompt() -> void:
	prompt_label.visible = false

func set_warning(on: bool) -> void:
	warn_label.visible = on

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
