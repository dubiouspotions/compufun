class_name CustomerCalling
extends PanelContainer
## A waiting customer calls out while the player looks elsewhere, until stop(): one line at a
## time, spoken in the customer's voice. The lines are grouped by mood, calmest first, in the order
## each mood first appears; the customer says [member lines_per_mood] random lines of a group
## (never the one just said) before the next, so they get more annoyed, and once at the end they
## stay annoyed, going round from group [member loop_from_mood] on.

## The id of the conversation a customer can have for this; without it they use [member lines].
const CONVERSATION: StringName = &"waiting"

## What a customer says while waiting, unless they have their own [constant CONVERSATION].
@export var lines: Conversation = preload("res://customers/conversations/waiting.tres")
## How many lines the customer says in one mood before the next.
@export var lines_per_mood: int = 2
## The mood group (0 is the calmest) that the customer goes back to after the angriest.
@export var loop_from_mood: int = 3
## The wait before the first line, in seconds.
@export var first_delay: float = 2.0
## The silence between one line and the next, in seconds.
@export var gap: float = 3.0
## The shortest time a line stays on screen, in seconds; a longer voice keeps it up longer.
@export var show_seconds: float = 2.5
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
## The side of the box that the arrow sticks out of: a unit vector, or zero for no arrow.
var _side: Vector2 = Vector2.ZERO

@onready var _name: Label = %Name
@onready var _label: Label = %Line
@onready var _voice: VoicePlayer = %Voice
@onready var _timer: Timer = %Timer


func _ready() -> void:
	_timer.timeout.connect(_on_timer)
	stop()


## Starts calling as [param customer], from the first line. Calling again for the same customer
## carries on where it was.
func call_out(customer: Customer) -> void:
	if customer == null:
		push_error("CustomerCalling.call_out: no customer")
		return
	if _calling and customer == _customer:
		return
	var own := customer.conversation(CONVERSATION)
	var conversation := own if own != null else lines
	_conversation = conversation
	if conversation == null or conversation.lines.is_empty():
		push_error("CustomerCalling: %s has no \"%s\" lines and no default is set" % [customer.resource_path, CONVERSATION])
		return
	_customer = customer
	_moods = _by_mood(conversation.lines)
	_step = 0
	_last = null
	_calling = true
	_timer.start(first_delay)


## Stops calling, the voice too, and hides the line.
func stop() -> void:
	_calling = false
	_timer.stop()
	_voice.hush()
	hide()


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
		_timer.start(gap)
		return
	var mood: Array = _moods[_mood_of(_step)]
	var choices: Array = mood.filter(func(l: DialogueLine) -> bool: return l != _last)
	if choices.is_empty():
		choices = mood
	var line: DialogueLine = choices.pick_random()
	_step += 1
	_last = line
	_name.text = _customer.spoken_name()
	_label.text = line.text
	show()
	_timer.start(maxf(show_seconds, _voice.say(line, _customer.voice, VoiceEffect.of(line, _conversation))))


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
