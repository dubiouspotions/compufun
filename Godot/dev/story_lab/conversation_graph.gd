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
@export var thumb_size: Vector2 = Vector2(40, 40)
## The least zoom that a new conversation shows at, to fit it in the view.
@export var min_fit_zoom: float = 0.7
## The text of a new line or choice, selected in its editor at once.
@export var new_text: String = "..."
## The condition of a new answer, selected in its editor at once.
@export var new_flag: StringName = &"new_flag"

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
	_overlay.draw.connect(_draw_returns)
	draw.connect(_overlay.queue_redraw)
	resized.connect(func() -> void:
		if _fit_pending:
			_queue_place())
	scroll_offset_changed.connect(func(_offset: Vector2) -> void: _overlay.queue_redraw())
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
	_rebuild()


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


## Sets the text of [param part]: a DialogueLine, a Choice, or the Conversation's brief. Returns ""
## or why the text was refused (empty, or it reads as something else in the story file).
func edit_text(part: Resource, text: String) -> String:
	var said := text.strip_edges()
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
	line.pose = mood
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


## Turns [param choice] from - (goes on below its list) to + (returns to its list) to [end] and back.
func cycle_mark(choice: Choice) -> void:
	if choice.ends:
		choice.ends = false
	elif choice.returns:
		choice.returns = false
		choice.ends = true
	else:
		choice.returns = true
	_changed(choice)


## Sets the condition of [param part], a Choice or an answer of one, from [param text] in the story
## file's condition syntax. Empty text removes it: the choice is always offered, or the answer
## becomes the choice's [code]else[/code] and moves last. Returns "" or the parse error.
func set_condition(part: Resource, text: String) -> String:
	var when: Condition = null
	if text.strip_edges() != "":
		var parsed := StoryFormat.parse_condition(text, "condition")
		if not parsed.errors.is_empty():
			return _without_place(parsed.errors)
		when = parsed.value as Condition
		if StoryFormat.write_condition(when) == "":
			when = null
	if part is Choice:
		(part as Choice).when = when
	elif _parent_of(part) is Choice:
		var choice := _parent_of(part) as Choice
		if when == null:
			for other: Reply in choice.replies:
				if other != part and other.when == null:
					return "This choice already has an answer without a condition (else)."
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
	reply.set_flags = (parsed.value as Reply).set_flags
	_changed(reply)
	return ""


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
	_rebuilding = true
	clear_connections()
	for box: GraphNode in _boxes.values():
		remove_child(box)
		box.queue_free()
	_rebuilding = false
	_boxes.clear()
	_columns.clear()
	_returns.clear()
	_spots.clear()
	_status.text = "Read only" if _read_only else "Double-click a text to edit it. Drag the dots to reorder."
	if _conversation == null:
		return
	var meets: Array[Array] = []
	_walk(_conversation, 0, null, false, meets)
	for pair: Array in meets:
		connect_node(_boxes[pair[0]].name, 0, _boxes[pair[1]].name, 0)
	if _boxes.has(_selected):
		_boxes[_selected].selected = true
	_queue_place()


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
	for column: int in range(widths.keys().max() + 1):
		xs.append(x)
		var width: float = widths.get(column, junction_width)
		x += width + column_gap
	var bottom := _place_reply(_conversation, 0.0, xs)
	if _fit_pending and size.x > 0.0:
		_fit_pending = false
		var content := Vector2(x - column_gap, bottom) + Vector2(80, 80)
		zoom = clampf(minf(size.x / content.x, size.y / content.y), min_fit_zoom, 1.0)
		scroll_offset = Vector2(-40, -70) * zoom
	_keep_in_view(_selected)
	_overlay.queue_redraw()


# Places [param reply] and everything under it, with its top at [param top]; returns the bottom.
func _place_reply(reply: Reply, top: float, xs: Array[float]) -> float:
	var box := _boxes[reply]
	box.position_offset = Vector2(xs[_columns[reply]], top)
	var bottom := top + box.size.y
	var y := top
	for choice: Choice in reply.choices:
		var choice_box := _boxes[choice]
		choice_box.position_offset = Vector2(xs[_columns[choice]], y)
		var choice_bottom := y + choice_box.size.y
		var answer_top := y
		for answer: Reply in choice.replies:
			var answer_bottom := _place_reply(answer, answer_top, xs)
			answer_top = answer_bottom + row_gap
			choice_bottom = maxf(choice_bottom, answer_bottom)
		y = choice_bottom + row_gap
		bottom = maxf(bottom, choice_bottom)
	if reply.then != null:
		bottom = maxf(bottom, _place_reply(reply.then, top, xs))
	return bottom


