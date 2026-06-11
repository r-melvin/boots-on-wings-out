extends StaticBody3D

var prompt_name := "Activate cockpit"

func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.9, 0.8)
	col.shape = shape
	col.position.y = 0.45
	add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.9, 0.8)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.3, 0.5)
	bm.material = mat
	mesh.mesh = bm
	mesh.position.y = 0.45
	add_child(mesh)

func interact() -> void:
	GameState.enter_flight()
