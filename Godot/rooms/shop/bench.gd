class_name Bench
extends Node3D
## The left end of the counter: the bench screen, its keyboard and the VGA cable. The player takes
## the plug of the cable in the hand: a press on the plug or the cord emits [signal plug_grabbed],
## the room moves the plug with [method drag_plug] while [member dragging], and lays the cable with
## [method lay_cable].

## The player clicked the screen: go to [param view].
signal view_requested(view: StringName)
## The player pressed the mouse button on the plug.
signal plug_grabbed
## The player clicked the monitor's Degauss button.
signal degauss_pressed

## The outline colour of the Degauss button while the mouse is over it.
@export var button_hover_color: Color = Color(1.0, 0.84, 0.35)
## The outline colour of the cable while the mouse is over the plug.
@export var hover_color: Color = Color(0.75, 0.9, 1.0)
## The outline colour of the cable while the plug is in the player's hand.
@export var held_color: Color = Color(1.0, 0.82, 0.2)
## How far the cable runs straight out of a socket before it bends to the counter, in metres.
@export var socket_reach: float = 0.06
## The plug follows the mouse on an upright plane facing the player, this far in front of the
## bench (local z), in metres; in front of the computers, so that they don't hide the plug.
@export var drag_depth: float = 0.32
## How far the connected cable bows forward of the counter's back, towards %PlugRest, before it
## turns back to the computers, in metres; this slack makes it read as a loose cable.
@export var slack: float = 0.28
## How thick the clickable band along the cord is, in metres. The connected plug hides behind its
## computer, so the cord is where the player grabs the cable.
@export var hit_width: float = 0.06

## True while the plug is in the player's hand: dragged with the button held, or carried after a
## click. [method lay_cable] leaves the plug where it is meanwhile.
var dragging: bool = false:
	set(value):
		dragging = value
		_sync_outline()

var _hovered: bool = false
var _cord_shapes: Array[CollisionShape3D] = []
var _cord_sphere := SphereShape3D.new()

## The bench screen.
@onready var monitor: CrtMonitor = %Monitor
@onready var _screen_hotspot: Hotspot = %ScreenHotspot
@onready var _degauss_hotspot: Hotspot = %DegaussHotspot
@onready var _plug_hotspot: Hotspot = %PlugHotspot
@onready var _cable: Path3D = %Cable
@onready var _outline: CSGPolygon3D = %Outline
@onready var _plug: Node3D = %Plug
@onready var _screen_socket: Marker3D = %ScreenSocket
@onready var _rest: Marker3D = %PlugRest


func _ready() -> void:
	_plug_hotspot.drag_source = true
	_screen_hotspot.clicked.connect(func(h: Hotspot) -> void: view_requested.emit(h.view))
	_plug_hotspot.clicked.connect(func(_h: Hotspot) -> void: plug_grabbed.emit())
	_degauss_hotspot.clicked.connect(func(_h: Hotspot) -> void: degauss_pressed.emit())
	_degauss_hotspot.highlight_on_hover(monitor.get_node(^"DegaussButton"), button_hover_color)
	_plug_hotspot.mouse_entered.connect(_set_hovered.bind(true))
	_plug_hotspot.mouse_exited.connect(_set_hovered.bind(false))
	_sync_outline()
	lay_cable(null)


## Lays the cable from the screen to [param socket], the VGA socket of the connected computer,
## whose +Z points out of the socket. null lays the plug at rest on the counter. Does nothing while
## [member dragging].
func lay_cable(socket: Node3D) -> void:
	if not dragging:
		_lay(_local(socket if socket != null else _rest), socket != null)


## Moves the plug to where the mouse ray from [param from] along [param dir] (world space) meets
## the drag plane (see [member drag_depth]), no lower than the counter top.
func drag_plug(from: Vector3, dir: Vector3) -> void:
	var local_from := to_local(from)
	var local_dir := global_basis.inverse() * dir
	if is_zero_approx(local_dir.z):
		return
	var point := local_from + local_dir * ((drag_depth - local_from.z) / local_dir.z)
	var rest := _local(_rest)
	point.y = maxf(point.y, rest.origin.y)
	_lay(Transform3D(rest.basis, point), false)


# The cable runs along the counter at the height of %PlugRest, behind the computers. With
# [param loose], it first snakes forward past %PlugRest and back, in an S.
func _lay(finish: Transform3D, loose: bool) -> void:
	var start := _local(_screen_socket)
	var rest := _local(_rest).origin
	var counter := rest.y
	var out_of_screen := start.origin + start.basis.z * socket_reach
	var into_end := finish.origin + finish.basis.z * socket_reach
	var behind := Vector3(out_of_screen.x, counter, out_of_screen.z)
	var points: Array[Vector3] = [start.origin, behind]
	if loose:
		points.append(Vector3(rest.x, counter, behind.z + slack))
		points.append(Vector3(lerpf(rest.x, into_end.x, 0.5), counter, behind.z + slack * 0.15))
	points.append_array([
		Vector3(into_end.x, counter, behind.z),
		Vector3(into_end.x, counter, into_end.z),
		finish.origin,
	])
	var curve := Curve3D.new()
	for i in points.size():
		curve.add_point(points[i])
	for i in range(1, points.size() - 1):
		var along := points[i + 1] - points[i - 1]
		along.y = 0.0  # a flat handle keeps the cable from dipping into the counter
		var reach := minf(points[i].distance_to(points[i - 1]), points[i].distance_to(points[i + 1])) * 0.4
		curve.set_point_in(i, -along.normalized() * reach)
		curve.set_point_out(i, along.normalized() * reach)
	curve.set_point_out(0, start.basis.z * socket_reach)
	curve.set_point_in(points.size() - 1, finish.basis.z * socket_reach)
	_cable.curve = curve
	_plug.transform = finish
	_fit_cord_hit_area()


# Lines the cord with spheres in the plug's hotspot, so that the cord takes the plug's hover and clicks.
func _fit_cord_hit_area() -> void:
	var curve := _cable.curve
	var length := curve.get_baked_length()
	var count := maxi(ceili(length / (hit_width * 0.5)), 1) + 1
	_cord_sphere.radius = hit_width * 0.5
	while _cord_shapes.size() < count:
		var shape := CollisionShape3D.new()
		shape.shape = _cord_sphere
		_plug_hotspot.add_child(shape)
		_cord_shapes.append(shape)
	while _cord_shapes.size() > count:
		_cord_shapes.pop_back().queue_free()
	var to_hotspot := (_plug.transform * _plug_hotspot.transform).affine_inverse() * _cable.transform
	for i in count:
		_cord_shapes[i].position = to_hotspot * curve.sample_baked(length * i / (count - 1))


func _local(node: Node3D) -> Transform3D:
	return global_transform.affine_inverse() * node.global_transform


func _set_hovered(on: bool) -> void:
	_hovered = on
	_sync_outline()


func _sync_outline() -> void:
	if not is_node_ready():
		return
	_outline.visible = dragging or _hovered
	(_outline.material as StandardMaterial3D).albedo_color = held_color if dragging else hover_color