func _keep_in_view(part: Resource) -> void:
	if not _boxes.has(part):
		return
	var box := _boxes[part]
	var rect := Rect2(box.position_offset * zoom, box.size * zoom)
	if not Rect2(scroll_offset, size).encloses(rect):
		scroll_offset = rect.position - Vector2(40, 40) * zoom


func _draw_returns() -> void:
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
	return box


func _reply_box(reply: Reply) -> GraphNode:
	var parent := _parent_of(reply)
	var is_then := parent is Reply
	var junction := is_then and reply.lines.is_empty() and reply.set_flags.is_empty()
	var speaker := _customer.spoken_name() if _customer != null else "Customer"
	var box := _new_box(customer_color, "then" if junction else speaker)
	if junction:
		box.custom_minimum_size.x = junction_width
	var head := HFlowContainer.new()
	head.custom_minimum_size.y = 6
	box.add_child(head)
	box.set_slot(0, reply != _conversation, 0, arrow_color, true, 0, arrow_color)
	if reply == _conversation and (not _read_only or _conversation.brief != ""):
		var brief := _label(_conversation.brief if _conversation.brief != "" else "(no brief)", 12, faint_ink)
		_spot(head, brief, _conversation, &"brief", _conversation.brief, func(text: String) -> String: return edit_text(_conversation, text))
		brief.custom_minimum_size.x = box_width - 24
	if parent is Choice:
		var only := "only if: " + StoryFormat.write_condition(reply.when) if reply.when != null else "else"
		if reply.when != null or (parent as Choice).replies.size() > 1:
			var chip := _chip(only, false)
			_spot(head, chip, reply, &"when", StoryFormat.write_condition(reply.when) if reply.when != null else "", func(text: String) -> String: return set_condition(reply, text))
		else:
			_spot(head, null, reply, &"when", "", func(text: String) -> String: return set_condition(reply, text))
	var sets := _chip("sets: " + StoryFormat.write_flags(reply.set_flags), false) if not reply.set_flags.is_empty() else null
	_spot(head, sets, reply, &"set_flags", StoryFormat.write_flags(reply.set_flags), func(text: String) -> String: return set_flags(reply, text))
	for i: int in reply.lines.size():
		box.add_child(_line_row(reply, i))
	if reply.lines.is_empty() and not junction and reply.choices.is_empty():
		box.add_child(_label("(says nothing)", 12, faint_ink))
	if not _read_only:
		var more := Button.new()
		more.text = "+ line"
		more.flat = true
		more.add_theme_color_override(&"font_color", faint_ink)
		more.add_theme_font_size_override(&"font_size", 12)
		more.pressed.connect(func() -> void: _open_spot(add_line(reply), &"text"))
		box.add_child(more)
		_menu(box, _reply_menu(reply))
	return box


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
	var chips := HFlowContainer.new()
	box.add_child(chips)
	var only := _chip("only if: " + StoryFormat.write_condition(choice.when), true) if choice.when != null else null
	_spot(chips, only, choice, &"when", StoryFormat.write_condition(choice.when) if choice.when != null else "", func(said: String) -> String: return set_condition(choice, said))
	var mark := Button.new()
	mark.text = "end" if choice.ends else ("+" if choice.returns else "-")
	mark.tooltip_text = "Ends the conversation after the answer." if choice.ends else ("Returns to this list after the answer." if choice.returns else "Goes on below this list after the answer.")
	mark.custom_minimum_size = Vector2(36, 0)
	mark.disabled = _read_only
	mark.pressed.connect(func() -> void: cycle_mark(choice))
	box.get_titlebar_hbox().add_child(mark)
	if not _read_only:
		_menu(box, _choice_menu(choice))
	return box


