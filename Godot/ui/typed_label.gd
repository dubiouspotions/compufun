class_name TypedLabel
extends Label
## A label that types its text out, a character at a time, as in the dialogue and on the phone. A
## customer's line types in time with its voice when the voice knows its timing ([method type_line]).

## How many characters a second the text types out at when no voice sets the pace; 0 shows it at
## once.
@export_range(0.0, 200.0) var chars_per_second: float = 45.0

# The characters typed so far; -1 when the whole text shows.
var _typed: float = -1.0
# The line whose voice sets the pace, and that voice; null for text that types at chars_per_second.
var _line: DialogueLine
var _voice: VoicePlayer
# Whether the voice has set the pace of this line yet.
var _followed: bool = false


## Shows [param new_text], typed out from the start at [member chars_per_second].
func type_out(new_text: String) -> void:
	_line = null
	_voice = null
	_start(new_text)


## Shows the text of [param line], typed out in time with [param voice] while the voice says this
## line and knows its timing ([method VoicePlayer.part_times]): each part's characters show evenly
## over the time that the part's audio takes, from the moment that it starts. Without known timing
## it types at [member chars_per_second], or shows at once when that is 0. Once the voice has set
## the pace, a hushed voice holds the typing where it is until the voice says the line again, and
## the typing then follows it from there. [method finish] shows all of it at once.
func type_line(line: DialogueLine, voice: VoicePlayer) -> void:
	_line = line
	_voice = voice
	_start(line.text if line != null else "")


## True while the text is still typing out.
func is_typing() -> bool:
	return _typed >= 0.0


## Shows the rest of the text at once.
func finish() -> void:
	_typed = -1.0
	visible_characters = -1


func _start(new_text: String) -> void:
	text = new_text
	_followed = false
	_typed = 0.0
	if _voiced_characters() < 0.0 and chars_per_second <= 0.0:
		finish()
		return
	_process(0.0)


func _process(delta: float) -> void:
	if _typed < 0.0:
		return
	var voiced := _voiced_characters()
	if voiced >= 0.0:
		_followed = true
		_typed = voiced
	elif _followed:
		return  # hushed mid-line: wait for the voice to say it again
	else:
		_typed += delta * chars_per_second
	visible_characters = int(_typed)
	if _typed >= get_total_character_count():
		finish()


# The characters that the voice of the line has reached, spread evenly over each part's audio; -1
# while the voice doesn't say the line or doesn't know its timing.
func _voiced_characters() -> float:
	if _line == null or _voice == null or _voice.said() != _line:
		return -1.0
	var times := _voice.part_times()
	var at := _voice.played()
	var starts := _line.part_starts()
	if times.size() != starts.size() or at < 0.0:
		return -1.0
	var part := _voice.playing_part()
	var end := starts[part + 1] if part + 1 < starts.size() else text.length()
	var share := clampf((at - times[part].x) / times[part].y, 0.0, 1.0) if times[part].y > 0.0 else 1.0
	return starts[part] + share * (end - starts[part])
