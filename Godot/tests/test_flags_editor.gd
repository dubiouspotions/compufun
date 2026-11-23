extends "res://tests/test.gd"
## The Story Lab's "remembers" editor writes the flags that its rows say (true 1, false 0, a number
## for a staged fact), says them in words, and the graph's chip opens it and stores what it says.

const GRAPH := "res://dev/story_lab/conversation_graph.tscn"


func run() -> void:
	var editor := StoryFlagsEditor.make(PackedStringArray(["skater_cambion"]))
	root.add_child(editor)
	await process_frame
	var shown: Dictionary[StringName, int] = {&"skater_cambion": 1, &"logo_stage": 2, &"skater_gone": 0}
	editor.edit(shown)
	check("it shows flags and gives them back", editor.flags(), shown)
	check("in words", StoryFlagsEditor.describe(editor.flags()), "skater cambion, logo stage is 2, skater gone is false")
	var becomes: OptionButton = editor.find_children("*", "OptionButton", true, false)[0]
	becomes.select(1)
	becomes.item_selected.emit(1)
	check("true can become false", editor.flags()[&"skater_cambion"], 0)
	becomes.select(2)
	becomes.item_selected.emit(2)
	var number: SpinBox = editor.find_children("*", "SpinBox", true, false)[0]
	check("or a number, whose field shows", [number.visible, editor.flags()[&"skater_cambion"]], [true, 2])
	for button: Node in editor.find_children("*", "Button", true, false):
		if (button as Button).text == "+ another fact":
			(button as Button).pressed.emit()
	var pickers := editor.find_children("*", "StoryFactPicker", true, false)
	(pickers[pickers.size() - 1] as StoryFactPicker).pick(&"Told about Loka")
	check("a new fact becomes true", editor.flags()[&"told_about_loka"], 1)
	editor.queue_free()

	var text: String = (load("res://tests/test_conversation_graph.gd") as GDScript).get_script_constant_map()["ERRAND"]
	var errand := StoryFormat.parse_errand(text, "res://story/errands/0101_skater_bro.errand").value as Errand
	var graph: GraphEdit = (load(GRAPH) as PackedScene).instantiate()
	graph.set(&"motion_seconds", 0.0)
	graph.set(&"flash_seconds", 0.0)
	root.add_child(graph)
	graph.call(&"show_conversation", errand.conversations[0], errand.customer)
	await process_frame
	var reply := errand.conversations[0].then.then.choices[0].replies[0]
	var chip: Button = graph.call(&"box_of", reply).find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "remembers: skater new windows")[0]
	chip.pressed.emit()
	var opened: StoryFlagsEditor = chip.find_children("*", "StoryFlagsEditor", true, false)[0]
	var row_becomes: OptionButton = opened.find_children("*", "OptionButton", true, false)[0]
	row_becomes.select(1)
	row_becomes.item_selected.emit(1)
	(chip.find_children("*", "PopupPanel", true, false)[0] as PopupPanel).hide()
	check("closing the chip's editor stores what it says", reply.set_flags, {&"skater_new_windows": 0})
	check("which the story file writes as a set line", "set skater_new_windows=0" in StoryFormat.write_errand(errand), true)
