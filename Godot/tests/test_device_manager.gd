extends "res://tests/test.gd"
## System > Device Manager lists the devices by type, collapsed unless one has a problem, and a stand-in
## shows instead of the device for the part that it poses as: Skater Bro's organs.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload


func run() -> void:
	var plain := await _tree(load("res://problems/dust_overheat.tres"))
	check("a plain computer: the types, those with a problem open", plain.shown_texts(), PackedStringArray([
		"Computer", "CDROM", "Disk drives", "Display adapters", "Floppy disk controllers", "Standard Floppy Disk Controller",
		"Hard disk controllers", "Keyboard", "Monitor", "Mouse", "Standard Serial Mouse", "Ports (COM & LPT)",
		"Sound, video and game controllers", "Creative Labs Sound Blaster", "Gameport Joystick", "System devices"]))
	_desktop.queue_free()
	var organs := await _tree(load("res://problems/organ_failure.tres"))
	var shown := organs.shown_texts()
	check("his organs instead of the hardware, their types open", [shown.has("Brain"), shown.has("Liver"), shown.has("Heart"), shown.has("Spleen"), shown.has("Lung"), shown.count("Kidney"), shown.has("System board")], [true, true, true, true, true, 2, false])
	var disks := shown.find("Disk drives")
	var box := organs.global_position + Vector2(10, 2 + disks * 17 + 8)
	await _click(box)
	check("a click on the box hides the drives", organs.shown_texts().has("Brain"), false)
	await _click(box)
	check("and shows them again", organs.shown_texts().has("Brain"), true)


var _desktop: Control


# The Device Manager tab of the System sheet, open on a desktop of a computer with [param problem].
func _tree(problem: Problem) -> FolderTree:
	var computer := Computer.new()
	computer.win95_setup = Win95Setup.new()
	var owner := Customer.new()
	owner.computer = computer
	var job := Job.new(owner, problem, 0, 0)
	game.jobs = [job] as Array[Job]
	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.job = job
	root.add_child(state)
	await process_frame
	_desktop = load("res://win95/desktop.gd").new()
	_desktop.computer = state
	_desktop.size = Vector2(640, 480)
	root.add_child(_desktop)
	var sheet: Node = load("res://win95/applets/system.tscn").instantiate()
	_desktop.add_child(sheet)
	var tree := sheet.get_node("%DeviceTree") as FolderTree
	var tabs := sheet.get_node("%Tabs") as TabContainer
	tabs.current_tab = tabs.get_tab_idx_from_control(sheet.get_node("%Tabs/Device Manager"))
	await process_frame
	await process_frame
	return tree


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = at
		event.global_position = at
		root.push_input(event, true)  # root coordinates, past the window's stretch
		await process_frame
