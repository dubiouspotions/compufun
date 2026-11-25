extends "res://tests/test.gd"
## Win95's own program files in C:\WINDOWS, and C:\WINDOWS itself, can't be deleted or moved, also
## renamed, so that the hat guy's noimages and the skater's defrag always stay fixable; renaming
## works. A folder with a program's name doesn't fix a FileCheck.

const COMPUTER_STATE_PATH := "res://win95/computer_state.gd"  # loaded at run time: it names the Game autoload


func run() -> void:
	var state := await _computer("0302_hat_guy", 3)
	var setup: Win95Setup = state.get("setup")
	var notepad := setup.file_at("C:\\WINDOWS\\NOTEPAD")
	check("the hat guy's Notepad lost its .EXE", notepad != null, true)
	var refused: String = state.call("delete_files", [notepad] as Array[Win95File])
	state.call("empty_recycle_bin")
	check("deleting it is denied, and it stays", [refused.begins_with("Cannot delete NOTEPAD: Access is denied."), setup.file_at("C:\\WINDOWS\\NOTEPAD") == notepad], [true, true])
	check("moving it is denied", (state.call("move_files", [notepad] as Array[Win95File], setup.desktop) as String).begins_with("Cannot move NOTEPAD: Access is denied."), true)
	var windows := setup.file_at("C:\\WINDOWS")
	refused = state.call("delete_files", [windows] as Array[Win95File])
	check("so is deleting C:\\WINDOWS", [refused.begins_with("Cannot delete %s: Access is denied." % windows.name), setup.file_at("C:\\WINDOWS") == windows], [true, true])
	var desktop_program: Array = setup.desktop.filter(func(f: Win95File) -> bool: return f.program != null and not f.is_folder)
	if not desktop_program.is_empty():
		check("a program file on the desktop is the customer's: it goes", state.call("delete_files", [desktop_program[0]] as Array[Win95File]), "")

	var fake: Win95File = state.call("new_folder", windows.children)
	state.call("rename_file", fake, "NOTEPAD.EXE")
	var notepad_check := FileCheck.new()
	notepad_check.path = "C:\\WINDOWS\\NOTEPAD.EXE"
	check("a folder named NOTEPAD.EXE doesn't fix it", notepad_check.is_fixed(setup), false)
	state.call("delete_files", [fake] as Array[Win95File])
	check("renaming Notepad back works", [state.call("rename_file", notepad, "NOTEPAD.EXE"), notepad_check.is_fixed(setup)], ["", true])
	state.queue_free()

	state = await _computer("0403_skater_bro", 4)
	setup = state.get("setup")
	var defrag := setup.file_at("C:\\WINDOWS\\DEFRAG.EXE")
	refused = state.call("delete_files", [defrag] as Array[Win95File])
	state.call("empty_recycle_bin")
	check("the skater's Disk Defragmenter can't be deleted", [refused.begins_with("Cannot delete DEFRAG.EXE: Access is denied."), setup.file_at("C:\\WINDOWS\\DEFRAG.EXE") == defrag], [true, true])
	state.queue_free()
	await process_frame


# The ComputerState of [param errand]'s computer on [param day], with the problem's break applied.
func _computer(errand: String, day: int) -> Node:
	game.reboot()
	check("restore %s" % errand, game.restore({"day": day, "arrivals": 3, "phase": "OPEN", "jobs": [{"errand": errand, "slot": 0, "powered": true}]}), "")
	var state: Node = load(COMPUTER_STATE_PATH).new()
	state.set("job", game.jobs[0])
	root.add_child(state)
	await process_frame
	return state
