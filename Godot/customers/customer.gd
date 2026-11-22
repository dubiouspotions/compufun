@tool
class_name Customer
extends Resource
## One customer for the whole week: who they are and their computer. What they say, and what is
## wrong with the computer, on a visit is that visit's Errand (a story file).

## The name dialogue uses while the person's nickname is empty.
@export var display_name: String = ""
@export var person: Person
@export var computer: Computer
## The trousers colour of the 3D customer. It tints the denim texture.
@export var trousers_color: Color = Color(0.46, 0.56, 0.74)
## The hat that the 3D customer wears, such as props/cap.tscn; null for none. Match the hat in the
## portrait. The scene's root must be a Node3D: its origin sits at the brow line in the middle of
## the head, with -Z the way the face looks, and the hat stays above y = 0 at the front to keep the
## face clear.
@export var hat: PackedScene
## What the 3D customer wears around the neck, such as props/scarf.tscn; null for none. Match the
## portrait. The scene's root must be a Node3D: its origin sits in the middle of the neck, with -Z
## the way the face looks, and it stays below the chin to keep the face clear.
@export var neckwear: PackedScene
## Who speaks this customer's lines: the person's voice, the bottom layer (voices/persons/); null
## while the person has none.
var voice: VoicePerson:
	get:
		return person.voice if person != null else null


## The name the dialogue shows: the person's nickname, or [member display_name] while that is empty.
func spoken_name() -> String:
	if person != null and person.nickname != "":
		return person.nickname
	return display_name
