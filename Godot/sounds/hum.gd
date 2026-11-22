class_name Hum
extends AudioStreamPlayer3D
## A quiet loop from a thing that runs: a lit bulb, a computer's fans, a CRT. It plays while [member on].
## Its stream must loop (edit/loop_mode in its .import). Each start picks a random place in the loop,
## so that two hums of the same sound don't play in step.

## Whether the hum plays. Turning it on starts the loop; turning it off stops it at once. Setting
## the value that it has already does nothing, so a caller may set it every frame.
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
		play(randf() * stream.get_length())
