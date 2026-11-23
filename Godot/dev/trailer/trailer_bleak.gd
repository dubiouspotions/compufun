extends "res://dev/trailer/trailer.gd"
## The same commercial, deadpan, as if made in a grey city in 1996: slow, still shots of the shop as
## the game shows it, in the rain at dusk, a tired narrator, plain white lines, no music but the rain,
## the street and the room, and the CompuFun jingle, slowed down, at the end.

const CUSTOMER := "res://customers/retired_accountant.tres"
const JINGLE: AudioStream = preload("res://sounds/compufun_jingle.ogg")
const LOGO: Texture2D = preload("res://ui/logos/compufun_logo.png")
## The jingle at the end plays this slow, and this loud in dB.
const JINGLE_SPEED := 0.72
const JINGLE_DB := -6.0
## How much louder than in the game the shop sounds: the rain, the street and the room carry it.
const AMBIENCE_DB := 9.0
## The pause after each line, in seconds: the deadpan beat.
const BEAT := 1.0
## Day 2 rains; with three customers come, it is dusk.
const DUSK := {"day": 2, "phase": "OPEN", "arrivals": 3}

var _plain: SystemFont
var _dip: ColorRect


func _init() -> void:
	narrator = preload("res://voices/persons/middle_manager.tres")
	narrator_mood = &"thinking"
	tears = false
	grey = 0.45
	tint = Color(0.9, 0.97, 0.95)


func _shots() -> void:
	_plain = SystemFont.new()
	_plain.font_names = PackedStringArray(["Helvetica Neue", "Arial"])
	AudioServer.set_bus_mute(_shop_bus, false)
	AudioServer.set_bus_volume_db(_shop_bus, AMBIENCE_DB)
	# The customer's arrival starts his conversation; this commercial neither shows nor plays it.
	(_main.get_node("UI/DialogueOverlay") as CanvasItem).modulate.a = 0.0
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Voice"), true)
	var dip_layer := CanvasLayer.new()
	dip_layer.layer = 126
	_tv.add_child(dip_layer)
	_dip = ColorRect.new()
	_dip.color = Color.BLACK
	_dip.size = SCREEN
	_dip.modulate.a = 0.0
	dip_layer.add_child(_dip)

	_restore(_dusk({"view": "Main"}))
	await _tell("Your computer is broken.", 3.5)

	_restore(_dusk({"visitor": CUSTOMER, "visit": "DROP_OFF", "visitor_state": "WALKING_IN", "view": "Main"}))
	await _tell("It is not your fault.", 2.6)
	await _tell("Bring it to CompuFun.", 2.6, "Bring it to Compu fun.")

	var job := {"customer": CUSTOMER, "problem": "hamster", "slot": 0, "order": 0}
	await _cut(_dusk({"jobs": [job], "focus_slot": 0, "view": "Workview"}))
	var shop_job: Job = Game.jobs[0]
	await _wait(0.5)
	Game.lay_down(shop_job)
	_line("We will open it.")
	var said := _say("We will open it.")
	await _wait(1.4)
	for screw in shop_job.panel_screws.size():
		Game.turn_screw(shop_job, screw)
		await _wait(1.0)
	await _wait(maxf(said - 3.4, 0.0))
	Game.open_case(shop_job, true)
	await _wait(1.0)
	Game.take_blocker(shop_job)
	await _wait(0.4)
	await _tell("Sometimes, there is a hamster.", 3.0)

	await _cut(_dusk({"jobs": [job], "db_day": 2, "view": "CompuFunDB"}))
	await _tell("We will write it down.", 3.2)

	job.merge({"hardware_fixed": true, "tested": true, "blocker": false}, true)
	await _cut(_dusk({"jobs": [job], "view": "Main"}))
	Game.pick_up_phone()
	Game.call_customer(Game.jobs[0])
	await _tell("We will call you.", 2.6)

	var night := _main.get_node("UI/EndOfDay")
	night.set(&"dusk_seconds", 2.5)
	night.set(&"fade_seconds", 1.5)
	night.set(&"black_seconds", 0.8)
	await _cut(_dusk({"view": "Main"}))
	Game.close_shop()
	await _tell("Tomorrow, it will break again.", 4.0)
	_new_card(Color.BLACK, Color.BLACK, true)
	await _wait(3.4)

	await _end_card()


