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
		Game.Phase.ENDED:
			return "Day %d: the end." % Game.day.number
		Game.Phase.CALLING:
			return "Day %d: calling a customer." % Game.day.number
		_:
			var status := "Day %d, %d of %d customers in, %d on the counter" % [
				Game.day.number, Game.arrivals, Game.day.customers.size(), Game.jobs.size()]
			if Game.visitor != null:
				status += ": %s %s" % [Game.visitor.display_name, String(Game.VisitorState.find_key(Game.visitor_state)).to_lower().replace("_", " ")]
			return status + "."
