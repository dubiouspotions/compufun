extends "res://tests/test.gd"
## Display > Screen Saver: Preview plays each registered saver (SAVERS in display_screensaver.gd) over the
## whole Win95 screen, or black for a listed name without one, and a key press ends it.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload
const SCREENSAVER_PATH := "res://win95/applets/display_screensaver.gd"  # loaded at run time: it names Game


func run() -> void:
	var computer := Computer.new()
	computer.win95_setup = Win95Setup.new()
	var owner := Customer.new()
	owner.computer = computer
	var check_saver := SettingCheck.new()
	check_saver.setting = &"screensaver"
	check_saver.broken_value = ""
	var job := Job.new(owner, software_problem(check_saver), 0, 0)
	game.jobs = [job] as Array[Job]
	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.job = job
	root.add_child(state)
	await process_frame
	var screen := Control.new()
	screen.size = Vector2(640, 480)
	root.add_child(screen)
	var desktop: Control = load("res://win95/desktop.gd").new()
	desktop.computer = state
	screen.add_child(desktop)
	var sheet: Control = (load("res://win95/applets/display.tres") as Applet).sheet.instantiate()
	desktop.add_child(sheet)
	var page: Node = sheet.find_child("Screen Saver", true, false)
	var list: OptionButton = page.get_node("Saver")
	var preview: Button = page.get_node("Preview")

	var savers: Dictionary = load(SCREENSAVER_PATH).get_script_constant_map()["SAVERS"]
	var unregistered: Array = Array(page.get("savers")).filter(func(n: String) -> bool: return not savers.has(n))
	var names: Array = savers.keys() + unregistered.slice(0, 1)
	for name: String in names:
		var row: int = Array(page.get("savers")).find(name) + 1
		check("%s is in the list" % name, row > 0, true)
		list.select(row)
		list.item_selected.emit(row)
		preview.pressed.emit()
		var saver: Control = screen.get_child(screen.get_child_count() - 1)
		var drawn: Script = savers.get(name)
		check("Preview plays %s over the screen" % name, saver.get_script() == drawn if drawn != null else saver.get_child(0) is ColorRect, true)
		check("%s is a Saver" % name, saver is Saver, true)
		await create_timer(1.0).timeout
		check("%s fills the screen" % name, saver.size, screen.size)
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.pressed = true
		saver.call(&"_gui_input", key)
		await process_frame
		check("a key ends %s" % name, is_instance_valid(saver), false)
	screen.queue_free()
	state.queue_free()

