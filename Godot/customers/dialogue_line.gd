@tool
class_name DialogueLine
extends Resource
## One line that a customer says, with the portrait pose to show while they say it.

@export_multiline var text: String = ""
## One of [constant Person.POSES]; the inspector shows them as a dropdown.
@export var pose: StringName = &"neutral"


## The voice file of this line in [param voice]. Its name is a hash of the voice and the text, so
## an edited line never finds old audio. voices/render_voices.gd renders the file.
func voice_path(voice: String) -> String:
	return "res://voices/%s.wav" % ("%s|%s" % [voice, text]).md5_text()


func _validate_property(property: Dictionary) -> void:
	if property.name == "pose":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(PackedStringArray(Person.POSES))