func _line_row(reply: Reply, index: int) -> Control:
	var line := reply.lines[index]
	var row := HBoxContainer.new()
	if not _read_only:
		row.add_child(_grip(line.text, {"kind": &"line", "list": reply, "index": index}))
		row.set_drag_forwarding(Callable(), _can_drop.bind(&"line", reply), func(_at: Vector2, data: Variant) -> void: move_line(reply, data["index"], index))
	var mood := Button.new()
	mood.custom_minimum_size = thumb_size
	mood.expand_icon = true
	mood.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var portrait := _portrait(line.pose)
	mood.icon = portrait
	if portrait == null:
		mood.text = "?"
		mood.add_theme_color_override(&"font_color", error_color)
	mood.tooltip_text = _mood_tip(line.pose)
	if not _read_only:
		mood.pressed.connect(_pick_mood.bind(line, mood))
	row.add_child(mood)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override(&"separation", 0)
	var caption := String(line.pose)
	if line.effect != null:
		caption += "  [effect %s]" % line.effect.resource_path.get_file().get_basename()
	words.add_child(_label(caption, 11, faint_ink))
	var text := _label(line.text, 14, ink)
	_spot(words, text, line, &"text", line.text, func(said: String) -> String: return edit_text(line, said))
	row.add_child(words)
	var play := Button.new()
	play.text = ">"
	play.flat = true
	play.tooltip_text = "Play this line in its mood"
	play.add_theme_font_size_override(&"font_size", 12)
	play.pressed.connect(_play.bind(line))
	row.add_child(play)
	if not _read_only:
		var cut := Button.new()
		cut.text = "x"
		cut.flat = true
		cut.tooltip_text = "Delete this line"
		cut.add_theme_color_override(&"font_color", faint_ink)
		cut.add_theme_font_size_override(&"font_size", 12)
		cut.pressed.connect(func() -> void: delete_line(reply, index))
		row.add_child(cut)
	return row


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 120
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


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


# Whether [param data] is a dragged [param kind] of the list of [param list].
func _can_drop(_at: Vector2, data: Variant, kind: StringName, list: Reply) -> bool:
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


func _open_spot(part: Resource, field: StringName) -> void:
	var spot: Array = _spots.get(_spot_key(part, field), [])
	if spot.is_empty() or _read_only:
		return
	var anchor: Control = spot[0]
	var apply: Callable = spot[2]
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var field_edit := LineEdit.new()
	field_edit.text = spot[1]
	field_edit.custom_minimum_size.x = 160
	field_edit.select_all_on_focus = true
	field_edit.placeholder_text = {&"when": "flag, not flag, days 2-4", &"set_flags": "flag, flag=2, flag=0"}.get(field, "")
	var error := _label("", 12, error_color)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color.WHITE
	paper.set_content_margin_all(3)
	error.add_theme_stylebox_override(&"normal", paper)
	error.hide()
	holder.add_child(field_edit)
	holder.add_child(error)
	anchor.get_parent().add_child(holder)
	anchor.get_parent().move_child(holder, anchor.get_index())
	anchor.hide()
	var commit := func(text: String) -> void:
		if _rebuilding or not field_edit.is_inside_tree():
			return
		var problem: String = apply.call(text)
		if problem != "":
			error.text = problem
			error.show()
	field_edit.text_submitted.connect(commit)
	field_edit.focus_exited.connect(func() -> void:
		if field_edit.text != spot[1]:
			commit.call(field_edit.text))
	field_edit.gui_input.connect(func(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.pressed and key.keycode == KEY_ESCAPE:
			field_edit.accept_event()
			_rebuild.call_deferred())
	field_edit.grab_focus.call_deferred()
	_selected = part if part is Choice or part is Reply else _owner_of(part)


# Opens the editor of [param field] of [param part] once the rebuild that its edit queued is done.
func _open_spot_later(part: Resource, field: StringName) -> void:
	_open_spot.call_deferred(part, field)


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
		["Sets flags...", func() -> void: _open_spot(reply, &"set_flags")],
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
	edited.emit()
	_rebuild.call_deferred()


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
		if a.lines[i].text != b.lines[i].text or a.lines[i].pose != b.lines[i].pose:
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
	var found: Array[StringName] = []
	if person == null:
		return found
	if person.has_method(&"moods"):
		found.assign(person.call(&"moods"))
		return found
	found.assign(person.portraits.keys())
	return found


func _portrait(mood: StringName) -> Texture2D:
	if _customer == null or _customer.person == null:
		return null
	return _customer.person.portraits.get(mood)


func _has_voice_mood(mood: StringName) -> bool:
	return ResourceLoader.exists(Voices.MOODS_DIR + String(mood) + ".tres")


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
		button.button_pressed = mood == line.pose
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
		_status.text = "Playing \"%s\" (%s)" % [line.text, line.pose]
	else:
		_status.text = "Nothing to play for \"%s\": this build has no live voice and the line has no rendered file (docs/building-and-testing.md, Voices)." % line.text
