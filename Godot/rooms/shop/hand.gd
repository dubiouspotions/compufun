class_name Hand
extends Node3D
## What the player holds (Game.hand), as a first-person held item (wiki: Hardware Repair): the part's
## own model low in the view, with its name beside it and BROKEN when it is broken. A child of the
## room's camera, so it follows every view and turn. It keeps the same place and size on screen
## whatever the camera's field of view. Hidden while the hand is empty, and lowered out of the picture
## in [member lowered_in_views].
##
## The player can drag the part out of the hand: dropped on a hotspot that takes a drop
## ([member Hotspot.takes_drop]) it acts as a click there; dropped anywhere else it goes back into the
## hand. A click on the part that doesn't drag reaches the room behind it.

## Where the part is held on screen: x from -1 (left edge) to 1 (right edge), y from -1 (bottom) to
## 1 (top).
@export var screen_position: Vector2 = Vector2(0.62, -0.58)
## How far in front of the camera the part is held, in metres. Short, so that the room seldom gets
## between the camera and the part.
@export_range(0.06, 1.0) var distance: float = 0.25
## The longest side of the part on screen, as a share of the height of the view's 16:9 frame.
@export_range(0.05, 1.0) var shown_size: float = 0.22
## How the part is turned in the hand, in degrees: tipped toward the player to show its top.
@export var held_rotation_degrees: Vector3 = Vector3(40.0, -30.0, 8.0)
## How far the part sways while held, as a share of the height of the view's 16:9 frame.
@export var sway: float = 0.008
## How far the part rocks while held, in degrees.
@export var sway_degrees: float = 2.0
## The sway's cycles per second.
@export var sway_speed: float = 0.35
## The seconds that the part takes to come up into view, or to go down out of it.
@export var raise_seconds: float = 0.18
## The views where the hand goes down, out of the picture: the views where a screen fills the view.
@export var lowered_in_views: Array[StringName] = [&"Screen", &"CompuFunDB"]
## The longest side of the part while the player drags it, as a share of the height of the view's
## 16:9 frame. Smaller than [member shown_size], and up and right of the mouse, so that the place
## under the mouse shows.
@export_range(0.02, 1.0) var dragged_size: float = 0.12
## How far the mouse moves, in pixels of the world buffer, before a press on the part becomes a drag.
@export var drag_threshold: float = 3.0

var _held: Piece
var _time: float = 0.0
var _lowered: float = 0.0  # 1 while the part is below the view, 0 while it is up
var _lowering_to: float = 0.0
var _lowering: Tween
var _model: Node3D
var _box: AABB  # around _model's meshes, in its own space
var _press: InputEventMouseButton  # the press on the part, while the button is down
var _dragging: bool = false
var _mouse: Vector2  # in pixels of the world buffer
var _passing: bool = false

@onready var _camera: ViewCamera = get_parent() as ViewCamera
@onready var _holder: Node3D = %Holder
@onready var _name: Label3D = %Name
@onready var _broken: Label3D = %Broken


func _ready() -> void:
	if _camera == null:
		push_error("Hand: the parent %s is not a ViewCamera" % get_parent().get_path())
		return
	Game.changed.connect(_sync)
	_sync()


## True while the player drags the part out of the hand.
func is_dragging() -> bool:
	return _dragging


## Holds a stand-in [param part] in view for one frame, so that the renderer compiles what the hand
## shows now and not on the player's first take (see [method Shop.warm_up]). Then shows Game.hand.
func warm_up(part: Part) -> void:
	_hold(Piece.new(part, true))
	_lowered = 0.0
	visible = true
	_process(0.0)
	await RenderingServer.frame_post_draw
	_sync()


