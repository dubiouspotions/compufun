extends "res://tests/test.gd"
## posters_bounce: every copy of the trail stays until the event ends, and each one draws over all the
## copies before it, as in the Solitaire win: the copies sort in the order they were left.

const FLAG: StringName = &"sign_posters_bounce"


func run() -> void:
	var room := Node3D.new()
	root.add_child(room)
	for at: int in 3:
		var sheet := MeshInstance3D.new()
		sheet.name = [&"SignLeft", &"CommercialPoster", &"Sign"][at]
		sheet.mesh = QuadMesh.new()
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/psx_world.gdshader")
		sheet.material_override = material
		sheet.position = Vector3(-3.0 + 3.0 * at, 2.0, -5.0)
		room.add_child(sheet)
		sheet.add_to_group(&"solitaire_posters")
	var sign: Node = load("res://corruption/posters_bounce.tscn").instantiate()
	room.add_child(sign)
	var trail: Node = sign.get_node("%Trail")
	game.set_flag(FLAG, 1)
	var most := 0
	while game.flag(FLAG) == 1 and now() < 60.0:
		await process_frame
		most = maxi(most, trail.get_child_count())
	check("the fall ends", game.flag(FLAG), 2)
	check("no copy goes before the end", trail.get_child_count(), most)
	var layered: Shader = load("res://shaders/psx_world_layered.gdshader")
	var offsets: Array[float] = []
	var in_pass := 0
	for copy: MeshInstance3D in trail.get_children():
		offsets.append(copy.sorting_offset)
		if (copy.material_override as ShaderMaterial).shader == layered:
			in_pass += 1
	var sorted := offsets.duplicate()
	sorted.sort()
	check("every sheet leaves copies", trail.get_child_count() > 30, true)
	check("every copy is in the layered pass", in_pass, trail.get_child_count())
	check("each copy sorts over the ones before it", [offsets == sorted, offsets.size() == _unique(offsets)], [true, true])
	game.set_flag(FLAG, 0)
	await process_frame
	await process_frame
	check("stage 0 takes the trail away", trail.get_child_count(), 0)
	room.queue_free()


func _unique(values: Array[float]) -> int:
	var seen := {}
	for value: float in values:
		seen[value] = true
	return seen.size()
