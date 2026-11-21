class_name ViewNav
extends Control
## The Back button, the view name and the status line. It shows a view marker and asks for view
## changes; it does not change the view itself. The arrow keys turn and look up (main.gd).

## The player pressed Back.
signal view_requested(view: StringName)

var _marker: ViewMarker

@onready var _back: Button = %BackButton
@onready var _view_label: Label = %ViewLabel
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_back.pressed.connect(func() -> void: _request(&"back"))


## Shows the Back button when [param marker] allows Back. null hides it.
func show_marker(marker: ViewMarker) -> void:
	_marker = marker
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
				status += ": %s %s" % [Game.visitor.spoken_name(), String(Game.VisitorState.find_key(Game.visitor_state)).to_lower().replace("_", " ")]
			return status + "."
