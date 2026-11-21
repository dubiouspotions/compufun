@tool
class_name DialogueLine
extends Resource
## One line that a customer says, with the portrait pose to show while they say it.

@export_multiline var text: String = ""
## One of [constant Person.POSES]; the inspector shows them as a dropdown. It sets the portrait and
## the mood of the voice (voices/moods/).
@export var pose: StringName = &"neutral"


func _validate_property(property: Dictionary) -> void:
	if property.name == "pose":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(PackedStringArray(Person.POSES))
