class_name ScreenView
extends Control
## The Screen View: a sharp copy of the screen buffer, laid exactly over the screen of the 3D
## monitor. It fades in while the camera zooms into the monitor and lands at [member zoom] times the
## buffer's size, where it takes the mouse and the keys. The 3D monitor shows the same buffer as its
## texture, so there is one desktop in one place. The buffer shows the desktop of the job that the
## cable is connected to (Game.connected), and NO SIGNAL while the cable hangs free. %Tube turns
## the monitor on while the shop is open and locks it onto the signal of a running computer.

## The player clicked the open view outside the screen.
signal outside_clicked

## The desktop of one job's computer, with a %ComputerState node. Each job gets its own at its
## first connection; it waits out of the tree while the cable is elsewhere, and is freed when the
## job leaves the counter. It reports software fixes to Game itself.
@export var desktop_scene: PackedScene
## The whole-number scale of the open screen: 2 shows the 640 x 480 buffer 1280 x 960 in 1080p,
## with chunky, sharp pixels. The Screen marker's distance must make the 3D screen this big.
@export_range(1, 4) var zoom: int = 2
## The seconds of the fade in and out. The main scene sets it to the camera's turn time.
@export var fade_seconds: float = 0.35
## The mouse cursor everywhere but over the desktop, from the start of the main scene. CrtScreen
## draws the desktop's.
@export var game_cursor: Texture2D = preload("res://ui/crosshair_cursor.png")
## The pixel of [member game_cursor] that points.
@export var game_cursor_hotspot: Vector2 = Vector2(6, 6)

var _open: bool = false
var _fade: Tween
var _desktops: Dictionary[Job, Control] = {}

@onready var _screen: CrtScreen = %Screen
@onready var _tube: CrtTube = %Tube
@onready var _buffer: SubViewport = %ScreenBuffer
@onready var _no_signal: Control = %NoSignal


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_show_cursor(game_cursor, game_cursor_hotspot)
	if desktop_scene == null:
		push_error("ScreenView: desktop_scene is empty")
	Game.changed.connect(_sync)
	_sync()


func _exit_tree() -> void:
	_show_cursor(null, Vector2.ZERO)  # Otherwise the display server outlives the texture and logs a leak at exit.
	for desktop: Control in _desktops.values():
		if desktop.get_parent() == null:
			desktop.free()  # out of the tree, nothing else frees it


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if _open and click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		outside_clicked.emit()


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
## within 1 % of [member zoom] times the buffer's size snaps to it, so the open screen is sharp.
func follow(rect: Rect2) -> void:
	var screen_size := Vector2(_buffer.size)
	var open_size := screen_size * zoom
	var sharp := absf(rect.size.x - open_size.x) <= open_size.x * 0.01
	if sharp:
		rect = Rect2((rect.get_center() - open_size * 0.5).round(), open_size)
	_screen.position = rect.position
	_screen.scale = rect.size / screen_size
	_screen.set_closeness(smoothstep(0.5, 1.0, rect.size.x / open_size.x))


## Degausses the monitor: the picture shakes and the magnetised colours clear.
func degauss() -> void:
	_tube.degauss()


# Frees the desktops of jobs that left the counter, and puts the connected job's desktop in the buffer.
func _sync() -> void:
	for job: Job in _desktops.keys():
		if job not in Game.jobs:
			_desktops[job].queue_free()
			_desktops.erase(job)
	var shown := _desktop(Game.connected) if Game.connected != null else null
	for child in _buffer.get_children():
		if child != shown and child != _no_signal:
			_buffer.remove_child(child)
	if shown != null and shown.get_parent() == null:
		_buffer.add_child(shown)
	_no_signal.visible = shown == null
	var running := Game.connected != null and Game.connected.powered
	_screen.cursor_visible = running and shown != null and shown.get(&"pointer_visible") != false
	_tube.reconcile(Game.phase == Game.Phase.OPEN or Game.phase == Game.Phase.CALLING, running, Game.day.warp if Game.day != null else 0.0)


# The desktop of [param job], made at the first call. Null, with an error, when the scene is unfit.
func _desktop(job: Job) -> Control:
	if _desktops.has(job):
		return _desktops[job]
	if desktop_scene == null:
		return null
	var desktop := desktop_scene.instantiate() as Control
	var state := desktop.get_node_or_null(^"%ComputerState") as ComputerState if desktop != null else null
	if state == null:
		push_error("ScreenView: %s is not a Control with a %%ComputerState node" % desktop_scene.resource_path)
		if desktop != null:
			desktop.free()
		return null
	if desktop.custom_minimum_size != Vector2(_buffer.size):
		push_error("ScreenView: %s is %s, but the screen buffer is %s" % [desktop_scene.resource_path, desktop.custom_minimum_size, _buffer.size])
	state.job = job
	if desktop.has_signal(&"pointer_changed"):
		desktop.pointer_changed.connect(_sync, CONNECT_DEFERRED)
	_desktops[job] = desktop  # before it enters the tree, whose boot can emit Game.changed again
	return desktop


# Replaces the image of the arrow shape, which Controls and the 3D world show; the hotspot hand stays.
func _show_cursor(cursor: Texture2D, hotspot: Vector2) -> void:
	Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, hotspot)
