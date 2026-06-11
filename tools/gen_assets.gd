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
