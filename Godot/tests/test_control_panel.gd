extends "res://tests/test.gd"
## The Control Panel's icons come from the .CPL files in C:\WINDOWS\SYSTEM; Apply sets the running
## copy and reports the fix; Add/Remove Programs uninstalls; the computer's clock has its offset.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload


func run() -> void:
	var raytrace := folder("Raytrace 2", [file("RAYTRACE.EXE")])
	var shortcut := file("Raytrace")
	shortcut.target = "C:\\Program Files\\Raytrace 2\\RAYTRACE.EXE"
	var notepad := file("Notepad")
	notepad.target = "C:\\WINDOWS\\NOTEPAD.EXE"
	var start_menu := folder("Start Menu", [folder("Programs", [shortcut, notepad])])
	var windows := folder("WINDOWS", [load("res://win95/system_stock.tres"), start_menu])
	var computer := Computer.new()
	computer.win95_setup = Win95Setup.new()
	computer.win95_setup.drive_c = [windows, folder("Program Files", [raytrace, folder("Accessories", [])])]

	var swapped := SettingCheck.new()
	swapped.setting = &"left_handed"
	swapped.broken_value = true
	var job := Job.new(customer(computer, swapped), 0, 0)
	game.jobs = [job] as Array[Job]
	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.job = job
	root.add_child(state)
	await process_frame  # _ready waits for the first frame under -s
	var setup: Win95Setup = state.setup

	var names: Array = state.control_panel().map(func(a: Applet) -> String: return a.name)
	check("16 icons, by name", names, ["Add New Hardware", "Add/Remove Programs", "Date/Time", "Display", "Fonts", "Joystick",
		"Keyboard", "Modems", "Mouse", "Multimedia", "Network", "Passwords", "Printers", "Regional Settings", "Sounds", "System"])
	var desk := setup.file_at("C:\\WINDOWS\\SYSTEM\\DESK.CPL")
	state.rename_file(desk, "DESK.CP_")
	check("a renamed .CPL hides its applets", state.control_panel().any(func(a: Applet) -> bool: return a.name == "Display"), false)
	state.rename_file(desk, "desk.cpl")
	check("any case of .CPL lists them", state.control_panel().size(), 16)
	var stock: Win95File = load("res://win95/system_stock.tres")
	check("the stock SYSTEM folder stays whole", stock.children.size(), 11)

	check("broken at boot", [setup.left_handed, job.software_fixed], [true, false])
	state.apply_settings({&"left_handed": false, &"pointer_trails": 4} as Dictionary[StringName, Variant])
	check("Apply sets the copy and fixes", [setup.left_handed, setup.pointer_trails, job.software_fixed], [false, 4, true])
	check("the .tres stays as it was", computer.win95_setup.left_handed, false)

	check("Add/Remove lists the folders in Program Files", state.removable_programs().map(func(f: Win95File) -> String: return f.name), ["Accessories", "Raytrace 2"])
	state.uninstall(setup.file_at("C:\\Program Files\\Raytrace 2"))
	check("uninstall removes the folder", setup.file_at("C:\\Program Files\\Raytrace 2"), null)
	check("and its shortcuts, not the others", setup.file_at("C:\\WINDOWS\\Start Menu\\Programs").children.map(func(f: Win95File) -> String: return f.name), ["Notepad"])

	var day1: Dictionary = state.now()
	check("the clock is the game's date", [day1.year, day1.month, day1.day], [1996, 5, 31])
	var target := {year = 1999, month = 12, day = 31, hour = 23, minute = 59, second = 0}
	state.apply_settings({&"clock_offset_seconds": state.offset_for(target)} as Dictionary[StringName, Variant])
	var later: Dictionary = state.now()
	check("Date/Time moves the clock", [later.year, later.month, later.day, later.hour, later.minute], [1999, 12, 31, 23, 59])
	var todo := file("todo.txt")
	setup.desktop.append(todo)
	state.write_text(todo, "party")
	check("a save is dated by the computer's clock", todo.modified.begins_with("Friday, December 31, 1999 11:59"), true)

	state.free()
	game.jobs = [] as Array[Job]


func customer(computer: Computer, check_: SoftwareCheck) -> Customer:
	var c := Customer.new()
	c.computer = computer
	c.problem = Problem.new()
	c.problem.location = Problem.Location.SOFTWARE
	c.problem.software_check = check_
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
