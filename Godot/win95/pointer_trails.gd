class_name PointerTrails
extends Control
## Win95's pointer trails: ghost arrows at the pointer's last positions, as many as
## [member computer]'s pointer_trails. The pointer leaves one behind every [member sample_seconds];
## while it rests, the ghosts catch up with it and vanish. The real pointer stays the CRT
## shader's, so this draws only the ghosts, on top of the rest of the screen buffer.

## The computer whose pointer_trails sets the length; while it is off, nothing draws.
@export var computer: ComputerState
## The Win95 screen; its pointer_visible hides the trail.
@export var screen: Control
## The ghost; the same picture and hotspot as CrtScreen's arrow cursor.
@export var arrow: Texture2D = preload("res://win95/theme/arrow_cursor.png")
@export var arrow_hotspot := Vector2.ZERO
## Seconds between ghosts.
@export var sample_seconds := 0.03

## The pointer's last positions in viewport pixels, oldest first.
var trail := PackedVector2Array()
var _since := 0.0


func _process(delta: float) -> void:
	var length := _length()
	if length == 0:
		if not trail.is_empty():
			trail.clear()
			queue_redraw()
		return
	_since += delta
	if _since < sample_seconds:
		return
	_since = fmod(_since, sample_seconds)
	sample(get_viewport().get_mouse_position(), length + 1)  # the newest is under the pointer


## Records the pointer at [param at] and keeps the newest [param length] positions. Every position
## but the pointer's own draws a ghost.
func sample(at: Vector2, length: int) -> void:
	trail.append(at)
	if trail.size() > length:
		trail = trail.slice(trail.size() - length)
	queue_redraw()


## Where the ghosts are now, in viewport pixels: every recorded position but the pointer's own.
func ghosts() -> PackedVector2Array:
	var pointer := get_viewport().get_mouse_position()
	var found := PackedVector2Array()
	for at in trail:
		if at != pointer:
			found.append(at)
	return found


func _draw() -> void:
	for at in ghosts():
		draw_texture(arrow, (at - arrow_hotspot).floor())


func _length() -> int:
	if computer == null or not computer.is_on or computer.setup == null or screen == null or not screen.get(&"pointer_visible"):
		return 0
	return computer.setup.pointer_trails
