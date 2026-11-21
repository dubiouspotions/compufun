class_name CustomerCalling
extends PanelContainer
## A waiting customer calls out while the player looks elsewhere: one line at a time, spoken in
## the customer's voice, getting more annoyed, then from the top again, until stop().

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
var _lines: Array[DialogueLine] = []
var _next_line: int = 0
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
	if conversation == null or conversation.lines.is_empty():
		push_error("CustomerCalling: %s has no \"%s\" lines and no default is set" % [customer.resource_path, CONVERSATION])
		return
	_customer = customer
	_lines = conversation.lines
	_next_line = 0
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
	var line := _lines[_next_line % _lines.size()]
	_next_line += 1
	_label.text = "%s: %s" % [_customer.display_name, line.text]
	show()
	_timer.start(maxf(show_seconds, _voice.say(line, _customer.voice)))
