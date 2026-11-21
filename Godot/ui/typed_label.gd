class_name TypedLabel
extends Label
## A label that types its text out, a character at a time, as in the dialogue and on the phone.

## How many characters a second the text types out at; 0 shows it at once.
@export_range(0.0, 200.0) var chars_per_second: float = 45.0

# The characters typed so far; -1 when the whole text shows.
var _typed: float = -1.0


## Shows [param new_text], typed out from the start.
func type_out(new_text: String) -> void:
	text = new_text
	_typed = 0.0 if chars_per_second > 0.0 else -1.0
	visible_characters = 0 if _typed >= 0.0 else -1


## True while the text is still typing out.
func is_typing() -> bool:
	return _typed >= 0.0


## Shows the rest of the text at once.
func finish() -> void:
	_typed = -1.0
	visible_characters = -1


func _process(delta: float) -> void:
	if _typed < 0.0:
		return
	_typed += delta * chars_per_second
	visible_characters = int(_typed)
	if _typed >= get_total_character_count():
		finish()
