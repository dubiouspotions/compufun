class_name Saver
extends "res://win95/cover_screen.gd"
## The base of every screensaver in win95/savers/: a cover screen that also ends when the mouse
## moves more than [member jitter] pixels. While a Saver is a child of the Win95 screen, Win95 hides
## its mouse pointer (win95.gd, pointer_visible).

## How far the mouse may drift from where it first moved, in screen pixels, before the saver ends.
@export var jitter: float = 4.0

var _moved_from: Variant = null


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if dismissable and motion != null:
		if _moved_from == null:
			_moved_from = motion.position - motion.relative
		if motion.position.distance_to(_moved_from) > jitter:
			accept_event()
			queue_free()
		return
	super(event)
