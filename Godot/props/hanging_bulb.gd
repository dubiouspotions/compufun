extends Node3D
## A bare bulb on a cord; the origin is where the cord meets the ceiling. The bulb is off while the
## story flag [member off_flag] is set; while it is lit, it hums faintly on the mains.

## The flag in Game.flags that switches the bulb off while it is set. Empty: the bulb is always on.
@export var off_flag: StringName = &""
@export var lit_material: Material
@export var off_material: Material

@onready var _light: OmniLight3D = $Light
@onready var _bulb: MeshInstance3D = $Bulb
@onready var _hum: Hum = $Hum


func _ready() -> void:
	Game.changed.connect(_sync)
	_sync()


func _sync() -> void:
	var on := off_flag == &"" or Game.flag(off_flag) == 0
	_light.visible = on
	_bulb.material_override = lit_material if on else off_material
	_hum.on = on
