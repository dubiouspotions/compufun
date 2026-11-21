@tool
extends Node3D
## A 1990s office wall clock. The hour and minute hands show the hour of the Outside node, the
## game's time of day; the second hand ticks on real seconds. The back is at the origin and the face
## looks along +Z, so it hangs on a wall where the origin touches the wall.

const PSX_WORLD: Shader = preload("res://shaders/psx_world.gdshader")

## The diameter of the clock, in metres.
@export_range(0.1, 1.0, 0.01) var diameter: float = 0.45:
	set(value):
		diameter = value
		_apply_look()
@export var rim_color: Color = Color(0.1, 0.1, 0.11):
	set(value):
		rim_color = value
		_apply_look()
@export var face_color: Color = Color(0.95, 0.93, 0.86):
	set(value):
		face_color = value
		_apply_look()
## The colour of the hour marks and the hour and minute hands.
@export var hand_color: Color = Color(0.08, 0.08, 0.09):
	set(value):
		hand_color = value
		_apply_look()
@export var second_hand_color: Color = Color(0.8, 0.08, 0.06):
	set(value):
		second_hand_color = value
		_apply_look()
## Shows the second hand. It ticks on real seconds, so the clock looks alive while the game's time
## stands still.
@export var second_hand: bool = true:
	set(value):
		second_hand = value
		_apply_look()
## Steps the hour and minute hands in whole game minutes instead of moving them smoothly.
@export var tick: bool = false
## How fast the hands run forward to a time up to 12 hours later, such as the next daypart, in game
## hours per real second. 0 jumps; a time that is earlier, or further ahead, always jumps.
@export_range(0.0, 48.0, 0.5) var sweep_hours_per_second: float = 8.0

var _rim_material := _psx_material()
var _face_material := _psx_material()
var _hand_material := _psx_material()
var _second_material := _psx_material()
var _outside: Outside
## The hour that the hands show, 0 to 24, or -1 before the first frame.
var _shown: float = -1.0

@onready var _body: Node3D = $Body
@onready var _hour_hand: MeshInstance3D = $Body/HourHand
@onready var _minute_hand: MeshInstance3D = $Body/MinuteHand
@onready var _second_hand: MeshInstance3D = $Body/SecondHand


func _ready() -> void:
	$Body/Rim.material_override = _rim_material
	$Body/Face.material_override = _face_material
	_hour_hand.material_override = _hand_material
	_minute_hand.material_override = _hand_material
	_second_hand.material_override = _second_material
	for i in 12:
		var quarter := i % 3 == 0
		var mark := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.05, 0.1) if quarter else Vector2(0.03, 0.06)
		mesh.center_offset = Vector3(0.0, 0.38 - mesh.size.y * 0.5, 0.0)
		mark.mesh = mesh
		mark.material_override = _hand_material
		mark.position.z = 0.115
		mark.rotation.z = -TAU * i / 12.0
		_body.add_child(mark)
	_apply_look()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _outside == null:
		_outside = get_tree().get_first_node_in_group(&"outside") as Outside
		if _outside == null:
			push_error("%s: no Outside node in the group \"outside\" to read the time from" % get_path())
			set_process(false)
			return
	var target := _outside.hour
	var ahead := fposmod(target - _shown, 24.0)
	var step := sweep_hours_per_second * delta
	if _shown >= 0.0 and ahead <= 12.0 and ahead > step:
		_shown = fposmod(_shown + step, 24.0)
	else:
		_shown = target
	var hour := floorf(_shown * 60.0) / 60.0 if tick else _shown
	_hour_hand.rotation.z = -TAU * fposmod(hour, 12.0) / 12.0
	_minute_hand.rotation.z = -TAU * fposmod(hour, 1.0)
	_second_hand.rotation.z = -TAU * (Time.get_ticks_msec() / 1000 % 60) / 60.0


func _apply_look() -> void:
	if not is_node_ready():
		return
	_body.scale = Vector3.ONE * diameter
	_rim_material.set_shader_parameter(&"albedo_color", rim_color)
	_face_material.set_shader_parameter(&"albedo_color", face_color)
	_hand_material.set_shader_parameter(&"albedo_color", hand_color)
	_second_material.set_shader_parameter(&"albedo_color", second_hand_color)
	_second_hand.visible = second_hand


static func _psx_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PSX_WORLD
	return material
