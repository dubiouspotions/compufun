extends "res://tests/test.gd"
## The conversation graph's mood picker offers the moods that the customer's person has portraits
## for, marks those without a voice mood, and sets the line's mood; Play speaks a line or says why not.

const GRAPH := "res://dev/story_lab/conversation_graph.tscn"
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
	var play := _find(graph.box_of(talk), func(node: Node) -> bool: return node is Button and node.get(&"tooltip_text") == "Play this line") as Button
	play.pressed.emit()
	check("Play without a voice says why", _status().contains("Nobody has no voice yet"), true)
	var portrait_less := _find(graph.box_of(talk), func(node: Node) -> bool: return node is Button and node.get(&"text") == "?") as Button
	check("a mood without a portrait is marked", portrait_less != null, true)
	graph.show_conversation(talk, manager)
	play = _find(graph.box_of(talk), func(node: Node) -> bool: return node is Button and node.get(&"tooltip_text") == "Play this line") as Button
	play.pressed.emit()
	if ClassDB.class_exists(&"ChimeraVoice"):
		check("Play speaks the line in its mood", _status(), "Playing \"%s\" (angry)" % line.text)
	else:
		check("Play without the live voice or a rendered file says why", _status().begins_with("Nothing to play for"), true)
	(graph.get_node("%Voice") as VoicePlayer).hush()


# [the portrait, whether the crop is square, its top] of a mood button's thumbnail.
func _thumb_of(button: Button) -> Array:
	var crop := button.icon as AtlasTexture
	if crop == null:
		return [button.icon]
	return [crop.atlas, is_equal_approx(crop.region.size.x, crop.region.size.y), crop.region.position.y]


func _status() -> String:
	return (graph.get_menu_hbox().get_node("Status") as Label).text


func _find(under: Node, matches: Callable) -> Node:
	for node: Node in under.find_children("*", "", true, false):
		if matches.call(node):
			return node
	return null
