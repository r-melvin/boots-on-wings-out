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
