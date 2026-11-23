extends "res://tests/test.gd"
## The corruption signs as the Story Lab shows them: each scene's description, and the Signs section.

const SIGNS := "res://corruption/"
## The signs that the old wiki table had no "In the game" text for.
const UNDESCRIBED: Array[String] = ["blood_puddle"]


func run() -> void:
	_every_described_sign_has_its_description()
	var drafts := StoryDrafts.new(user_dir() + "drafts/")
	drafts.git = func(_arguments: PackedStringArray) -> Dictionary: return {"code": 1, "out": ""}
	var lab: Control = (load("res://dev/story_lab/story_lab.tscn") as PackedScene).instantiate()
	lab.set("drafts", drafts)
	root.add_child(lab)
	await process_frame
	lab.call("show_section", "Signs")
	var panel: Node = lab.call("sign_panel")
	_the_section_lists_every_sign_once_grouped(panel)
	_starts_say_where_in_plain_words(lab, panel)
	_a_switched_off_sign_shows_so(panel)
	lab.queue_free()
	await process_frame


func _every_described_sign_has_its_description() -> void:
	var missing := PackedStringArray()
	for file: String in ResourceLoader.list_directory(SIGNS):
		if file.get_extension() != "tscn" or file.get_basename() in UNDESCRIBED:
			continue
		var sign_node := (load(SIGNS + file) as PackedScene).instantiate()
		var description: Variant = sign_node.get(&"description")  # by name: CorruptionSign names Game
		if description == null or (description as String).strip_edges() == "":
			missing.append(file)
		sign_node.free()
	check("every sign scene but the undescribed ones says how it looks", missing, PackedStringArray())


func _the_section_lists_every_sign_once_grouped(panel: Node) -> void:
	var scenes := PackedStringArray()
	for file: String in ResourceLoader.list_directory(SIGNS):
		if file.get_extension() == "tscn":
			scenes.append(file.get_basename())
	var timing := {}
	for shown: Dictionary in panel.call("signs"):
		timing[String(shown["id"])] = shown["timing"]
	var listed := PackedStringArray()
	var group := -1
	var misplaced := PackedStringArray()
	for child: Node in panel.get_child(0).get_children():
		if child is Label:
			group += 1
		elif child is PanelContainer:
			listed.append(child.name)
			if timing.get(String(child.name), -1) != group:
				misplaced.append(child.name)
	listed.sort()
	scenes.sort()
	check("every sign scene is listed once", listed, scenes)
	check("each under its Early, Mid or Late heading", misplaced, PackedStringArray())


func _starts_say_where_in_plain_words(lab: Control, panel: Node) -> void:
	var week: StoryFiles.Week = lab.get("_week")
	var index: Dictionary = load("res://story/story_check.gd").call("flag_index", week)
	var texts := func(id: StringName) -> Array:
		return (panel.call("starts", week, index, id) as Array).map(func(start: Dictionary) -> String: return start["text"])
	check("logo_blue starts on day 3 at closing", "Day 3, at closing" in texts.call(&"logo_blue"), true)
	check("blood_puddle starts at organ failure's drop-off", "the problem organ failure, at drop-off" in texts.call(&"blood_puddle"), true)
	check("a day that sets a sign's flag to 0 stops it", "Day 7, as the day starts (stops it)" in texts.call(&"customer_x"), true)
	var wrong := PackedStringArray()
	for shown: Dictionary in panel.call("signs"):
		var says := panel.find_child(String(shown["id"]), true, false).find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == "Not started anywhere yet")
		if says != texts.call(shown["id"]).is_empty():
			wrong.append(shown["id"])
	check("a sign says \"Not started anywhere yet\" exactly when nothing starts it", wrong, PackedStringArray())
	var day_3: Dictionary = (panel.call("starts", week, index, &"logo_blue") as Array)[0]
	panel.call("_open", day_3)
	var day_panel: Control = lab.find_children("*", "StoryDayPanel", true, false)[0]
	check("clicking a start opens that day", [panel.visible, day_panel.is_visible_in_tree()], [false, true])


func _a_switched_off_sign_shows_so(panel: Node) -> void:
	var card: Control = panel.call("_card", {"id": &"off", "title": "Off", "description": "", "hint": "", "stages": 1, "enabled": false, "timing": 0}, [] as Array[Dictionary])
	var chips := card.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text.strip_edges())
	check("a switched-off sign says so and shows greyed", ["switched off" in chips, card.modulate.a < 1.0], [true, true])
	card.free()
