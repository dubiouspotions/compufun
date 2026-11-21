extends Node3D
## A modem on the line. Its RD and SD lights flicker in bursts of data with quiet gaps between.

@export var lit_material: Material
@export var off_material: Material
## The lights that flicker with the data: receive (RD) and send (SD).
@export var data_leds: Array[MeshInstance3D] = []
## Seconds that each flicker state holds during a burst.
@export var flicker_seconds: float = 0.07
## The longest burst of data, in seconds; each burst lasts 0.3 s up to this.
@export var max_burst_seconds: float = 1.5
## The longest quiet gap between bursts, in seconds; each gap lasts 0.3 s up to this.
@export var max_quiet_seconds: float = 2.5

var _bursting: bool = false
var _phase_left: float = 0.0
var _flicker_left: float = 0.0


func _process(delta: float) -> void:
	_phase_left -= delta
	if _phase_left <= 0.0:
		_bursting = not _bursting
		_phase_left = randf_range(0.3, max_burst_seconds if _bursting else max_quiet_seconds)
	_flicker_left -= delta
	if _flicker_left > 0.0:
		return
	_flicker_left = flicker_seconds
	for led: MeshInstance3D in data_leds:
		led.material_override = lit_material if _bursting and randf() < 0.5 else off_material
