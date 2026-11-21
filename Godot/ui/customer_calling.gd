class_name CustomerCalling
extends PanelContainer
## A waiting customer calls out while the player looks elsewhere: one line at a time, in turn,
## until stop().

## What the customer says, in this order, then from the top again.
@export var lines: PackedStringArray = ["Hello...", "Are you there?", "Hello?", "Excuse me..."]
## The wait before the first line, in seconds.
@export var first_delay: float = 2.0
## The time from one line to the next, in seconds.
@export var interval: float = 5.0
## How long each line stays on screen, in seconds.
@export var show_seconds: float = 3.0

var _customer: Customer
var _next_line: int = 0
var _clock: float = 0.0

@onready var _label: Label = %Line


func _ready() -> void:
	stop()


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= 0.0 and not lines.is_empty():
		_label.text = "%s: %s" % [_customer.display_name, lines[_next_line % lines.size()]]
		_next_line += 1
		_clock = -interval
		show()
	elif visible and _clock >= show_seconds - interval:
		hide()


## Starts calling as [param customer], from the first line. Calling again for the same customer
## carries on where it was.
func call_out(customer: Customer) -> void:
	if customer == null:
		push_error("CustomerCalling.call_out: no customer")
		return
	if is_processing() and customer == _customer:
		return
	_customer = customer
	_next_line = 0
	_clock = -first_delay
	set_process(true)


## Stops calling and hides the line.
func stop() -> void:
	set_process(false)
	hide()
