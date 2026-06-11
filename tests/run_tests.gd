extends SceneTree

const TEST_SCRIPTS := [
	"res://tests/test_health.gd",
	"res://tests/test_flight_model.gd",
	"res://tests/test_game_state.gd",
]

func _init() -> void:
	var total := 0
	var failed := 0
	for path in TEST_SCRIPTS:
		if not ResourceLoader.exists(path):
			continue
		var test = load(path).new()
		for m in test.get_method_list():
			if not m.name.begins_with("test_"):
				continue
			total += 1
			test.current = m.name
			test.call(m.name)
		for f in test.failures:
			failed += 1
			printerr("FAIL " + f)
	print("%d tests, %d assertion failures" % [total, failed])
	quit(1 if failed > 0 else 0)
