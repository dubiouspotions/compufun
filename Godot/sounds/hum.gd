class_name Hum
extends AudioStreamPlayer3D
## A quiet loop from a thing that runs: a lit bulb, a computer's fans, a CRT. It plays while [member on].
## Its stream must loop (edit/loop_mode in its .import). Each start picks a random place in the loop,
## so that two hums of the same sound don't play in step, unless [member from_clock].

## Whether the hum plays. Turning it on starts the loop; turning it off stops it at once. Setting
## the value that it has already does nothing, so a caller may set it every frame.
## Starts at the clock's place in the loop (the seconds since the game started, modulo its length),
## so that something that moves by the same clock keeps in step with it, as a heart with its beat.
@export var from_clock: bool = false
var on: bool = false:
	set(value):
		if value == on:
			return
		on = value
		if is_inside_tree():
			_sync()


func _enter_tree() -> void:
	area_mask = SoundSet.SOUND_ZONES
	_sync()


func _sync() -> void:
	if not on:
		stop()
	elif stream == null:
		push_error("Hum %s has no stream" % get_path())
	else:
		var length := stream.get_length()
		play(fmod(Time.get_ticks_msec() / 1000.0, length) if from_clock else randf() * length)
