extends "res://tests/test.gd"
## The desktop keeps a lined-up icon where the player saw it when another arrives, but that pin is
## its own memory: a setup patch of the change holds only the new folder, not every icon's place.

const WIN95 := "res://win95/win95.tscn"  # loaded at run time: it names the Game autoload


func run() -> void:
	var customer: Customer = load("res://customers/office_girl.tres")
	var job := Job.new(customer, Problem.new(), 0, 0)
	job.powered = true
	job.skips_boot = true
	var win95: Control = (load(WIN95) as PackedScene).instantiate()
	var state: Node = win95.get_node("ComputerState")  # untyped: its script names the Game autoload
	state.job = job
	root.add_child(win95)
	for i in 5:
		await process_frame
	var setup: Win95Setup = state.setup
	var before := SetupPatch.start(customer, game.week.patches)  # as Game.setup_for made the running copy
	SetupPatch.catch_up(before, customer, null, true, game.week.errands(), game.week.patches)
	check("before the new folder, nothing differs", (SetupPatch.between(before, setup) as SetupPatch).is_empty(), true)
	state.call("new_folder", setup.desktop)
	for i in 5:
		await process_frame
	check("the icons there are pinned where they were seen", setup.desktop.filter(func(f: Win95File) -> bool: return f.seen_at != Vector2.ZERO).size() > 1, true)
	var patch: Variant = SetupPatch.between(before, setup)
	check("the patch holds only the new folder", (patch as SetupPatch).write().strip_edges().begins_with("folder Desktop\\New Folder"), true)
	check("and no place", (patch as SetupPatch).write().contains("desktop_position"), false)
