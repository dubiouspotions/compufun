class_name CeilingLight
extends Node3D
## A ceiling light panel: a cold tube that is on only in [member lit_dayparts], blinks on when it
## switches on, and stutters now and then, more often on later days. The panel glows in the colour
## of the light. [method cover] blacks the lights out to hide a change in the shop.

## Every ceiling light, for [method cover].
const GROUP: StringName = &"ceiling_lights"

## The names of the Game.Daypart values in which the light is on. In the others it is off, so the
## daylight comes through the windows.
@export var lit_dayparts: Array[StringName] = [&"AFTERNOON", &"EVENING", &"NIGHT"]
## How often the light flickers on each day, from day 1, in flickers per minute. Days past the end
## use the last value; before the first day, the first.
@export var flickers_per_minute: PackedFloat32Array = PackedFloat32Array([1.0, 2.0, 3.0, 5.0, 8.0, 12.0, 18.0])
## How long one flicker lasts.
@export_range(0.05, 2.0, 0.01, "suffix:s") var flicker_seconds: float = 0.4
## The brightness that the light drops to in a flicker, as a share of its full energy.
@export_range(0.0, 1.0) var flicker_low: float = 0.1
## How long the tube stutters when it switches on. Each light waits up to [member blink_delay]
## first, so that the lights in a room don't blink in step.
@export_range(0.0, 3.0, 0.01, "suffix:s") var blink_seconds: float = 0.9
@export_range(0.0, 2.0, 0.01, "suffix:s") var blink_delay: float = 0.6
## How long the light stays dark in [method cover] before it stutters back on.
@export_range(0.05, 2.0, 0.01, "suffix:s") var cover_seconds: float = 0.3

var _energy: float
var _panel_material: StandardMaterial3D
var _flicker: Tween
var _lit: bool = false

@onready var _light: OmniLight3D = $Light
@onready var _panel: MeshInstance3D = $Panel


## Blacks out every ceiling light in [param tree] that is lit, or switches on now, for its
## [member cover_seconds], then stutters it back on, and calls [param in_the_dark] halfway through the
## dark. With no light lit it calls it at once.
static func cover(tree: SceneTree, in_the_dark: Callable) -> void:
	var lit: Array[CeilingLight] = []
	for node: Node in tree.get_nodes_in_group(GROUP):
		var light := node as CeilingLight
		if light != null and light._lit_now():
			lit.append(light)
	if lit.is_empty():
		in_the_dark.call()
		return
	for light: CeilingLight in lit:
		light._black_out()
	tree.create_timer(lit[0].cover_seconds * 0.5).timeout.connect(in_the_dark)


func _ready() -> void:
	add_to_group(GROUP)
	_energy = _light.light_energy
	var material := _panel.material_override as StandardMaterial3D
	if material == null:
		push_error("%s: Panel needs a StandardMaterial3D material_override, not %s" % [get_path(), _panel.material_override])
		set_process(false)
		return
	_panel_material = material.duplicate() as StandardMaterial3D  # per light, so one can flicker alone
	_panel.material_override = _panel_material
	for daypart: StringName in lit_dayparts:
		if not Game.Daypart.has(String(daypart)):
			push_error("%s: lit_dayparts has \"%s\", which is not one of %s" % [get_path(), daypart, Game.Daypart.keys()])
	_lit = _lit_now()
	_set_level(1.0 if _lit else 0.0)
	Game.changed.connect(_sync)


func _process(delta: float) -> void:
	if not _lit or (_flicker != null and _flicker.is_running()):
		return
	if randf() < _flickers_today() / 60.0 * delta:
		_stutter(flicker_seconds, 0.0)


func _sync() -> void:
	var lit := _lit_now()
	if lit == _lit:
		return
	_lit = lit
	if _flicker != null:
		_flicker.kill()
	_set_level(0.0)
	if lit:
		_stutter(blink_seconds, randf_range(0.0, blink_delay))


func _lit_now() -> bool:
	return lit_dayparts.has(StringName(Game.Daypart.find_key(Game.daypart)))


func _flickers_today() -> float:
	if flickers_per_minute.is_empty():
		return 0.0
	return flickers_per_minute[clampi(Game.day_number - 1, 0, flickers_per_minute.size() - 1)]


func _black_out() -> void:
	if _flicker != null:
		_flicker.kill()
	_set_level(0.0)
	_flicker = create_tween()
	_flicker.tween_interval(cover_seconds)
	_flicker.tween_callback(_stutter.bind(blink_seconds, 0.0))


# Alternates dark and bright steps for [param seconds], after [param delay], and ends at full.
func _stutter(seconds: float, delay: float) -> void:
	_flicker = create_tween()
	if delay > 0.0:
		_flicker.tween_interval(delay)
	var left := seconds
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
	_light.visible = level > 0.0  # an off light skips its shadow pass
	var glow := lerpf(0.35, 1.0, level)
	var c := _light.light_color
	_panel_material.albedo_color = Color(c.r * glow, c.g * glow, c.b * glow)
