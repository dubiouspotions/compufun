class_name Hand
extends Node3D
## What the player holds (Game.hand), as a first-person held item (wiki: Hardware Repair): the part's
## own model low in the view, with its name beside it and BROKEN when it is broken. A child of the
## room's camera, so it follows every view and turn; it has no collision, so clicks reach the room
## behind it. It keeps the same place and size on screen whatever the camera's field of view.
## Hidden while the hand is empty, and lowered out of the picture in [member lowered_in_views].

## Where the part is held on screen: x from -1 (left edge) to 1 (right edge), y from -1 (bottom) to
## 1 (top).
@export var screen_position: Vector2 = Vector2(0.62, -0.58)
## How far in front of the camera the part is held, in metres. Short, so that the room seldom gets
## between the camera and the part.
@export_range(0.06, 1.0) var distance: float = 0.25
## The longest side of the part on screen, as a share of the view's height.
@export_range(0.05, 1.0) var shown_size: float = 0.22
## How the part is turned in the hand, in degrees: tipped toward the player to show its top.
@export var held_rotation_degrees: Vector3 = Vector3(40.0, -30.0, 8.0)
## How far the part sways while held, as a share of the view's height.
@export var sway: float = 0.008
## How far the part rocks while held, in degrees.
@export var sway_degrees: float = 2.0
## The sway's cycles per second.
@export var sway_speed: float = 0.35
## The seconds that the part takes to come up into view, or to go down out of it.
@export var raise_seconds: float = 0.18
## The views where the hand goes down, out of the picture: the views where a screen fills the view.
@export var lowered_in_views: Array[StringName] = [&"Screen", &"CompuFunDB"]

var _held: Piece
var _time: float = 0.0
var _lowered: float = 0.0  # 1 while the part is below the view, 0 while it is up
var _lowering_to: float = 0.0
var _lowering: Tween

@onready var _camera: Camera3D = get_parent() as Camera3D
@onready var _holder: Node3D = %Holder
@onready var _name: Label3D = %Name
@onready var _broken: Label3D = %Broken


func _ready() -> void:
	if _camera == null:
		push_error("Hand: the parent %s is not a Camera3D" % get_parent().get_path())
		return
	Game.changed.connect(_sync)
	_sync()


## Holds a stand-in [param part] in view for one frame, so that the renderer compiles what the hand
## shows now and not on the player's first take (see [method Shop.warm_up]). Then shows Game.hand.
func warm_up(part: Part) -> void:
	_hold(Piece.new(part, true))
	_lowered = 0.0
	visible = true
	_process(0.0)
	await RenderingServer.frame_post_draw
	_sync()


# The node's local units are heights of the view, so the part and its labels keep their size on
# screen across fields of view, and one font pixel is one pixel of the world buffer.
func _process(delta: float) -> void:
	_time += delta
	var view := _camera.get_viewport().get_visible_rect().size
	var half_height := tan(deg_to_rad(_camera.fov) * 0.5) * distance
	var height := 2.0 * half_height
	var bob := sin(_time * TAU * sway_speed)
	var drift := cos(_time * TAU * sway_speed * 0.5)
	var below := (1.0 + screen_position.y) * 0.5 + shown_size  # just out of the bottom of the view
	position = Vector3(
		screen_position.x * half_height * view.x / view.y + drift * sway * height,
		screen_position.y * half_height + (bob * sway - _lowered * below) * height,
		-distance)
	scale = Vector3.ONE * height
	_holder.rotation_degrees = held_rotation_degrees + Vector3(bob, drift, 0.0) * sway_degrees
	_name.pixel_size = 1.0 / view.y
	_broken.pixel_size = _name.pixel_size


func _sync() -> void:
	var holding := Game.hand != null
	visible = holding
	set_process(holding)
	if Game.hand != _held:
		_hold(Game.hand)
	var to := 1.0 if Game.view in lowered_in_views else 0.0
	if holding and to != _lowering_to:
		_lowering_to = to
		if _lowering != null:
			_lowering.kill()
		_lowering = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_lowering.tween_property(self, "_lowered", to, raise_seconds)


# Swaps in the model of [param piece], below the view, for _sync to raise it.
func _hold(piece: Piece) -> void:
	_held = piece
	for child: Node in _holder.get_children():
		child.queue_free()
	if _held == null:
		return
	_name.text = _held.part.display_name
	_broken.visible = _held.broken
	_lowered = 1.0
	_lowering_to = -1.0
	_process(0.0)
	if _held.part.model == null:
		push_error("Hand: %s has no model" % _held.part.resource_path)
		return
	var model := _held.part.model.instantiate() as Node3D
	_holder.add_child(model)
	var box := _bounds(model)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var fit := shown_size / maxf(longest, 0.001)
	model.scale = Vector3.ONE * fit
	model.position = -box.get_center() * fit


# The box around the model's meshes, in the model's own space. Turns off their shadows on the way:
# so close to the camera, the room's lights would throw a huge shadow of the part.
func _bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var part_box: AABB = mesh.transform * mesh.get_aabb()
		box = part_box if first else box.merge(part_box)
		first = false
	return box
