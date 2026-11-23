class_name CustomerCalling
extends PanelContainer
## A waiting customer calls out while the player looks elsewhere, until stop(): one line at a
## time, spoken in the customer's voice. The lines are grouped by mood, calmest first, in the order
## each mood first appears; the customer says [member lines_per_mood] random lines of a group
## (never the one just said) before the next, so they get more annoyed, and once at the end they
## stay annoyed, going round from group [member loop_from_mood] on. A customer who goes calls out
## their leaving lines instead, each once. While a look of the conversation has turned the player
## away, the box says the conversation's line instead ([method say]).

## The line that [method say] shows has been read: its voice ended and [member read_seconds] passed,
## or the player clicked the box or pressed accept. Fires once per line.
signal line_read(line: DialogueLine)

## What every customer says while waiting.
@export var lines: Conversation = preload("res://customers/conversations/waiting.tres")
## How many lines the customer says in one mood before the next.
@export var lines_per_mood: int = 2
## The mood group (0 is the calmest) that the customer goes back to after the angriest.
@export var loop_from_mood: int = 3
## The wait before the first line, in seconds.
@export var first_delay: float = 2.0
## The silence between one line and the next, in seconds.
@export var gap: float = 3.0
## The silence between one leaving line and the next, in seconds.
@export var leaving_gap: float = 0.4
## The shortest time a line stays on screen, in seconds; a longer voice keeps it up longer.
@export var show_seconds: float = 2.5
## The seconds of quiet after the voice of a conversation's line ([method say]) before it counts as
## read, so that the player can finish reading it.
@export var read_seconds: float = 1.5
## The gap between the box and the edge of the screen, in pixels.
@export var margin: float = 48.0
## The size of the arrow that points at the customer, in pixels.
@export var arrow_size: float = 20.0

var _customer: Customer
var _conversation: Conversation
## The lines grouped by mood, calmest first.
var _moods: Array[Array] = []
var _step: int = 0
var _last: DialogueLine
var _calling: bool = false
# The leaving lines to call out, each once; empty while waiting.
var _leaving: Array[DialogueLine] = []
# The conversation's line that [method say] shows; null while waiting or leaving.
var _said: DialogueLine
# Seconds that _said has shown, and that its voice has been over; its voice's length, 0 if unknown.
var _shown: float = 0.0
var _quiet: float = 0.0
var _voice_seconds: float = 0.0
## The side of the box that the arrow sticks out of: a unit vector, or zero for no arrow.
var _side: Vector2 = Vector2.ZERO

@onready var _name: Label = %Name
@onready var _label: Label = %Line
@onready var _voice: VoicePlayer = %Voice
@onready var _timer: Timer = %Timer


func _ready() -> void:
	_timer.timeout.connect(_on_timer)
	gui_input.connect(_on_click)
	stop()


func _process(delta: float) -> void:
	if _said == null:
		return
	_shown += delta
	# The length also ends it where no audio plays out, as in a headless run.
	var over := _voice.quiet() or (_voice_seconds > 0.0 and _shown >= _voice_seconds)
	_quiet = _quiet + delta if over else 0.0
	if _shown >= show_seconds and _quiet >= read_seconds:
		_read()


func _unhandled_input(event: InputEvent) -> void:
	if _said != null and event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_read()


