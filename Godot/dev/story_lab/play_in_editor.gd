class_name StoryPlayInEditor
extends Control
## Play in editor: the game's own dialogue box (ui/dialogue_overlay.tscn) over the Story Lab plays a
## conversation as the game plays it, from its start or from one of its lines: the lines one after
## another, then the choices under the box, a pick's reply, and on to the end. Leaving lines that
## end it show in the box last. It walks on sandbox flags ([ConversationWalk.Sandbox]), so the paused
## game stays as it was. Looks don't turn anything. Esc or Shift+Enter closes it at any point; once
## the conversation is over it closes after [member end_seconds], or at a click or Enter. It takes
## every key while it shows, so the text behind it doesn't change.

## The box closed.
signal closed

const OVERLAY: String = "res://ui/dialogue_overlay.tscn"
## The game's theme: the box looks as it does in the game, not in the Lab's theme.
const GAME_THEME: String = "res://ui/theme.tres"
## How dark the shade behind the box is, so the Lab recedes; 0 for none.
const SHADE: float = 0.45

## Seconds that the last line stays once the conversation is over, before the box closes.
@export_range(0.0, 10.0, 0.1) var end_seconds: float = 2.0

var _overlay: DialogueOverlay
var _customer: Customer
var _walk: ConversationWalk
# The leaving lines that ended the conversation show in the box now.
var _calling_out: bool = false
var _over: bool = false
var _end: Timer
# The control that had the keyboard focus before the box opened; it gets it back.
var _focus: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = load(GAME_THEME) as Theme
	if theme == null:
		push_error("Story Lab: %s doesn't load; Play in editor uses the Lab's theme" % GAME_THEME)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, SHADE)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_end = Timer.new()
	_end.one_shot = true
	_end.timeout.connect(close)
	add_child(_end)
	var scene := load(OVERLAY) as PackedScene
	if scene == null:
		push_error("Story Lab: %s doesn't load, so conversations can't play in the editor" % OVERLAY)
	else:
		_overlay = scene.instantiate() as DialogueOverlay
		_overlay.finished.connect(_on_finished)
		add_child(_overlay)
	hide()


## Plays [param conversation] of [param customer] in the dialogue box from its start, or from
## [param from], one of its lines, as [ConversationWalk] starts there. Conditions see day
## [param day] and a copy of [param flags]; the conversation and what plays set flags in that copy
## ([method walk]). A run that plays stops first. Returns "" or why it can't play, and then stays
## closed.
func play(customer: Customer, conversation: Conversation, from: DialogueLine, day: int, flags: Dictionary[StringName, int]) -> String:
	if _overlay == null:
		return "%s doesn't load" % OVERLAY
	if customer == null or customer.person == null:
		return "%s has no portraits to show" % (customer.spoken_name() if customer != null else "The errand has no customer, so it")
	if conversation == null:
		return "there is no conversation to play"
	if conversation.lines.is_empty() and conversation.choices.is_empty():
		return "the conversation has no lines yet"
	if from == conversation.pop_up:
		from = null  # the pop-up line comes before the box opens
	if from != null and not conversation.all_lines().has(from):
		return "the line '%s' is not in the conversation as it last parsed" % from.text
	close()
	_customer = customer
	_walk = ConversationWalk.new(conversation, from, ConversationWalk.Sandbox.new(day, flags.duplicate()))
	_calling_out = false
	_over = false
	_focus = get_viewport().gui_get_focus_owner()
	show()
	_overlay.start(customer, conversation, _walk)
	return ""


## The walk that plays, with its sandbox flags; null before the first [method play].
func walk() -> ConversationWalk:
	return _walk


## The line that the box shows; null while the box is closed or choices show.
func shown_line() -> DialogueLine:
	return _overlay.shown_line() if visible and _overlay != null else null


## True once the conversation is over and the box waits to close.
func is_over() -> bool:
	return visible and _over


## Closes the box and hushes its voice; nothing happens while it is closed.
func close() -> void:
	if not visible:
		return
	_end.stop()
	_overlay.hush()
	hide()
	_over = false
	if is_instance_valid(_focus) and _focus.is_inside_tree():
		_focus.grab_focus()
	_focus = null
	closed.emit()


func _on_finished(leaving: Array[DialogueLine]) -> void:
	if not visible or _over:
		return  # the shown overlay says finished again at each auto-advance
	if leaving.is_empty() or _calling_out:
		_over = true
		_end.start(maxf(end_seconds, 0.001))
		return
	_calling_out = true
	var called := Conversation.new()
	called.id = "story_lab/leaving"
	for line: DialogueLine in leaving:
		var said := line.duplicate() as DialogueLine
		said.leaving = false
		called.lines.append(said)
	var rise := _overlay.rise_seconds
	_overlay.rise_seconds = 0.0  # the customer is still there
	_overlay.start(_customer, called, ConversationWalk.new(called, null, _walk.sandbox))
	_overlay.rise_seconds = rise


# A click outside the box or Enter: on with the line, or closed once the conversation is over.
func _go_on() -> void:
	if _over:
		close()
	else:
		_overlay.click()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_go_on()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key := event as InputEventKey
	if key != null:
		var shift_enter := key.shift_pressed and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER)
		if key.pressed and not key.echo:
			if key.keycode == KEY_ESCAPE or shift_enter:
				close()
			elif key.is_action_pressed(&"ui_accept"):
				_go_on()
		get_viewport().set_input_as_handled()
	elif _over and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
		get_viewport().set_input_as_handled()
