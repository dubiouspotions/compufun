class_name Conversation
extends Resource
## One conversation of a customer: the lines they say, then the replies the player can pick.

## Unique within its customer, for example &"arrive". The game asks for a conversation by this id.
@export var id: StringName = &""
@export var lines: Array[DialogueLine] = []
## The replies that the player can pick after the last line. Empty shows a plain "OK".
@export var replies: PackedStringArray = []
