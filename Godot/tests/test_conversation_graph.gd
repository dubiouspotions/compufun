extends "res://tests/test.gd"
## The Story Lab's conversation graph draws the docs/dialogue.md example: its boxes, its arrows, the
## meeting arrows of - branches and the dashed arrows of + answers.

const GRAPH := "res://dev/story_lab/conversation_graph.tscn"
const ConversationGraph := preload("res://dev/story_lab/conversation_graph.gd")
const PATH := "res://story/errands/0101_skater_bro.errand"
const ERRAND := """customer: skater_bro

== drop-off [once]
brief: He arrives cheerful; the problem comes out only when asked.
(neutral) Yo! What's up! Is this the computer repair shop?
- Welcome to CompuFun! You're in the right place! How can I help you?
	(happy) Sweet! Maybe you can help a buddy out!
	(neutral) My computer isn't working!
- Did your mom give it away?
	(angry) Whatever dude.. You don't have to be a douche about it.

- What seems to be the issue?
	(problem) When I start it, everything seems primo. Then Windows turns it off again!

+ When did it start?
	set skater_new_windows
	(thinking) Right after I got the new Windows.
+ Did you install anything?
	if skater_new_windows
		set skater_cambion
		(happy) Oh yeah. My buddy gave me this Windows 95 on floppies.
	else
		(neutral) Nah, nothing, man.
+ Cambion? [if skater_cambion]
	(happy) It's the rad one, dude.
- OK, leave it with me.
	(happy) Cool. Call me, dude.
"""

var graph: ConversationGraph


func run() -> void:
	var parsed := StoryFormat.parse_errand(ERRAND, PATH)
	check("the example parses", parsed.errors, PackedStringArray())
	var errand := parsed.value as Errand
	var talk := errand.conversations[0]
	graph = (load(GRAPH) as PackedScene).instantiate()
	graph.set_anchors_preset(Control.PRESET_TOP_LEFT)
	graph.size = Vector2(1400, 800)
	graph.motion_seconds = 0.0
	graph.flash_seconds = 0.0
	root.add_child(graph)
	graph.show_conversation(talk, errand.customer)
	await process_frame
	await process_frame

	var greeting := talk.choices
	var issue := talk.then
	var questions := issue.then
	var install := questions.choices[1]
	var boxes: Array[Resource] = [talk, greeting[0], greeting[0].replies[0], greeting[1], greeting[1].replies[0],
		issue, issue.choices[0], issue.choices[0].replies[0], questions]
	for choice: Choice in questions.choices:
		boxes.append(choice)
		boxes.append_array(choice.replies)
	check("a box for every reply and choice", boxes.filter(func(part: Resource) -> bool: return graph.box_of(part) == null), [])
	check("no other boxes", graph.get_children().filter(func(node: Node) -> bool: return node is GraphNode).size(), boxes.size())
	check("the greeting box has its line", _texts(graph.box_of(talk)).has("Yo! What's up! Is this the computer repair shop?"), true)
	check("a choice box shows its mark", _texts(graph.box_of(questions.choices[0])).has("+"), true)
	check("a condition chip", _texts(graph.box_of(questions.choices[2])).has("only if skater cambion"), true)
	check("a flags chip", _texts(graph.box_of(questions.choices[0].replies[0])).has("remembers: skater new windows"), true)
	check("if and else answers are boxes with chips", [_texts(graph.box_of(install.replies[0])).has("only if skater new windows"), _texts(graph.box_of(install.replies[1])).has("otherwise")], [true, true])

	var arrows := _arrows()
	var expected: Array[Array] = [
		[talk, greeting[0]], [talk, greeting[1]], [greeting[0], greeting[0].replies[0]], [greeting[1], greeting[1].replies[0]],
		[greeting[0].replies[0], issue], [greeting[1].replies[0], issue],
		[issue, issue.choices[0]], [issue.choices[0], issue.choices[0].replies[0]], [issue.choices[0].replies[0], questions],
	]
	for choice: Choice in questions.choices:
		expected.append([questions, choice])
		for answer: Reply in choice.replies:
			expected.append([choice, answer])
	check("the arrows", _sorted(arrows), _sorted(expected.map(_names)))
	check("both greetings meet at the issue question", arrows.has(_names([greeting[0].replies[0], issue])) and arrows.has(_names([greeting[1].replies[0], issue])), true)
	var returns: Array[Array] = []
	for choice: Choice in questions.choices.slice(0, 3):
		for answer: Reply in choice.replies:
			returns.append(_names([answer, questions]))
	check("the + answers return to their list, dashed", _sorted(graph.return_arrows()), _sorted(returns))

	var top := graph.box_of(talk).position_offset
	check("depth is the column: a choice is right of its box", graph.box_of(greeting[0]).position_offset.x > top.x, true)
	check("siblings are rows", graph.box_of(greeting[1]).position_offset.y > graph.box_of(greeting[0]).position_offset.y, true)
	check("the meeting point is right of both branches", graph.box_of(issue).position_offset.x > graph.box_of(greeting[1].replies[0]).position_offset.x, true)
	check("boxes and + then... buttons don't overlap", _overlaps(), [])

	graph.show_conversation(talk, errand.customer, true)
	var menus := graph.find_children("*", "MenuButton", true, false)
	var adds := graph.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "+ line")
	check("read only: no menus and no + line", [menus.size(), adds.size()], [0, 0])
	check("read only: the same boxes", graph.box_of(questions.choices[3]) != null, true)


func _names(pair: Array) -> Array:
	return [graph.box_of(pair[0]).name, graph.box_of(pair[1]).name]


func _arrows() -> Array:
	return graph.get_connection_list().map(func(c: Dictionary) -> Array: return [c.from_node, c.to_node])


func _sorted(pairs: Array) -> Array:
	var copy := pairs.map(func(pair: Array) -> String: return "%s>%s" % pair)
	copy.sort()
	return copy


# Every Label and Button text in [param node].
func _texts(node: Node) -> PackedStringArray:
	var found := PackedStringArray()
	for child: Node in node.find_children("*", "", true, false):
		if child is Label or child is Button:
			found.append(child.get(&"text"))
	return found


func _overlaps() -> Array:
	var found: Array = []
	var boxes := graph.get_children().filter(func(node: Node) -> bool: return node is GraphElement)
	for i: int in boxes.size():
		for j: int in range(i + 1, boxes.size()):
			var a := Rect2(boxes[i].position_offset, boxes[i].size)
			var b := Rect2(boxes[j].position_offset, boxes[j].size)
			if a.intersects(b):
				found.append([boxes[i].name, boxes[j].name])
	return found
