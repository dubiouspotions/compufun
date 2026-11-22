extends "res://win95/window.gd"
## A Win95 message box: an icon, a message and a row of buttons. show_message() tells, with the
## error icon and OK or other buttons; ask() asks, with the warning icon and Yes, No and Cancel.

## The player pressed [param button], by its text, such as "OK", "Retry" or "Cancel". Closing the box
## with its X answers the last button. The box closes itself after this.
signal answered(button: String)

@export var error_icon: Texture2D
@export var warning_icon: Texture2D
## Plays when show_message() shows; null plays nothing.
@export var error_sound: AudioStream
## Plays when ask() asks; null plays nothing.
@export var question_sound: AudioStream

var _buttons: Array[String] = []
var _answered := false


func _ready() -> void:
	super()
	closed.connect(func() -> void:
		if not _answered and not _buttons.is_empty():
			_answered = true
			answered.emit(_buttons[-1]))


## Shows [param text] under the title [param title], with the error icon and [param buttons]; the
## first is the default. Listen to [signal answered] when there is more than OK.
func show_message(title: String, text: String, buttons: Array[String] = ["OK"]) -> void:
	_show(title, text, error_icon, buttons)
	_play(error_sound)


## Asks [param text] under the title [param title], with the warning icon and [param buttons]; the
## first is the default. Listen to [signal answered].
func ask(title: String, text: String, buttons: Array[String] = ["Yes", "No", "Cancel"]) -> void:
	_show(title, text, warning_icon, buttons)
	_play(question_sound)


func _show(title: String, text: String, icon: Texture2D, buttons: Array[String]) -> void:
	%TitleBar.title = title
	%Text.text = text
	%Icon.texture = icon
	_buttons = buttons
	for old in %Buttons.get_children():
		old.free()
	for i in buttons.size():
		var button := Button.new()
		button.text = buttons[i]
		button.custom_minimum_size = Vector2(75, 23)
		if i == 0:
			button.theme_type_variation = &"DefaultButton"
		button.pressed.connect(_answer.bind(buttons[i]))
		%Buttons.add_child(button)
	reset_size()


func _answer(button: String) -> void:
	_answered = true
	answered.emit(button)
	close()


# On the desktop, not the box, so that closing the box doesn't cut the sound off.
func _play(sound: AudioStream) -> void:
	if sound == null:
		return
	if get_parent() == null:
		push_error("Message box '%s': not on a desktop, so its sound doesn't play" % %TitleBar.title)
		return
	Win95Desktop.play_sound(sound, get_parent())
