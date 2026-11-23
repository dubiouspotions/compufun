extends GraphEdit
## The Story Lab's graph of one conversation (docs/dialogue.md, "Conversations"): a white box per
## run of customer lines (a Reply), a teal box per player choice, and arrows for where the
## conversation goes. It lays itself out from the conversation after every change and stores no
## positions. Every edit changes the conversation in place, then emits [signal edited].

## The conversation changed in place; the owner writes its story file from it.
signal edited

@export var box_width: float = 280.0
## The width of a box for a reply without lines or flags: where branches meet before a list.
@export var junction_width: float = 120.0
@export var column_gap: float = 70.0
@export var row_gap: float = 24.0
@export var customer_color: Color = Color.WHITE
@export var player_color: Color = Color("5ad7c9")
@export var ink: Color = Color("1e1e1e")
@export var faint_ink: Color = Color("6b6b6b")
@export var error_color: Color = Color("c0392b")
@export var selected_color: Color = Color("e89f2b")
@export var arrow_color: Color = Color("3c8f86")
@export var thumb_size: Vector2 = Vector2(48, 48)
## The share of a portrait's width that its thumbnail shows, from the top: the face and upper body.
@export_range(0.2, 1.0, 0.01) var thumb_crop: float = 0.62
## The lines that the text editor shows at least.
@export var editor_lines: int = 5
## How long boxes take to move to their new places after an edit, in seconds; 0 moves them at once.
@export var motion_seconds: float = 0.2
## The room, in pixels on screen, that the view leaves around the editor of a new item when it
## scrolls to show it.
@export var reveal_margin: float = 16.0
## How long a new box's outline flashes, in seconds; 0 for no flash.
@export var flash_seconds: float = 0.6
## The least zoom that a new conversation shows at, to fit it in the view.
@export var min_fit_zoom: float = 0.7
## The text of a new line or choice, selected in its editor at once.
@export var new_text: String = "..."
## The condition of a new answer, selected in its editor at once.
@export var new_flag: StringName = &"new_flag"

## Where the conversation goes after a choice's answer.
enum After {
	GO_ON, ## On below the list that the choice is in (a - choice).
	ASK_AGAIN, ## Back to the same list, with this choice greyed (a + choice).
	END, ## The conversation ends.
}

## The words for each [enum After], as the choice's dropdown shows them.
const AFTER_WORDS: PackedStringArray = ["Go on below", "Ask the other questions again", "End the conversation"]
const AFTER_TIPS: PackedStringArray = [
	"After the answer, the conversation goes on below this list",
	"After the answer, the player picks from this list again; this choice shows greyed",
	"After the answer, the conversation ends",
]

## The known facts (flag names) that the condition editors offer; the Lab sets it from the week.
var facts: PackedStringArray = []

var _conversation: Conversation
var _customer: Customer
var _read_only: bool = false
var _boxes: Dictionary[Resource, GraphNode] = {}
var _columns: Dictionary[Resource, int] = {}
# [from, to] pairs: a + answer's arrow back to the reply that offers its list.
var _returns: Array[Array] = []
# What can be edited in place, by _spot_key: [the control it replaces, its text, apply(text) -> error].
var _spots: Dictionary[String, Array] = {}
var _selected: Resource
var _rebuilding: bool = false
var _place_queued: bool = false
var _fit_pending: bool = false
var _pending_delete: Resource
var _status: Label
# The "+ then..." button under each list that has no then yet.
var _then_buttons: Dictionary[Reply, GraphElement] = {}
# The next rebuild replaces the whole view: no motion, and the view fits it.
var _fresh: bool = true
# Boxes of removed parts, fading out.
var _leaving: Array[GraphElement] = []
# What the view holds still through a relayout: parts, best first, and where their boxes were.
var _anchors: Array[Resource] = []
var _anchor_spots: Array[Vector2] = []
# The scroll that this script set last, to tell it apart from the writer's scrolling.
var _own_scroll: Vector2 = Vector2.INF
var _moves: Tween
var _pan: Tween
# Where the last placing put each box, in graph units.
var _targets: Dictionary[GraphElement, Vector2] = {}
# Outline flashes of new boxes: part to strength, 1 to 0.
var _flashes: Dictionary[Resource, float] = {}

@onready var _overlay: Control = %Returns
@onready var _voice: VoicePlayer = %Voice
@onready var _mood_picker: PopupPanel = %MoodPicker
@onready var _moods_grid: GridContainer = %Moods
@onready var _confirm: ConfirmationDialog = %ConfirmDelete


func _ready() -> void:
	_status = Label.new()
	_status.name = "Status"
	_status.add_theme_color_override(&"font_color", faint_ink)
	_status.add_theme_font_size_override(&"font_size", 13)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	get_menu_hbox().add_child(_status)
	_overlay.draw.connect(_draw_overlay)
	draw.connect(_overlay.queue_redraw)
	resized.connect(func() -> void:
		if _fit_pending:
			_queue_place())
	scroll_offset_changed.connect(func(offset: Vector2) -> void:
		if not offset.is_equal_approx(_own_scroll):
			_anchors.clear()
		_overlay.queue_redraw())
	node_selected.connect(_on_node_selected)
	delete_nodes_request.connect(func(names: Array[StringName]) -> void:
		for part: Resource in _boxes:
			if names.has(_boxes[part].name) and part != _conversation and not _read_only:
				_ask_delete(part)
				return)
	_confirm.confirmed.connect(func() -> void:
		if _pending_delete != null:
			delete_box(_pending_delete))
	_rebuild()


## Draws [param conversation] of [param customer], whose person gives the portraits and the voice
## (null draws no portraits and plays nothing). With [param read_only] nothing can be edited, as
## when the story file has errors elsewhere; Play still works. Replaces what was shown.
func show_conversation(conversation: Conversation, customer: Customer, read_only: bool = false) -> void:
	_conversation = conversation
	_customer = customer
	_read_only = read_only
	_selected = null
	_fit_pending = true
	_fresh = true
	_anchors.clear()
	_rebuild()


## How strongly the outline of [param part]'s box flashes now, from 1 (just added) to 0 (not).
func flash_of(part: Resource) -> float:
	return _flashes.get(part, 0.0)


## The box that draws [param part] (a Reply, the Conversation included, or a Choice), or null.
func box_of(part: Resource) -> GraphNode:
	return _boxes.get(part)


## The dashed arrows, as [code][from box name, to box name][/code]: from the end of each + answer
## back to the box whose list it returns to.
func return_arrows() -> Array[Array]:
	var found: Array[Array] = []
	for pair: Array in _returns:
		found.append([_boxes[pair[0]].name, _boxes[pair[1]].name])
	return found


