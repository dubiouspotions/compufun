class_name OpenSign
extends Node3D
## The sign that hangs in the shop window: OPEN while the shop is open, CLOSED otherwise. Its
## origin is where the strings hang from; the board swings about it.

@export var open_texture: Texture2D
@export var closed_texture: Texture2D
## How far the sign swings when the player tries to close the shop too early, in degrees.
@export var wobble_degrees: float = 9.0
## How long the swing lasts, in seconds.
@export var wobble_seconds: float = 0.6

var _wobble: Tween

@onready var _board: MeshInstance3D = %Board


func _ready() -> void:
	Game.changed.connect(_sync)
	_sync()


## Swings the sign briefly, to show that it does not turn yet.
func wobble() -> void:
	if _wobble != null:
		_wobble.kill()
	rotation.z = 0.0
	_wobble = create_tween().set_trans(Tween.TRANS_SINE)
	var step := wobble_seconds / 4.0
	for degrees: float in [wobble_degrees, -wobble_degrees * 0.6, wobble_degrees * 0.3, 0.0]:
		_wobble.tween_property(self, "rotation:z", deg_to_rad(degrees), step)


func _sync() -> void:
	var open := Game.phase == Game.Phase.OPEN or Game.phase == Game.Phase.CALLING
	(_board.material_override as ShaderMaterial).set_shader_parameter("albedo_texture", open_texture if open else closed_texture)
