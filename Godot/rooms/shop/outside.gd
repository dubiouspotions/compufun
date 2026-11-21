class_name Outside
extends Node3D
## The world outside the shop windows: the back alley, the sky, the sun (moonlight at night), the
## lamps, the fog and the rain. It runs the time of day and the weather. The colour gradients go
## over one day: the left end is midnight, the middle is noon.

## The time of day in hours, 0 to 24.
@export_range(0.0, 24.0, 0.01) var hour: float = 13.0:
	set(value):
		hour = fposmod(value, 24.0)
		if is_node_ready():
			_apply()
## Real minutes for one full day. 0 stops the clock.
@export_range(0.0, 120.0, 0.5) var day_minutes: float = 0.0
@export var raining: bool = false:
	set(value):
		raining = value
		if is_node_ready():
			_apply()
@export var sky_top: Gradient
@export var sky_horizon: Gradient
@export var sun_color: Gradient
@export var ambient_color: Gradient
@export var ambient_energy: Curve
## How much rain greys and darkens the sky and the light, 0 to 1.
@export_range(0.0, 1.0) var rain_gloom: float = 0.55
## The fog density without rain and with rain. More fog makes the distance softer.
@export var fog_clear: float = 0.012
@export var fog_rain: float = 0.04
@export var moon_color: Color = Color(0.6, 0.7, 1.0)
@export var moon_energy: float = 0.15
## The energy of the lamps (the lights in the group "lamp") at night. They fade in at dusk.
@export var lamp_energy: float = 1.4

var _lamps: Array[Light3D] = []

@onready var _sun: DirectionalLight3D = %Sun
@onready var _environment: WorldEnvironment = %Environment
@onready var _rain: CPUParticles3D = %Rain


func _ready() -> void:
	add_to_group(&"outside")
	for node: Node in find_children("*", "Light3D"):
		if node.is_in_group(&"lamp"):
			_lamps.append(node as Light3D)
	_apply()


func _process(delta: float) -> void:
	if day_minutes > 0.0:
		hour = hour + delta * 24.0 / (day_minutes * 60.0)


func _apply() -> void:
	var t := hour / 24.0
	var gloom := rain_gloom if raining else 0.0
	var horizon := _grey(sky_horizon.sample(t), gloom)
	var environment := _environment.environment
	var sky := environment.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = _grey(sky_top.sample(t), gloom)
	sky.sky_horizon_color = horizon
	sky.ground_horizon_color = horizon.darkened(0.1)
	sky.ground_bottom_color = horizon.darkened(0.5)
	environment.fog_light_color = horizon
	environment.fog_density = fog_rain if raining else fog_clear
	environment.ambient_light_color = _grey(ambient_color.sample(t), gloom)
	environment.ambient_light_energy = ambient_energy.sample(t) * (1.0 - 0.3 * gloom)
	# Daylight is 1 at noon, 0 at 6 and 18, below 0 at night (then the light is the moon).
	var daylight := sin((hour - 6.0) / 12.0 * PI)
	var elevation := absf(daylight) * 60.0 + 4.0
	var azimuth := lerpf(-60.0, 60.0, fposmod(hour - 6.0, 12.0) / 12.0)
	# Rotated 180 degrees, the light falls in through the windows; the sun shows outside them.
	_sun.rotation_degrees = Vector3(-elevation, 180.0 + azimuth, 0.0)
	if daylight > 0.0:
		_sun.light_color = sun_color.sample(t)
		_sun.light_energy = clampf(daylight * 3.0, 0.0, 1.0) * (1.0 - 0.7 * gloom)
	else:
		_sun.light_color = moon_color
		_sun.light_energy = moon_energy * clampf(-daylight * 3.0, 0.0, 1.0) * (1.0 - 0.7 * gloom)
	# The lamps: off in daylight, on from dusk to dawn, a little on in the rain.
	var dark := maxf(1.0 - clampf(daylight * 4.0, 0.0, 1.0), 0.5 * gloom)
	for lamp: Light3D in _lamps:
		lamp.light_energy = lamp_energy * dark
		lamp.visible = dark > 0.01
	_rain.emitting = raining


static func _grey(color: Color, amount: float) -> Color:
	var luminance := color.get_luminance() * 0.8
	return color.lerp(Color(luminance, luminance, luminance), amount)
