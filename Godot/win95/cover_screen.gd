extends Control
## A screen that covers all of Win95: shut-down screens and crashes. Any key or click removes it
## when dismissable is on.

@export var dismissable: bool = true


func _gui_input(event: InputEvent) -> void:
	if dismissable and (event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		accept_event()
		queue_free()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	grab_focus.call_deferred()
