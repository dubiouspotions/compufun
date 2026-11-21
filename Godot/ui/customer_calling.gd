class_name CustomerCalling
extends PanelContainer
## A waiting customer calls out while the player looks elsewhere, until stop(): one line at a
## time, spoken in the customer's voice. The lines are grouped by pose, in the order each pose
## first appears; each call says a random line of the next group (never the one just said), so the
## customer gets more annoyed, then starts over.

## The id of the conversation a customer can have for this; without it they use [member lines].
const CONVERSATION: StringName = &"waiting"

## What a customer says while waiting, unless they have their own [constant CONVERSATION].
@export var lines: Conversation = preload("res://customers/conversations/waiting.tres")
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
	var choices: Array = _moods[_step % _moods.size()].filter(func(l: DialogueLine) -> bool: return l != _last)
	if choices.is_empty():
		choices = _moods[_step % _moods.size()]
	var line: DialogueLine = choices.pick_random()
	_step += 1
	_last = line
	_label.text = "%s: %s" % [_customer.spoken_name(), line.text]
	show()
	_timer.start(maxf(show_seconds, _voice.say(line, _customer.voice, VoiceType.of(line, _conversation))))


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
