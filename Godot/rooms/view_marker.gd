class_name ViewMarker
extends Marker3D
## A fixed point of view in a room. The node name is the name of the view; the camera moves to the
## marker's transform. Move the marker in the editor to change the view.

enum Screen { NONE, COMPUFUN_DB, WIN95, WORKVIEW }

## The view to the left of this one. Empty: the player cannot turn left.
@export var left: StringName = &""
## The view to the right of this one. Empty: the player cannot turn right.
@export var right: StringName = &""
## The view that Back (Esc) goes to. Empty: no Back.
@export var back: StringName = &""
## The UI screen that opens in this view.
@export var screen: Screen = Screen.NONE
## The vertical field of view of the camera, in degrees. Lower is flatter.
@export_range(20.0, 100.0) var fov: float = 50.0
