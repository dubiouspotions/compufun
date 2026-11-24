extends "res://tests/test.gd"
## Win95 reads a program in from the disk before its window opens, with the busy pointer: the first
## time after a boot takes the program's load_seconds, the next time a share of it; a fragmented
## drive or too little memory takes longer, and a power cut opens nothing. The drive ticks meanwhile.

const WIN95 := "res://win95/win95.tscn"  # loaded at run time: its scripts name the Game autoload


func run() -> void:
	var script: GDScript = load("res://win95/win95.gd")
	script.set(&"load_scale", 1.0)
	check("the tests can turn loading on", script.get(&"load_scale"), 1.0)

	var drive := HardDrive.new()
	root.add_child(drive)
	drive.read.call(0.3)  # not awaited, to hear it meanwhile
	check("a drive ticks while it reads", drive.playing, true)
	check("and reads to the end", await drive.read(0.05), true)
	drive.free()

	var job := Job.new(load("res://customers/activist_guy.tres"), Problem.new(), 0, 0)
	game.jobs = [job] as Array[Job]
	game.set_powered(job, true)
	var win95: Control = (load(WIN95) as PackedScene).instantiate()
	win95.get_node("ComputerState").job = job
	win95.comfortable_memory_kb = 0  # memory doesn't slow it, until checked below
	root.add_child(win95)
	await process_frame
	var desktop: Node = win95.get_node("Desktop")
	var setup: Win95Setup = win95.get_node("ComputerState").setup
	var notepad := setup.file_at("C:\\WINDOWS\\NOTEPAD.EXE")

	var first := await _open(win95, notepad)
	check("Notepad isn't there at once; the pointer is busy meanwhile", first.busy_at_once, true)
	check("then it opens, and the pointer is the arrow again", [first.opened, win95.pointer_busy], [true, false])
	check("Notepad's first load takes its load_seconds", absf(first.seconds - 0.3) < 0.05, true)
	desktop.active_window().close()
	var again := await _open(win95, notepad)
	check("the second time it comes from memory, quicker", again.seconds < first.seconds * 0.5, true)
	desktop.active_window().close()

	setup.fragmented = true
	check("a fragmented drive slows loading", win95._slowness(), win95.fragmented_factor)
	setup.fragmented = false
	win95.comfortable_memory_kb = 16384
	win95.set(&"_memory_kb", 8192)
	check("half the memory loads twice as slow", win95._slowness(), 2.0)
	win95.set(&"_memory_kb", 1024)
	check("however little memory, at most max_swap_factor", win95._slowness(), win95.max_swap_factor)
	win95.comfortable_memory_kb = 0

	var paint := setup.file_at("C:\\WINDOWS\\PBRUSH.EXE")
	check("the activist has Paint", paint != null, true)
	if paint != null:
		var windows: int = desktop.windows().size()
		win95.open_file(paint)
		await process_frame
		game.set_powered(job, false)
		for i: int in 90:
			await process_frame
		check("a power cut while it loads opens nothing", [desktop.windows().size(), win95.pointer_busy], [windows, false])

	game.jobs = [] as Array[Job]
	win95.free()
	script.set(&"load_scale", 0.0)


# Opens [param file] and waits for its window: whether the pointer was busy right after the open,
# whether a window opened, and the seconds it took.
func _open(win95: Control, file: Win95File) -> Dictionary:
	var desktop: Node = win95.get_node("Desktop")
	var before: Node = desktop.active_window()
	win95.open_file(file)
	var result := {"busy_at_once": win95.pointer_busy and desktop.active_window() == before, "opened": false, "seconds": 0.0}
	var frames := 0
	while frames < 300 and (desktop.active_window() == before or desktop.active_window() == null):
		await process_frame
		frames += 1
	result.opened = frames < 300
	result.seconds = float(frames) / FPS
	return result
