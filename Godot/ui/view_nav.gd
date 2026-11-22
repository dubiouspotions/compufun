class_name ViewNav
extends Control
## The turn buttons, the Back button and the status line (debug builds only). It shows a view marker
## and asks for view changes; it does not change the view itself. In the Workview, Left and Right
## move to the computer beside the one in focus.

## The player pressed a turn button or Back.
signal view_requested(view: StringName)
## The player pressed Left or Right in the Workview while a computer stands on that side of the one
## in focus.
signal focus_requested(job: Job)

## The seconds that the back strip takes to darken, and to clear again.
@export var back_strip_fade_seconds: float = 0.12
## The seconds that a button stays pressed down after a turn, so a quick click or a key shows it.
@export var press_seconds: float = 0.15

var _marker: ViewMarker
var _back_strip_fade: Tween
var _lifts: Dictionary[Button, Tween] = {}

@onready var _left: Button = %LeftButton
@onready var _right: Button = %RightButton
@onready var _back: Button = %BackButton
@onready var _status_label: Label = %StatusLabel
@onready var _back_strip: TextureRect = %BackStrip


func _ready() -> void:
	_status_label.visible = OS.is_debug_build()
	_left.pressed.connect(turn.bind(&"left"))
	_right.pressed.connect(turn.bind(&"right"))
	_back.pressed.connect(turn.bind(&"back"))


## Shows the buttons that [param marker] allows. null hides them.
func show_marker(marker: ViewMarker) -> void:
	_marker = marker
	_left.visible = marker != null and (marker.left != &"" or _beside(&"left") != null)
	_right.visible = marker != null and (marker.right != &"" or _beside(&"right") != null)
	_back.visible = marker != null and marker.back != &""
	_status_label.text = _status_text()


## Shows the button for [param direction] (&"left", &"right" or &"back") pressed down for
## [member press_seconds]: the player turned that way, with the button or with a key.
func press(direction: StringName) -> void:
	var button: Button = {&"left": _left, &"right": _right, &"back": _back}.get(direction)
	if button == null or not button.visible:
		return
	var down := button.get_theme_stylebox(&"pressed")
	button.add_theme_stylebox_override(&"normal", down)
	button.add_theme_stylebox_override(&"hover", down)
	if _lifts.has(button):
		_lifts[button].kill()
	_lifts[button] = create_tween()
	_lifts[button].tween_interval(press_seconds)
	_lifts[button].tween_callback(func() -> void:
		button.remove_theme_stylebox_override(&"normal")
		button.remove_theme_stylebox_override(&"hover"))


## True while [method press] holds the button for [param direction] down.
func is_pressed_down(direction: StringName) -> bool:
	var button: Button = {&"left": _left, &"right": _right, &"back": _back}.get(direction)
	return button != null and button.has_theme_stylebox_override(&"normal")


## Darkens the bottom [param height] of the screen (a share of its height) while [param on], to show
## that a click there goes back (see [member Shop.back_strip_height]).
func show_back_strip(on: bool, height: float) -> void:
	_back_strip.anchor_top = 1.0 - height
	if _back_strip_fade != null:
		_back_strip_fade.kill()
	_back_strip_fade = create_tween()
	_back_strip_fade.tween_property(_back_strip, "modulate:a", 1.0 if on else 0.0, back_strip_fade_seconds)


## The buttons on screen now, in the coordinates of the UI layer, for UI that must not cover them.
func button_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for button: Button in [_left, _right, _back]:
		if button.is_visible_in_tree():
			rects.append(button.get_global_rect())
	return rects


## Turns the way of [param direction] (&"left", &"right" or &"back"), as its button does: asks for
## the computer beside the one in focus in the Workview, or else for the view that the marker names
## that way, and shows the button pressed down.
func turn(direction: StringName) -> void:
	press(direction)
	var beside := _beside(direction)
	if beside != null:
		focus_requested.emit(beside)
	elif _marker != null:
		view_requested.emit(_marker.get(direction))


func _beside(direction: StringName) -> Job:
	if Game.view != Shop.WORKVIEW or direction == &"back":
		return null
	return Game.job_beside(Game.focus, -1 if direction == &"left" else 1)


func _status_text() -> String:
	match Game.phase:
		Game.Phase.IDLE:
			return "No day has started."
		Game.Phase.CLOSED:
			return "Day %d: the shop is closed." % Game.day.number
		Game.Phase.DAY_OVER:
			return "Day %d is over." % Game.day.number
		Game.Phase.ENDED:
			return "Day %d: the end." % Game.day.number
		Game.Phase.CALLING:
			return "Day %d: calling a customer." % Game.day.number
		_:
			var status := "Day %d, %d of %d customers in, %d on the counter" % [
				Game.day.number, Game.arrivals, Game.day.codes().size(), Game.jobs.size()]
			if Game.visitor != null:
				status += ": %s %s" % [Game.visitor.spoken_name(), String(Game.VisitorState.find_key(Game.visitor_state)).to_lower().replace("_", " ")]
			return status + "."