# A dip to black and back between two shots, which also hides the camera's turn to the new view.
func _cut(state: Dictionary) -> void:
	await create_tween().tween_property(_dip, "modulate:a", 1.0, 0.3).finished
	_new_card(Color.BLACK, Color.BLACK, true)
	_restore(state)
	await _wait(0.8)
	await create_tween().tween_property(_dip, "modulate:a", 0.0, 0.4).finished


# Dusk on the rainy day, with [param more] on top: a state for Game.restore.
func _dusk(more: Dictionary) -> Dictionary:
	var state := DUSK.duplicate()
	state.merge(more, true)
	return state


# Shows [param text] and says it, or [param spoken] where the voice needs another spelling, then
# waits at least [param seconds] and the beat.
func _tell(text: String, seconds: float, spoken: String = "") -> void:
	_line(text)
	await _wait(maxf(_say(spoken if spoken != "" else text), seconds) + BEAT)


# One plain white line on a dark band low on the screen, as cheap TV subtitles; it replaces the one
# before.
func _line(text: String) -> void:
	_new_card(Color.BLACK, Color.BLACK, true)
	var label := Label.new()
	label.text = text
	var settings := LabelSettings.new()
	settings.font = _plain
	settings.font_size = 54
	settings.font_color = Color(0.94, 0.94, 0.9)
	settings.shadow_color = Color(0, 0, 0, 0.75)
	settings.shadow_size = 6
	settings.shadow_offset = Vector2(3, 3)
	label.label_settings = settings
	var band := StyleBoxFlat.new()
	band.bg_color = Color(0, 0, 0, 0.6)
	band.content_margin_left = 28
	band.content_margin_right = 28
	band.content_margin_top = 6
	band.content_margin_bottom = 10
	label.add_theme_stylebox_override(&"normal", band)
	_card.add_child(label)
	label.size = label.get_combined_minimum_size()
	label.position = Vector2((SCREEN.x - label.size.x) / 2.0, 900)
	create_tween().tween_property(label, "modulate:a", 1.0, 0.5).from(0.0)


# The logo on its white paper, as the game's loading screen shows it, the promise, and the jingle,
# slowed down.
func _end_card() -> void:
	_new_card(Color.BLACK, Color.BLACK, true)
	var paper := ColorRect.new()
	paper.color = Color.WHITE
	paper.size = SCREEN
	_card.add_child(paper)
	create_tween().tween_property(paper, "modulate:a", 1.0, 1.0).from(0.0)
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size = Vector2(720, 300)
	logo.position = Vector2((SCREEN.x - 720) / 2.0, 300)
	_card.add_child(logo)
	create_tween().tween_property(logo, "modulate:a", 1.0, 1.2).from(0.0)
	var jingle := _sound(JINGLE, JINGLE_DB)
	jingle.pitch_scale = JINGLE_SPEED
	await _wait(1.0)
	var label := Label.new()
	label.text = "It will be a lot of fun."
	var settings := LabelSettings.new()
	settings.font = _plain
	settings.font_size = 48
	settings.font_color = Color(0.25, 0.25, 0.25)
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(SCREEN.x, 70)
	label.position = Vector2(0, 690)
	_card.add_child(label)
	create_tween().tween_property(label, "modulate:a", 1.0, 0.8).from(0.0)
	await _wait(maxf(_say("Compu fun. It will be a lot of fun."), JINGLE.get_length() / JINGLE_SPEED - 1.0) + 2.5)
