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
## The hat that the 3D customer wears, such as props/cap.tscn; null for none. Match the hat in the
## portrait. The scene's root must be a Node3D: its origin sits at the brow line in the middle of
## the head, with -Z the way the face looks, and the hat stays above y = 0 at the front to keep the
## face clear.
@export var hat: PackedScene
## Who speaks this customer's lines: the bottom layer of their voice (voices/persons/). A new
## body needs new voice files: run voices/render_voices.gd.
@export var voice: VoicePerson = preload("res://voices/persons/man.tres")


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
