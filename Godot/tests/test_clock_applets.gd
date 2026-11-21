extends "res://tests/test.gd"
## The taskbar shows the computer's clock; Date/Time sets it; System shows the setup; Add/Remove
## Programs uninstalls.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload

var state: Node
var setup: Win95Setup


func run() -> void:
	var job := Job.new(customer(), 0, 0)
	game.jobs = [job] as Array[Job]
	state = load(COMPUTER_STATE_PATH).new()
	state.job = job
	root.add_child(state)
	await process_frame  # _ready waits for the first frame under -s
	setup = state.setup

	test_systray()

	state.free()
	game.jobs = [] as Array[Job]


func test_systray() -> void:
	var tray: Node = load("res://win95/systray.tscn").instantiate()
	root.add_child(tray)
	tray.set(&"computer", state)
	var clock: Label = tray.get_node("%Clock")
	check("the taskbar shows the computer's clock", clock.text, Win95Time.clock(state.now()))
	state.apply_settings({&"clock_offset_seconds": setup.clock_offset_seconds + 3 * 3600} as Dictionary[StringName, Variant])
	check("and follows a Date/Time change at once", clock.text, Win95Time.clock(state.now()))
	state.apply_settings({&"clock_offset_seconds": 0} as Dictionary[StringName, Variant])
	tray.free()


func customer() -> Customer:
	var raytrace := folder("Raytrace 2", [file("RAYTRACE.EXE")])
	var shortcut := file("Raytrace")
	shortcut.target = "C:\\Program Files\\Raytrace 2\\RAYTRACE.EXE"
	var notepad := file("Notepad")
	notepad.target = "C:\\WINDOWS\\NOTEPAD.EXE"
	var start_menu := folder("Start Menu", [folder("Programs", [shortcut, notepad])])
	var c := Customer.new()
	c.computer = Computer.new()
	c.computer.win95_setup = Win95Setup.new()
	c.computer.win95_setup.drive_c = [folder("WINDOWS", [start_menu]), folder("Program Files", [raytrace, folder("Accessories", [])])]
	c.problem = Problem.new()
	return c


func file(file_name: String) -> Win95File:
	var f := Win95File.new()
	f.name = file_name
	return f


func folder(folder_name: String, children: Array[Resource]) -> Win95File:
	var f := Win95File.new()
	f.name = folder_name
	f.is_folder = true
	f.children = children
	return f
