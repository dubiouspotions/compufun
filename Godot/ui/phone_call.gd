class_name PhoneCall
extends PanelContainer
## The phone, as a whitebox: pick the customer of a fixed computer, call to say it is ready, and
## hang up; then the customer comes for it. Opens when the player picks up the phone
## (Shop.phone_requested); Esc puts it down before a call.

## What the player says on the call; %s is the customer's name.
@export_multiline var you_say: String = "Hello %s, this is CompuFun! Your computer is fixed. You can come and pick it up."
## What the customer answers.
@export_multiline var they_say: String = "Oh, great! I'll come right away."

var _was_calling := false

@onready var _title: Label = %Title
@onready var _choices: VBoxContainer = %Choices
@onready var _talk: VBoxContainer = %Talk
@onready var _note: Label = %Note
@onready var _action: Button = %Action


func _ready() -> void:
	hide()
	Game.changed.connect(_sync)
	_action.pressed.connect(_on_action)


## Shows the phone: the call that is on, or the customers to call.
func open() -> void:
	show()
	_sync()


func _unhandled_input(event: InputEvent) -> void:
	if visible and Game.phase != Game.Phase.CALLING and event.is_action_pressed(&"ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


func _sync() -> void:
	var calling := Game.phase == Game.Phase.CALLING and Game.calling != null
	if _was_calling and not calling:
		hide()  # the call ended, also by the debug skip
	_was_calling = calling
	if not visible:
		return
	for old in _choices.get_children():
		old.queue_free()
	_choices.visible = not calling
	_talk.visible = calling
	if calling:
		var who := Game.calling.customer.display_name
		_title.text = "Calling %s" % who
		(%YouSay as Label).text = "You: " + (you_say % who if you_say.contains("%s") else you_say)
		(%TheySay as Label).text = "%s: %s" % [who, they_say]
		_note.hide()
		_action.text = "Hang up"
		return
	_title.text = "Call a customer"
	_action.text = "Put down"
	var jobs := Game.jobs.duplicate()
	jobs.sort_custom(func(a: Job, b: Job) -> bool: return a.order < b.order)
	for job: Job in jobs:
		var button := Button.new()
		button.text = "%s: %s%s" % [job.customer.display_name, job.problem.perceived_issue, "" if job.fixed else " (not fixed yet)"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not (job.fixed and Game.can_call())
		button.pressed.connect(Game.call_customer.bind(job))
		_choices.add_child(button)
	if Game.visitor != null:
		_note.text = "Someone is in the shop. Call when they have left."
	elif Game.phase != Game.Phase.OPEN:
		_note.text = "The shop is closed."
	elif jobs.is_empty():
		_note.text = "No computers on the counter."
	elif not jobs.any(func(j: Job) -> bool: return j.fixed):
		_note.text = "No computer is fixed yet."
	else:
		_note.text = ""
	_note.visible = _note.text != ""


func _on_action() -> void:
	if Game.phase == Game.Phase.CALLING:
		Game.hang_up()
	hide()
