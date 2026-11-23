@tool
class_name DialogueLine
extends Resource
## One line that a customer says, and the mood that they say it in.

## The looks ([member look]) and the view that each turns the player to: left to the storage side,
## right to the work computer, ahead to the counter, facing the customer. A look names a view, not
## a turn: "ahead" after "left" turns back.
const LOOKS: Dictionary[StringName, StringName] = {&"left": &"Left", &"right": &"Right", &"ahead": &"Main"}

@export_multiline var text: String = ""
## One of [constant Person.MOODS]; the inspector shows them as a dropdown. It sets the portrait, and
## the voice mood (voices/moods/) unless [member voice_mood] sets another.
@export var mood: StringName = &"neutral"
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


func _validate_property(property: Dictionary) -> void:
	if property.name == "mood":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(PackedStringArray(Person.MOODS))