## Sets the text of [param part]: a DialogueLine, a Choice, or the Conversation's brief. A story
## file holds each on one line, so line breaks become spaces. Returns "" or why the text was
## refused (empty, or it reads as something else in the story file).
func edit_text(part: Resource, text: String) -> String:
	var said := text.replace("\r", "").replace("\n", " ").strip_edges()
	if part is Conversation:
		(part as Conversation).brief = said
		_changed(part)
		return ""
	if said == "":
		return "Type some text, or delete it."
	var old: String = part.get(&"text")
	var was_misread := _misread() != ""
	part.set(&"text", said)
	var problem := _misread()
	if problem != "" and not was_misread:
		part.set(&"text", old)
		return problem
	_changed(_owner_of(part))
	return ""


## Makes [param line] say its text in [param mood], one of the customer's person's moods.
func set_mood(line: DialogueLine, mood: StringName) -> void:
	line.mood = mood
	_changed(_owner_of(line))


## Inserts a new line into [param reply] at [param index] (its end for -1) and returns it.
func add_line(reply: Reply, index: int = -1) -> DialogueLine:
	var line := DialogueLine.new()
	line.text = new_text
	reply.lines.insert(reply.lines.size() if index < 0 else index, line)
	_changed(reply)
	return line


## Removes the line at [param index] of [param reply].
func delete_line(reply: Reply, index: int) -> void:
	reply.lines.remove_at(index)
	_changed(reply)


## Adds a new - choice, with a reply that says nothing yet, at the end of [param reply]'s list.
func add_choice(reply: Reply) -> Choice:
	var choice := Choice.new()
	choice.text = new_text
	choice.replies.append(Reply.new())
	reply.choices.append(choice)
	_changed(choice)
	return choice


## Adds an [code]if[/code] answer to [param choice], before its [code]else[/code], with the
## condition [member new_flag]. A choice's only answer without a condition becomes the
## [code]else[/code].
func add_answer(choice: Choice) -> Reply:
	var answer := Reply.new()
	answer.when = Condition.new()
	answer.when.need_flags.append(new_flag)
	var at := choice.replies.size()
	if at > 0 and choice.replies[at - 1].when == null:
		at -= 1
	choice.replies.insert(at, answer)
	_changed(answer)
	return answer


## Turns [param choice] from going on below its list to asking again to ending, and back.
func cycle_mark(choice: Choice) -> void:
	set_after(choice, ((after_of(choice) + 1) % After.size()) as After)


## Where the conversation goes after [param choice]'s answer.
static func after_of(choice: Choice) -> After:
	return After.END if choice.ends else (After.ASK_AGAIN if choice.returns else After.GO_ON)


## Makes the conversation go to [param after] once [param choice]'s answer has played.
func set_after(choice: Choice, after: After) -> void:
	choice.ends = after == After.END
	choice.returns = after == After.ASK_AGAIN
	_changed(choice)


## Sets the condition of [param part], a Choice or an answer of one, from [param text] in the story
## file's condition syntax (see [method set_when]). Returns "" or the parse error.
func set_condition(part: Resource, text: String) -> String:
	var when: Condition = null
	if text.strip_edges() != "":
		var parsed := StoryFormat.parse_condition(text, "condition")
		if not parsed.errors.is_empty():
			return _without_place(parsed.errors)
		when = parsed.value as Condition
	return set_when(part, when)


## Sets the condition of [param part], a Choice or an answer of one, to [param when]. A null or
## always-true condition removes it: the choice is always offered, or the answer becomes the one
## that plays when no other's condition holds, and moves last. Returns "" or why not, in words.
func set_when(part: Resource, when: Condition) -> String:
	if when != null and StoryFormat.write_condition(when) == "":
		when = null
	if part is Choice:
		(part as Choice).when = when
	elif _parent_of(part) is Choice:
		var choice := _parent_of(part) as Choice
		if when == null:
			for other: Reply in choice.replies:
				if other != part and other.when == null:
					return "Another answer of this choice already plays when no condition holds; give this one a fact."
			choice.replies.erase(part)
			choice.replies.append(part)
		(part as Reply).when = when
	else:
		push_error("ConversationGraph: only a choice or an answer has a condition, not %s" % part)
		return "Only a choice or an answer has a condition."
	_changed(part)
	return ""


## Sets the flags that [param reply] sets as it starts, from [param text] ("a, b=2, c=0"); empty text
## sets none. Returns "" or the parse error.
func set_flags(reply: Reply, text: String) -> String:
	var parsed := StoryFormat.parse_flags(text, "flags")
	if not parsed.errors.is_empty():
		return _without_place(parsed.errors)
	remember(reply, (parsed.value as Reply).set_flags)
	return ""


## Makes [param reply] remember [param flags] as it starts: fact to number, 0 to clear it.
func remember(reply: Reply, flags: Dictionary[StringName, int]) -> void:
	reply.set_flags = flags.duplicate()
	_changed(reply)


## Opens the "remembers" editor of [param reply] under its "remembers" words (or its box). Closing
## the editor sets what it remembers, as [method remember] does.
func edit_remembers(reply: Reply) -> void:
	if _read_only:
		return
	var editor := StoryFlagsEditor.make(facts)
	editor.edit(reply.set_flags)
	StoryConditionEditor.popup(_near(reply, &"set_flags"), "When this plays, the story remembers:", editor, func() -> void:
		var flags := editor.flags()
		if flags != reply.set_flags:
			remember(reply, flags))


## Opens the condition editor of [param part], a Choice or an answer of one, under its "only if"
## words (or its box). Closing the editor sets the condition, as [method set_when] does.
func edit_condition(part: Resource) -> void:
	if _read_only:
		return
	var editor := StoryConditionEditor.make(facts)
	editor.edit(part.get(&"when"))
	var title := "Offer this choice only if:" if part is Choice else "Play this answer only if:"
	StoryConditionEditor.popup(_near(part, &"when"), title, editor, func() -> void:
		var when := editor.condition()
		if _condition_text(when) == _condition_text(part.get(&"when")):
			return
		var problem := set_when(part, when)
		if problem != "":
			_status.text = problem)


## Gives [param reply]'s list a [member Reply.then]: a new box below the list, with one line,
## where the list's - choices meet. Returns it, or null when the list is empty or has one.
func go_on_below(reply: Reply) -> Reply:
	if reply.choices.is_empty() or reply.then != null:
		return null
	reply.then = Reply.new()
	reply.then.lines.append(DialogueLine.new())
	reply.then.lines[0].text = new_text
	_changed(reply.then)
	return reply.then


## Moves the line at [param from] of [param reply] to [param to].
func move_line(reply: Reply, from: int, to: int) -> void:
	var line := reply.lines[from]
	reply.lines.remove_at(from)
	reply.lines.insert(to, line)
	_changed(reply)


## Moves the choice at [param from] of [param reply]'s list to [param to].
## Moves the answer at [param from] of [param choice] to [param to]. Returns "" or, when the move
## would put the answer that plays when no condition holds anywhere but last, why not, in words.
func move_answer(choice: Choice, from: int, to: int) -> String:
	if not _answer_move_ok(choice, from, to):
		return "The answer that plays when no condition holds stays last."
	var answer := choice.replies[from]
	choice.replies.remove_at(from)
	choice.replies.insert(to, answer)
	_changed(answer)
	return ""


