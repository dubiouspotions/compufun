extends "res://dev/trailer/trailer.gd"
## The same commercial, deadpan, as if made in a grey city in 1996: slow, still shots of the shop as
## the game shows it, in the rain at dusk, a tired narrator, plain white lines, no music but the rain,
## the street and the room, the job offer on the note taped to the counter, and the CompuFun intro,
## its jingle and ink slowed down, at the end.

const CUSTOMER := "res://customers/retired_accountant.tres"
const DISPLAY: Applet = preload("res://win95/applets/display.tres")
const TAPED_NOTE := "res://props/taped_note.tscn"
const HIRING_NOTE := "NOW HIRING!\nIt's a chill gig.\nThe week will fly by!"
## The intro's jingle at the end plays this slow; the ink follows it.
const JINGLE_SPEED := 0.72
## How much louder than in the game the shop sounds: the rain, the street and the room carry it.
const AMBIENCE_DB := 9.0
## The pause after each line, in seconds: the deadpan beat.
const BEAT := 0.8
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
	var waited := 0.0
	while Game.visitor_state == Game.VisitorState.WALKING_IN and waited < 8.0:
		await _wait(0.1)
		waited += 0.1
	await _wait(0.8)

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
		await _wait(0.8)
	await _wait(maxf(said - 3.0, 0.0))
	Game.open_case(shop_job, true)
	await _wait(1.0)
	Game.take_blocker(shop_job)
	await _wait(0.4)
	await _tell("Sometimes, there is a hamster.", 3.0)

	await _cut(_dusk({"view": "Left"}))
	Game.go_to_view(&"Storage")
	await _wait(1.6)
	Game.take_new_part(FAN)
	await _tell("We have spare parts.", 2.4)
	await _tell("Most of them work.", 2.4)

	await _windows()

	await _cut(_dusk({"jobs": [job], "db_day": 2, "view": "CompuFunDB"}))
	await _tell("We will write it down.", 3.2)

	job.merge({"hardware_fixed": true, "tested": true, "blocker": false}, true)
	await _cut(_dusk({"jobs": [job], "view": "Main"}))
	Game.pick_up_phone()
	Game.call_customer(Game.jobs[0])
	await _tell("We will call you.", 2.6)

	await _cut(_dusk({"view": "Main"}))
	for note: Node in _main.find_children("*", "Node3D", true, false):
		if note.scene_file_path == TAPED_NOTE:
			(note.get_node("Text") as Label3D).text = HIRING_NOTE
			(note.get_node("Arrow") as Node3D).hide()  # it points at the Open sign, for the note's own text
	await _wait(0.6)
	Game.go_to_view(&"Note")
	await _wait(1.4)
	_new_card(Color.BLACK, Color.BLACK, true)  # the note says it; no subtitle
	await _wait(_say("We are hiring.") + BEAT)
	await _wait(maxf(_say("It's a chill gig. The week will fly by."), 3.4) + BEAT)

	await _logo()


# The bench computer, with its colours broken, comes on with a quick boot behind a dip to black; then
# Display Properties puts its colour scheme back, with a click for each step: Apply first, so the open
# window shows the change.
func _windows() -> void:
	await _dip_to(1.0)
	_new_card(Color.BLACK, Color.BLACK, true)
	get_tree().node_added.connect(_quick_boot)
	var job := {"customer": CUSTOMER, "problem": "inverted_colors", "slot": 0, "order": 0, "powered": true}
	_restore(_dusk({"jobs": [job], "connected_slot": 0, "view": "Screen"}))
	await _wait(0.7)
	var win95 := _shown_desktop()
	var boot: Node = win95.get(&"_boot") if win95 != null else null
	if not is_instance_valid(boot):
		push_error("Trailer: the bench computer is not booting")
		await _dip_to(0.0)
		return
	boot.set(&"_skipped", true)
	var waited := 0.0
	while win95.get(&"pointer_visible") != true and waited < 5.0:
		await _wait(0.1)
		waited += 0.1
	await _dip_to(0.0)
	_line("We know Windows 95.")
	var said := _say("We know Windows 95.")
	await _wait(0.6)
	_click()
	var sheet: Control = (win95.get_node(^"Desktop") as Control).call(&"open", DISPLAY.sheet)
	await _wait(1.0)
	var appearance: Control = null
	for page: Control in sheet.call(&"pages"):
		if page.get_script().resource_path.ends_with("display_appearance.gd"):
			appearance = page
	if appearance == null:
		push_error("Trailer: Display Properties has no Appearance tab")
		return
	_click()
	(sheet.find_child("Tabs", true, false) as TabContainer).current_tab = appearance.get_index()
	await _wait(1.0)
	var scheme := appearance.find_child("Scheme", true, false) as OptionButton
	for i in scheme.item_count:
		if scheme.get_item_text(i) == "Windows Standard":
			_click()
			scheme.select(i)
			scheme.item_selected.emit(i)
	await _wait(1.0)
	_click()
	(sheet.find_child("Apply", true, false) as Button).pressed.emit()
	await _wait(1.4)
	_click()
	(sheet.find_child("Ok", true, false) as Button).pressed.emit()
	await _wait(maxf(said - 5.0, 0.0) + 1.0)


# A dip to black and back between two shots, which also hides the camera's turn to the new view.
func _cut(state: Dictionary) -> void:
	await _dip_to(1.0)
	_new_card(Color.BLACK, Color.BLACK, true)
	_restore(state)
	await _wait(0.6)
	await _dip_to(0.0)


func _dip_to(alpha: float) -> void:
	await create_tween().tween_property(_dip, "modulate:a", alpha, 0.3 if alpha > 0.5 else 0.4).finished


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


# The game's own CompuFun intro, its jingle slowed down, and the ink with it, then the promise.
func _logo() -> void:
	await _dip_to(1.0)
	_new_card(Color.BLACK, Color.BLACK, true)
	var intro := (load("res://ui/loading_screen.tscn") as PackedScene).instantiate()
	intro.set(&"reveal_game", false)
	_tv.add_child(intro)
	(intro.get_node("%Jingle") as AudioStreamPlayer).pitch_scale = JINGLE_SPEED
	_dip.modulate.a = 0.0
	await _wait(2.15 / JINGLE_SPEED + 1.6)
	await _wait(_say("Compu fun. It will be a lot of fun.") + 2.0)
