@tool
class_name DialogueLine
extends Resource
## One line that a customer says, and the mood that they say it in. The mood can change partway
## through: the line then has line parts ([method parts]), each in its own mood, still in one box.

## The looks ([member look]) and the view that each turns the player to: left to the storage side,
## right to the work computer, ahead to the counter, facing the customer. A look names a view, not
## a turn: "ahead" after "left" turns back.
const LOOKS: Dictionary[StringName, StringName] = {&"left": &"Left", &"right": &"Right", &"ahead": &"Main"}

@export_multiline var text: String = ""
## One of [constant Person.MOODS]; the inspector shows them as a dropdown. It sets the portrait, and
## the voice mood (voices/moods/) unless [member voice_mood] sets another.
@export var mood: StringName = &"neutral"
## Where the mood changes partway through the line, as [code](mood)[/code] inside the line in a
## story file: the index in [member text] where a later part starts, to that part's mood, one of
## [constant Person.MOODS]. The part before the first change is in [member mood]. Empty for a line
## in one mood. [member text] holds the words without the [code](mood)[/code]s.
@export var mood_changes: Dictionary[int, StringName] = {}
## The voice mood that the line is spoken in when it differs from [member mood], such as a portrait
## used outside its own mood; empty speaks in [member mood]. [method voice] is the one to use.
@export var voice_mood: StringName = &""
## The voice effect of this line; null takes its conversation's.
@export var effect: VoiceEffect
## The customer calls it out while walking out, outside the dialogue box ([leaving] in a story file).
@export var leaving: bool = false
## Where the player's view turns before the line is said ([code][look left][/code] in a story file):
## a key of [constant LOOKS], or empty to stay. While a look has turned the player away from the
## customer, the conversation goes on in the call-out box. The story check lists a look that is
## not a key of [constant LOOKS]; the game skips it with an error.
@export var look: StringName = &""


## The voice mood that the line is spoken in: [member voice_mood], or [member mood] while that is
## empty. Speaking, rendering and the voice file's name all use it.
func voice() -> StringName:
	return voice_mood if voice_mood != &"" else mood


## The index in [member text] where each part starts, in order: 0, then each key of
## [member mood_changes].
func part_starts() -> PackedInt32Array:
	var starts := PackedInt32Array(mood_changes.keys())
	starts.sort()
	starts.insert(0, 0)
	return starts


## The mood of the part that the character at [param index] of [member text] is in: [member mood]
## before the first change.
func mood_at(index: int) -> StringName:
	var found := mood
	for start: int in part_starts().slice(1):
		if start <= index:
			found = mood_changes[start]
	return found


## The parts of the line in order: what the voice says one after another, and the faces that the
## dialogue box shows as each one's audio starts. Each part is a new DialogueLine with its own
## words (without the spaces around them) and mood, and this line's [member voice_mood] and
## [member effect], which hold for the whole line. A line in one mood is its own only part,
## [code][self][/code], so its voice file stays the same.
func parts() -> Array[DialogueLine]:
	if mood_changes.is_empty():
		return [self]
	var found: Array[DialogueLine] = []
	var starts := part_starts()
	for i: int in starts.size():
		var end := starts[i + 1] if i + 1 < starts.size() else text.length()
		var part := DialogueLine.new()
		part.text = text.substr(starts[i], end - starts[i]).strip_edges()
		part.mood = mood_at(starts[i])
		part.voice_mood = voice_mood if voice_mood != part.mood else &""
		part.effect = effect
		found.append(part)
	return found


func _validate_property(property: Dictionary) -> void:
	if property.name == "mood":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(PackedStringArray(Person.MOODS))
