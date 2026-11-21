class_name DialogueOverlay
extends Control
## The customer talks at the counter: a portrait placeholder, one line at a time, then the replies.

## The player chose a reply after the last line.
signal finished

var _customer: Customer
var _line: int = 0

@onready var _name: Label = %NameLabel
@onready var _text: Label = %LineLabel
@onready var _portrait: Label = %PortraitLabel
@onready var _next: Button = %NextButton
@onready var _replies: HBoxContainer = %Replies


func _ready() -> void:
	_next.pressed.connect(_on_next)


## Starts the dialogue of [param customer] at the first line.
func start(customer: Customer) -> void:
	if customer == null:
		push_error("DialogueOverlay.start: no customer")
		return
	_customer = customer
	_line = 0
	_name.text = customer.display_name
	var person_name := customer.person.display_name if customer.person != null else "no person"
	_portrait.text = "PORTRAIT\n%s" % person_name
	_show_line()


func _show_line() -> void:
	for child: Node in _replies.get_children():
		child.queue_free()
	var lines := _customer.lines
	_text.text = lines[_line] if _line < lines.size() else ""
	var last := _line >= lines.size() - 1
	_next.visible = not last or _customer.replies.is_empty()
	_next.text = "Next" if not last else "OK"
	if last:
		for reply: String in _customer.replies:
			var button := Button.new()
			button.text = reply
			button.pressed.connect(finished.emit)
			_replies.add_child(button)


func _on_next() -> void:
	if _line >= _customer.lines.size() - 1:
		finished.emit()
		return
	_line += 1
	_show_line()
