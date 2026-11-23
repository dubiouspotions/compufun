extends "res://tests/test.gd"
## The conversation graph holds the view still through an edit: the box under the mouse, else the box
## that the edit changed, keeps its place on screen. Boxes glide to their new places, new ones fade
## in with a flash, and removed ones fade out.

const GRAPH := "res://dev/story_lab/conversation_graph.tscn"
const ConversationGraph := preload("res://dev/story_lab/conversation_graph.gd")

var graph: ConversationGraph
var view: SubViewport


func run() -> void:
	var text: String = (load("res://tests/test_conversation_graph.gd") as GDScript).get_script_constant_map()["ERRAND"]
	var errand := StoryFormat.parse_errand(text, "res://story/errands/0101_skater_bro.errand").value as Errand
	var talk := errand.conversations[0]
	graph = (load(GRAPH) as PackedScene).instantiate()
	graph.motion_seconds = 0.0
	graph.flash_seconds = 0.0
	view = SubViewport.new()
	view.size = Vector2i(1400, 800)
	root.add_child(view)
	view.add_child(graph)
	graph.show_conversation(talk, errand.customer)
	await _frames(3)
	graph.zoom = 1.0
	var questions := talk.then.then
	graph.scroll_offset = graph.box_of(questions).position_offset - Vector2(100, 120)
	await _frames(3)

	_hover(Vector2(-10, -10))
	var before := _on_screen(questions)
	graph.add_choice(questions)
	await _frames(3)
	check("without the mouse over a box, the box that got the choice stays put", _on_screen(questions), before)

	var install := questions.choices[1]
	var below := install.replies[1]
	_hover(_on_screen(below) + Vector2(20, 20))
	var hovered := _on_screen(below)
	var acted := _on_screen(install.replies[0])
	graph.add_line(install.replies[0], 0)
	graph.add_line(install.replies[0], 0)
	await _frames(3)
	check("the box under the mouse stays put", _on_screen(below), hovered)
	check("rather than the box above it, which grew", _on_screen(install.replies[0]).y < acted.y, true)

	graph.motion_seconds = 0.2
	graph.flash_seconds = 0.6
	_hover(Vector2(-10, -10))
	var still := _on_screen(questions.choices[3])
	var first_choice := _on_screen(questions.choices[0])
	var added := graph.add_choice(questions)
	await _frames(1)
	var fresh := graph.box_of(added)
	check("a new box starts faded out", fresh.modulate.a < 1.0, true)
	check("and is lit", graph.flash_of(added) > 0.0, true)
	await _frames(45)
	check("and is there after the motion and the flash", [fresh.modulate.a, graph.flash_of(added)], [1.0, 0.0])
	check("the list's first choice kept its place", _on_screen(questions.choices[0]), first_choice)
	check("a choice above the new one kept its place", _on_screen(questions.choices[3]), still)

	var gone := graph.box_of(added)
	graph.delete_box(added)
	await _frames(2)
	check("a removed box fades out", [is_instance_valid(gone), gone.modulate.a < 1.0 if is_instance_valid(gone) else false], [true, true])
	await _frames(30)
	check("and is freed after it", is_instance_valid(gone), false)

	var greeting := talk.choices[0].replies[0]
	var mover := talk.choices[1]
	var start := graph.box_of(mover).position_offset
	graph.add_line(greeting)
	await _frames(2)
	var midway := graph.box_of(mover).position_offset
	await _frames(30)
	var end := graph.box_of(mover).position_offset
	check("a box that moves glides there", start != end and midway != end, true)

	graph.scroll_offset += Vector2(0, 40)
	await _frames(2)
	var scrolled := _on_screen(questions)
	graph.edit_text(questions.choices[0], "When did it all start?")
	await _frames(30)
	check("after the writer scrolls, an edit holds the new view", _on_screen(questions), scrolled)

	await _check_reveal(questions)


# A new choice at the end of a list whose place is below the view: the view scrolls down by just
# what brings its editor, and reveal_margin around it, inside.
func _check_reveal(questions: Reply) -> void:
	graph.motion_seconds = 0.0
	graph.flash_seconds = 0.0
	_hover(Vector2(-10, -10))
	var top := graph.box_of(questions).position_offset * graph.zoom
	graph.scroll_offset = Vector2(top.x - 100.0, top.y - (graph.size.y - 120.0))
	await _frames(3)
	var before := graph.scroll_offset
	_plus_of(questions).pressed.emit()
	await _frames(4)
	var added := questions.choices[questions.choices.size() - 1]
	var editor: TextEdit = graph.box_of(added).find_children("*", "TextEdit", true, false)[0]
	var spot := graph.get_global_transform().affine_inverse() * editor.get_global_rect()
	var room := Rect2(Vector2.ONE * graph.reveal_margin, graph.size - Vector2.ONE * graph.reveal_margin * 2.0)
	check("the new choice's editor ends inside the view, with the margin", room.grow(0.5).encloses(spot), true)
	check("the view moved down by just what that needs", [is_equal_approx(roundf(spot.end.y), roundf(room.end.y)), graph.scroll_offset.y > before.y], [true, true])
	check("and not sideways", graph.scroll_offset.x, before.x)

	graph.motion_seconds = 0.2
	var from := graph.scroll_offset
	_plus_of(questions).pressed.emit()
	await _frames(6)
	var midway := graph.scroll_offset.y
	await _frames(30)
	check("the view glides there", [midway > from.y, midway < graph.scroll_offset.y], [true, true])
	graph.motion_seconds = 0.0
	var answer := questions.choices[0].replies[0]
	graph.scroll_offset = graph.box_of(answer).position_offset * graph.zoom - Vector2(100, 100)
	await _frames(3)
	var still := graph.scroll_offset
	for node: Node in graph.box_of(answer).find_children("*", "Button", true, false):
		if (node as Button).text == "+ line":
			(node as Button).pressed.emit()
	await _frames(4)
	editor = graph.box_of(answer).find_children("*", "TextEdit", true, false)[0]
	check("a new line whose editor opens in view doesn't move the view", [room.grow(0.5).encloses(graph.get_global_transform().affine_inverse() * editor.get_global_rect()), graph.scroll_offset], [true, still])


func _plus_of(reply: Reply) -> Button:
	for node: Node in graph.box_of(reply).find_children("*", "Button", true, false):
		if (node as Button).tooltip_text == "Add a choice the player can say after these lines":
			return node
	return null


func _on_screen(part: Resource) -> Vector2:
	var box := graph.box_of(part)
	return (box.position_offset * graph.zoom - graph.scroll_offset).round()


func _hover(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	view.push_input(motion)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame
