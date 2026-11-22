class_name Printer
extends MeshInstance3D
## The dot-matrix printer under the work desk. It keeps one page: the last one printed sticks out
## of its top until the next print replaces it.

## The group of the shop's printer; CompuFunDB prints to its first member.
const GROUP: StringName = &"printer"

## The seconds that the head takes to print one line.
@export var line_seconds: float = 0.12
## The paper that one line feeds, in metres along the page.
@export var line_pitch: float = 0.009
## How far the top of a finished page sticks out of the slot, in metres, at least.
@export var shown_length: float = 0.17
## The seconds of the form feed after the last line.
@export var feed_seconds: float = 0.4
## The sound of the head printing one line.
@export var line_sound: SoundSet = preload("res://sounds/printer_line.tres")

var _tween: Tween

@onready var _sheet: MeshInstance3D = %Sheet
@onready var _text: Label3D = %Text
@onready var _speaker: AudioStreamPlayer3D = %Speaker


## Prints [param lines] on a new page: the old page goes, and the new one feeds out line by line
## with the print sound. A print during a print starts over with the new lines.
func print_page(lines: PackedStringArray) -> void:
	if _tween != null:
		_tween.kill()
	_text.text = "\n".join(lines)
	_set_feed(0.0)
	_tween = create_tween()
	for i: int in lines.size():
		_tween.tween_callback(line_sound.play_on.bind(_speaker))
		_tween.tween_method(_set_feed, i * line_pitch, (i + 1) * line_pitch, line_seconds)
	var done := lines.size() * line_pitch
	var page := _sheet.get_aabb().size.y
	_tween.tween_method(_set_feed, done, clampf(done + line_pitch, shown_length, page), feed_seconds)


# Sticks the top of the page [param length] metres out of the slot; the rest is inside the printer.
func _set_feed(length: float) -> void:
	_sheet.position.y = minf(length, _sheet.get_aabb().size.y)
