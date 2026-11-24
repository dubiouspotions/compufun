extends "res://tests/test.gd"
## mIRC on the activist's computer: only he has it, its shortcut opens it, Connect fails through
## Dial-Up Networking, and each of his logs reads the same from Options > Logging and from Notepad.

const WIN95 := "res://win95/win95.tscn"  # loaded at run time: its scripts name the Game autoload
const MIRC_PATH := "res://win95/mirc.tscn"
const LOGS := {
	"#oddbuilds.log": "res://customers/activist_guy/mirc_logs/oddbuilds.log",
	"fl0ppyjoe.log": "res://customers/activist_guy/mirc_logs/fl0ppyjoe.log",
	"s1mmking.log": "res://customers/activist_guy/mirc_logs/s1mmking.log",
}


func run() -> void:
	for path in DirAccess.get_files_at("res://customers"):
		var customer := load("res://customers/" + path) as Customer if path.ends_with(".tres") else null
		if customer != null and customer.computer != null and customer.computer.win95_setup != null:
			var setup := SetupPatch.start(customer, game.week.patches)
			var mirc := setup.file_at("C:\\MIRC\\MIRC32.EXE")
			var has_mirc := mirc != null and mirc.program == load(MIRC_PATH)
			check("only the activist has mIRC: %s" % path, has_mirc, path == "activist_guy.tres")
			if has_mirc:
				check("with a desktop shortcut and a Start menu entry", [setup.file_at("Desktop\\mIRC32").target, setup.file_at("C:\\WINDOWS\\Start Menu\\Programs\\mIRC32").target], ["C:\\MIRC\\MIRC32.EXE", "C:\\MIRC\\MIRC32.EXE"])
				for log_name: String in LOGS:
					var text := FileAccess.get_file_as_string(LOGS[log_name])
					check("%s holds its text file's text" % log_name, [text.length() > 100, setup.file_at("C:\\MIRC\\" + log_name).contents == text], [true, true])
	var stock := Win95Setup.new().copy()
	check("a setup without Start menu additions keeps the stock Programs", stock.file_at("C:\\WINDOWS\\Start Menu\\Programs\\mIRC32"), null)

	var script: GDScript = load("res://win95/mirc.gd")
	check("a server line", script.parse_server("irc.dal.net (DALnet USA)SERVER:irc.dal.net:7000GROUP:3"), PackedStringArray(["irc.dal.net (DALnet USA)", "irc.dal.net", "7000"]))
	check("a line without a server", script.parse_server("nick=elmroot"), PackedStringArray())

	await _on_the_activists_desktop()


func _on_the_activists_desktop() -> void:
	var customer: Customer = load("res://customers/activist_guy.tres")
	var job := Job.new(customer, Problem.new(), 0, 0)
	job.powered = true
	var win95: Control = (load(WIN95) as PackedScene).instantiate()
	win95.get_node("ComputerState").job = job
	root.add_child(win95)
	await process_frame
	var desktop: Node = win95.get_node("Desktop")
	var setup: Win95Setup = win95.get_node("ComputerState").setup

	win95.open_file(setup.file_at("Desktop\\mIRC32"))
	var window: Control = desktop.active_window()
	check("its shortcut opens mIRC", [window != null and window.scene_file_path == MIRC_PATH, window.get_node("%TitleBar").title if window != null else ""], [true, "mIRC32"])
	if window == null or window.scene_file_path != MIRC_PATH:
		win95.free()
		return

	window.connect_to_server()
	var dialog: Control = window.blocked_by
	check("Connect: the Status window says where, and AutoDial asks, blocking mIRC", [window.status_lines, dialog != null and dialog.get_node("%TitleBar").title == "Connect To"], [PackedStringArray(["*** Connecting to irc.dal.net (6667)"]), true])
	check("with his provider", dialog.get_node("%Name").text if dialog != null else "", "MainStreet Online")
	if dialog != null:
		dialog.get_node("%Cancel").pressed.emit()
	await process_frame
	check("cancelled, it can't reach the server", [window.connecting, window.status_lines[-1]], [false, "*** Unable to resolve IRC server name"])
	window.get_node("%Editbox").text_submitted.emit("hello")
	check("typing offline", window.status_lines[-1], "*** Not connected to server")

	window.open_setup()
	var sheet: Control = window.blocked_by
	check("Setup shows his MIRC.INI", [sheet.get_node("%TitleBar").title, sheet.get_node("%Nickname").text, sheet.get_node("%Servers").get_item_text(sheet.get_node("%Servers").selected)], ["mIRC Setup", "elmroot", "irc.dal.net (DALnet USA)"])
	sheet.close()
	await process_frame

	window.open_options()
	sheet = window.blocked_by
	var list: ItemList = sheet.get_node("%Logs")
	var listed: Array[String] = []
	for i in list.item_count:
		listed.append(list.get_item_text(i))
	check("Options > Logging lists his logs", listed, ["#oddbuilds.log", "fl0ppyjoe.log", "s1mmking.log"])
	for i in list.item_count:
		list.select(i)
		sheet.get_node("%View").pressed.emit()
		check("View opens %s in Notepad" % listed[i], _notepad(desktop), [listed[i] + " - Notepad", FileAccess.get_file_as_string(LOGS[listed[i]])])
	sheet.close()

	for log_name: String in LOGS:
		win95.open_file(setup.file_at("C:\\MIRC\\" + log_name))
		check("%s opens in Notepad from its folder" % log_name, _notepad(desktop), [log_name + " - Notepad", FileAccess.get_file_as_string(LOGS[log_name])])

	(window.get_node("VBox/MenuBar/Help") as PopupMenu).id_pressed.emit(5)
	var about: Control = window.blocked_by
	check("Help > About mIRC, free for home users", [about.get_node("%TitleBar").title, about.get_node("%Text").text.begins_with("mIRC32 v4.1")] if about != null else [], ["About mIRC", true])

	root.remove_child(win95)
	win95.free()


# The title and the text of the window in front, a Notepad.
func _notepad(desktop: Node) -> Array:
	var front: Control = desktop.active_window()
	if front == null or front.get_node_or_null(^"%Text") == null:
		return ["no Notepad in front: %s" % front]
	return [front.get_node("%TitleBar").title, front.get_node("%Text").text]
