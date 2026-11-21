class_name Person
extends Resource
## One photographed person. One person can play many customers.

@export var display_name: String = ""
## The cut-out portraits, one per pose, for example &"neutral" or &"shrug". Empty in the wireframe.
@export var portraits: Dictionary[StringName, Texture2D] = {}
## The square face texture on the 3D customer. null shows a grey placeholder.
@export var face: Texture2D