func _on_click(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if _said != null and button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_read()


## Starts calling as [param customer], from the first line. Calling again for the same customer
## carries on where it was.
func call_out(customer: Customer) -> void:
	if customer == null:
		push_error("CustomerCalling.call_out: no customer")
		return
	if _calling and customer == _customer and _leaving.is_empty() and _said == null:
		return
	if _said != null:
		stop()
	_leaving = []
	var conversation := lines
	_conversation = conversation
	if conversation == null or conversation.lines.is_empty():
		push_error("CustomerCalling: no waiting lines are set (lines: %s), so %s can't call out" % [conversation, customer.resource_path])
		return
	_customer = customer
	_moods = _by_mood(conversation.lines)
	_step = 0
	_last = null
	_calling = true
	_timer.start(first_delay)


## [param customer] calls out [param leaving] as they go, at once, each line once and in order,
## then hides. Calling again with the same lines carries on, or stays quiet once they are said.
func call_out_leaving(customer: Customer, leaving: Array[DialogueLine]) -> void:
	if customer == null or leaving.is_empty():
		push_error("CustomerCalling.call_out_leaving: no customer (%s) or no lines (%d)" % [customer, leaving.size()])
		return
	if customer == _customer and leaving == _leaving:
		return
	_customer = customer
	_conversation = null
	_end_line()
	_leaving = leaving.duplicate()
	_step = 0
	_calling = true
	hide()
	_on_timer()


## Says [param line] of [param conversation] as [param customer] at once, and shows it until the
## next call: the visitor's line while a look of the conversation has turned the player away from
## them. [signal line_read] fires once the player has had the time to read it, or clicks it. Saying
## the line that shows again carries on.
func say(customer: Customer, line: DialogueLine, conversation: Conversation) -> void:
	if customer == null or line == null:
		push_error("CustomerCalling.say: no customer (%s) or no line (%s)" % [customer, line])
		return
	if line == _said and customer == _customer:
		return
	stop()
	_customer = customer
	_conversation = conversation
	_said = line
	_shown = 0.0
	_quiet = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_name.text = customer.spoken_name()
	_label.text = line.text
	show()
	_voice_seconds = _voice.say(line, customer.voice, VoiceEffect.of(line, conversation))


## The conversation's line that [method say] shows and that the player hasn't read yet; null
## otherwise.
func unread_line() -> DialogueLine:
	return _said


## Stops calling, the voice too, and hides the line.
func stop() -> void:
	_calling = false
	_leaving = []
	_end_line()
	_timer.stop()
	_voice.hush()
	hide()


func _read() -> void:
	var line := _said
	_end_line()
	line_read.emit(line)


# Forgets the conversation's line: it no longer takes clicks or counts as unread.
func _end_line() -> void:
	_said = null
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Moves the box to the edge of the screen toward the customer, with its arrow pointing at them.
## [param direction] is Shop.customer_direction(); zero puts the box at the top, without an arrow.
## The box moves in from the edge past each of [param avoid], with its arrow clear of them too.
func point_to(direction: Vector2, avoid: Array[Rect2] = []) -> void:
	var screen := get_viewport_rect().size
	var side := Vector2.ZERO
	if direction != Vector2.ZERO:
		side = Vector2(signf(direction.x), 0.0) if absf(direction.x) >= absf(direction.y) else Vector2(0.0, -signf(direction.y))
	var free := screen - size - Vector2.ONE * (margin + arrow_size) * 2.0
	var at := (screen - size) * 0.5
	if side.x != 0.0:
		at.x = margin if side.x < 0.0 else screen.x - size.x - margin
		at.y = (screen.y - size.y) * 0.5 + clampf(-direction.y, -1.0, 1.0) * free.y * 0.5
	else:
		at.y = margin + 48.0 if side.y <= 0.0 else screen.y - size.y - margin
		at.x = (screen.x - size.x) * 0.5 + clampf(direction.x, -1.0, 1.0) * free.x * 0.5
	var reach := arrow_size + margin * 0.5
	for rect: Rect2 in avoid:
		if not Rect2(at, size).grow(reach).intersects(rect):
			continue
		if side.x > 0.0:
			at.x = minf(at.x, rect.position.x - reach - size.x)
		elif side.x < 0.0:
			at.x = maxf(at.x, rect.end.x + reach)
		elif side.y > 0.0:
			at.y = minf(at.y, rect.position.y - reach - size.y)
		else:
			at.y = maxf(at.y, rect.end.y + reach)
	position = at.round()
	if side != _side:
		_side = side
		queue_redraw()


func _draw() -> void:
	if _side == Vector2.ZERO:
		return
	var box := get_theme_stylebox(&"panel") as StyleBoxFlat
	var across := Vector2(-_side.y, _side.x)
	var center := size * 0.5 + _side * size * 0.5
	var border := box.border_width_left
	_triangle(center, across, arrow_size + border * 1.5, box.border_color)
	_triangle(center - _side * border, across, arrow_size, box.bg_color)


func _triangle(base: Vector2, across: Vector2, length: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([base + across * length, base + _side * length, base - across * length]), color)


func _on_timer() -> void:
	if not _calling:
		return
	if visible:
		hide()
		if not _leaving.is_empty() and _step >= _leaving.size():
			_calling = false
			return
		_timer.start(leaving_gap if not _leaving.is_empty() else gap)
		return
	var line := _leaving[_step] if not _leaving.is_empty() else _waiting_line()
	_step += 1
	_last = line
	_name.text = _customer.spoken_name()
	_label.text = line.text
	show()
	_timer.start(maxf(show_seconds, _voice.say(line, _customer.voice, VoiceEffect.of(line, _conversation))))


func _waiting_line() -> DialogueLine:
	var mood: Array = _moods[_mood_of(_step)]
	var choices: Array = mood.filter(func(l: DialogueLine) -> bool: return l != _last)
	if choices.is_empty():
		choices = mood
	return choices.pick_random()


# The mood group of the line at [param step]: up through the groups, then round the angriest ones.
func _mood_of(step: int) -> int:
	var count := _moods.size()
	var mood := step / maxi(1, lines_per_mood)
	if mood < count:
		return mood
	var from := clampi(loop_from_mood, 0, count - 1)
	return from + (mood - count) % (count - from)


static func _by_mood(lines: Array[DialogueLine]) -> Array[Array]:
	var order: Array[StringName] = []
	var groups := {}
	for line in lines:
		if line == null or line.text.strip_edges().is_empty():
			continue
		if not groups.has(line.mood):
			order.append(line.mood)
			groups[line.mood] = []
		groups[line.mood].append(line)
	var moods: Array[Array] = []
	for mood: StringName in order:
		moods.append(groups[mood])
	return moods
