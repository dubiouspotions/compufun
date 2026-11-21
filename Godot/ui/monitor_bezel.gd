class_name MonitorBezel
extends Control
## The Screen View: the monitor bezel with the screen buffer inside, at 1:1. The same buffer is
## the texture of the 3D monitor, so the desktop is live in the room too.

## The desktop that runs in the screen buffer: win95/desktop_stub.tscn until the Win95 interface
## exists. It must have the signal problem_fixed(problem: Problem).
@export var desktop_scene: PackedScene

@onready var _buffer: SubViewport = %ScreenBuffer


func _ready() -> void:
	if desktop_scene == null:
		push_error("MonitorBezel: desktop_scene is empty")
		return
	var desktop := desktop_scene.instantiate()
	_buffer.add_child(desktop)
	var err := desktop.connect(&"problem_fixed", _on_problem_fixed)
	if err != OK:
		push_error("MonitorBezel: %s has no signal problem_fixed: %s" % [desktop_scene.resource_path, error_string(err)])


func _notification(what: int) -> void:
	# The container turns the buffer's updates off when it is hidden; the 3D monitor needs them on.
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		_keep_live.call_deferred()


func _keep_live() -> void:
	_buffer.render_target_update_mode = SubViewport.UPDATE_ALWAYS


## The live picture of the screen buffer, for the 3D monitor.
func screen_texture() -> ViewportTexture:
	return _buffer.get_texture()


func _on_problem_fixed(_problem: Problem) -> void:
	Game.fix(Problem.Location.SOFTWARE)
