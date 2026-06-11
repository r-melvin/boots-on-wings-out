extends RefCounted

var failures: Array[String] = []
var current := ""

func assert_eq(got, expected, note := "") -> void:
	if got != expected:
		failures.append("%s: expected %s, got %s. %s" % [current, expected, got, note])

func assert_true(cond: bool, note := "") -> void:
	if not cond:
		failures.append("%s: expected true. %s" % [current, note])

func assert_almost(got: float, expected: float, eps := 0.001, note := "") -> void:
	if absf(got - expected) > eps:
		failures.append("%s: expected ~%s, got %s. %s" % [current, expected, got, note])
