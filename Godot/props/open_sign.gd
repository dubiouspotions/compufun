class_name OpenSign
extends Node3D
## The sign that hangs in the shop window. The player, inside, reads the back of what the street
## reads: OPEN while the shop is closed, a click away from opening, and CLOSED while it is open.
## Its origin is where the strings hang from. It takes clicks only while [method Game.can_open] or
## [method Game.can_close] is true, and then a yellow outline pulses around it. [method shake]
## swings it on its strings to draw the eye. When the shop opens or closes, it turns over on its
## strings with [member flip_sound]; a restore or a new day shows the side at once.

## The player clicked the sign while [method Game.can_open] is true.
signal open_requested
## The player clicked the sign while [method Game.can_close] is true.
signal close_requested

## The face that reads OPEN, which the player sees while the shop is closed.
@export var open_texture: Texture2D
## The face that reads CLOSED, which the player sees while the shop is open.
@export var closed_texture: Texture2D
## The outline's opacity at the bottom of each pulse, 0 to 1; the top is 1.
@export_range(0.0, 1.0, 0.01) var pulse_low: float = 0.2
## How long one pulse of the outline takes, in seconds.
@export var pulse_seconds: float = 1.2
## Plays when the sign turns over: the shop opens, or closes for the night.
@export var flip_sound: SoundSet = preload("res://sounds/sign_flip.tres")
## Plays with each [method shake]; tools/make_shop_sounds.py times its ticks to the default shake.
@export var rattle_sound: SoundSet = preload("res://sounds/sign_rattle.tres")
## How long the sign takes to turn over, in seconds.
@export_range(0.05, 3.0, 0.05) var flip_seconds: float = 0.5
## How long one [method shake] lasts, in seconds.
@export_range(0.05, 3.0, 0.05) var shake_seconds: float = 0.6
## How far a [method shake] first swings the sign to each side, in degrees; the swings die out.
@export_range(0.0, 45.0) var shake_degrees: float = 9.0
## How many times a [method shake] swings back and forth.
@export_range(1.0, 10.0) var shake_swings: float = 4.0

var _pulse: Tween
var _shake: Tween
var _flip: Tween
var _rest_y: float
var _rest_z: float
# Whether the shop was open on the last sync: a change turns the sign over.
var _was_open: bool
var _jump: int

@onready var _board: MeshInstance3D = %Board
@onready var _outline: MeshInstance3D = %Outline
@onready var _hotspot: Hotspot = %Hotspot


func _ready() -> void:
	_rest_y = rotation.y
	_rest_z = rotation.z
	_was_open = _open()
	_jump = Game.jump
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


## Swings the sign on its strings for [member shake_seconds], from where it hangs. A shake while
## one runs starts over.
func shake() -> void:
	if _shake != null:
		_shake.kill()
	_shake = create_tween()
	_shake.tween_method(_swing, 0.0, 1.0, shake_seconds)
	rattle_sound.play_at(self)


## True while a [method shake] runs.
func is_shaking() -> bool:
	return _shake != null and _shake.is_running()


func _swing(progress: float) -> void:
	rotation.z = _rest_z + deg_to_rad(shake_degrees) * sin(TAU * shake_swings * progress) * (1.0 - progress)


func _open() -> bool:
	return Game.phase == Game.Phase.OPEN or Game.phase == Game.Phase.CALLING


func _sync() -> void:
	var open := _open()
	var side := closed_texture if open else open_texture
	if open != _was_open and Game.jump == _jump:
		flip_sound.play_at(self)
		_turn_over(side)
	elif Game.jump != _jump or _flip == null or not _flip.is_running():
		_stop_turning()
		_show_side(side)
	_was_open = open
	_jump = Game.jump
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


# Turns the sign edge-on, shows [param side], and turns it back, in [member flip_seconds].
func _turn_over(side: Texture2D) -> void:
	_stop_turning()
	_flip = create_tween().set_trans(Tween.TRANS_SINE)
	_flip.tween_property(self, "rotation:y", _rest_y + PI / 2.0, flip_seconds / 2.0).set_ease(Tween.EASE_IN)
	_flip.tween_callback(_show_side.bind(side))
	_flip.tween_property(self, "rotation:y", _rest_y, flip_seconds / 2.0).from(_rest_y - PI / 2.0).set_ease(Tween.EASE_OUT)


func _stop_turning() -> void:
	if _flip != null:
		_flip.kill()
		_flip = null
	rotation.y = _rest_y


func _show_side(side: Texture2D) -> void:
	(_board.material_override as ShaderMaterial).set_shader_parameter("albedo_texture", side)


func _on_clicked(_h: Hotspot) -> void:
	if Game.can_open():
		open_requested.emit()
	elif Game.can_close():
		close_requested.emit()
