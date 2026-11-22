class_name ScreenView
extends Control
## A close-up of a 3D monitor: its screen buffer through the CRT look, laid exactly over the
## monitor's screen. It fades in while the camera zooms into the monitor and lands at [member zoom]
## times the buffer's size, where it takes the mouse and the keys. The 3D monitor shows the same
## buffer, and %Tube drives both looks: one monitor, one tube. The tube is on while the shop is open,
## and locks onto the content's signal. See docs/crt.md.

## The player clicked the open view outside the screen.
signal outside_clicked

## The view marker's screen that opens this view; the room's monitor for it shows the buffer.
@export var screen: ViewMarker.Screen = ViewMarker.Screen.WIN95
## What runs in the screen buffer: a Control of the buffer's size. When its script has a
## [code]has_picture() -> bool[/code], the tube locks onto the picture only while it returns true;
## a [code]pointer_visible() -> bool[/code] hides the cursor while it returns false, and a
## [code]pointer_changed[/code] signal says when that changes; [code]picture_changed[/code] says that
## [code]has_picture()[/code] did. Its [code]screen_opened()[/code], if
## it has one, is called each time the view opens.
@export var content: PackedScene
## The shader draws the mouse cursor into the picture while there is a signal. False when the
## content draws its own, as CompuFunDB's text mode does.
@export var draw_cursor: bool = true
## The whole-number scale of the open screen: 2 shows the 640 x 480 buffer 1280 x 960 in 1080p,
## with chunky, sharp pixels. The view marker's distance must make the 3D screen this big.
@export_range(1, 4) var zoom: int = 2
## The seconds of the fade in and out. The main scene sets it to the camera's turn time.
@export var fade_seconds: float = 0.35
## The mouse cursor everywhere but over the screen, from the start of the main scene. CrtScreen
## draws the screen's.
@export var game_cursor: Texture2D = preload("res://ui/crosshair_cursor.png")
## The pixel of [member game_cursor] that points.
@export var game_cursor_hotspot: Vector2 = Vector2(6, 6)
## The monitor's keyboard: each key that the player presses while the view is open; null is silent.
@export var keystroke: SoundSet = preload("res://sounds/keystroke.tres")
## The monitor's mouse: a button pressed and released over the open screen; null is silent.
@export var mouse_down: SoundSet = preload("res://sounds/mouse_down.tres")
@export var mouse_up: SoundSet = preload("res://sounds/mouse_up.tres")

var _open: bool = false
var _open_rect: Rect2 = Rect2()
var _fade: Tween
var _content: Control
var _keys: AudioStreamPlayer
var _buttons: AudioStreamPlayer

@onready var _screen: CrtScreen = %Screen
@onready var _tube: CrtTube = %Tube
@onready var _buffer: SubViewport = %ScreenBuffer


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_show_cursor(game_cursor, game_cursor_hotspot)
	_keys = AudioStreamPlayer.new()
	add_child(_keys)
	_buttons = AudioStreamPlayer.new()
	add_child(_buttons)
	var node := content.instantiate() if content != null else null
	_content = node as Control
	if _content == null:
		push_error("ScreenView %s: content is not a Control scene: %s" % [name, content])
		if node != null:
			node.free()
	else:
		if _content.custom_minimum_size != Vector2(_buffer.size):
			push_error("ScreenView %s: %s is %s, but the screen buffer is %s" % [name, content.resource_path, _content.custom_minimum_size, _buffer.size])
		_buffer.add_child(_content)
		for changes: StringName in [&"pointer_changed", &"picture_changed"]:
			if _content.has_signal(changes):
				_content.connect(changes, _sync, CONNECT_DEFERRED)
	Game.changed.connect(_sync)
	_sync()


func _exit_tree() -> void:
	_show_cursor(null, Vector2.ZERO)  # Otherwise the display server outlives the texture and logs a leak at exit.


# _input, before the screen takes the event: a key or a click that the screen handles sounds too.
func _input(event: InputEvent) -> void:
	if not _open:
		return
	var key := event as InputEventKey
	if keystroke != null and key != null and key.pressed and not key.echo:
		keystroke.play_on(_keys)
	var button := event as InputEventMouseButton
	if button != null and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] \
			and _screen.get_global_rect().has_point(button.position):
		var sound := mouse_down if button.pressed else mouse_up
		if sound != null:
			sound.play_on(_buttons)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if _open and click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		outside_clicked.emit()


## The live picture of the screen buffer, for the 3D monitor.
func screen_texture() -> ViewportTexture:
	return _buffer.get_texture()


## Lets the tube drive [param look] too: the 3D monitor's material, which shows [method screen_texture].
func add_look(look: ShaderMaterial) -> void:
	if look != null:
		_tube.add_look(look)


## Fades the view in (true) or out (false). It stays visible until the fade out ends.
func set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	_open_rect = Rect2()
	if _fade != null:
		_fade.kill()
	if open:
		visible = true
		if _content != null and _content.has_method(&"screen_opened"):
			_content.call(&"screen_opened")
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
	_open_rect = rect if sharp and _open else Rect2()


## The screen's rect in canvas coordinates once the view is open and the camera has zoomed all the
## way in (see [method follow]); empty while the view is closed, closing or still zooming.
func open_rect() -> Rect2:
	return _open_rect


## Whether the monitor's power switch is on. It starts on; [method toggle_power] flips it.
var switched_on: bool = true


## Flips the monitor's power switch, with the tube's power-on or power-off.
func toggle_power() -> void:
	switched_on = not switched_on
	_sync()


## Degausses the monitor: the picture shakes and the magnetised colours clear.
func degauss() -> void:
	_tube.degauss()


func _sync() -> void:
	var has_picture: bool = _content != null and (not _content.has_method(&"has_picture") or _content.call(&"has_picture"))
	var pointer: bool = _content == null or not _content.has_method(&"pointer_visible") or _content.call(&"pointer_visible")
	_screen.cursor_visible = draw_cursor and has_picture and pointer
	_tube.reconcile(switched_on, has_picture, Game.day.warp if Game.day != null else 0.0)


# Replaces the image of the arrow shape, which Controls and the 3D world show; the hotspot hand stays.
func _show_cursor(cursor: Texture2D, hotspot: Vector2) -> void:
	Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, hotspot)
