class_name PhoneCall
extends Control
## The phone: the dialogue box with a red rotary phone in it. A click on the phone
## (Shop.phone_requested) calls the customer of the oldest done (fixed and tested) computer: the
## phone rings, the customer answers (their PHONE conversation, or [member greeting]), the player
## says [member you_say], and hangs up; then the customer comes for it. A PHONE conversation without
## lines rings out: [member no_answer] shows, and the call ends. Each line goes on by itself
## [member auto_advance_seconds] after it ends, or at a click anywhere (or Enter), as in the dialogue. The shop's
## phone takes clicks only while a computer is done. Off the hook without a call (Game.pick_up_phone), it lists
## the computers; Esc or "Put down" puts it down. Game refuses both while the shop is closed or someone is in it.

## The heading over the customers to call.
@export var pick_title: String = "Call a customer"
## What shows while the phone rings.
@export var ringing_text: String = "Ring... ring..."
## What a customer without a PHONE conversation says when they answer. Customers never say their
## nickname: the player gave it to them.
@export var greeting: String = "Hello?"
## What the player says once the customer has spoken.
@export var you_say: String = "Your computer is ready now!"
## What shows when nobody answers (Game.rings_out); then the call ends, and nobody comes.
@export var no_answer: String = "Nobody answers."
## How long the call takes before the customer answers, in seconds: the dialling, one ring and the
## far end's click in sounds/phone_receiver.wav, which ends 0.395 s after that click. The sound
## starts a few frames after this timer, so the customer answers about 0.15 s after the click.
@export_range(0.0, 10.0) var ring_seconds: float = 3.13
## How far the phone rattles to each side while it rings, in degrees.
@export_range(0.0, 20.0) var ring_degrees: float = 5.0
## How many times a second it rattles.
@export_range(1.0, 40.0) var ring_shakes: float = 18.0
## Seconds of quiet, once a line is typed out and its voice has ended, before the call goes on by
## itself; 0 waits for a click.
@export_range(0.0, 10.0, 0.1) var auto_advance_seconds: float = 1.5
## One customer to call: a Button with Name, Number, Issue and Status labels (unique names).
@export var choice_scene: PackedScene

var _was_calling := false
var _call_time: float = 0.0
var _lines: Array[DialogueLine] = []
# Which line shows: -1 while it rings, then the customer's lines, then the player's (== size).
var _line: int = -1
# Seconds since the shown line was typed out and its voice went quiet.
var _quiet: float = 0.0

@onready var _name: Label = %Name
@onready var _text: TypedLabel = %Line
@onready var _choices: VBoxContainer = %Choices
@onready var _next: Button = %Next
@onready var _phone: Control = %Phone
@onready var _voice: VoicePlayer = %Voice


func _ready() -> void:
	hide()
	Game.changed.connect(_sync)
	_next.pressed.connect(_put_down)
	($Box as Control).gui_input.connect(_on_click)


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
	if not visible or not _was_calling:
		_phone.rotation = 0.0
		return
	if _line >= 0:
		_phone.rotation = 0.0
		_quiet = _quiet + delta if not _text.is_typing() and _voice.quiet() else 0.0
		if auto_advance_seconds > 0.0 and _quiet >= auto_advance_seconds:
			_advance()
		return
	_call_time += delta
	_phone.rotation = deg_to_rad(ring_degrees * sin(TAU * _call_time * ring_shakes))
	if _call_time >= ring_seconds:
		_line = 0
		_show_line()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _was_calling and event.is_action_pressed(&"ui_cancel"):
		_put_down()
		get_viewport().set_input_as_handled()
	else:
		_on_click(event)


# A click, or the accept key, during the call: on with the line. Clicks while it rings do nothing.
func _on_click(event: InputEvent) -> void:
	if not visible or not _was_calling:
		return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		if _line >= 0:
			_advance()


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
	if Game.rings_out():
		_lines = []
	elif Game.conversation != null and not Game.conversation.lines.is_empty():
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
	_next.get_parent().hide()  # the call goes on by itself or at a click


func _show_line() -> void:
	_quiet = 0.0
	var customer := Game.calling.customer
	if _line < _lines.size():
		var line := _lines[_line]
		_name.text = customer.display_name
		_text.type_out(line.text)
		_voice.say(line, customer.voice, VoiceEffect.of(line, Game.conversation))
	elif Game.rings_out():
		_name.text = number_of(customer)
		_text.type_out(no_answer)
		_voice.hush()
	else:
		_name.text = "You"
		_text.type_out(you_say)
		_voice.hush()


func _show_customers() -> void:
	_clear_choices()
	_name.text = pick_title
	_text.hide()
	_next.get_parent().show()
	var jobs := Game.jobs.duplicate()
	jobs.sort_custom(func(a: Job, b: Job) -> bool: return a.order < b.order)
	var rows: Array[Button] = []
	for job: Job in jobs:
		var button := choice_scene.instantiate() as Button
		if button == null:
			push_error("PhoneCall: choice_scene %s is not a Button" % choice_scene)
			return
		var status := "" if job.done else "untested" if job.fixed else "unfixed"
		for part: Array in [["%Name", job.customer.display_name], ["%Number", number_of(job.customer)], ["%Issue", job.perceived_issue()], ["%Status", status]]:
			(button.get_node(part[0]) as Label).text = part[1]
		button.disabled = not (job.done and Game.can_call())
		button.pressed.connect(Game.call_customer.bind(job))
		_choices.add_child(button)
		rows.append(button)
	for column: String in ["%Name", "%Number", "%Issue"]:
		var width := 0.0
		for row in rows:
			width = maxf(width, (row.get_node(column) as Label).get_minimum_size().x)
		for row in rows:
			(row.get_node(column) as Label).custom_minimum_size.x = width


func _clear_choices() -> void:
	_text.show()
	for old in _choices.get_children():
		old.queue_free()


func _advance() -> void:
	if _text.is_typing():  # a click while the line types shows the rest
		_text.finish()
		return
	if _line < _lines.size():
		_line += 1
		_show_line()
	else:
		Game.hang_up()  # its changed signal puts the phone down


func _put_down() -> void:
	_voice.hush()
	Game.put_down_phone()
