@tool
class_name Customer
extends Resource
## One customer: who they are, what they say, and what is wrong with the computer.

## The name dialogue uses while the person's nickname is empty.
@export var display_name: String = ""
@export var person: Person
@export var conversations: Array[Conversation] = []
@export var problem: Problem
@export var computer: Computer
## The trousers colour of the 3D customer. It tints the denim texture.
@export var trousers_color: Color = Color(0.46, 0.56, 0.74)
## The Chimera voice that speaks this customer's lines. A change needs new voice files: run
## voices/render_voices.gd.
@export_enum("male", "female", "child") var voice: String = "male"


## The name the dialogue shows: the person's nickname, or [member display_name] while that is empty.
func spoken_name() -> String:
	if person != null and person.nickname != "":
		return person.nickname
	return display_name


## The conversation with [param id], or null if this customer has none.
func conversation(id: StringName) -> Conversation:
	for c: Conversation in conversations:
		if c != null and c.id == id:
			return c
	return null
