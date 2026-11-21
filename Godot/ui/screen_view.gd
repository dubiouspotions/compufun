class_name ScreenView
extends Control
## The Screen View: a sharp copy of the screen buffer, laid exactly over the screen of the 3D
## monitor. It fades in while the camera zooms into the monitor and lands at the buffer's size (1:1
## in 1080p), where it takes the mouse and the keys. The 3D monitor shows the same buffer as its
## texture, so there is one desktop in one place.

## The player clicked the open view outside the screen and the Fix button.
signal outside_clicked

## The desktop that runs in the screen buffer. Its root should have the signal
## problem_fixed(problem: Problem); without it, a placeholder Fix button appears under the screen.
@export var desktop_scene: PackedScene
## The seconds of the fade in and out. The main scene sets it to the camera's turn time.
@export var fade_seconds: float = 0.35
## The mouse cursor everywhere but over the desktop, from the start of the main scene.
@export var game_cursor: Texture2D = preload("res://ui/crosshair_cursor.png")
## The pixel of [member game_cursor] that points.
@export var game_cursor_hotspot: Vector2 = Vector2(6, 6)
## The mouse cursor over the desktop.
@export var desktop_cursor: Texture2D = preload("res://win95/theme/arrow_cursor.png")
## The pixel of [member desktop_cursor] that points.
@export var desktop_cursor_hotspot: Vector2 = Vector2.ZERO

var _open: bool = false
var _has_fix_signal: bool = false
var _fade: Tween

@onready var _container: SubViewportContainer = %ScreenContainer
@onready var _buffer: SubViewport = %ScreenBuffer
@onready var _fix: Button = %FixButton


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_fix.pressed.connect(func() -> void: Game.fix(Problem.Location.SOFTWARE))
	_show_cursor(game_cursor, game_cursor_hotspot)
	_container.mouse_entered.connect(_show_cursor.bind(desktop_cursor, desktop_cursor_hotspot))
	_container.mouse_exited.connect(_show_cursor.bind(game_cursor, game_cursor_hotspot))
	if desktop_scene == null:
		push_error("ScreenView: desktop_scene is empty")
		return
	var desktop := desktop_scene.instantiate()
	if desktop is Control and (desktop as Control).custom_minimum_size != Vector2(_buffer.size):
		push_error("ScreenView: %s is %s, but the screen buffer is %s" % [desktop_scene.resource_path, (desktop as Control).custom_minimum_size, _buffer.size])
	_buffer.add_child(desktop)
	_has_fix_signal = desktop.has_signal(&"problem_fixed")
	if _has_fix_signal:
		desktop.connect(&"problem_fixed", _on_problem_fixed)
	else:
		push_warning("ScreenView: %s has no signal problem_fixed(problem); the placeholder Fix button stands in" % desktop_scene.resource_path)
	_fix.visible = not _has_fix_signal


func _exit_tree() -> void:
	_show_cursor(null, Vector2.ZERO)  # Otherwise the display server outlives the texture and logs a leak at exit.


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if _open and click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		outside_clicked.emit()


func _notification(what: int) -> void:
	# The container turns the buffer's updates off when it is hidden; the 3D monitor needs them on.
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		_keep_live.call_deferred()


func _keep_live() -> void:
	_buffer.render_target_update_mode = SubViewport.UPDATE_ALWAYS


## The live picture of the screen buffer, for the 3D monitor.
func screen_texture() -> ViewportTexture:
	return _buffer.get_texture()


## Fades the view in (true) or out (false). It stays visible until the fade out ends.
func set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	if _fade != null:
		_fade.kill()
	if open:
		visible = true
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0 if open else 0.0, fade_seconds)
	if not open:
		_fade.tween_callback(hide)


## Lays the screen over [param rect]: the screen of the 3D monitor, in canvas coordinates. A rect
## within 1 % of the buffer's size snaps to it, so the open screen is sharp.
func follow(rect: Rect2) -> void:
	var screen_size := Vector2(_buffer.size)
	var sharp := absf(rect.size.x - screen_size.x) <= screen_size.x * 0.01
	if sharp:
		rect = Rect2((rect.get_center() - screen_size * 0.5).round(), screen_size)
	_container.position = rect.position
	_container.scale = rect.size / screen_size
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if sharp else CanvasItem.TEXTURE_FILTER_LINEAR
	_fix.position = Vector2(rect.end.x + 24.0, rect.end.y - _fix.size.y)


# Replaces the image of the arrow shape, which Controls and the 3D world show; the hotspot hand stays.
func _show_cursor(cursor: Texture2D, hotspot: Vector2) -> void:
	Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, hotspot)


func _on_problem_fixed(_problem: Problem) -> void:
	Game.fix(Problem.Location.SOFTWARE)
