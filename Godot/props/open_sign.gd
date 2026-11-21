class_name OpenSign
extends Node3D
## The sign that hangs in the shop window. Its OPEN side faces the street while the shop is open,
## so the player, inside, reads CLOSED; while the shop is closed, the player reads OPEN. Its origin
## is where the strings hang from. It takes clicks only while [method Game.can_open] or
## [method Game.can_close] is true, and then a yellow outline pulses around it.

## The player clicked the sign while [method Game.can_open] is true.
signal open_requested
## The player clicked the sign while [method Game.can_close] is true.
signal close_requested

@export var open_texture: Texture2D
@export var closed_texture: Texture2D
## The outline's opacity at the bottom of each pulse, 0 to 1; the top is 1.
@export_range(0.0, 1.0, 0.01) var pulse_low: float = 0.2
## How long one pulse of the outline takes, in seconds.
@export var pulse_seconds: float = 1.2

var _pulse: Tween

@onready var _board: MeshInstance3D = %Board
@onready var _outline: MeshInstance3D = %Outline
@onready var _hotspot: Hotspot = %Hotspot


func _ready() -> void:
	_hotspot.clicked.connect(_on_clicked)
	Game.changed.connect(_sync)
	_sync()


## The four corners of the board's face, in world space: where the end-of-day question shows.
func board_corners() -> Array[Vector3]:
	var half := (_board.mesh as QuadMesh).size / 2.0
	var corners: Array[Vector3] = []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		corners.append(_board.global_transform * Vector3(corner.x * half.x, corner.y * half.y, 0.0))
	return corners


func _sync() -> void:
	var open := Game.phase == Game.Phase.OPEN or Game.phase == Game.Phase.CALLING
	(_board.material_override as ShaderMaterial).set_shader_parameter("albedo_texture", closed_texture if open else open_texture)
	var clickable := Game.can_open() or Game.can_close()
	_hotspot.set_enabled(clickable)
	if clickable == _outline.visible:
		return
	_outline.visible = clickable
	if _pulse != null:
		_pulse.kill()
		_pulse = null
	if clickable:
		var material := _outline.material_override as StandardMaterial3D
		_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(material, "albedo_color:a", pulse_low, pulse_seconds / 2.0).from(1.0)
		_pulse.tween_property(material, "albedo_color:a", 1.0, pulse_seconds / 2.0)


func _on_clicked(_h: Hotspot) -> void:
	if Game.can_open():
		open_requested.emit()
	elif Game.can_close():
		close_requested.emit()
