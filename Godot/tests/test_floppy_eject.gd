extends "res://tests/test.gd"
## In the Workview, the eject button of the floppy drive sticks out and pulses while a floppy is in A:,
## and a click on it ejects the floppy (Game.eject_floppy) and lets the button in; with the floppy in
## the hand a click puts it back (Game.insert_floppy); on an empty drive with an empty hand the button
## is flush and a click on it does nothing.

var _shop: Node3D
var _camera: Camera3D


func run() -> void:
	_shop = load("res://rooms/shop/shop.tscn").instantiate()
	root.add_child(_shop)
	await process_frame
	check("restore a floppy in A: and an empty drive, in the Workview", game.restore({"jobs": [
		{"customer": "res://customers/young_entrepreneur.tres", "problem": "bootfloppy", "slot": 0},
		{"customer": "res://customers/skater_bro.tres", "problem": "dust_overheat", "slot": 1}],
		"focus_slot": 0, "connected_slot": -1, "view": "Workview"}), "")
	await create_timer(1.0).timeout  # the camera reaches the Workview
	_camera = _shop.get_node("%Camera")
	var job: Job = game.jobs[0]
	var drive := _drive(job)
	var empty := _drive(game.jobs[1])
	check("a floppy in A: sticks the button out, and it pulses", [game.has_floppy(job), _out(drive), drive.eject_button.material_overlay != null], [true, true, true])
	check("an empty drive's button is flush", [game.has_floppy(game.jobs[1]), _out(empty), empty.eject_button.material_overlay == null], [false, false, true])

	var at := _camera.unproject_position(drive.eject_button.global_position)
	var hotspot: Node = _shop.hotspot_at(at)
	check("the eject button takes the click", hotspot != null, true)
	_click(at)
	await create_timer(0.3).timeout
	check("a click on it ejects the floppy", [game.has_floppy(job), job.software_fixed], [false, true])
	check("the button goes in", _out(drive), false)
	check("with the floppy in the hand, the drive pulses to take it back", [_shop.hotspot_at(at) == hotspot, drive.eject_button.material_overlay != null], [true, true])
	_click(at)
	await create_timer(0.3).timeout
	check("a click puts it back in", [game.has_floppy(job), game.hand, job.software_fixed, _out(drive)], [true, null, false, true])
	_click(at)
	await create_timer(0.3).timeout
	game.trash_part()
	await process_frame
	check("ejected and trashed, the button stops pulsing", [game.has_floppy(job), drive.eject_button.material_overlay == null], [false, true])
	check("the empty drive takes no click", _shop.hotspot_at(at) == hotspot, false)
	_click(at)
	check("a click on it does nothing", [game.has_floppy(job), job.software_fixed], [false, true])
	_shop.queue_free()


func _drive(job: Job) -> FloppyDrive:
	for computer: Node in _shop.get_node("%JobSlots").find_children("*", "JobComputer", true, false):
		if computer.get("job") == job:
			return computer.get_node("Tower").call("floppy_drive")
	return null


func _out(drive: FloppyDrive) -> bool:
	return drive.eject_button.position.z > drive.eject_travel / 2.0


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = root.get_final_transform() * at
		event.global_position = event.position
		Input.parse_input_event(event)
		Input.flush_buffered_events()
