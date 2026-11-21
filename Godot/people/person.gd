class_name Person
extends Resource
## One photographed person. One person can play many customers.

## The poses that every person is photographed in. A line of dialogue picks one of them.
const POSES: Array[StringName] = [
	&"neutral", &"happy", &"angry", &"problem", &"thinking",
	&"irritated01", &"irritated02", &"irritated03",
]

@export var display_name: String = ""
## The cut-out portraits, one per pose in [constant POSES]. Empty in the wireframe.
@export var portraits: Dictionary[StringName, Texture2D] = {}
## The square face texture on the 3D customer. null shows a grey placeholder.
@export var face: Texture2D
## The part of the neutral portrait that the 3D customer's shirt shows, in shares of the picture (0 to 1):
## from sleeve to sleeve, and from the collar down to the bottom edge.
@export var shirt_rect: Rect2 = Rect2(0.3, 0.33, 0.46, 0.67)
