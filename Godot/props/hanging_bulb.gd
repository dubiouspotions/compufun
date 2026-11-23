extends Node3D
## A bare bulb on a cord; the origin is where the cord meets the ceiling. The bulb is off while the
## story flag [member off_flag] is set; while it is lit, it hums faintly on the mains.

## The flag in Game.flags that switches the bulb off while it is set. Empty: the bulb is always on.
@export var off_flag: StringName = &""
@export var lit_material: Material
@export var off_material: Material
## The box, in the bulb's space, that its shadow falls in: the shadow renders only while the camera
## sees part of it, because a shadow costs six passes over everything in the light's range in every
## frame (docs/performance.md). Empty: the shadow renders always, if the light casts one.
@export var shadow_bounds: AABB = AABB()
## The views (Game.view) in which the shadow renders even while [member shadow_bounds] is out of
## sight, for the light that it shapes outside the box.
@export var shadow_views: Array[StringName] = []

var _shadow_seen: VisibleOnScreenNotifier3D

@onready var _light: OmniLight3D = $Light
@onready var _bulb: MeshInstance3D = $Bulb
@onready var _hum: Hum = $Hum
@onready var _casts_shadow: bool = _light.shadow_enabled


func _ready() -> void:
	if shadow_bounds.has_volume():
		_shadow_seen = VisibleOnScreenNotifier3D.new()
		_shadow_seen.aabb = shadow_bounds
		add_child(_shadow_seen, false, Node.INTERNAL_MODE_BACK)
		_shadow_seen.screen_entered.connect(_sync)
		_shadow_seen.screen_exited.connect(_sync)
	Game.changed.connect(_sync)
	_sync()


func _sync() -> void:
	var on := off_flag == &"" or Game.flag(off_flag) == 0
	_light.visible = on
	_light.shadow_enabled = _casts_shadow and (_shadow_seen == null or _shadow_seen.is_on_screen() or Game.view in shadow_views)
	_bulb.material_override = lit_material if on else off_material
	_hum.on = on
