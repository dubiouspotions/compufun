extends "res://tests/test.gd"
## posters_bounce: every copy of the trail stays until the event ends, and each one draws over all the
## copies before it, as in the Solitaire win: the copies sort in the order they were left. The signs on
## the counter front fall only once the wall sheets have landed, and the night doesn't wait for them.

const FLAG: StringName = &"sign_posters_bounce"
const WALL: Array[StringName] = [&"SignLeft", &"CommercialPoster", &"Sign"]
const COUNTER: Array[StringName] = [&"FuntasticSticker", &"TrashPoster", &"TapedNote"]


func run() -> void:
	var room := Node3D.new()
	root.add_child(room)
	for at: int in 3:
		var sheet := _sheet()
		sheet.name = WALL[at]
		sheet.position = Vector3(-3.0 + 3.0 * at, 2.0, -5.0)
		room.add_child(sheet)
		sheet.add_to_group(&"solitaire_posters")
	var counter: Array[Node3D] = []
	for at: int in 3:
		var sheet: Node3D = _note() if COUNTER[at] == &"TapedNote" else _sheet()
		sheet.name = COUNTER[at]
		sheet.position = Vector3(-0.9 + 0.75 * at, 0.75, -0.92)
		room.add_child(sheet)
		sheet.add_to_group(&"solitaire_posters")
		counter.append(sheet)
	var sign: Node = load("res://corruption/posters_bounce.tscn").instantiate()
	room.add_child(sign)
	var trail: Node = sign.get_node("%Trail")
	game.set_flag(FLAG, 1)
	check("the night waits while the wall sheets fall", sign.busy(), true)
	var most := 0
	var homes: Array[Vector3] = []
	for sheet: Node3D in counter:
		homes.append(sheet.position)
	var counter_at_release: Array[bool] = []
	while game.flag(FLAG) == 1 and now() < 60.0:
		await process_frame
		most = maxi(most, trail.get_child_count())
		if counter_at_release.is_empty() and not sign.busy():
			for at: int in counter.size():
				counter_at_release.append(counter[at].position.distance_to(homes[at]) < 0.1)  # the first may have taken one step
			check("the night stops waiting while the event still runs", game.flag(FLAG), 1)
	check("the counter signs are still in place when the night may fade", counter_at_release, [true, true, true])
	check("the fall ends", game.flag(FLAG), 2)
	check("no copy goes before the end", trail.get_child_count(), most)
	for sheet: Node3D in counter:
		check("%s bounces just in front of the counter" % sheet.name, absf(sheet.position.z - float(sign.get("fade_lane_z"))) < 0.001, true)
	var layered: Shader = load("res://shaders/psx_world_layered.gdshader")
	var offsets: Array[float] = []
	var in_pass := 0
	var labels := 0
	for copy: GeometryInstance3D in trail.get_children():
		offsets.append(copy.sorting_offset)
		if copy is Label3D:
			labels += 1
			in_pass += 1
		elif copy.material_override is ShaderMaterial and (copy.material_override as ShaderMaterial).shader == layered:
			in_pass += 1
		elif copy.material_override is BaseMaterial3D and (copy.material_override as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
			in_pass += 1
	var sorted := offsets.duplicate()
	sorted.sort()
	check("every sheet leaves copies", trail.get_child_count() > 60, true)
	check("the note's text leaves copies", labels > 10, true)
	check("every copy is in the transparent pass", in_pass, trail.get_child_count())
	check("each copy sorts over the ones before it", [offsets == sorted, offsets.size() == _unique(offsets)], [true, true])
	game.set_flag(FLAG, 0)
	await process_frame
	await process_frame
	check("stage 0 takes the trail away", trail.get_child_count(), 0)
	room.queue_free()


func _sheet() -> MeshInstance3D:
	var sheet := MeshInstance3D.new()
	sheet.mesh = QuadMesh.new()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/psx_world.gdshader")
	sheet.material_override = material
	return sheet


# Like props/taped_note.tscn: paper, a label and an arrow whose material is on its mesh.
func _note() -> Node3D:
	var note := Node3D.new()
	var paper := _sheet()
	(paper.mesh as QuadMesh).size = Vector2(0.66, 0.34)
	note.add_child(paper)
	var text := Label3D.new()
	text.text = "Opening the shop"
	note.add_child(text)
	var arrow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var ink := StandardMaterial3D.new()
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	quad.material = ink
	arrow.mesh = quad
	note.add_child(arrow)
	return note


func _unique(values: Array[float]) -> int:
	var seen := {}
	for value: float in values:
		seen[value] = true
	return seen.size()