## Makes [param line] speak with [param effect], or with its conversation's effect for null.
func set_line_effect(line: DialogueLine, effect: VoiceEffect) -> void:
	line.effect = effect
	_changed(_owner_of(line))


func move_choice(reply: Reply, from: int, to: int) -> void:
	var choice := reply.choices[from]
	reply.choices.remove_at(from)
	reply.choices.insert(to, choice)
	_changed(choice)


## Removes [param part], a Choice or a Reply other than the Conversation, and everything under it.
## A list that loses its last choice takes in its [member Reply.then], as the story file reads it.
func delete_box(part: Resource) -> void:
	_pending_delete = null
	var parent := _parent_of(part)
	if part is Choice:
		var reply := parent as Reply
		reply.choices.erase(part)
		if reply.choices.is_empty() and reply.then != null:
			var then := reply.then
			reply.set_flags.merge(then.set_flags, true)
			reply.lines.append_array(then.lines)
			reply.choices = then.choices
			reply.then = then.then
		_changed(reply)
	elif parent is Choice:
		var choice := parent as Choice
		choice.replies.erase(part)
		if choice.replies.is_empty():
			choice.replies.append(Reply.new())
		_changed(choice)
	elif parent is Reply:
		(parent as Reply).then = null
		_changed(parent)
	else:
		push_error("ConversationGraph: can't delete %s; the Story Lab removes a whole conversation" % part)


# --- Drawing ---


func _rebuild() -> void:
	if not is_node_ready():
		return
	var old := _boxes.duplicate()
	var old_thens := _then_buttons.duplicate()
	_rebuilding = true
	clear_connections()
	var focused := get_viewport().gui_get_focus_owner()
	for box: GraphElement in old.values() + old_thens.values():
		if focused != null and box.is_ancestor_of(focused):
			focused.release_focus()
		box.name = "Old%d" % box.get_instance_id()
	_boxes.clear()
	_then_buttons.clear()
	_columns.clear()
	_returns.clear()
	_spots.clear()
	_status.text = "Read only" if _read_only else "Double-click a text to edit it. Drag the dots to reorder."
	if _conversation != null:
		var meets: Array[Array] = []
		_walk(_conversation, 0, null, false, meets)
		for pair: Array in meets:
			connect_node(_boxes[pair[0]].name, 0, _boxes[pair[1]].name, 0)
		if _boxes.has(_selected):
			_boxes[_selected].selected = true
	_replace(old, _boxes)
	_replace(old_thens, _then_buttons)
	_rebuilding = false
	_fresh = false
	_queue_place()


# Swaps the boxes in [param old] for those in [param new], by part: a box that stays starts where its
# old one was, a new one waits to fade in, and a removed one fades out.
func _replace(old: Dictionary, new: Dictionary) -> void:
	for part: Resource in old:
		var box: GraphElement = old[part]
		if new.has(part):
			(new[part] as GraphElement).position_offset = box.position_offset
		if new.has(part) or _fresh or motion_seconds <= 0.0:
			remove_child(box)
			box.queue_free()
		else:
			_leave(box)
	if _fresh:
		return
	for part: Resource in new:
		if not old.has(part):
			(new[part] as GraphElement).modulate.a = 0.0
			(new[part] as GraphElement).set_meta(&"arriving", true)


