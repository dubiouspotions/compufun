class_name Person
extends Resource
## One photographed person. One person can play many customers.

## Poses a line of dialogue can show. A person may have no photo for some of them.
const POSES: Array[StringName] = [
	&"neutral", &"happy", &"angry", &"despair", &"problem", &"thinking",
	&"irritated01", &"irritated02", &"irritated03",
	&"trust", &"bye", &"explanation",
]

## The name on this person's own computer. Dialogue never shows it.
@export var name: String = ""
## What the dialogue calls them. Empty until set; dialogue then uses the customer's display name.
@export var nickname: String = ""
## The address on this person's own computer. Dialogue never shows it.
@export var email: String = ""
## The cut-out portraits, keyed by pose. Empty in the wireframe.
@export var portraits: Dictionary[StringName, Texture2D] = {}
## The square face texture on the 3D customer. null shows a grey placeholder.
@export var face: Texture2D
## The person seen from behind, cut to the neutral portrait's outline mirrored: the back of the 3D
## customer's photo relief (PhotoRelief). tools/make_portrait_backs.py makes it. null shows the
## portrait mirrored and darkened there.
@export var back: Texture2D
## The part of the neutral portrait that the 3D customer's shirt shows, in shares of the picture (0 to 1):
## from sleeve to sleeve, and from the collar down to the bottom edge.
@export var shirt_rect: Rect2 = Rect2(0.3, 0.33, 0.46, 0.67)
## Who speaks when this person plays a customer: the bottom layer of the voice (voices/persons/),
## under the mood of each line and its effect. A new body needs new voice files: run
## voices/render_voices.gd.
@export var voice: VoicePerson


## "Name <email>" for the computer screen, or "" when both are still empty.
func computer_identity() -> String:
	if name == "" and email == "":
		return ""
	if name == "":
		return email
	if email == "":
		return name
	return "%s <%s>" % [name, email]
