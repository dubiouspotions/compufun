extends "res://tests/test.gd"
## Every computer that has Word and Excel gets their shortcuts on its desktop, after its own icons,
## once; a shortcut shows Win95's arrow overlay; and on every customer's desktop, problem breaks
## included, no icon covers another.

const WIN95 := "res://win95/win95.tscn"  # loaded at run time: its scripts name the Game autoload
const WORD_PATH := "C:\\Program Files\\Microsoft Office\\Office\\WINWORD.EXE"
const EXCEL_PATH := "C:\\Program Files\\Microsoft Office\\Office\\EXCEL.EXE"
const ARROW := preload("res://win95/theme/icons_extracted/overlay_shortcut_32.png")


func run() -> void:
	_every_customer_gets_them()
	_only_where_office_is()
	_the_arrow()
	await _no_icon_covers_another()


func _shortcuts(setup: Win95Setup) -> Array:
	return setup.desktop.filter(func(f: Win95File) -> bool: return f.target != "").map(func(f: Win95File) -> Array: return [f.name, f.target])


func _every_customer_gets_them() -> void:
	for path in DirAccess.get_files_at("res://customers"):
		var customer := load("res://customers/" + path) as Customer if path.ends_with(".tres") else null
		if customer == null or customer.computer == null or customer.computer.win95_setup == null:
			continue
		var own := customer.computer.win95_setup.desktop.size()
		var running := customer.computer.win95_setup.copy()
		var last: Array = running.desktop.slice(running.desktop.size() - 2).map(func(f: Win95File) -> Array: return [f.name, f.target, f.desktop_position, f.icon.resource_path.get_file()])
		check("%s: Word and Excel last on the desktop, flowing with the others" % path, last,
			[["Microsoft Word", WORD_PATH, Vector2.ZERO, "word_32.png"], ["Microsoft Excel", EXCEL_PATH, Vector2.ZERO, "excel_32.png"]])
		check("%s: its own icons stay, before them" % path, running.desktop.filter(func(f: Win95File) -> bool: return f.system == &"").size(), own + 2)
		check("%s: a copy of the running copy adds no second pair" % path, _shortcuts(running.copy()), _shortcuts(running))


func _only_where_office_is() -> void:
	var bare := Win95Setup.new()
	check("a computer without Office gets no shortcuts", _shortcuts(bare.copy()), [])
	var customer: Customer = load("res://customers/skater_bro.tres")
	var running := customer.computer.win95_setup.copy()
	var word: Win95File = running.desktop.filter(func(f: Win95File) -> bool: return f.target == WORD_PATH)[0]
	running.desktop.erase(word)
	running.recycle_bin.append(word)
	check("one in the Recycle Bin doesn't come back", _shortcuts(running.copy()).map(func(s: Array) -> String: return s[0]), ["Microsoft Excel"])


func _the_arrow() -> void:
	var icon: Control = (load("res://win95/file_icon.tscn") as PackedScene).instantiate()
	root.add_child(icon)
	var word := load("res://win95/office/icons/word_32.png") as Texture2D
	icon.set(&"icon", word)
	var shown := func() -> Image: return ((icon.get_node("%Icon") as TextureRect).texture).get_image()
	check("a file shows its own icon", shown.call().get_pixel(4, 27), word.get_image().get_pixel(4, 27))
	icon.set(&"shortcut", true)
	var arrow := ARROW.get_image()
	var corner := Vector2i(4, 27)
	check("a shortcut shows the arrow in the bottom left corner", [arrow.get_pixel(corner.x, corner.y).a > 0.5, shown.call().get_pixel(corner.x, corner.y)], [true, arrow.get_pixel(corner.x, corner.y)])
	check("and its own icon elsewhere", shown.call().get_pixel(20, 8), word.get_image().get_pixel(20, 8))
	icon.queue_free()


# Each customer's desktop as the game boots it, with the break of every problem that their errands
# bring: no two icons overlap, and each stands inside the screen, above the taskbar.
func _no_icon_covers_another() -> void:
	for d: Day in game.week.days:
		for errand: Errand in d.errands:
			var customer := errand.customer
			if customer == null or customer.computer == null or customer.computer.win95_setup == null:
				continue
			game.setups.clear()
			var job := Job.new(customer, errand.problem if errand.problem != null else Problem.new(), 0, 0)
			job.powered = true
			var win95: Control = (load(WIN95) as PackedScene).instantiate()
			win95.get_node("ComputerState").job = job
			root.add_child(win95)
			win95.size = Vector2(640, 480)
			for i in 3:
				await process_frame
			var icons: Array = win95.get_node("Desktop").find_children("*", "", true, false).filter(
				func(n: Node) -> bool: return n.has_method(&"hit_rect") and n.get_parent().name == "DesktopIcons")
			var screen := Rect2(Vector2.ZERO, Vector2(640, 480 - 28))
			var wrong := PackedStringArray()
			for i in icons.size():
				var a: Rect2 = icons[i].hit_rect()
				if not screen.encloses(a) and icons[i].get(&"placed_at") == Vector2.ZERO:
					wrong.append("%s is off the screen at %s" % [icons[i].text, a])
				for j in range(i + 1, icons.size()):
					if a.intersects(icons[j].hit_rect()):
						wrong.append("%s covers %s" % [icons[i].text, icons[j].text])
			var names := icons.map(func(n: Node) -> String: return n.get(&"text"))
			check("%s %s: the icons don't cover each other" % [errand.code, customer.resource_path.get_file()], [wrong, icons.is_empty()], [PackedStringArray(), false])
			if errand.problem == null or errand.problem.software_check == null or errand.problem.software_check.get_script().get_global_name() != &"DesktopPrankCheck":
				check("%s %s: Word and Excel are on the desktop" % [errand.code, customer.resource_path.get_file()], [names.has("Microsoft Word"), names.has("Microsoft Excel")], [true, true])
			root.remove_child(win95)
			win95.free()
