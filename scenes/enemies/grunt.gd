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
