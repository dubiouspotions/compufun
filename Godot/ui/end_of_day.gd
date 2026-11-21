class_name EndOfDay
extends Control
## Asks the player, in a Win95 message box, whether to end the day. While the day is over
## (Game.Phase.DAY_OVER), the screen fades to black and the sound fades out; when a new day
## starts, both come back at once.

const _MessageBox := preload("res://win95/message_box.gd")

## The question in the message box.
@export var question: String = "Do you want to end the day?"
## The title of the message box.
@export var title: String = "Close the shop"
## How long the fade to black and the fade of the sound take, in seconds.
@export var fade_seconds: float = 2.0

var _night: bool = false
var _fade: Tween

@onready var _dialog: SubViewportContainer = %Dialog
@onready var _box: _MessageBox = %MessageBox
@onready var _black: ColorRect = %Black
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
	if _fade != null:
		_fade.kill()
	if night:
		_black.show()
		_fade = create_tween().set_parallel()
		_fade.tween_property(_black, "modulate:a", 1.0, fade_seconds).from(0.0)
		_fade.tween_method(_set_volume, 1.0, 0.0, fade_seconds)
	else:
		_black.hide()
		_set_volume(1.0)


func _set_volume(linear: float) -> void:
	AudioServer.set_bus_volume_linear(_master, linear)