func _leave(box: GraphElement) -> void:
	box.selectable = false
	box.propagate_call(&"set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])
	_leaving.append(box)
	var fade := create_tween()
	fade.tween_property(box, ^"modulate:a", 0.0, motion_seconds)
	fade.tween_callback(func() -> void:
		_leaving.erase(box)
		box.queue_free())


# Draws [param reply] in [param column] and everything under it. [param exit] is where the walk goes
# once this reply and its list are done (null: the conversation ends), back to a list when
# [param back]. Returns the deepest column drawn.
func _walk(reply: Reply, column: int, exit: Reply, back: bool, meets: Array[Array]) -> int:
	var box := _reply_box(reply)
	_boxes[reply] = box
	_columns[reply] = column
	var deepest := column
	var leaves := not reply.choices.is_empty()
	var after: Reply = reply.then if reply.then != null else exit
	var after_back: bool = back if reply.then == null else false
	for i: int in reply.choices.size():
		var choice := reply.choices[i]
		var choice_box := _choice_box(choice, reply, i)
		_boxes[choice] = choice_box
		_columns[choice] = column + 1
		connect_node(box.name, 0, choice_box.name, 0)
		deepest = maxi(deepest, column + 1)
		var target: Reply = null
		var target_back := false
		if choice.returns:
			target = reply
			target_back = true
		else:
			leaves = false
			if not choice.ends:
				target = after
				target_back = after_back
		for answer: Reply in choice.replies:
			deepest = maxi(deepest, _walk(answer, column + 2, target, target_back, meets))
			connect_node(choice_box.name, 0, _boxes[answer].name, 0)
	if reply.then != null:
		deepest = maxi(deepest, _walk(reply.then, deepest + 1, exit, back, meets))
	# A list of + choices only has the leave button, which goes on like a - choice.
	if (reply.choices.is_empty() or leaves) and after != null:
		if after_back:
			_returns.append([reply, after])
		else:
			meets.append([reply, after])
	return deepest


func _queue_place() -> void:
	if not _place_queued:
		_place_queued = true
		_place.call_deferred()


func _place() -> void:
	_place_queued = false
	if not _boxes.has(_conversation):
		return
	var widths: Dictionary[int, float] = {}
	for part: Resource in _boxes:
		var box := _boxes[part]
		box.reset_size()
		var widest: float = widths.get(_columns[part], 0.0)
		widths[_columns[part]] = maxf(widest, box.size.x)
	var xs: Array[float] = []
	var x := 0.0
	for column: int in range(widths.keys().max() + 2):
		xs.append(x)
		var width: float = widths.get(column, junction_width)
		x += width + column_gap
	var targets: Dictionary[GraphElement, Vector2] = {}
	var bottom := _place_reply(_conversation, 0.0, xs, targets)
	_targets = targets
	var opening := _fit_pending and size.x > 0.0
	if opening:
		_fit_pending = false
		var content := Vector2(xs[xs.size() - 1] - column_gap, bottom) + Vector2(80, 80)
		zoom = clampf(minf(size.x / content.x, size.y / content.y), min_fit_zoom, 1.0)
		_scroll_to(Vector2(-40, -70) * zoom)
	if opening:
		for box: GraphElement in targets:
			box.position_offset = targets[box]
	else:
		_move(targets, _hold_anchor(targets))
	_overlay.queue_redraw()


# Scrolls so that the first anchor that still has a box stays where it was on screen, and returns
# how far that moved the view, in graph units.
func _hold_anchor(targets: Dictionary[GraphElement, Vector2]) -> Vector2:
	for i: int in _anchors.size():
		var box: GraphElement = _boxes.get(_anchors[i])
		if box == null:
			continue
		var before := scroll_offset
		_scroll_to(targets[box] * zoom - _anchor_spots[i])
		return (scroll_offset - before) / zoom
	return Vector2.ZERO


func _scroll_to(offset: Vector2) -> void:
	scroll_offset = offset
	_own_scroll = scroll_offset


# Moves every box to its target, keeping each still on screen through a scroll of [param shift]
# first; new boxes fade and grow in where they belong.
func _move(targets: Dictionary[GraphElement, Vector2], shift: Vector2) -> void:
	if _moves != null:
		_moves.kill()
	for box: GraphElement in _leaving:
		box.position_offset += shift
	var animate := motion_seconds > 0.0
	_moves = null
	for box: GraphElement in targets:
		if box.has_meta(&"arriving"):
			box.remove_meta(&"arriving")
			box.position_offset = targets[box]
			_arrive(box)
		elif animate:
			box.position_offset += shift
			if _moves == null:
				_moves = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			_moves.tween_property(box, ^"position_offset", targets[box], motion_seconds)
		else:
			box.position_offset = targets[box]


# Fades [param box] in, sliding out of the box that it branches from; GraphEdit owns its scale.
func _arrive(box: GraphElement) -> void:
	if motion_seconds <= 0.0:
		box.modulate.a = 1.0
	else:
		var target := box.position_offset
		box.position_offset -= Vector2(column_gap * 0.5, 0)
		var grow := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		grow.tween_property(box, ^"modulate:a", 1.0, motion_seconds)
		grow.tween_property(box, ^"position_offset", target, motion_seconds)
	var part: Resource = _boxes.find_key(box) if box is GraphNode else null
	if flash_seconds > 0.0 and part != null:
		_flashes[part] = 1.0
		create_tween().tween_method(func(strength: float) -> void:
			if strength <= 0.0:
				_flashes.erase(part)
			else:
				_flashes[part] = strength
			_overlay.queue_redraw(), 1.0, 0.0, flash_seconds)


# Finds where [param reply] and everything under it go, with its top at [param top], into
# [param targets]; returns the bottom.
func _place_reply(reply: Reply, top: float, xs: Array[float], targets: Dictionary[GraphElement, Vector2]) -> float:
	var box := _boxes[reply]
	targets[box] = Vector2(xs[_columns[reply]], top)
	var bottom := top + box.size.y
	var y := top
	var list_end := top
	for choice: Choice in reply.choices:
		var choice_box := _boxes[choice]
		targets[choice_box] = Vector2(xs[_columns[choice]], y)
		list_end = y + choice_box.size.y
		var choice_bottom := y + choice_box.size.y
		var answer_top := y
		for answer: Reply in choice.replies:
			var answer_bottom := _place_reply(answer, answer_top, xs, targets)
			answer_top = answer_bottom + row_gap
			choice_bottom = maxf(choice_bottom, answer_bottom)
		y = choice_bottom + row_gap
		bottom = maxf(bottom, choice_bottom)
	if _then_buttons.has(reply):
		var then_button := _then_buttons[reply]
		then_button.reset_size()
		targets[then_button] = Vector2(xs[_columns[reply] + 1], list_end + row_gap * 0.25)
		bottom = maxf(bottom, list_end + row_gap * 0.25 + then_button.size.y)
	if reply.then != null:
		bottom = maxf(bottom, _place_reply(reply.then, top, xs, targets))
	return bottom


func _draw_overlay() -> void:
	for part: Resource in _flashes:
		var lit: GraphNode = _boxes.get(part)
		if lit != null:
			var outline := Rect2(lit.position, lit.size * zoom).grow(5.0 * zoom)
			_overlay.draw_rect(outline, Color(selected_color, _flashes[part]), false, 3.0 * zoom)
	for pair: Array in _returns:
		var from := _boxes[pair[0]]
		var to := _boxes[pair[1]]
		# Up the column gap right of the answer, then left in the row gap above the list: no box is there.
		var start := from.position + from.get_output_port_position(0) * zoom
		var end := to.position + Vector2(to.size.x * 0.5, 0) * zoom
		var lane := end.y - row_gap * 0.5 * zoom
		var gap_x := start.x + column_gap * 0.3 * zoom
		_dash(PackedVector2Array([start, Vector2(gap_x, start.y), Vector2(gap_x, lane), Vector2(end.x, lane), end]), 8.0 * zoom)
		var head := 6.0 * zoom
		_overlay.draw_colored_polygon(PackedVector2Array([end, end + Vector2(-head, -head * 1.6), end + Vector2(head, -head * 1.6)]), arrow_color)


func _dash(points: PackedVector2Array, length: float) -> void:
	var on := true
	var left := length
	for i: int in range(1, points.size()):
		var p := points[i - 1]
		var q := points[i]
		var rest := p.distance_to(q)
		while rest > 0.0:
			var step := minf(left, rest)
			var r := p.move_toward(q, step)
			if on:
				_overlay.draw_line(p, r, arrow_color, 2.0 * zoom, true)
			p = r
			rest -= step
			left -= step
			if left <= 0.0:
				on = not on
				left = length


# --- Boxes ---


func _new_box(fill: Color, title: String) -> GraphNode:
	var box := GraphNode.new()
	box.name = "Box%d" % _boxes.size()
	box.title = title
	box.draggable = false
	box.custom_minimum_size.x = box_width
	for state: StringName in [&"panel", &"panel_selected"]:
		var panel := StyleBoxFlat.new()
		panel.bg_color = fill
		panel.set_corner_radius_all(0)
		panel.corner_radius_bottom_left = 4
		panel.corner_radius_bottom_right = 4
		panel.set_content_margin_all(10)
		panel.content_margin_top = 4
		panel.border_color = selected_color if state == &"panel_selected" else fill.darkened(0.25)
		panel.set_border_width_all(2 if state == &"panel_selected" else 1)
		panel.border_width_top = 0
		box.add_theme_stylebox_override(state, panel)
	for state: StringName in [&"titlebar", &"titlebar_selected"]:
		var bar := StyleBoxFlat.new()
		bar.bg_color = fill.darkened(0.06)
		bar.set_corner_radius_all(0)
		bar.corner_radius_top_left = 4
		bar.corner_radius_top_right = 4
		bar.set_content_margin_all(6)
		bar.border_color = selected_color if state == &"titlebar_selected" else fill.darkened(0.25)
		bar.set_border_width_all(2 if state == &"titlebar_selected" else 1)
		bar.border_width_bottom = 0
		box.add_theme_stylebox_override(state, bar)
	var title_label := box.get_titlebar_hbox().get_child(0) as Label
	if title_label != null:
		title_label.add_theme_color_override(&"font_color", faint_ink)
		title_label.add_theme_font_size_override(&"font_size", 12)
	box.add_theme_color_override(&"resizer_color", Color.TRANSPARENT)
	add_child(box)
	box.minimum_size_changed.connect(_queue_place)
	box.position_offset_changed.connect(_overlay.queue_redraw)
	return box


func _reply_box(reply: Reply) -> GraphNode:
	var parent := _parent_of(reply)
	var is_then := parent is Reply
	var junction := is_then and reply.lines.is_empty() and reply.set_flags.is_empty()
	var speaker := _customer.spoken_name() if _customer != null else "Customer"
	var box := _new_box(customer_color, "then" if junction else speaker)
	if junction:
		box.custom_minimum_size.x = junction_width
	var head_row := HBoxContainer.new()
	var head := HFlowContainer.new()
	head.custom_minimum_size.y = 6
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(head)
	if not _read_only and parent is Choice and (parent as Choice).replies.size() > 1:
		var choice := parent as Choice
		var index := choice.replies.find(reply)
		head_row.add_child(_grip(StoryConditionEditor.describe(reply.when), {"kind": &"answer", "list": choice, "index": index}))
		head_row.move_child(head_row.get_child(head_row.get_child_count() - 1), 0)
		box.set_drag_forwarding(Callable(),
			func(at: Vector2, data: Variant) -> bool: return _can_drop(at, data, &"answer", choice) and _answer_move_ok(choice, data["index"], index),
			func(_at: Vector2, data: Variant) -> void: move_answer(choice, data["index"], index))
	if not _read_only:
		head_row.add_child(_branch("Add a choice the player can say after these lines", func() -> void: _open_spot_later(add_choice(reply), &"text")))
	box.add_child(head_row)
	box.set_slot(0, reply != _conversation, 0, arrow_color, true, 0, arrow_color)
	if parent is Choice:
		var only := "only if " + StoryConditionEditor.describe(reply.when) if reply.when != null else "otherwise"
		if reply.when != null or (parent as Choice).replies.size() > 1:
			var chip := _chip(only, false)
			_spot(head, chip, reply, &"when", StoryFormat.write_condition(reply.when) if reply.when != null else "", func(text: String) -> String: return set_condition(reply, text))
		else:
			_spot(head, null, reply, &"when", "", func(text: String) -> String: return set_condition(reply, text))
	var sets := _chip("remembers: " + StoryFlagsEditor.describe(reply.set_flags), false) if not reply.set_flags.is_empty() else null
	_spot(head, sets, reply, &"set_flags", StoryFormat.write_flags(reply.set_flags), func(text: String) -> String: return set_flags(reply, text))
	for i: int in reply.lines.size():
		box.add_child(_line_row(reply, i))
	if reply.lines.is_empty() and not junction and reply.choices.is_empty():
		box.add_child(_label("(says nothing)", 12, faint_ink))
	if not _read_only:
		box.add_child(_action("+ line", "Add a line that the customer says, at the end of this box", func() -> void: _open_spot_later(add_line(reply), &"text")))
		if not reply.choices.is_empty() and reply.then == null:
			_then_buttons[reply] = _then_button(reply)
		_menu(box, _reply_menu(reply))
	return box


# The "+ then..." button that sits under [param reply]'s list.
func _then_button(reply: Reply) -> GraphElement:
	var holder := GraphElement.new()
	holder.name = "Then%d" % _then_buttons.size()
	holder.selectable = false
	holder.draggable = false
	var button := _action("+ then...", "What is said after this list, whichever choice was picked", func() -> void: _open_spot_later(go_on_below(reply).lines[0], &"text"))
	holder.add_child(button)
	holder.custom_minimum_size = button.get_combined_minimum_size()
	add_child(holder)
	return holder


func _choice_box(choice: Choice, reply: Reply, index: int) -> GraphNode:
	var box := _new_box(player_color, "Player")
	var head := HBoxContainer.new()
	box.add_child(head)
	box.set_slot(0, true, 0, arrow_color, true, 0, arrow_color)
	if not _read_only:
		head.add_child(_grip(choice.text, {"kind": &"choice", "list": reply, "index": index}))
		box.set_drag_forwarding(Callable(), _can_drop.bind(&"choice", reply), func(_at: Vector2, data: Variant) -> void: move_choice(reply, data["index"], index))
	var text := _label(choice.text, 15, ink)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spot(head, text, choice, &"text", choice.text, func(said: String) -> String: return edit_text(choice, said))
	if not _read_only:
		head.add_child(_branch("Add an answer that plays only if a condition holds (if)", func() -> void: _open_spot_later(add_answer(choice), &"when")))
	var chips := HFlowContainer.new()
	box.add_child(chips)
	var only := _chip("only if " + StoryConditionEditor.describe(choice.when), true) if choice.when != null else null
	_spot(chips, only, choice, &"when", StoryFormat.write_condition(choice.when) if choice.when != null else "", func(said: String) -> String: return set_condition(choice, said))
	var after_row := HBoxContainer.new()
	after_row.add_child(_label("After the answer:", 11, ink))
	var after := OptionButton.new()
	after.add_theme_font_size_override(&"font_size", 11)
	for i: int in AFTER_WORDS.size():
		after.add_item(AFTER_WORDS[i], i)
		after.set_item_tooltip(i, AFTER_TIPS[i])
	after.select(after_of(choice))
	after.tooltip_text = AFTER_TIPS[after_of(choice)]
	after.disabled = _read_only
	after.focus_mode = Control.FOCUS_NONE
	after.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	after.item_selected.connect(func(index: int) -> void: set_after(choice, index as After))
	after_row.add_child(after)
	box.add_child(after_row)
	if not _read_only:
		_menu(box, _choice_menu(choice))
	return box


func _line_row(reply: Reply, index: int) -> Control:
	var line := reply.lines[index]
	var row := HBoxContainer.new()
	if not _read_only:
		row.add_child(_grip(line.text, {"kind": &"line", "list": reply, "index": index}))
		row.set_drag_forwarding(Callable(), _can_drop.bind(&"line", reply), func(_at: Vector2, data: Variant) -> void: move_line(reply, data["index"], index))
	var face := VBoxContainer.new()
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	face.add_theme_constant_override(&"separation", 0)
	var mood := Button.new()
	mood.custom_minimum_size = thumb_size
	mood.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mood.expand_icon = true
	mood.icon = _thumb(line.mood)
	if mood.icon == null:
		mood.text = "?"
	mood.tooltip_text = _mood_tip(line.mood)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color("e4e4e4") if state != &"hover" else Color("d2d2d2")
		frame.set_corner_radius_all(4)
		frame.set_content_margin_all(0)
		mood.add_theme_stylebox_override(state, frame)
	mood.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	mood.add_theme_color_override(&"font_color", error_color)
	if not _read_only:
		mood.pressed.connect(_pick_mood.bind(line, mood))
	face.add_child(mood)
	var caption := _label(String(line.mood), 10, faint_ink if _portrait(line.mood) != null else error_color)
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.custom_minimum_size.x = thumb_size.x
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.add_child(caption)
	row.add_child(face)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override(&"separation", 0)
	var text := _label(line.text, 14, ink)
	_spot(words, text, line, &"text", line.text, func(said: String) -> String: return edit_text(line, said))
	words.add_child(_line_effect(line))
	row.add_child(words)
	row.add_child(_icon_button(_play_icon(), "Play this line", _play.bind(line)))
	if not _read_only:
		row.add_child(_icon_button(_trash_icon(), "Delete line", func() -> void: delete_line(reply, index)))
	return row


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 120
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


# A small flat button at the bottom of a box that adds something.
func _action(text: String, tip: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", 12)
	button.add_theme_color_override(&"font_color", faint_ink)
	button.add_theme_color_override(&"font_hover_color", ink)
	button.add_theme_color_override(&"font_pressed_color", ink)
	button.pressed.connect(pressed)
	return button


# The small round "+" at a box's right edge, by its output port: it adds what the box branches out to.
func _branch(tip: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = "+"
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(22, 22)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override(&"font_size", 14)
	for state: StringName in [&"normal", &"hover", &"pressed"]:
		var round := StyleBoxFlat.new()
		round.bg_color = arrow_color if state == &"normal" else arrow_color.darkened(0.25)
		round.set_corner_radius_all(11)
		round.set_content_margin_all(0)
		button.add_theme_stylebox_override(state, round)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.pressed.connect(pressed)
	return button


func _icon_button(icon: Texture2D, tip: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.icon = icon
	button.flat = true
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.add_theme_constant_override(&"icon_max_width", 16)
	button.add_theme_color_override(&"icon_normal_color", faint_ink)
	button.add_theme_color_override(&"icon_hover_color", ink)
	button.add_theme_color_override(&"icon_pressed_color", ink)
	button.pressed.connect(pressed)
	return button


# A 32 px white triangle pointing right; buttons tint it.
static func _play_icon() -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in 32:
		for x: int in 32:
			if x >= 8 and x <= 26 and absf(y - 15.5) <= (26 - x) * 0.62:
				image.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)


# A 32 px white trash can, lid and handle on a ribbed body; buttons tint it.
static func _trash_icon() -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(12, 3, 8, 3), Color.WHITE)
	image.fill_rect(Rect2i(5, 6, 22, 3), Color.WHITE)
	image.fill_rect(Rect2i(8, 11, 16, 18), Color.WHITE)
	for x: int in [12, 16, 20]:
		image.fill_rect(Rect2i(x - 1, 14, 2, 12), Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)


func _chip(text: String, on_player: bool) -> Button:
	var chip := Button.new()
	chip.text = text
	chip.add_theme_font_size_override(&"font_size", 11)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("2f9e92") if on_player else Color("e6e6e6")
		if state == &"hover":
			fill.bg_color = fill.bg_color.darkened(0.1)
		fill.draw_center = state != &"focus"
		fill.set_corner_radius_all(8)
		fill.content_margin_left = 8
		fill.content_margin_right = 8
		fill.content_margin_top = 1
		fill.content_margin_bottom = 1
		chip.add_theme_stylebox_override(state, fill)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_disabled_color", &"font_focus_color"]:
		chip.add_theme_color_override(state, Color.WHITE if on_player else ink)
	return chip


# A handle that drags [param data] ({kind, list, index}) with [param text] as its preview.
func _grip(text: String, data: Dictionary) -> Label:
	var grip := Label.new()
	grip.text = "::"
	grip.tooltip_text = "Drag to reorder"
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = Control.CURSOR_DRAG
	grip.add_theme_color_override(&"font_color", faint_ink)
	var drag := func(_at: Vector2) -> Variant:
		grip.set_drag_preview(_label(text, 14, ink))
		return data
	grip.set_drag_forwarding(drag, Callable(), Callable())
	return grip


# Whether moving [param choice]'s answer at [param from] to [param to] keeps the answer that plays
# when no condition holds last.
func _answer_move_ok(choice: Choice, from: int, to: int) -> bool:
	var order := choice.replies.duplicate()
	var moved: Reply = order.pop_at(from)
	order.insert(to, moved)
	for i: int in order.size() - 1:
		if (order[i] as Reply).when == null:
			return false
	return true


# The small dropdown of [param line]'s own voice effect.
func _line_effect(line: DialogueLine) -> OptionButton:
	var effect := OptionButton.new()
	effect.flat = true
	effect.focus_mode = Control.FOCUS_NONE
	effect.add_theme_font_size_override(&"font_size", 10)
	effect.add_theme_color_override(&"font_color", faint_ink)
	effect.tooltip_text = "How this line sounds: the conversation's voice effect, or one of its own"
	effect.add_item("Conversation's voice")
	for name: String in LabUI.resource_names(Voices.EFFECTS_DIR):
		effect.add_item(name)
		if line.effect != null and line.effect.resource_path.get_file().get_basename() == name:
			effect.select(effect.item_count - 1)
	effect.disabled = _read_only
	effect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	effect.item_selected.connect(func(index: int) -> void:
		if index == 0:
			set_line_effect(line, null)
			return
		var path := Voices.EFFECTS_DIR + effect.get_item_text(index) + ".tres"
		var chosen := load(path) as VoiceEffect
		if chosen == null:
			push_error("Story Lab: %s doesn't load as a VoiceEffect" % path)
			_status.text = "The voice effect %s doesn't load." % effect.get_item_text(index)
			return
		set_line_effect(line, chosen))
	return effect


# Whether [param data] is a dragged [param kind] of the list of [param list].
func _can_drop(_at: Vector2, data: Variant, kind: StringName, list: Resource) -> bool:
	return data is Dictionary and (data as Dictionary).get("kind") == kind and (data as Dictionary).get("list") == list


# --- Editing in place ---


func _spot_key(part: Resource, field: StringName) -> String:
	return "%d:%s" % [part.get_instance_id(), field]


# Registers what [param shown] (null: nothing until it is edited) shows in [param parent] as
# editable in place: a double-click on a label or a click on a chip opens a field there.
func _spot(parent: Control, shown: Control, part: Resource, field: StringName, text: String, apply: Callable) -> void:
	var anchor: Control = shown
	if anchor == null:
		anchor = Control.new()
		anchor.hide()
	parent.add_child(anchor)
	_spots[_spot_key(part, field)] = [anchor, text, apply]
	if _read_only or shown == null:
		return
	if shown is Button:
		(shown as Button).pressed.connect(_open_spot.bind(part, field))
	else:
		shown.mouse_filter = Control.MOUSE_FILTER_PASS
		shown.gui_input.connect(func(event: InputEvent) -> void:
			var click := event as InputEventMouseButton
			if click != null and click.double_click and click.button_index == MOUSE_BUTTON_LEFT:
				_open_spot(part, field))


# Opens an editor of [param field] of [param part] in place. With [param reveal], as for a new item,
# the view scrolls the least that shows the whole editor, if it isn't in view.
func _open_spot(part: Resource, field: StringName, reveal: bool = false) -> void:
	if field == &"when":
		edit_condition(part)
		return
	if field == &"set_flags":
		edit_remembers(part)
		return
	var spot: Array = _spots.get(_spot_key(part, field), [])
	if spot.is_empty() or _read_only:
		return
	var anchor: Control = spot[0]
	var apply: Callable = spot[2]
	var said: String = spot[1]
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var error := _label("", 12, error_color)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color.WHITE
	paper.set_content_margin_all(3)
	error.add_theme_stylebox_override(&"normal", paper)
	error.hide()
	var commit := func(text: String) -> void:
		if _rebuilding or not holder.is_inside_tree():
			return
		var problem: String = apply.call(text)
		if problem != "":
			error.text = problem
			error.show()
	var editor := _text_editor(said, commit)
	# A text gets the whole width of its box, under the row that shows it.
	var row: Control = anchor
	while not (row.get_parent() is GraphNode):
		row = row.get_parent()
	row.get_parent().add_child(holder)
	row.get_parent().move_child(holder, row.get_index() + 1)
	_paper(editor)
	editor.gui_input.connect(func(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.pressed and key.keycode == KEY_ESCAPE:
			editor.accept_event()
			_rebuild.call_deferred())
	holder.add_child(editor)
	holder.add_child(error)
	anchor.hide()
	editor.grab_focus.call_deferred()
	_selected = part if part is Choice or part is Reply else _owner_of(part)
	if reveal:
		_reveal(editor)


# Once [param editor]'s box is laid out, scrolls over [member motion_seconds] by the least that
# brings the editor and [member reveal_margin] around it inside the view; nothing when it is in view.
func _reveal(editor: Control) -> void:
	await get_tree().process_frame
	if not editor.is_inside_tree():
		return
	var up: Node = editor.get_parent()
	while up != null and not (up is GraphNode):
		up = up.get_parent()
	var box := up as GraphNode
	if box == null or not _targets.has(box):
		return
	var inside := box.get_global_transform().affine_inverse() * editor.get_global_rect()
	var spot := Rect2((_targets[box] + inside.position) * zoom - scroll_offset, inside.size * zoom)
	var room := Rect2(Vector2.ONE * reveal_margin, size - Vector2.ONE * reveal_margin * 2.0)
	var need := Vector2.ZERO
	for axis: int in 2:
		if spot.position[axis] < room.position[axis] or spot.size[axis] > room.size[axis]:
			need[axis] = spot.position[axis] - room.position[axis]
		elif spot.end[axis] > room.end[axis]:
			need[axis] = spot.end[axis] - room.end[axis]
	if need == Vector2.ZERO:
		return
	_anchors.clear()
	if _pan != null:
		_pan.kill()
	if motion_seconds <= 0.0:
		_scroll_to(scroll_offset + need)
		return
	_pan = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_pan.tween_method(_scroll_to, scroll_offset, scroll_offset + need, motion_seconds)


# A word-wrapping editor of [param said], at least [member editor_lines] tall, that grows with its
# text. Enter (with or without Ctrl or Cmd) and leaving it call [param commit] with the text.
func _text_editor(said: String, commit: Callable) -> TextEdit:
	var edit := TextEdit.new()
	edit.text = said
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.scroll_fit_content_height = true
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override(&"font_size", 14)
	edit.tooltip_text = "Enter saves, Esc cancels"
	edit.ready.connect(func() -> void:
		edit.custom_minimum_size = Vector2(box_width - 24, edit.get_line_height() * editor_lines + 12)
		if said == new_text:
			edit.select_all()
		else:
			edit.set_caret_line(edit.get_line_count() - 1)
			edit.set_caret_column(edit.get_line(edit.get_line_count() - 1).length()))
	edit.gui_input.connect(func(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.pressed and key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			edit.accept_event()
			commit.call(edit.text))
	edit.focus_exited.connect(func() -> void:
		if edit.text != said:
			commit.call(edit.text))
	return edit


# Gives a field the box's light look, whatever the theme around the graph.
func _paper(field: Control) -> void:
	for state: StringName in [&"normal", &"focus", &"read_only"]:
		var paper := StyleBoxFlat.new()
		paper.bg_color = Color.WHITE
		paper.border_color = selected_color if state == &"focus" else Color("b5b5b5")
		paper.set_border_width_all(2 if state == &"focus" else 1)
		paper.set_corner_radius_all(3)
		paper.set_content_margin_all(6)
		field.add_theme_stylebox_override(state, paper)
	field.add_theme_color_override(&"font_color", ink)
	field.add_theme_color_override(&"caret_color", ink)
	field.add_theme_color_override(&"font_placeholder_color", faint_ink)
	field.add_theme_color_override(&"selection_color", player_color.lightened(0.4))
	field.add_theme_color_override(&"font_selected_color", ink)


# What a popup editor of [param field] of [param part] opens under: its words in the box while
# they show, else its box.
func _near(part: Resource, field: StringName) -> Control:
	var spot: Array = _spots.get(_spot_key(part, field), [])
	if not spot.is_empty() and (spot[0] as Control).is_visible_in_tree():
		return spot[0]
	var box: GraphNode = _boxes.get(part)
	return box if box != null else self


# [param when] as the story file writes it; "" for null.
static func _condition_text(when: Condition) -> String:
	return StoryFormat.write_condition(when) if when != null else ""


# Opens the editor of [param field] of a new [param part] once the rebuild that its edit queued is
# done, and brings it into view.
func _open_spot_later(part: Resource, field: StringName) -> void:
	_open_spot.call_deferred(part, field, true)


func _menu(box: GraphNode, items: Array[Array]) -> void:
	var menu := MenuButton.new()
	menu.text = "..."
	menu.flat = true
	menu.tooltip_text = "More"
	var popup := menu.get_popup()
	for i: int in items.size():
		popup.add_item(items[i][0], i)
	popup.id_pressed.connect(func(id: int) -> void: (items[id][1] as Callable).call())
	box.get_titlebar_hbox().add_child(menu)


func _reply_menu(reply: Reply) -> Array[Array]:
	var items: Array[Array] = [
		["Add a line", func() -> void: _open_spot_later(add_line(reply), &"text")],
		["Add a choice", func() -> void: _open_spot_later(add_choice(reply), &"text")],
		["Remembers...", func() -> void: edit_remembers(reply)],
	]
	if _parent_of(reply) is Choice:
		items.append(["Only if...", func() -> void: _open_spot(reply, &"when")])
	if not reply.choices.is_empty() and reply.then == null:
		items.append(["Go on below the list", func() -> void: _open_spot_later(go_on_below(reply).lines[0], &"text")])
	if reply != _conversation:
		items.append(["Delete", func() -> void: _ask_delete(reply)])
	return items


func _choice_menu(choice: Choice) -> Array[Array]:
	return [
		["Add an answer (if)", func() -> void: _open_spot_later(add_answer(choice), &"when")],
		["Only if...", func() -> void: _open_spot(choice, &"when")],
		["Delete", func() -> void: _ask_delete(choice)],
	]


func _ask_delete(part: Resource) -> void:
	var under := _count_under(part)
	if under == 0:
		delete_box(part)
		return
	_pending_delete = part
	_confirm.dialog_text = "Delete this box and the %d box%s under it?" % [under, "" if under == 1 else "es"]
	_confirm.popup_centered()


func _count_under(part: Resource) -> int:
	var count := 0
	if part is Choice:
		for answer: Reply in (part as Choice).replies:
			count += 1 + _count_under(answer)
	elif part is Reply:
		for choice: Choice in (part as Reply).choices:
			count += 1 + _count_under(choice)
		if (part as Reply).then != null:
			count += 1 + _count_under((part as Reply).then)
	return count


func _changed(focus: Resource) -> void:
	_selected = focus
	_hold_still(focus)
	edited.emit()
	_rebuild.call_deferred()


# Remembers where the box under the mouse is on screen, and the nearest box around [param focus]
# (the part that the edit changed or added), so the relayout after the edit keeps them still.
func _hold_still(focus: Resource) -> void:
	_anchors.clear()
	_anchor_spots.clear()
	var mouse := get_local_mouse_position()
	if Rect2(Vector2.ZERO, size).has_point(mouse):
		for part: Resource in _boxes:
			var box := _boxes[part]
			if Rect2(box.position, box.size * zoom).has_point(mouse):
				_anchors.append(part)
				_anchor_spots.append(box.position)
	var near: Resource = _owner_of(focus)
	while near != null and not _boxes.has(near):
		near = _parent_of(near)
	if near != null:
		_anchors.append(near)
		_anchor_spots.append(_boxes[near].position)


# The box that holds [param part]: the Reply of a line, else [param part].
func _owner_of(part: Resource) -> Resource:
	if part is DialogueLine:
		for reply: Reply in _replies(_conversation):
			if reply.lines.has(part):
				return reply
	return part


# What offers [param part]: an answer's Choice, a choice's Reply, or the Reply whose then it is;
# null for the conversation or a part that isn't in it.
func _parent_of(part: Resource) -> Resource:
	for reply: Reply in _replies(_conversation):
		if reply.then == part:
			return reply
		for choice: Choice in reply.choices:
			if choice == part:
				return reply
			for answer: Reply in choice.replies:
				if answer == part:
					return choice
	return null


# [param reply] and every reply under it.
func _replies(reply: Reply) -> Array[Reply]:
	var found: Array[Reply] = []
	if reply == null:
		return found
	found.append(reply)
	for choice: Choice in reply.choices:
		for answer: Reply in choice.replies:
			found.append_array(_replies(answer))
	found.append_array(_replies(reply.then))
	return found


# Why the conversation, written to its story file, reads back differently (a text that looks like
# a choice, a mood or a tag), or "".
func _misread() -> String:
	if _customer == null or _customer.resource_path == "":
		return ""
	var errand := Errand.new()
	errand.customer = _customer
	errand.conversations.append(_conversation)
	var written := StoryFormat.write_errand(errand)
	var parsed := StoryFormat.parse_errand(written, "res://story/errands/0101_graph_check.errand")
	if not parsed.errors.is_empty():
		return "The story file can't hold this text: %s" % _without_place(parsed.errors)
	if not _same(_conversation, (parsed.value as Errand).conversations[0]):
		return "The story file would read this text as something else, such as a tag."
	return ""


# Whether [param a] and [param b] say the same lines and offer the same choices, all the way down.
func _same(a: Reply, b: Reply) -> bool:
	if a == null or b == null:
		return a == b
	if a.lines.size() != b.lines.size() or a.choices.size() != b.choices.size():
		return false
	for i: int in a.lines.size():
		if a.lines[i].text != b.lines[i].text or a.lines[i].mood != b.lines[i].mood:
			return false
	for i: int in a.choices.size():
		var x := a.choices[i]
		var y := b.choices[i]
		if x.text != y.text or x.returns != y.returns or x.ends != y.ends or x.replies.size() != y.replies.size():
			return false
		for j: int in x.replies.size():
			if not _same(x.replies[j], y.replies[j]):
				return false
	return _same(a.then, b.then)


func _without_place(errors: PackedStringArray) -> String:
	var whats := PackedStringArray()
	for error: String in errors:
		whats.append(error.substr(error.find(": ") + 2) if error.contains(": ") else error)
	return "; ".join(whats)


func _on_node_selected(node: Node) -> void:
	for part: Resource in _boxes:
		if _boxes[part] == node:
			_selected = part


# --- Moods and voice ---


# The customer's person's moods: the ones it has portraits for.
func _moods() -> Array[StringName]:
	var person := _customer.person if _customer != null else null
	return person.moods() if person != null else ([] as Array[StringName])


func _portrait(mood: StringName) -> Texture2D:
	if _customer == null or _customer.person == null:
		return null
	return _customer.person.portraits.get(mood)


# The face and upper body from the top of [param mood]'s portrait, square; the person's face
# without one; null without either.
func _thumb(mood: StringName) -> Texture2D:
	var portrait := _portrait(mood)
	if portrait == null:
		return _customer.person.face if _customer != null and _customer.person != null else null
	var side := minf(portrait.get_width() * thumb_crop, portrait.get_height())
	var crop := AtlasTexture.new()
	crop.atlas = portrait
	crop.region = Rect2((portrait.get_width() - side) * 0.5, 0.0, side, side)
	return crop


func _has_voice_mood(mood: StringName) -> bool:
	return Voices.has_mood(mood)


func _mood_tip(mood: StringName) -> String:
	var tip := String(mood)
	if _portrait(mood) == null:
		tip += "\nThe person has no portrait for this mood."
	if not _has_voice_mood(mood):
		tip += "\nNo voices/moods/%s.tres: it speaks as neutral." % mood
	return tip


func _pick_mood(line: DialogueLine, near: Control) -> void:
	for child: Node in _moods_grid.get_children():
		_moods_grid.remove_child(child)
		child.queue_free()
	var moods := _moods()
	if moods.is_empty():
		_status.text = "%s has no portraits, so no moods to pick." % (_customer.display_name if _customer != null else "This customer")
		return
	for mood: StringName in moods:
		var button := Button.new()
		button.icon = _portrait(mood)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.custom_minimum_size = Vector2(88, 118)
		button.text = String(mood) if _has_voice_mood(mood) else "%s (no voice)" % mood
		button.tooltip_text = _mood_tip(mood)
		button.toggle_mode = true
		button.button_pressed = mood == line.mood
		if not _has_voice_mood(mood):
			button.add_theme_color_override(&"font_color", error_color)
		button.pressed.connect(func() -> void:
			_mood_picker.hide()
			set_mood(line, mood))
		_moods_grid.add_child(button)
	_mood_picker.reset_size()
	var at := near.get_global_transform_with_canvas() * Vector2(0, near.size.y)
	_mood_picker.popup(Rect2i(Vector2i(at), Vector2i.ZERO))


func _play(line: DialogueLine) -> void:
	if _customer == null or _customer.voice == null:
		_status.text = "%s has no voice person (voices/persons/); nothing to play." % (_customer.display_name if _customer != null else "This customer")
		return
	var seconds := _voice.say(line, _customer.voice, line.effect if line.effect != null else _conversation.effect)
	if seconds > 0.0 or OS.has_feature("web"):
		_status.text = "Playing \"%s\" (%s)" % [line.text, line.mood]
	else:
		_status.text = "Nothing to play for \"%s\": this build has no live voice and the line has no rendered file (docs/building-and-testing.md, Voices)." % line.text
