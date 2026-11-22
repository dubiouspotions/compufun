class_name PhoneCall
extends Control
## The phone: the dialogue box with a red rotary phone in it. A click on the phone
## (Shop.phone_requested) calls the customer of the oldest done (fixed and tested) computer: the
## phone rings, the customer answers (their PHONE conversation, or [member greeting]), the player
## says [member you_say], and hangs up; then the customer comes for it. With no computer done, the
## click picks up the phone instead, which lists the computers and says why nobody can be called;
## Esc or "Put down" puts it down. Game refuses both while the shop is closed or someone is in it.

## The heading over the customers to call.
@export var pick_title: String = "Call a customer"
## What shows while the phone rings.
@export var ringing_text: String = "Ring... ring..."
## What a customer without a PHONE conversation says when they answer. Customers never say their
## nickname: the player gave it to them.
@export var greeting: String = "Hello?"
## What the player says once the customer has spoken.
@export var you_say: String = "Your computer is ready now!"
## How long the call takes before the customer answers, in seconds: the dialling, one ring and the
## far end's click in sounds/phone_receiver.wav, which ends 0.395 s after that click. The sound
## starts a few frames after this timer, so the customer answers about 0.15 s after the click.
@export_range(0.0, 10.0) var ring_seconds: float = 3.13
## How far the phone rattles to each side while it rings, in degrees.
@export_range(0.0, 20.0) var ring_degrees: float = 5.0
## How many times a second it rattles.
@export_range(1.0, 40.0) var ring_shakes: float = 18.0
## One customer to call: a Button with Name, Number and Issue labels (unique names).
@export var choice_scene: PackedScene

var _was_calling := false
var _call_time: float = 0.0
var _lines: Array[DialogueLine] = []
# Which line shows: -1 while it rings, then the customer's lines, then the player's (== size).
var _line: int = -1

@onready var _name: Label = %Name
@onready var _text: TypedLabel = %Line
@onready var _choices: VBoxContainer = %Choices
@onready var _next: Button = %Next
@onready var _phone: Control = %Phone
@onready var _voice: VoicePlayer = %Voice


func _ready() -> void:
	hide()
	Game.changed.connect(_sync)
	_next.pressed.connect(_on_next)


## Calls the customer of [method Game.next_to_call] at once when [method Game.can_call]. Otherwise
## picks up the phone to show the computers and why nobody can be called, unless someone is in the
## shop: then nothing happens.
func open() -> void:
	if Game.can_call():
		Game.call_customer(Game.next_to_call())
	else:
		Game.pick_up_phone()


## A made-up phone number for [param customer], the same on every call.
static func number_of(customer: Customer) -> String:
	return "555-%04d" % (customer.resource_path.get_file().hash() % 10000)


func _process(delta: float) -> void:
	if not visible or not _was_calling or _line >= 0:
		_phone.rotation = 0.0
		return
	_call_time += delta
	_phone.rotation = deg_to_rad(ring_degrees * sin(TAU * _call_time * ring_shakes))
	if _call_time >= ring_seconds:
		_line = 0
		_show_line()


func _unhandled_input(event: InputEvent) -> void:
	if visible and Game.phase != Game.Phase.CALLING and event.is_action_pressed(&"ui_cancel"):
		_put_down()
		get_viewport().set_input_as_handled()


func _sync() -> void:
	var calling := Game.phase == Game.Phase.CALLING and Game.calling != null
	var started := calling and not _was_calling
	_was_calling = calling
	visible = Game.phone_off_hook
	if not visible:
		_voice.hush()
		return
	if started:
		_ring()
	elif not calling:
		_show_customers()


## The phone starts to ring for the called customer, whose lines are ready for when they answer.
func _ring() -> void:
	var customer := Game.calling.customer
	if Game.conversation != null and not Game.conversation.lines.is_empty():
		_lines = Game.conversation.lines
	else:
		var hello := DialogueLine.new()
		hello.text = greeting
		_lines = [hello]
	_call_time = 0.0
	_line = -1
	_clear_choices()
	_name.text = number_of(customer)
	_text.type_out(ringing_text)
	_next.get_parent().hide()


func _show_line() -> void:
	_next.get_parent().show()
	var customer := Game.calling.customer
	if _line < _lines.size():
		var line := _lines[_line]
		_name.text = customer.display_name
		_text.type_out(line.text)
		_voice.say(line, customer.voice, VoiceEffect.of(line, Game.conversation))
		_next.text = "Next >"
	else:
		_name.text = "You"
		_text.type_out(you_say)
		_voice.hush()
		_next.text = "Hang up"


func _show_customers() -> void:
	_clear_choices()
	_name.text = pick_title
	_next.get_parent().show()
	_next.text = "Put down"
	var jobs := Game.jobs.duplicate()
	jobs.sort_custom(func(a: Job, b: Job) -> bool: return a.order < b.order)
	for job: Job in jobs:
		var button := choice_scene.instantiate() as Button
		if button == null:
			push_error("PhoneCall: choice_scene %s is not a Button" % choice_scene)
			return
		var issue := job.problem.perceived_issue + ("" if job.done else " (not tested yet)" if job.fixed else " (not fixed yet)")
		for part: Array in [["%Name", job.customer.display_name], ["%Number", number_of(job.customer)], ["%Issue", issue]]:
			(button.get_node(part[0]) as Label).text = part[1]
		button.disabled = not (job.done and Game.can_call())
		button.pressed.connect(Game.call_customer.bind(job))
		_choices.add_child(button)
	var note := ""
	if Game.visitor != null:
		note = "Someone is in the shop. Call when they have left."
	elif Game.phase != Game.Phase.OPEN:
		note = "The shop is closed."
	elif jobs.is_empty():
		note = "No computers on the counter."
	elif not jobs.any(func(j: Job) -> bool: return j.done):
		note = "No computer is fixed and tested yet."
	_text.visible = note != ""
	_text.type_out(note)


func _clear_choices() -> void:
	_text.show()
	for old in _choices.get_children():
		old.queue_free()


func _on_next() -> void:
	if _text.is_typing():  # a click while the line types shows the rest
		_text.finish()
		return
	if not _was_calling:
		_put_down()
	elif _line < _lines.size():
		_line += 1
		_show_line()
	else:
		Game.hang_up()  # its changed signal puts the phone down


func _put_down() -> void:
	_voice.hush()
	Game.put_down_phone()
