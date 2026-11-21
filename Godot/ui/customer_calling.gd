class_name CustomerCalling
extends PanelContainer
## A waiting customer calls out while the player looks elsewhere, until stop(): one line at a
## time, spoken in the customer's voice. The lines are grouped by pose, calmest first, in the order
## each pose first appears; the customer says [member lines_per_mood] random lines of a group
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

var _customer: Customer
var _conversation: Conversation
## The lines grouped by pose, calmest first.
var _moods: Array[Array] = []
var _step: int = 0
var _last: DialogueLine
var _calling: bool = false

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
	_moods = _by_pose(conversation.lines)
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
	_label.text = "%s: %s" % [_customer.spoken_name(), line.text]
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


static func _by_pose(lines: Array[DialogueLine]) -> Array[Array]:
	var order: Array[StringName] = []
	var groups := {}
	for line in lines:
		if line == null or line.text.strip_edges().is_empty():
			continue
		if not groups.has(line.pose):
			order.append(line.pose)
			groups[line.pose] = []
		groups[line.pose].append(line)
	var moods: Array[Array] = []
	for pose in order:
		moods.append(groups[pose])
	return moods
