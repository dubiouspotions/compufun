extends "res://dev/trailer/trailer.gd"
## The cheerful commercial with more Windows 95: the repaired computer's desktop crashes first, then
## shows the Start menu, Solitaire and the fix, and the job offer comes as a Win95 question on it, all
## in Win95's own windows on the bench screen.

func _init() -> void:
	music_speed = 0.910


func _shots() -> void:
	_music = _sound(MUSIC, MUSIC_DB)
	_music.pitch_scale = music_speed
	await _problems()
	await _angry_faces()
	await _parts()
	await _budget()
	await _repair()
	var win95 := await _boot_to_windows()
	if win95 != null:
		AudioServer.set_bus_mute(_shop_bus, false)
		var desktop := win95.get_node(^"Desktop") as Control
		var crash := _desktop_box(desktop, "SKATE.EXE", "This program has performed an illegal\noperation and will be shut down.")
		_new_card(Color.BLACK, Color.BLACK, true)
		_caption("CRASHES?", 150, Vector2(1560, 200), Color.WHITE, 5.0, 0.3)
		await _wait(1.0)
		crash.queue_free()
		await _tour(win95)
	await _before_after()
	if win95 != null:
		await _job_offer(win95)
	await _come_by()
	await _intro_and_glitch()


# The job offer as a Win95 question on the bench screen's desktop.
func _job_offer(win95: Control) -> void:
	AudioServer.set_bus_mute(_shop_bus, false)
	var desktop := win95.get_node(^"Desktop") as Control
	desktop.call(&"close_all")
	_desktop_box(desktop, "Help Wanted", "We're looking for employees!\nIt's a chill gig. The week will fly by!", null, ["Yes!", "No"])
	_new_card(Color.BLACK, Color.BLACK, true)
	_caption("NOW HIRING!", 150, Vector2(1500, 200), YELLOW, -5.0)
	await _wait(maxf(_say(SAY_HIRING), 2.6) + 0.25)
	AudioServer.set_bus_mute(_shop_bus, true)
