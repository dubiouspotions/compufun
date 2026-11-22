class_name ViewMarker
extends Marker3D
## A fixed point of view in a room. The node name is the name of the view; the camera moves to the
## marker's transform. Move the marker in the editor to change the view.

enum Screen { NONE, COMPUFUN_DB, WIN95, WORKVIEW }

## The view to the left of this one. Empty: the player cannot turn left.
@export var left: StringName = &""
## The view to the right of this one. Empty: the player cannot turn right.
@export var right: StringName = &""
## The view that Up or W goes to: above this one, or ahead, as the storage room is from the Left View. Empty: Up does nothing.
@export var up: StringName = &""
## The view that Back (the down arrow button, Esc, Down or S) goes to. Empty: no Back.
@export var back: StringName = &""
## The player sees the customer at the counter from here, so the customer talks to them.
@export var faces_customer: bool = false
## The UI screen that opens in this view.
@export var screen: Screen = Screen.NONE
## The vertical field of view of the camera, in degrees. Lower is flatter.
@export_range(20.0, 100.0) var fov: float = 50.0
## How long the camera takes to turn to this view, in seconds; 0 uses the room's turn_seconds.
@export_range(0.0, 10.0, 0.05, "suffix:s") var turn_seconds: float = 0.0
