extends Node3D
## A ceiling light panel: a cold tube that stutters now and then, more often on later days. The
## panel glows in the colour of the light.

## How often the light flickers on each day, from day 1, in flickers per minute. Days past the end
## use the last value; before the first day, the first.
@export var flickers_per_minute: PackedFloat32Array = PackedFloat32Array([1.0, 2.0, 3.0, 5.0, 8.0, 12.0, 18.0])
## How long one flicker lasts.
@export_range(0.05, 2.0, 0.01, "suffix:s") var flicker_seconds: float = 0.4
## The brightness that the light drops to in a flicker, as a share of its full energy.
@export_range(0.0, 1.0) var flicker_low: float = 0.1

var _energy: float
var _panel_material: StandardMaterial3D
var _flicker: Tween

@onready var _light: OmniLight3D = $Light
@onready var _panel: MeshInstance3D = $Panel


func _ready() -> void:
	_energy = _light.light_energy
	var material := _panel.material_override as StandardMaterial3D
	if material == null:
		push_error("%s: Panel needs a StandardMaterial3D material_override, not %s" % [get_path(), _panel.material_override])
		set_process(false)
		return
	_panel_material = material.duplicate() as StandardMaterial3D  # per light, so one can flicker alone
	_panel.material_override = _panel_material
	_set_level(1.0)


func _process(delta: float) -> void:
	if _flicker != null and _flicker.is_running():
		return
	if randf() < _flickers_today() / 60.0 * delta:
		_start_flicker()


func _flickers_today() -> float:
	if flickers_per_minute.is_empty():
		return 0.0
	return flickers_per_minute[clampi(Game.day_number - 1, 0, flickers_per_minute.size() - 1)]


func _start_flicker() -> void:
	_flicker = create_tween()
	var left := flicker_seconds
	var dark := true
	while left > 0.0:
		var level := randf_range(flicker_low, 0.4) if dark else randf_range(0.7, 1.0)
		var step := minf(randf_range(0.03, 0.09), left)
		_flicker.tween_callback(_set_level.bind(level))
		_flicker.tween_interval(step)
		left -= step
		dark = not dark
	_flicker.tween_callback(_set_level.bind(1.0))


func _set_level(level: float) -> void:
	_light.light_energy = _energy * level
	var glow := lerpf(0.35, 1.0, level)
	var c := _light.light_color
	_panel_material.albedo_color = Color(c.r * glow, c.g * glow, c.b * glow)
