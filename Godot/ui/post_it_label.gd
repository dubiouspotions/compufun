class_name PostItLabel
extends Control
## The post-it that the player reads in the Workview, written in sharp UI text over the 3D paper (a
## PostIt3D with text_3d off) and following it as the camera moves: the perceived issue and, once the
## post-it is ticked, the prompt to call the customer next to the 3D check.

## The font size, as a fraction of the paper's height on screen.
@export_range(0.02, 0.5) var font_fraction: float = 0.1

## The job whose post-it this is, or null to show nothing.
var job: Job:
	set(value):
		if value == job:
			return
		job = value
		if is_node_ready():
			_sync()

@onready var _issue: Label = %Issue
@onready var _pickup: Label = %Pickup


func _ready() -> void:
	Game.changed.connect(_sync)
	_sync()


## Lays the text over [param rect]: the paper as the camera sees it, in canvas coordinates.
func follow(rect: Rect2) -> void:
	position = rect.position.round()
	size = rect.size.round()
	var font_size := maxi(1, roundi(rect.size.y * font_fraction))
	for label: Label in [_issue, _pickup]:
		label.add_theme_font_size_override(&"font_size", font_size)


func _sync() -> void:
	_issue.text = job.problem.perceived_issue if job != null else ""
	_pickup.visible = job != null and job.post_it_ticked
