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
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		hud.hide_prompt()
		return
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
