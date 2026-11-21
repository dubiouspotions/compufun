@tool
class_name Win95Palette
extends Resource
## The Windows 95 system colours that Win95Bevel draws with. Named after the items in
## Display Properties > Appearance. Bevels that share one palette all redraw when it changes.

## "3D Objects": buttons, windows, dialogs.
@export var face_color := Color("#c0c0c0"):
	set(value):
		face_color = value
		emit_changed()
## "Window": the inside of text fields and lists.
@export var window_color := Color("#ffffff"):
	set(value):
		window_color = value
		emit_changed()
## The bright line on the lit side of an edge.
@export var highlight_color := Color("#ffffff"):
	set(value):
		highlight_color = value
		emit_changed()
## The softer second line on the lit side.
@export var light_color := Color("#dfdfdf"):
	set(value):
		light_color = value
		emit_changed()
## The gray line on the shaded side.
@export var shadow_color := Color("#808080"):
	set(value):
		shadow_color = value
		emit_changed()
## The black outer line on the shaded side.
@export var dark_shadow_color := Color("#000000"):
	set(value):
		dark_shadow_color = value
		emit_changed()
