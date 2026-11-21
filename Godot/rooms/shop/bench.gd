class_name Bench
extends Node3D
## The left end of the counter: the bench screen, its keyboard and the VGA cable. A click on the
## cable unplugs it and puts its plug in the player's hand; a click on a computer then plugs it in
## there ([method plug_into]), and a second click on the cable puts the plug down. The room lays the
## cable to the connected computer with [method lay_cable].

## The player clicked the screen: go to [param view].
signal view_requested(view: StringName)

## The outline colour of the cable while the mouse is over it.
@export var hover_color: Color = Color(0.75, 0.9, 1.0)
## The outline colour of the cable while the player holds its plug.
@export var held_color: Color = Color(1.0, 0.82, 0.2)
## How far the cable runs straight out of a socket before it bends to the counter, in metres.
@export var socket_reach: float = 0.06

## True while the player holds the plug: the next click on a computer plugs it in there.
var holding: bool = false:
	set(value):
		holding = value
		_sync_outline()

var _hovered: bool = false

@onready var _monitor: CrtMonitor = %Monitor
@onready var _screen_hotspot: Hotspot = %ScreenHotspot
@onready var _cable_hotspot: Hotspot = %CableHotspot
@onready var _cable: Path3D = %Cable
@onready var _outline: CSGPolygon3D = %Outline
@onready var _plug: Node3D = %Plug
@onready var _screen_socket: Marker3D = %ScreenSocket
@onready var _rest: Marker3D = %PlugRest


func _ready() -> void:
	_screen_hotspot.clicked.connect(func(h: Hotspot) -> void: view_requested.emit(h.view))
	_cable_hotspot.clicked.connect(func(_h: Hotspot) -> void: _on_cable_clicked())
	_cable_hotspot.mouse_entered.connect(_set_hovered.bind(true))
	_cable_hotspot.mouse_exited.connect(_set_hovered.bind(false))
	_sync_outline()
	lay_cable(null)


## The four corners of the bench screen, in world space.
func screen_corners() -> Array[Vector3]:
	return _monitor.screen_corners()


## Shows [param texture] (the screen buffer) on the bench screen.
func set_screen_texture(texture: Texture2D) -> void:
	_monitor.set_screen_texture(texture)


## Plugs the held plug into the computer of [param job] (Game.connect_cable) and empties the
## player's hand. Does nothing unless the player holds the plug.
func plug_into(job: Job) -> void:
	if not holding:
		return
	holding = false
	Game.connect_cable(job)


## Lays the cable from the screen to [param socket], the VGA socket of the connected computer,
## whose +Z points out of the socket. null lays the plug at rest on the counter. The cable runs
## along the counter at the height of %PlugRest, behind the computers.
func lay_cable(socket: Node3D) -> void:
	var end := socket if socket != null else _rest
	var start := _local(_screen_socket)
	var finish := _local(end)
	var counter := _local(_rest).origin.y
	var out_of_screen := start.origin + start.basis.z * socket_reach
	var into_end := finish.origin + finish.basis.z * socket_reach
	var behind := Vector3(out_of_screen.x, counter, out_of_screen.z)
	var points: Array[Vector3] = [
		start.origin,
		behind,
		Vector3(into_end.x, counter, behind.z),
		Vector3(into_end.x, counter, into_end.z),
		finish.origin,
	]
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


func _local(node: Node3D) -> Transform3D:
	return global_transform.affine_inverse() * node.global_transform


func _on_cable_clicked() -> void:
	if holding:
		holding = false
		return
	Game.connect_cable(null)
	holding = true


func _set_hovered(on: bool) -> void:
	_hovered = on
	_sync_outline()


func _sync_outline() -> void:
	if not is_node_ready():
		return
	_outline.visible = holding or _hovered
	(_outline.material as StandardMaterial3D).albedo_color = held_color if holding else hover_color
