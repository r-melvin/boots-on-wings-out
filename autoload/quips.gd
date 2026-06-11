extends CanvasLayer

const SHOW_TIME := 2.2

const GRUNT_KILLS := [
	"Stay down.",
	"Mopped up. Send the bill.",
	"Nothing personal. Okay, a little personal.",
]
const FIGHTER_KILLS := [
	"Smoked. Literally.",
	"Insurance won't cover that.",
	"Dust to stardust, pal.",
]

var label: Label
var time_left := 0.0
var grunt_kill_i := 0
var fighter_kill_i := 0

func _ready() -> void:
	layer = 10
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.position += Vector2(0, 80)
	label.visible = false
	add_child(label)

func _process(delta: float) -> void:
	if time_left > 0.0:
		time_left -= delta
		if time_left <= 0.0:
			label.visible = false

func say(text: String) -> void:
	label.text = text
	label.visible = true
	time_left = SHOW_TIME

func grunt_kill() -> void:
	say(GRUNT_KILLS[grunt_kill_i % GRUNT_KILLS.size()])
	grunt_kill_i += 1

func fighter_kill() -> void:
	say(FIGHTER_KILLS[fighter_kill_i % FIGHTER_KILLS.size()])
	fighter_kill_i += 1
