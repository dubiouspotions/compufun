class_name EndOfDay
extends Control
## Asks the player, in a Win95 message box, whether to end the day, and plays the night after
## Game.close_shop(): a short wait in the evening, the screen and the sound fade out, a black pause,
## the sound comes back with the next day's title on the black screen, then that day starts
## (Game.start_next_day) and the shop fades in. After the last day the screen stays black with
## [member week_over_text]. It follows Game.phase: leaving DAY_OVER in any way fades the shop back in.

const _MessageBox := preload("res://win95/message_box.gd")

## The question in the message box.
@export var question: String = "Do you want to end the day?"
## The title of the message box.
@export var title: String = "Close the shop"
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
@onready var _black: ColorRect = %Black
@onready var _title: Label = %Title
@onready var _master: int = AudioServer.get_bus_index(&"Master")


func _ready() -> void:
	_dialog.hide()
	_box.answered.connect(_on_answered)
	Game.changed.connect(_sync)
	_sync()


## Shows the question. Yes closes the shop through [method Game.close_shop]; No, or the X, leaves
## it open.
func ask() -> void:
	_box.ask(title, question, ["Yes", "No"])
	_box.show()
	_dialog.show()


func _on_answered(button: String) -> void:
	_dialog.hide()
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
	_sequence.tween_callback(_black.show)
	_sequence.tween_property(_black, "modulate:a", 1.0, fade_seconds).from(0.0)
	_sequence.parallel().tween_method(_set_volume, 1.0, 0.0, fade_seconds)
	_sequence.tween_interval(black_seconds)
	_sequence.tween_callback(_show_title)
	_sequence.tween_method(_set_volume, 0.0, 1.0, fade_seconds)
	if Game.has_next_day():
		_sequence.tween_interval(title_seconds)
		_sequence.tween_callback(Game.start_next_day)


func _show_title() -> void:
	_title.text = day_title % (Game.day_number + 1) if Game.has_next_day() else week_over_text
	_title.show()


func _set_volume(linear: float) -> void:
	AudioServer.set_bus_volume_linear(_master, linear)
