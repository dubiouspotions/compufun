extends "res://tests/test.gd"
## The desktop screenshot prank: the icons go into a folder in a corner and a screenshot becomes
## the wallpaper; Cut and Paste move them back, refusing a name clash or a folder into itself, and
## a new wallpaper with the icons back fixes it.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload


func run() -> void:
	var prank: Problem = load("res://problems/desktop_prank.tres")
	var computer := Computer.new()
	computer.win95_setup = Win95Setup.new()
	var clouds: Texture2D = load("res://win95/wallpapers/clouds.png")
	computer.win95_setup.wallpaper = clouds
	computer.win95_setup.desktop = [file("todo.txt"), file("letter.doc")]
	var job := Job.new(customer(computer), prank, 0, 0)
	game.jobs = [job] as Array[Job]
	var setup: Win95Setup = game.setup_for(job)
	var hidden := setup.file_at("Desktop\\New Folder")
	check("one folder on the desktop, in the corner", [setup.desktop.size(), hidden != null and hidden.desktop_position != Vector2.ZERO], [1, true])
	check("it holds the icons", hidden.children.map(func(f: Win95File) -> String: return f.name), ["todo.txt", "letter.doc"])
	var shot := setup.wallpaper as DesktopScreenshot
	check("the wallpaper is a screenshot of the old one", [shot != null, shot.wallpaper if shot else null, shot.get_width() if shot else 0], [true, clouds, 640])
	prank.software_check.apply_break(setup)
	check("breaking twice is breaking once", [setup.desktop.size(), setup.wallpaper], [1, shot])

	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.job = job
	root.add_child(state)
	await process_frame
	var todo: Win95File = hidden.children[0]
	check("a folder into itself is refused", state.move_files([hidden] as Array[Win95File], hidden.children).contains("subfolder"), true)
	setup.desktop.append(file("todo.txt"))
	check("a name clash is refused", state.move_files([todo] as Array[Win95File], setup.desktop).contains("same name"), true)
	setup.desktop.pop_back()
	var back: Array[Win95File] = []
	back.assign(hidden.children)
	check("the icons back move", state.move_files(back, setup.desktop), "")
	check("but the wallpaper still fools", [hidden.children.size(), job.software_fixed], [0, false])
	state.apply_settings({&"wallpaper": clouds} as Dictionary[StringName, Variant])
	check("a new wallpaper fixes it", job.software_fixed, true)
	state.move_files([todo] as Array[Win95File], hidden.children)
	check("hiding an icon again un-fixes it", job.software_fixed, false)
	var places: Array[Vector2] = [Vector2(300, 200)]
	state.move_files([todo] as Array[Win95File], setup.desktop, places)
	check("a drop onto the desktop stands it there", [setup.desktop.has(todo), todo.desktop_position], [true, Vector2(300, 200)])
	places = [Vector2(40, 40)]
	state.move_files([todo] as Array[Win95File], setup.desktop, places)
	check("a drag on the desktop moves it", todo.desktop_position, Vector2(40, 40))
	state.move_files([todo] as Array[Win95File], hidden.children)
	check("moved into a folder, it lines up", todo.desktop_position, Vector2.ZERO)
	state.free()
	game.jobs = [] as Array[Job]


func customer(computer: Computer) -> Customer:
	var c := Customer.new()
	c.display_name = "Prankee"
	c.computer = computer
	return c


func file(file_name: String) -> Win95File:
	var f := Win95File.new()
	f.name = file_name
	return f
