extends "res://tests/test.gd"
## The email virus (VirusCheck, win95/bizopp.tscn): the break puts BIZOPP.EXE in C:\WINDOWS and a
## shortcut in StartUp, once; each boot that reaches the desktop runs it as a task, which opens and
## closes the CD tray; its file is in use, so a delete, rename or move is refused with the sharing
## violation; End Task in Close Program (Ctrl+Alt+Del) stops it; deleting it then fixes the problem,
## and the next boot runs nothing. Ctrl+Alt+Del twice restarts the computer.

const VIRUS_PATH := "C:\\WINDOWS\\BIZOPP.EXE"
const SHARING := ": There has been a sharing violation.\nThe source or destination file may be in use."
const WAIT := 0.5


func run() -> void:
	var problem: Problem = load("res://problems/email_virus.tres")
	var virus_check := problem.software_check as VirusCheck
	check("email_virus has a VirusCheck", virus_check != null, true)
	virus_check.virus.program = _fast(virus_check.virus.program)
	var job := Job.new(load("res://customers/young_entrepreneur.tres"), problem, 0, 0)
	game.jobs = [job] as Array[Job]
	var setup: Win95Setup = game.setup_for(job)
	var startup := setup.file_at(Win95Setup.STARTUP_PATH)
	var virus := setup.file_at(VIRUS_PATH)
	check("the break puts BIZOPP.EXE in C:\\WINDOWS", virus != null and virus.program == virus_check.virus.program, true)
	check("and a shortcut to it in StartUp", startup.children.map(func(f: Win95File) -> Array: return [f.name, f.target]), [["BizOpp", VIRUS_PATH]])
	virus_check.apply_break(setup)
	check("a second break adds nothing", [virus_check.copies(setup).size(), startup.children.size()], [1, 1])
	check("broken", virus_check.is_fixed(setup), false)

	var bench: Control = load("res://ui/bench_screen.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	game.set_powered(job, true)
	game.connect_cable(job)
	await process_frame
	var win95: Control = bench._desktops.get(job)
	var state: Node = win95.get_node("%ComputerState")
	var desktop: Node = win95.get_node("Desktop")
	check("no task before the desktop is up", _task_names(state), [])
	(win95.get("_boot") as Node).finished.emit()
	check("the boot reaches the desktop and runs StartUp's BizOpp", _task_names(state), ["Bizopp"])
	check("BIZOPP.EXE is in use", state.call(&"in_use", virus), true)

	await create_timer(WAIT + 0.1).timeout
	check("the virus opens the CD tray", job.cd_tray_open, true)
	await create_timer(WAIT).timeout
	check("and closes it", job.cd_tray_open, false)

	var as_array: Array[Win95File] = [virus]
	check("a delete is refused", state.call(&"delete_files", as_array), "Cannot delete BIZOPP.EXE" + SHARING)
	check("a rename is refused", state.call(&"rename_file", virus, "BIZOPP.TXT"), "Cannot rename BIZOPP.EXE" + SHARING)
	check("a move is refused", state.call(&"move_files", as_array, setup.desktop), "Cannot move BIZOPP.EXE" + SHARING)
	check("the file stays where it is", [setup.file_at(VIRUS_PATH), setup.recycle_bin.has(virus)], [virus, false])

	var folder := _open_windows_folder(win95, desktop)
	var icon := _item(folder, "BIZOPP.EXE")
	(folder as Node).emit_signal(&"delete_requested", [icon] as Array[FileIcon])
	var box := _front(desktop)
	check("Delete in Explorer says so", [box.get_node("%TitleBar").title, box.get_node("%Text").text], ["Error Deleting File", "Cannot delete BIZOPP.EXE" + SHARING])
	box.call(&"close")
	check("and leaves the file", setup.file_at(VIRUS_PATH), virus)

	root.push_input(_ctrl_alt(KEY_DELETE))
	var dialog := _front(desktop)
	var names: PackedStringArray = dialog.call(&"program_names")
	check("Ctrl+Alt+Del opens Close Program", dialog.get_node("%TitleBar").title, "Close Program")
	check("it lists the windows, then the task", [names.has("Windows"), names[names.size() - 1]], [true, "Bizopp"])
	dialog.call(&"select", names.size() - 1)
	dialog.get_node("%EndTask").pressed.emit()
	await process_frame
	check("End Task stops the virus, and the dialog closes", [_task_names(state), is_instance_valid(dialog) and dialog.visible], [[], false])
	check("its file is free", state.call(&"in_use", virus), false)
	await create_timer(WAIT * 2.0).timeout
	check("and the tray stays put", job.cd_tray_open, false)

	check("now the delete goes through", state.call(&"delete_files", as_array), "")
	check("and the problem is fixed", [virus_check.is_fixed(setup), job.software_fixed], [true, true])

	game.set_powered(job, false)
	game.set_powered(job, true)
	await process_frame
	(win95.get("_boot") as Node).finished.emit()
	check("after the fix a boot runs nothing", _task_names(state), [])
	check("StartUp's dangling shortcut says so", _front(desktop).get_node("%TitleBar").title, "Problem with Shortcut")

	root.push_input(_ctrl_alt(KEY_END))
	check("Ctrl+Alt+End opens Close Program too", _front(desktop).get_node("%TitleBar").title, "Close Program")
	root.push_input(_ctrl_alt(KEY_BACKSPACE))
	await create_timer(0.1).timeout
	check("pressed again, it restarts: the power goes off", job.powered, false)
	await create_timer(1.2).timeout
	check("and on again", job.powered, true)
	game.jobs = [] as Array[Job]
	bench.free()


# Bizopp with both waits at WAIT, so the tray moves on a known beat.
func _fast(program: PackedScene) -> PackedScene:
	var task := program.instantiate()
	task.set(&"min_seconds", WAIT)
	task.set(&"max_seconds", WAIT)
	var fast := PackedScene.new()
	fast.pack(task)
	task.free()
	return fast


func _task_names(state: Node) -> Array:
	return (state.call(&"tasks") as Array).map(func(task: Node) -> String: return task.get(&"task_name"))


# Opens My Computer, (C:) and Windows, as double-clicks do, and returns the last one's icon view.
func _open_windows_folder(win95: Node, desktop: Node) -> Node:
	var view: Node = win95.get("_icons")
	for item_name: String in ["My Computer", "(C:)", "Windows"]:
		win95.call(&"_open_item", _item(view, item_name))
		view = _front(desktop).get(&"items")
	return view


func _item(view: Node, item_name: String) -> FileIcon:
	for item: Node in view.get_children():
		if item is FileIcon and (item as FileIcon).text == item_name and not item.is_queued_for_deletion():
			return item
	push_error("no icon %s in %s" % [item_name, view])
	return null


func _front(desktop: Node) -> Node:
	var windows: Array = desktop.call(&"windows")
	return windows[windows.size() - 1]


func _ctrl_alt(keycode: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.ctrl_pressed = true
	key.alt_pressed = true
	key.pressed = true
	return key