# The node's local units are heights of the view's 16:9 frame, so the part and its labels keep their
# size on screen across fields of view and window shapes, and one font pixel is one pixel of the world
# buffer. screen_position spans the whole picture, so the part stays at its edge.
func _process(delta: float) -> void:
	_time += delta
	var view := _camera.get_viewport().get_visible_rect().size
	var half_picture := _camera.tangents() * distance
	var height := 2.0 * ViewCamera.design_tangents(_camera.view_fov).y * distance
	var bob := sin(_time * TAU * sway_speed)
	var drift := cos(_time * TAU * sway_speed * 0.5)
	var below := (1.0 + screen_position.y) * half_picture.y + shown_size * height  # just out of the bottom of the view
	var at := screen_position * half_picture
	if _dragging:
		at = Vector2(_mouse.x - view.x * 0.5, view.y * 0.5 - _mouse.y) * (2.0 * half_picture.y / view.y) + Vector2.ONE * dragged_size * 0.6 * height
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):  # released over the UI, which kept the release
			_drop(_mouse)
	position = Vector3(at.x + drift * sway * height, at.y + bob * sway * height - _lowered * below, -distance)
	scale = Vector3.ONE * height
	_holder.scale = Vector3.ONE * (dragged_size / shown_size if _dragging else 1.0)
	_name.visible = not _dragging
	_broken.visible = not _dragging and _held != null and _held.broken
	_holder.rotation_degrees = held_rotation_degrees + Vector3(bob, drift, 0.0) * sway_degrees
	_name.pixel_size = 2.0 * half_picture.y / view.y / height
	_broken.pixel_size = _name.pixel_size


func _unhandled_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if mouse == null or _passing:
		return
	_mouse = mouse.position
	var button := mouse as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and _press == null and covers(button.position):
			_press = button
			get_viewport().set_input_as_handled()  # physics picking skips handled events: the room under the part gets no press
		elif not button.pressed and _press != null:
			get_viewport().set_input_as_handled()
			if _dragging:
				_drop(button.position)
			else:
				_pass_click.call_deferred(_press, button)
				_press = null
	elif _press != null and not _dragging and _mouse.distance_to(_press.position) > drag_threshold:
		_dragging = true


## True when [param at], in pixels of the world buffer, is on the part in the hand (false while the
## hand is empty or lowered).
func covers(at: Vector2) -> bool:
	if _model == null or not visible or _lowered > 0.5:
		return false
	var rect := Rect2(_camera.unproject_position(_model.global_transform * _box.position), Vector2.ZERO)
	for corner: int in 8:
		rect = rect.expand(_camera.unproject_position(_model.global_transform * _box.get_endpoint(corner)))
	return rect.has_point(at)


# Drops the dragged part at [param at], in pixels of the world buffer: a click on the nearest hotspot
# there that takes a drop. When the part is still in the hand after it, the part comes back up.
func _drop(at: Vector2) -> void:
	_dragging = false
	_press = null
	var target := _drop_target(at)
	if target != null:
		target.clicked.emit(target)
	if Game.hand == _held and _held != null:
		_lowered = 1.0
		_lowering_to = -1.0
		_sync()


func _drop_target(at: Vector2) -> Hotspot:
	var from := _camera.project_ray_origin(at)
	var dir := _camera.project_ray_normal(at)
	var nearest: Hotspot = null
	var nearest_distance := INF
	for node: Node in get_tree().get_nodes_in_group(Hotspot.DROP_TARGETS):
		var hotspot := node as Hotspot
		var hit := hotspot.ray_distance(from, dir)
		if hit >= 0.0 and hit < nearest_distance:
			nearest = hotspot
			nearest_distance = hit
	return nearest


# Sends a press and release that didn't drag on to the room behind the part.
func _pass_click(press: InputEventMouseButton, release: InputEventMouseButton) -> void:
	_passing = true
	get_viewport().push_input(press, true)
	get_viewport().push_input(release, true)
	_passing = false


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
	_model = null
	_press = null
	_dragging = false
	for child: Node in _holder.get_children():
		child.queue_free()
	if _held == null:
		return
	_name.text = _held.part.display_name
	_lowered = 1.0
	_lowering_to = -1.0
	_process(0.0)
	_model = _held.make_model()
	if _model == null:
		return
	_holder.add_child(_model)
	# So close to the camera, the room's lights would throw a huge shadow of the part.
	for mesh: Node in _model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box = Part.bounds(_model)
	var longest := maxf(_box.size.x, maxf(_box.size.y, _box.size.z))
	var fit := shown_size / maxf(longest, 0.001)
	_model.scale = Vector3.ONE * fit
	_model.position = -_box.get_center() * fit

