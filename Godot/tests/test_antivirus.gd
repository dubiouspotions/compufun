extends "res://tests/test.gd"
## CompuFun AntiVirus: a disk from its box in the storage room goes into drive A: of the computer
## with the email virus, A: lists its files, SETUP.EXE installs the scanner (once), AV.EX_ doesn't
## run, the scanner finds BIZOPP.EXE by what it is and Clean removes it with its task and its StartUp
## shortcut, which fixes the problem; a clean computer has no viruses; a boot with the disk in stops
## at "Non-System disk"; the disk ejects into the hand and goes back in its box.

const DISK := "res://parts/antivirus_floppy.tres"
const VIRUS_PATH := "C:\\WINDOWS\\BIZOPP.EXE"
const AV_PATH := "C:\\Program Files\\CompuFun AntiVirus\\AV.EXE"


func run() -> void:
	var storage: Node = load("res://rooms/shop/storage.tscn").instantiate()
	root.add_child(storage)
	await process_frame
	var box := _box_of(storage, load(DISK))
	var disk: FloppyDisk = box.get(&"part") if box != null else null
	check("the storage room has a box of AntiVirus disks", box != null, true)

	var problem: Problem = load("res://problems/email_virus.tres")
	var virus_check := problem.software_check as VirusCheck
	var job := Job.new(load("res://customers/young_entrepreneur.tres"), problem, 0, 0)
	game.jobs = [job] as Array[Job]
	var setup: Win95Setup = game.setup_for(job)
	var virus := setup.file_at(VIRUS_PATH)
	check("no AntiVirus on this computer yet", setup.file_at("C:\\Program Files\\CompuFun AntiVirus"), null)

	var bench: Control = load("res://ui/bench_screen.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	game.set_powered(job, true)
	game.connect_cable(job)
	await process_frame
	var win95: Control = bench._desktops.get(job)
	var state: Node = win95.get_node("%ComputerState")
	var desktop: Node = win95.get_node("Desktop")
	(win95.get("_boot") as Node).finished.emit()
	check("the virus runs", _task_names(state), ["Bizopp"])

	check("the box gives a disk", [game.can_insert_floppy(job), game.take_new_part(disk), game.can_insert_floppy(job)], [false, true, true])
	game.insert_floppy(job)
	check("it goes into A:", [game.has_floppy(job), game.hand, setup.floppy_disk == disk], [true, null, true])
	check("and can't go in twice", game.can_insert_floppy(job), false)
	var drive_a := _open(win95, desktop, ["My Computer", "3\u00bd Floppy (A:)"])
	check("A: lists the disk's files", _names(drive_a), ["SETUP.EXE", "README.TXT", "AV.EX_"])
	check("the files are the computer's own copies", setup.floppy_files[1] != (disk).files[1], true)

	win95.call(&"_open_item", _item(drive_a, "AV.EX_"))
	var box_text: String = _front(desktop).get_node("%Text").text
	check("AV.EX_ doesn't run", box_text.begins_with("Windows cannot open this file"), true)
	_front(desktop).call(&"close")
	win95.call(&"_open_item", _item(drive_a, "README.TXT"))
	check("README.TXT opens in Notepad", _front(desktop).scene_file_path, "res://win95/notepad.tscn")
	_front(desktop).call(&"close")

	var wizard := _run_setup(win95, desktop, drive_a)
	check("Setup welcomes", [wizard.call(&"page"), wizard.get_node("%TitleBar").title], [&"WELCOME", "CompuFun AntiVirus Setup"])
	wizard.set(&"copy_seconds", 0.2)
	wizard.get_node("%Next").pressed.emit()
	check("Next copies", wizard.call(&"page"), &"COPYING")
	await create_timer(0.4).timeout
	check("Setup is complete", [wizard.call(&"page"), (wizard.call(&"text") as String).begins_with("Setup is complete.")], [&"DONE", true])
	var installed := setup.file_at(AV_PATH)
	check("AV.EXE is in C:\\Program Files\\CompuFun AntiVirus", installed != null and installed.program != null, true)
	check("with a Start menu shortcut", setup.file_at("C:\\WINDOWS\\Start Menu\\Programs\\CompuFun AntiVirus").target, AV_PATH)
	check("a desktop shortcut", setup.file_at("Desktop\\CompuFun AntiVirus").target, AV_PATH)
	check("and its name in installed_apps", setup.installed_apps.has("CompuFun AntiVirus"), true)
	wizard.get_node("%Next").pressed.emit()
	await process_frame
	check("Finish closes Setup", is_instance_valid(wizard), false)

	wizard = _run_setup(win95, desktop, drive_a)
	wizard.get_node("%Next").pressed.emit()
	check("a second run says it's installed", [wizard.call(&"page"), wizard.call(&"text")], [&"INSTALLED", "CompuFun AntiVirus is already installed on this computer."])
	check("and adds nothing", [_count(setup.desktop, "CompuFun AntiVirus"), Array(setup.installed_apps).count("CompuFun AntiVirus")], [1, 1])
	wizard.get_node("%Next").pressed.emit()

	win95.call(&"_open_item", _item(win95.get("_icons"), "CompuFun AntiVirus"))
	var scanner := _front(desktop)
	check("the desktop shortcut opens the scanner", scanner.get_node("%TitleBar").title, "CompuFun AntiVirus")
	scanner.set(&"scan_seconds", 0.2)
	scanner.get_node("%ScanNow").pressed.emit()
	await process_frame
	check("Scan Now shows each path as it goes", (scanner.get_node("%Path") as Label).text.begins_with("C:\\"), true)
	await create_timer(0.3).timeout
	check("it finds BIZOPP.EXE", scanner.call(&"results"), PackedStringArray(["BIZOPP.EXE: infected with Bizopp.A"]))
	scanner.get_node("%Clean").pressed.emit()
	await process_frame
	check("Clean removes it", scanner.call(&"status"), "1 virus removed.")
	check("ends its task", _task_names(state), [])
	check("deletes the file", [setup.file_at(VIRUS_PATH), state.call(&"has_file", virus), setup.recycle_bin.has(virus)], [null, false, false])
	check("and the StartUp shortcut", setup.file_at(Win95Setup.STARTUP_PATH).children, [])
	check("so the problem is fixed", [virus_check.is_fixed(setup), job.software_fixed], [true, true])
	scanner.get_node("%ScanNow").pressed.emit()
	await create_timer(0.3).timeout
	check("a clean computer has no viruses", [scanner.call(&"results"), scanner.call(&"status")], [PackedStringArray(), "No viruses found."])
	scanner.call(&"close")

	game.set_powered(job, false)
	game.set_powered(job, true)
	await process_frame
	check("a boot with the disk in A: stops at Non-System disk", (win95.get("_boot") as Node).get(&"floppy_in_a"), true)

	game.eject_floppy(job)
	check("eject gives the AntiVirus disk back", [game.has_floppy(job), game.hand.part == disk, setup.floppy_files], [false, true, []])
	check("and it goes back in its box", [game.can_return_part(disk), game.return_part(disk), game.hand], [true, true, null])
	check("the disk's .tres keeps its files", _names_of((disk).files), ["SETUP.EXE", "README.TXT", "AV.EX_"])
	game.jobs = [] as Array[Job]
	bench.free()
	storage.free()


func _box_of(storage: Node, part: Part) -> Node:
	for box: Node in storage.find_children("*", "Node3D", true, false):
		if box.get(&"part") == part and box.has_node(^"Pieces"):
			return box
	return null


# Opens the icons named [param path] one after the other, as double-clicks do, from the desktop;
# returns the last window's icon view.
func _open(win95: Node, desktop: Node, path: Array[String]) -> Node:
	var view: Node = win95.get("_icons")
	for item_name in path:
		win95.call(&"_open_item", _item(view, item_name))
		view = _front(desktop).get(&"items")
	return view


func _run_setup(win95: Node, desktop: Node, drive_a: Node) -> Node:
	win95.call(&"_open_item", _item(drive_a, "SETUP.EXE"))
	return _front(desktop)


func _names(view: Node) -> Array:
	return view.get_children().filter(func(item: Node) -> bool: return item is FileIcon and not item.is_queued_for_deletion()).map(func(item: FileIcon) -> String: return item.text)


func _names_of(files: Array) -> Array:
	return files.map(func(file: Win95File) -> String: return file.name)


func _count(files: Array, file_name: String) -> int:
	return files.filter(func(file: Win95File) -> bool: return file.name == file_name).size()


func _task_names(state: Node) -> Array:
	return (state.call(&"tasks") as Array).map(func(task: Node) -> String: return task.get(&"task_name"))


func _item(view: Node, item_name: String) -> FileIcon:
	for item: Node in view.get_children():
		if item is FileIcon and (item as FileIcon).text == item_name and not item.is_queued_for_deletion():
			return item
	push_error("no icon %s in %s" % [item_name, view])
	return null


func _front(desktop: Node) -> Control:
	var windows: Array = desktop.call(&"windows")
	return windows.filter(func(w: Control) -> bool: return w.visible and not w.is_queued_for_deletion()).back()
