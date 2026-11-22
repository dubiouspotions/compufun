class_name Person
extends Resource
## One photographed person. One person can play many customers.

## The moods that a line of dialogue can pick. A person may have no portrait for some of them.
const MOODS: Array[StringName] = [
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
## The cut-out portraits, keyed by mood. Empty in the wireframe.
@export var portraits: Dictionary[StringName, Texture2D] = {}
## The square face texture on the 3D customer. null shows a grey placeholder.
@export var face: Texture2D
## The mood whose portrait the 3D customer's photo relief (PhotoRelief) shows. [member back] must be
## drawn from the same portrait: after a change, run tools/make_portrait_backs.py with --force.
@export var relief_pose: StringName = &"neutral"
## The person seen from behind, cut to the outline of the [member relief_pose] portrait mirrored: the
## back of the 3D customer's photo relief. tools/make_portrait_backs.py makes it. null shows the
## portrait mirrored and darkened there.
@export var back: Texture2D
## The part of the neutral portrait that the 3D customer's shirt shows, in shares of the picture (0 to 1):
## from sleeve to sleeve, and from the collar down to the bottom edge.
@export var shirt_rect: Rect2 = Rect2(0.3, 0.33, 0.46, 0.67)
## Who speaks when this person plays a customer: the bottom layer of the voice (voices/persons/),
## under the mood of each line and its effect. A new body needs new voice files: run
## voices/render_voices.gd.
@export var voice: VoicePerson


## The moods that this person has portraits for, in [constant MOODS] order. A line in another mood
## shows the neutral portrait.
func moods() -> Array[StringName]:
	var found: Array[StringName] = []
	found.assign(MOODS.filter(func(mood: StringName) -> bool: return portraits.has(mood)))
	return found


## "Name <email>" for the computer screen, or "" when both are still empty.
func computer_identity() -> String:
	if name == "" and email == "":
		return ""
	if name == "":
		return email
	if email == "":
		return name
	return "%s <%s>" % [name, email]
