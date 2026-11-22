class_name EndOfDay
extends Control
## Asks the player whether to end the day, over the open sign, in the game's own panel or, once
## Cambion has warped the shop far enough, in a Win95 message box, and plays the night after
## Game.close_shop(): a short wait in the evening, longer while a corruption sign is busy, the screen
## and the sound fade out, a black pause, the sound comes back with the next day's title on the black
## screen, then that day starts (Game.start_next_day) and the shop fades in. After the last day the
## screen stays black with [member week_over_text]. It follows Game.phase: leaving DAY_OVER in any
## way fades the shop back in.

const _MessageBox := preload("res://win95/message_box.gd")

## The question, in the panel and the message box.
@export var question: String = "Do you want to end the day?"
## The title of the panel and the message box.
@export var title: String = "Close the shop"
## From this [member Game.warp] on, the question comes in a Win95 message box instead of the panel;
## 0.45 is day 4's warp.
@export_range(0.0, 1.0, 0.01) var win95_from_warp: float = 0.45
## The title on the black screen before a day starts; %d is the day's number.
@export var day_title: String = "DAY %d"
## The text on the black screen after the last day.
@export_multiline var week_over_text: String = "That was the week at CompuFun.\nThanks for playing!"
## How long the shop stays in the evening light after closing, in seconds.
@export var dusk_seconds: float = 3.0
## How long each fade of the screen and the sound takes, in seconds.
@export var fade_seconds: float = 2.0
## How long the screen stays black and silent, in seconds.
@export var black_seconds: float = 5.0
## How long the day's title shows before the shop fades in, in seconds.
@export var title_seconds: float = 3.0

var _night: bool = false
var _sequence: Tween

@onready var _dialog: SubViewportContainer = %Dialog
@onready var _box: _MessageBox = %MessageBox
@onready var _panel: PanelContainer = %Panel
@onready var _buffer: SubViewport = %Buffer
@onready var _center: CenterContainer = %Center
@onready var _black: ColorRect = %Black
@onready var _title: Label = %Title
@onready var _master: int = AudioServer.get_bus_index(&"Master")


func _ready() -> void:
	_dialog.hide()
	_box.answered.connect(_on_answered)
	(%Yes as Button).pressed.connect(_on_answered.bind("Yes"))
	(%No as Button).pressed.connect(_on_answered.bind("No"))
	set_process(false)
	Game.changed.connect(_sync)
	_sync()


## Shows the question: in the panel, or in the Win95 message box from [member win95_from_warp] on.
## Yes closes the shop through [method Game.close_shop]; No, Esc on the panel, or the X of the
## message box leaves it open.
func ask() -> void:
	if Game.warp >= win95_from_warp:
		_box.ask(title, question, ["Yes", "No"])
		_box.show()
		_dialog.show()
		return
	(%AskTitle as Label).text = title
	(%AskQuestion as Label).text = question
	_panel.show()


## True while the question shows, in the panel or in the message box.
func asking() -> bool:
	return _panel.visible or _dialog.visible


## Centres the question on [param rect], the open sign on the screen in pixels of the window, and
## keeps it inside the screen. Main calls it every frame while the question shows.
func follow(rect: Rect2) -> void:
	if _panel.visible:
		_panel.position = (rect.get_center() - global_position - _panel.size / 2.0).clamp(Vector2.ZERO, size - _panel.size).round()
	if _dialog.visible:
		var scale := _dialog.size / Vector2(_buffer.size)
		var box_size := _box.get_combined_minimum_size()
		var centre := (rect.get_center() - _dialog.global_position) / scale
		_center.size = box_size
		_center.position = (centre - box_size / 2.0).clamp(Vector2.ZERO, Vector2(_buffer.size) - box_size).round()


func _unhandled_input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed(&"ui_cancel"):
		_on_answered("No")
		get_viewport().set_input_as_handled()


func _on_answered(button: String) -> void:
	_dialog.hide()
	_panel.hide()
	if button == "Yes":
		Game.close_shop()


func _sync() -> void:
	var night := Game.phase == Game.Phase.DAY_OVER
	if night == _night:
		return
	_night = night
	if _sequence != null:
		_sequence.kill()
	_sequence = create_tween()
	if night:
		_play_night()
	else:
		_set_volume(1.0)
		_sequence.tween_property(_black, "modulate:a", 0.0, fade_seconds)
		_sequence.tween_callback(_black.hide)


func _play_night() -> void:
	_title.hide()
	_sequence.tween_interval(dusk_seconds)
	_sequence.tween_callback(_fade_out_when_quiet)


func _process(_delta: float) -> void:
	if not _night or not _sign_busy():
		set_process(false)
		if _night:
			_fade_out_when_quiet()


# The rest of the night, once no corruption sign is busy (such as posters_bounce on day 5).
func _fade_out_when_quiet() -> void:
	if _sign_busy():
		set_process(true)
		return
	_sequence = create_tween()
	_sequence.tween_callback(_black.show)
	_sequence.tween_property(_black, "modulate:a", 1.0, fade_seconds).from(0.0)
	_sequence.parallel().tween_method(_set_volume, 1.0, 0.0, fade_seconds)
	_sequence.tween_interval(black_seconds)
	_sequence.tween_callback(_show_title)
	_sequence.tween_method(_set_volume, 0.0, 1.0, fade_seconds)
	if Game.has_next_day():
		_sequence.tween_interval(title_seconds)
		_sequence.tween_callback(Game.start_next_day)


func _sign_busy() -> bool:
	return get_tree().get_nodes_in_group(CorruptionSign.GROUP).any(func(node: Node) -> bool: return (node as CorruptionSign).busy())


func _show_title() -> void:
	_title.text = day_title % (Game.day_number + 1) if Game.has_next_day() else week_over_text
	_title.show()


func _set_volume(linear: float) -> void:
	AudioServer.set_bus_volume_linear(_master, linear)
