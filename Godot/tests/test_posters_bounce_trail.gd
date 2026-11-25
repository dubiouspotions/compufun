extends "res://tests/test.gd"
## posters_bounce: every copy of the trail stays until the event ends, and each one draws over all the
## copies before it, as in the Solitaire win: the copies sort in the order they were left. The signs on
## the counter front fall only once the wall sheets have landed, and the night doesn't wait for them.
## The Open sign goes first, once it has had the time to turn over, and each sheet leaves its place on
## time.

const FLAG: StringName = &"sign_posters_bounce"
const WALL: Array[StringName] = [&"OpenSign", &"SignLeft", &"CommercialPoster", &"Sign"]
const STEP_TOLERANCE: float = 0.06  # a trail step and a frame
const COUNTER: Array[StringName] = [&"FuntasticSticker", &"TrashPoster", &"TapedNote"]


func run() -> void:
	var room := Node3D.new()
	root.add_child(room)
	var sheets: Array[Node3D] = []
	for at: int in WALL.size():
		var sheet := _sheet()
		sheet.name = WALL[at]
		sheet.position = Vector3(-3.0 + 2.0 * at, 2.0, -5.0)
		room.add_child(sheet)
		sheet.add_to_group(&"solitaire_posters")
		sheets.append(sheet)
	var counter: Array[Node3D] = []
	for at: int in 3:
		var sheet: Node3D = _note() if COUNTER[at] == &"TapedNote" else _sheet()
		sheet.name = COUNTER[at]
		sheet.position = Vector3(-0.9 + 0.75 * at, 0.75, -0.92)
		room.add_child(sheet)
		sheet.add_to_group(&"solitaire_posters")
		counter.append(sheet)
		sheets.append(sheet)
	var sign: Node = load("res://corruption/posters_bounce.tscn").instantiate()
	room.add_child(sign)
	var trail: Node = sign.get_node("%Trail")
	var open_sign: Node = load("res://props/open_sign.tscn").instantiate()
	check("the Open sign has turned over before it shakes", float(sign.get("lead_seconds")) >= float(open_sign.get("flip_seconds")), true)
	open_sign.free()
	var started := now()
	game.set_flag(FLAG, 1)
	check("the night waits while the wall sheets fall", sign.busy(), true)
	var most := 0
	var homes: Array[Vector3] = []
	for sheet: Node3D in counter:
		homes.append(sheet.position)
	var all_homes: Array[Vector3] = []
	for sheet: Node3D in sheets:
		all_homes.append(sheet.position)
	var left_at: Array[float] = []
	left_at.resize(sheets.size())
	left_at.fill(-1.0)
	var released := -1.0
	var counter_at_release: Array[bool] = []
	while game.flag(FLAG) == 1 and now() < 60.0:
		await process_frame
		most = maxi(most, trail.get_child_count())
		for at: int in sheets.size():
			if left_at[at] < 0.0 and sheets[at].position != all_homes[at]:
				left_at[at] = now() - started
		if counter_at_release.is_empty() and not sign.busy():
			released = now() - started
			for at: int in counter.size():
				counter_at_release.append(counter[at].position.distance_to(homes[at]) < 0.1)  # the first may have taken one step
			check("the night stops waiting while the event still runs", game.flag(FLAG), 1)
	check("the counter signs are still in place when the night may fade", counter_at_release, [true, true, true])
	var lead: float = sign.get("lead_seconds")
	var stagger: float = sign.get("stagger_seconds")
	var shake: float = sign.get("shake_seconds")
	var fade_stagger: float = sign.get("fade_stagger_seconds")
	var order: Array[StringName] = []
	var by_time := range(sheets.size())
	by_time.sort_custom(func(a: int, b: int) -> bool: return left_at[a] < left_at[b])
	for at: int in by_time:
		order.append(sheets[at].name)
	check("they leave in order, the Open sign first", order, WALL + COUNTER)
	for at: int in WALL.size():
		check("%s leaves its place on time" % WALL[at], absf(left_at[at] - (lead + at * stagger + shake)) < STEP_TOLERANCE, true)
	for at: int in COUNTER.size():
		check("%s leaves the counter on time" % COUNTER[at], absf(left_at[WALL.size() + at] - (released + at * fade_stagger)) < STEP_TOLERANCE, true)
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
