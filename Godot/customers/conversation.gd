@tool
class_name Conversation
extends Resource
## One conversation of a customer: the lines they say, one at a time.

## Unique within its customer, for example &"arrive". The game asks for a conversation by this id.
@export var id: StringName = &""
@export var lines: Array[DialogueLine] = []
