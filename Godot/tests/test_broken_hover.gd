extends "res://tests/test.gd"
## In the open case, a broken piece under the mouse shows the broken hover outline (red), in its place
## and on the mat; a healthy one shows the usual hover outline, and neither shows red off the mouse.


func run() -> void:
	var accountant: Customer = load("res://customers/activist_guy.tres")
	var slot_1: Part = load("res://parts/ram_1.tres")
	var slot_2: Part = load("res://parts/ram_2.tres")
	game.start_day(make_day(1, [[accountant, load("res://problems/bad_ram.tres")]]))
	game.open_shop()
	game.customer_arrived()
	game.dialogue_finished()
	game.customer_left()
	var job: Job = game.jobs[0]
	var bad: Part = slot_1 if job.piece(slot_1).broken else slot_2
	var good: Part = slot_2 if bad == slot_1 else slot_1
	var case: Node3D = (load("res://rooms/shop/open_case.tscn") as PackedScene).instantiate()  # untyped: OpenCase needs the Game autoload to compile
	root.add_child(case)
	await process_frame
	case.set(&"job", job)
	game.focus_job(job)
	game.go_to_view(&"Workview")
	game.lay_down(job)
	game.turn_screw(job, 0)
	game.turn_screw(job, 1)
	game.open_case(job, true)
	case.set(&"active", true)
	await process_frame

	var red: Color = (case.get(&"outline") as ClickableOutline).broken_hover_color
	var hover: Color = case.get(&"hover_color")
	var places := case.get_node("%Places")
	var place_hotspot := func(part: Part) -> Hotspot: return places.get_node(String(part.id())).get_node("Hotspot")
	var colour := func(part: Part) -> Color: return _overlay(places.get_node(String(part.id())))

	check("off the mouse, the broken module isn't red", colour.call(bad) == red, false)
	(place_hotspot.call(bad) as Hotspot).mouse_entered.emit()
	check("the broken module under the mouse is red", colour.call(bad), red)
	(place_hotspot.call(bad) as Hotspot).mouse_exited.emit()
	(place_hotspot.call(good) as Hotspot).mouse_entered.emit()
	check("the good module under the mouse has the usual hover colour", colour.call(good), hover)
	(place_hotspot.call(good) as Hotspot).mouse_exited.emit()

	check("the broken module comes out", game.take_part(job, bad), true)
	game.put_on_mat(job)
	await process_frame
	var spot_hotspot: Hotspot = null
	for spot: Node in case.get_node("%Spots").get_children():
		var hotspot := spot.get_node("Hotspot") as Hotspot
		if hotspot.input_ray_pickable:
			spot_hotspot = hotspot
	check("the mat pile with the broken module takes a click", spot_hotspot != null, true)
	if spot_hotspot == null:
		return
	spot_hotspot.mouse_entered.emit()
	check("the broken module on the mat under the mouse is red", _overlay(case.get_node("%Spots")), red)
	spot_hotspot.mouse_exited.emit()
	case.queue_free()
	await process_frame


# The outline colour of the first outlined mesh under [param node], or transparent black.
func _overlay(node: Node) -> Color:
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_overlay is StandardMaterial3D:
			return (mesh.material_overlay as StandardMaterial3D).albedo_color
	return Color(0, 0, 0, 0)
