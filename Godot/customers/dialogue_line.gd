class_name DialogueLine
extends Resource
## One line that a customer says, with the portrait pose to show while they say it.

@export_multiline var text: String = ""
## A key of [member Person.portraits], for example &"neutral". Empty uses the default pose.
@export var pose: StringName = &""
