extends "res://tests/test.gd"
## A setup patch can give a computer a plain desktop: no wallpaper, in a colour of its own, and the
## desktop draws it.


func run() -> void:
	var parsed := SetupPatch.parse("set wallpaper: none\nset desktop_color: Color(0, 0, 0, 1)\n", "res://story/computers/test.setup")
	check("the patch parses", parsed.errors, PackedStringArray())
	var activist: Customer = load("res://customers/activist_guy.tres")
	var running := activist.computer.win95_setup.copy()
	check("a computer's desktop is Win95's teal by default", running.desktop_color, Color(0, 0.5019608, 0.5019608))
	(parsed.value as SetupPatch).apply(running)
	check("the patch sets no wallpaper and a black desktop", [running.wallpaper, running.desktop_color], [null, Color.BLACK])
	var game: Node = root.get_node("Game")
	game.setups[activist.computer] = running
	var job := Job.new(activist, Problem.new(), 0, 0)
	job.broken = true
	job.powered = true
	var win95: Control = (load("res://win95/win95.tscn") as PackedScene).instantiate()
	win95.get_node("ComputerState").job = job
	root.add_child(win95)
	win95.size = Vector2(640, 480)
	for i in 3:
		await process_frame
	check("the desktop shows no wallpaper over black", [(win95.get_node("Desktop/DesktopBackground") as TextureRect).texture == null, (win95.get_node("Desktop/DesktopColour") as ColorRect).color], [true, Color.BLACK])
	win95.free()
	game.setups.erase(activist.computer)
