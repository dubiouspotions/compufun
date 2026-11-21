extends "res://tests/test.gd"
## A computer's running copy: made once per computer, broken once per job, kept across a return
## visit; FileCheck breaks and fixes; saving a text file; the sizes that Properties shows.

const PROPERTIES := preload("res://win95/properties_window.gd")
const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload


func run() -> void:
	var computer := Computer.new()
	computer.win95_setup = Win95Setup.new()
	var windows := folder("WINDOWS", [file("PBRUSH.EXE", ""), file("SYSTEM.INI", "[386Enh]\ndevice=*vmouse\nkeyboard=*vkd")])
	computer.win95_setup.drive_c = [windows]
	computer.win95_setup.desktop = [file("todo.txt", "milk")]

	var noimages := FileCheck.new()
	noimages.path = "C:\\WINDOWS\\PBRUSH.EXE"
	noimages.broken_name = "PBRUSH.EX_"
	var first := Job.new(customer(computer, noimages), 0, 0)
	game.jobs = [first] as Array[Job]
	var setup: Win95Setup = game.setup_for(first)
	check("broken: renamed", [setup.file_at("C:\\WINDOWS\\PBRUSH.EXE"), setup.file_at("c:\\windows\\pbrush.ex_") != null], [null, true])
	check("the .tres stays healthy", computer.win95_setup.file_at("C:\\WINDOWS\\PBRUSH.EXE") != null, true)
	check("one copy per computer", game.setup_for(first), setup)

	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.job = first
	root.add_child(state)
	await process_frame  # _ready waits for the first frame under -s
	check("not fixed at boot", first.software_fixed, false)
	state.rename_file(setup.file_at("C:\\WINDOWS\\PBRUSH.EX_"), "PBRUSH.EXE")
	check("renaming back fixes", first.software_fixed, true)
	var todo := setup.file_at("Desktop\\todo.txt")
	state.write_text(todo, "eggs\nflour")
	check("saved into the copy only", [todo.contents, computer.win95_setup.desktop[0].contents], ["eggs\nflour", "milk"])
	check("path of a desktop file", state.path_of(todo), "C:\\WINDOWS\\Desktop\\todo.txt")
	state.free()

	var no_mouse := FileCheck.new()
	no_mouse.path = "C:\\WINDOWS\\SYSTEM.INI"
	no_mouse.healthy_line = "device=*vmouse"
	no_mouse.broken_line = ";device=*vmouse"
	var back := Job.new(customer(computer, no_mouse), 1, 1)
	game.jobs = [back] as Array[Job]
	check("a return visit gets the same copy", game.setup_for(back), setup)
	check("with the player's changes", [todo.contents, setup.file_at("C:\\WINDOWS\\PBRUSH.EXE") != null], ["eggs\nflour", true])
	var ini := setup.file_at("C:\\WINDOWS\\SYSTEM.INI")
	check("the new break on top", [ini.contents, no_mouse.is_fixed(setup)], ["[386Enh]\n;device=*vmouse\nkeyboard=*vkd", false])
	no_mouse.apply_break(setup)
	check("breaking twice is breaking once", ini.contents, "[386Enh]\n;device=*vmouse\nkeyboard=*vkd")
	ini.contents = "[386Enh]\n  DEVICE=*vmouse\nkeyboard=*vkd"
	check("the line fixes, ignoring case and spaces", no_mouse.is_fixed(setup), true)

	check("CRLF counts two bytes", todo.size_in_bytes(), 11)
	check("small size", PROPERTIES.size_text(426), "426 bytes")
	check("KB size", PROPERTIES.size_text(1262), "1.23KB (1,262 bytes)")
	game.jobs = [] as Array[Job]


func customer(computer: Computer, check_: SoftwareCheck) -> Customer:
	var c := Customer.new()
	c.computer = computer
	c.problem = Problem.new()
	c.problem.location = Problem.Location.SOFTWARE
	c.problem.software_check = check_
	return c


func file(file_name: String, contents: String) -> Win95File:
	var f := Win95File.new()
	f.name = file_name
	f.contents = contents
	return f


func folder(folder_name: String, children: Array[Resource]) -> Win95File:
	var f := Win95File.new()
	f.name = folder_name
	f.is_folder = true
	f.children = children
	return f
