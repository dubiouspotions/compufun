@tool
class_name DialogueLine
extends Resource
## One line that a customer says, and the mood that they say it in.

@export_multiline var text: String = ""
## One of [constant Person.MOODS]; the inspector shows them as a dropdown. It sets the portrait and
## the mood of the voice (voices/moods/).
@export var mood: StringName = &"neutral"
## The voice effect of this line; null takes its conversation's.
@export var effect: VoiceEffect
## The customer calls it out while walking out, outside the dialogue box ([leaving] in a story file).
@export var leaving: bool = false


func _validate_property(property: Dictionary) -> void:
	if property.name == "mood":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(PackedStringArray(Person.MOODS))
