class_name Customer
extends Resource
## One customer: who they are, what they say, and what is wrong with the computer.

## The name in the game.
@export var display_name: String = ""
@export var person: Person
@export var conversations: Array[Conversation] = []
@export var problem: Problem
## The trousers colour of the 3D customer. It tints the denim texture.
@export var trousers_color: Color = Color(0.46, 0.56, 0.74)


## The conversation with [param id], or null if this customer has none.
func conversation(id: StringName) -> Conversation:
	for c: Conversation in conversations:
		if c != null and c.id == id:
			return c
	return null
