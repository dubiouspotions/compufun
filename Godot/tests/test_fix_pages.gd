extends "res://tests/test.gd"
## Every FIX that CompuFunDB can print fits on the printer's sheet, searched by the problem's longest
## symptom, which takes the most lines.


func run() -> void:
	check("a fresh day, CompuFunDB on", game.restore({"day": 1, "db_day": 1}), "")
	var db: Control = load("res://compufun_db/compufun_db.tscn").instantiate()  # untyped: CompuFunDB names Game
	db.set("hdd_seek", null)
	root.add_child(db)
	var printer: Node3D = load("res://props/printer.tscn").instantiate()
	root.add_child(printer)
	await process_frame
	var sheet: MeshInstance3D = printer.get_node("%Sheet")
	var text: Node3D = printer.get_node("%Text")
	var fits := floori((sheet.get_aabb().size.y + text.position.y) / float(printer.get("line_pitch")))
	check("the sheet holds a page", fits > 20, true)
	var printed := 0
	for file: String in ResourceLoader.list_directory("res://problems/"):
		if not file.ends_with(".tres"):
			continue
		var problem := load("res://problems/" + file) as Problem
		if problem == null or not problem.in_compufun_db:
			continue
		var longest := ""
		for symptom: String in problem.symptoms:
			longest = symptom if symptom.length() > longest.length() else longest
		game.search_db(longest, PackedStringArray([longest]))
		var page: PackedStringArray = db.call("_fix_page", problem)
		check("%s: its FIX of %d lines fits the %d of the sheet" % [file, page.size(), fits], page.size() <= fits, true)
		printed += 1
	check("every problem in CompuFunDB was printed", printed > 10, true)
	printer.queue_free()
	db.queue_free()
	await process_frame
