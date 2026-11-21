class_name ViewNav
extends Control
## The turn buttons, the Back button and the status line. It shows a view marker
## and asks for view changes; it does not change the view itself.

## The player pressed a turn button, the up button or Back.
signal view_requested(view: StringName)

## The colour that the up button pulses to while the ceiling mouse squeaks.
@export var call_color: Color = Color(1.0, 0.84, 0.35)
## The seconds that the back strip takes to darken, and to clear again.
@export var back_strip_fade_seconds: float = 0.12

var _marker: ViewMarker
var _pulse: Tween
var _back_strip_fade: Tween

@onready var _left: Button = %LeftButton
@onready var _right: Button = %RightButton
@onready var _up: Button = %UpButton
@onready var _back: Button = %BackButton
@onready var _status_label: Label = %StatusLabel
@onready var _back_strip: TextureRect = %BackStrip


func _ready() -> void:
	_left.pressed.connect(func() -> void: _request(&"left"))
	_right.pressed.connect(func() -> void: _request(&"right"))
	_up.pressed.connect(func() -> void: _request(&"up"))
	_back.pressed.connect(func() -> void: _request(&"back"))


## Shows the buttons that [param marker] allows. null hides them.
func show_marker(marker: ViewMarker) -> void:
	_marker = marker
	_left.visible = marker != null and marker.left != &""
	_right.visible = marker != null and marker.right != &""
	_up.visible = marker != null and marker.up != &""
	_back.visible = marker != null and marker.back != &""
	_sync_pulse(_up.visible and CeilingMouse.stage() == CeilingMouse.Stage.SQUEAKING)
	_status_label.text = _status_text()


## Darkens the bottom [param height] of the screen (a share of its height) while [param on], to show
## that a click there goes back (see [member Shop.back_strip_height]).
func show_back_strip(on: bool, height: float) -> void:
	_back_strip.anchor_top = 1.0 - height
	if _back_strip_fade != null:
		_back_strip_fade.kill()
	_back_strip_fade = create_tween()
	_back_strip_fade.tween_property(_back_strip, "modulate:a", 1.0 if on else 0.0, back_strip_fade_seconds)


# The up button pulses while the ceiling mouse squeaks, so the player looks up.
func _sync_pulse(on: bool) -> void:
	if on == (_pulse != null):
		return
	if _pulse != null:
		_pulse.kill()
		_pulse = null
		_up.modulate = Color.WHITE
		return
	_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_up, "modulate", call_color, 0.45)
	_pulse.tween_property(_up, "modulate", Color.WHITE, 0.45)


func _request(direction: StringName) -> void:
	if _marker != null:
		view_requested.emit(_marker.get(direction))


func _status_text() -> String:
	match Game.phase:
		Game.Phase.IDLE:
			return "No day has started."
		Game.Phase.DAY_OVER:
			return "Day %d is over." % Game.day.number
		Game.Phase.ENDED:
			return "Day %d: the end." % Game.day.number
		Game.Phase.CALLING:
			return "Day %d: calling a customer." % Game.day.number
		_:
			var status := "Day %d, %d of %d customers in, %d on the counter" % [
				Game.day.number, Game.arrivals, Game.day.customers.size(), Game.jobs.size()]
			if Game.visitor != null:
				status += ": %s %s" % [Game.visitor.spoken_name(), String(Game.VisitorState.find_key(Game.visitor_state)).to_lower().replace("_", " ")]
			return status + "."
