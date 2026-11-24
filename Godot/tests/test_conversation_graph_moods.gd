extends "res://tests/test.gd"
## The conversation graph's mood picker offers the moods that the customer's person has portraits
## for, marks those without a voice mood, and sets the line's mood; Play asks to play from the line.

const GRAPH := "res://dev/story_lab/conversation_graph.tscn"
const PLAY := "Play from this line in the game's dialogue box"
const ConversationGraph := preload("res://dev/story_lab/conversation_graph.gd")

var graph: ConversationGraph


func run() -> void:
	var text: String = (load("res://tests/test_conversation_graph.gd") as GDScript).get_script_constant_map()["ERRAND"]
	var talk := (StoryFormat.parse_errand(text, "res://story/errands/0101_skater_bro.errand").value as Errand).conversations[0]
	var manager := Customer.new()
	manager.display_name = "Manager"
	manager.person = load("res://people/middle_manager/person.tres")
	graph = (load(GRAPH) as PackedScene).instantiate()
	graph.set_anchors_preset(Control.PRESET_TOP_LEFT)
	graph.size = Vector2(1400, 800)
	graph.motion_seconds = 0.0
	graph.flash_seconds = 0.0
	root.add_child(graph)
	graph.show_conversation(talk, manager)
	await process_frame

	var line := talk.lines[0]
	var box := graph.box_of(talk)
	var mood := _find(box, func(node: Node) -> bool: return node is Button and node.get(&"tooltip_text").begins_with("neutral")) as Button
	check("the line shows the top of its mood's portrait, square", _thumb_of(mood), [manager.person.portraits[&"neutral"], true, 0.0])
	mood.pressed.emit()
	var picker := graph.get_node("%MoodPicker") as PopupPanel
	var choices := picker.find_children("*", "Button", true, false)
	var names := choices.map(func(button: Button) -> String: return button.text)
	check("the picker offers each portrait's mood", names.size(), manager.person.portraits.size())
	check("a mood without voices/moods/<mood>.tres is marked", [names.has("bye (no voice)"), names.has("angry")], [ResourceLoader.exists("res://voices/moods/bye.tres") == false, true])
	var angry := choices.filter(func(button: Button) -> bool: return button.text == "angry")[0] as Button
	angry.pressed.emit()
	check("picking a mood sets the line's mood", line.mood, &"angry")
	await process_frame
	mood = _find(graph.box_of(talk), func(node: Node) -> bool: return node is Button and node.get(&"tooltip_text").begins_with("angry")) as Button
	check("the line shows its new portrait", _thumb_of(mood) if mood != null else null, [manager.person.portraits[&"angry"], true, 0.0])

	var nobody := Customer.new()
	nobody.display_name = "Nobody"
	graph.show_conversation(talk, nobody)
	var portrait_less := _find(graph.box_of(talk), func(node: Node) -> bool: return node is Button and node.get(&"text") == "?") as Button
	check("a mood without a portrait is marked", portrait_less != null, true)
	graph.show_conversation(talk, manager)
	var asked: Array[DialogueLine] = []
	graph.preview_requested.connect(func(said: DialogueLine) -> void: asked.append(said))
	var play := _find(graph.box_of(talk), func(node: Node) -> bool: return node is Button and node.get(&"tooltip_text") == PLAY) as Button
	play.pressed.emit()
	check("Play asks to play from its line in the dialogue box", [asked.size(), asked.has(line)], [1, true])
	await _check_voice_dropdown(talk, manager)


# The line row's Voice dropdown offers every voice mood, writes the line's own voice mood and clears it.
func _check_voice_dropdown(talk: Conversation, manager: Customer) -> void:
	graph.show_conversation(talk, manager)
	await process_frame
	var line := talk.lines[0]
	var voice := _voice_of(talk)
	var moods := LabUI.resource_names(Voices.MOODS_DIR)
	check("it offers the picture's voice, then every voice mood", [voice.get_item_text(0), voice.item_count, voice.selected], ["Same as the picture", moods.size() + 1, 0])
	var thinking := moods.find("thinking") + 1
	voice.select(thinking)
	voice.item_selected.emit(thinking)
	check("picking one gives the line its own voice mood", [line.voice_mood, line.voice(), line.mood], [&"thinking", &"thinking", &"angry"])
	var errand := Errand.new()
	errand.customer = load("res://customers/skater_bro.tres")
	errand.conversations.append(talk)
	check("which the story file writes as a voice tag", StoryFormat.write_errand(errand).contains("(angry) %s [voice thinking]" % line.text), true)
	await process_frame
	voice = _voice_of(talk)
	check("and the dropdown shows it", voice.get_item_text(voice.selected), "thinking")
	voice.select(0)
	voice.item_selected.emit(0)
	check("Same as the picture clears it", [line.voice_mood, line.voice()], [&"", &"angry"])
	graph.set_voice_mood(line, &"angry")
	check("the picture's own mood is no voice mood of its own", line.voice_mood, &"")


func _voice_of(talk: Conversation) -> OptionButton:
	return _find(graph.box_of(talk), func(node: Node) -> bool: return node is OptionButton and (node as OptionButton).get_item_text(0) == "Same as the picture") as OptionButton


# [the portrait, whether the crop is square, its top] of a mood button's thumbnail.
func _thumb_of(button: Button) -> Array:
	var crop := button.icon as AtlasTexture
	if crop == null:
		return [button.icon]
	return [crop.atlas, is_equal_approx(crop.region.size.x, crop.region.size.y), crop.region.position.y]


func _find(under: Node, matches: Callable) -> Node:
	for node: Node in under.find_children("*", "", true, false):
		if matches.call(node):
			return node
	return null
