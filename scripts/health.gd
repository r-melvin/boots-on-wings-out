extends RefCounted

var max_hp: int
var hp: int

func _init(p_max: int) -> void:
	max_hp = p_max
	hp = p_max

func take_damage(amount: int) -> bool:
	if hp <= 0:
		return false
	hp = maxi(hp - amount, 0)
	return hp == 0

func is_dead() -> bool:
	return hp <= 0
