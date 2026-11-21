class_name ViewNav
extends Control
## The turn buttons, the Back button, the view name and the status line. It shows a view marker
## and asks for view changes; it does not change the view itself.

## The player pressed a turn button or Back.
signal view_requested(view: StringName)

var _marker: ViewMarker

@onready var _left: Button = %LeftButton
@onready var _right: Button = %RightButton
@onready var _back: Button = %BackButton
@onready var _view_label: Label = %ViewLabel
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_left.pressed.connect(func() -> void: _request(&"left"))
	_right.pressed.connect(func() -> void: _request(&"right"))
	_back.pressed.connect(func() -> void: _request(&"back"))


## Shows the buttons that [param marker] allows. null hides them.
func show_marker(marker: ViewMarker) -> void:
	_marker = marker
	_left.visible = marker != null and marker.left != &""
	_right.visible = marker != null and marker.right != &""
	_back.visible = marker != null and marker.back != &""
	_view_label.text = String(Game.view)
	_status_label.text = _status_text()


func _request(direction: StringName) -> void:
	if _marker != null:
		view_requested.emit(_marker.get(direction))


func _status_text() -> String:
	match Game.phase:
		Game.Phase.IDLE:
			return "No day has started."
		Game.Phase.DAY_OVER:
			return "Day %d is over." % Game.day.number
		_:
			return "Day %d, customer %d of %d: %s" % [
				Game.day.number, Game.customer_index + 1, Game.day.customers.size(),
				String(Game.Phase.find_key(Game.phase)).to_lower().replace("_", " ")]
