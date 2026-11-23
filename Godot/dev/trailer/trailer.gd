extends Node
## A cheesy TV commercial for CompuFun, as if from 1995: a narrator in the game's own voice synth,
## loud title cards, the latest parts on a turntable (and a budget processor), quick repairs in the
## shop, customers before and after, and the CompuFun intro to end, with one tiny glitch. It all plays
## as on an old TV, filling the frame: the trailer renders at 480 lines, a tape layer wobbles and tears
## it now and then, and it shows through the game's strong CRT look, almost flat. Record
## it with Godot's Movie Maker, then give it tape and TV sound with tools/make_trailer.sh.
## The narrator needs the ChimeraVoice extension: build it with tools/build-voice.sh.

const NARRATOR: VoicePerson = preload("res://voices/persons/handsome_dude.tres")
const SAY_PROBLEMS := "Do you have computer problems?"
const SAY_PARTS := "We have the latest parts! Graphics cards! Processors! Fans!"
const SAY_BUDGET := "And budget options, like the Korean B processor!"
# "Compu fun", not "CompuFun": the dictionary has "compu" (comp-u), and the voice guesses at words it lacks.
const SAY_COME := "Come by Compu fun. It will be a lot of fun!"
const SAY_HIRING := "We're looking for employees! It's a chill gig. The week will fly by!"
const MESSAGE_BOX: PackedScene = preload("res://win95/message_box.tscn")
const SOLITAIRE: PackedScene = preload("res://win95/solitaire/solitaire.tscn")
const WIN95_SCRIPT := "res://win95/win95.gd"
const CLICK_DOWN: SoundSet = preload("res://sounds/mouse_down.tres")
const CLICK_UP: SoundSet = preload("res://sounds/mouse_up.tres")
const KEYS: SoundSet = preload("res://sounds/keystroke.tres")
const FAN: Part = preload("res://parts/fan.tres")
## The sound effects are loud, as in a TV commercial: the clicks and keys get this much on top of
## their game volume, the shop's sounds too, and the music steps back during the repair. A limiter on
## the master bus keeps the peaks from clipping.
const SFX_BOOST_DB := 5.0
const MUSIC_UNDER_SFX_DB := -20.0
const RATCHET_DB := -8.0
## "Sigla 2" by sandroperrotta on Pixabay (Pixabay Content License): the music under the commercial.
const MUSIC: AudioStream = preload("res://dev/trailer/sandroperrotta_sigla_2.mp3")
## The music's volume, and its volume while the narrator speaks, in dB.
const MUSIC_DB := -10.0
const MUSIC_UNDER_VOICE_DB := -18.0
const DING: AudioStream = preload("res://win95/sounds/ding.ogg")
const BUZZ: AudioStream = preload("res://win95/sounds/hang_buzz.wav")
const INK := Color(0.13, 0.02, 0.35)
const YELLOW := Color(1.0, 0.9, 0.23)
const SCREEN := Vector2(1920, 1080)
## The TV's picture: 480 lines, as NTSC, so its scanlines show.
const TV_LINES := Vector2i(854, 480)
const TV_LOOK: ShaderMaterial = preload("res://shaders/crt_looks/strong.tres")
## The strong look, flattened so the picture fills the frame: no rounded corners, no border, a slight curve.
const TV_FLAT := {&"curvature_x": 0.05, &"curvature_y": 0.05, &"corner_radius": 0.0, &"underscan": 0.0,
	&"vignette": 0.3, &"reflection": 0.03, &"noise": 0.035, &"hum_bar": 0.07, &"flicker": 0.03}
## How much larger than the frame the TV picture is drawn, so the slight curve's corners fall outside it.
const TV_ZOOM := 1.08
## A tear runs through the tape about this often, in seconds, at random.
const TEAR_EVERY := Vector2(2.5, 5.0)
const VCR_FONT: Font = preload("res://compufun_db/fonts/Px437_IBM_VGA_8x16.ttf")

const STRIPES := """
shader_type canvas_item;
uniform vec4 top : source_color;
uniform vec4 bottom : source_color;
void fragment() {
	vec3 c = mix(top.rgb, bottom.rgb, UV.y);
	float stripe = step(0.5, fract((UV.x * 1.78 + UV.y) * 7.0 - TIME * 0.5));
	COLOR = vec4(c * (0.86 + 0.14 * stripe), 1.0);
}
"""

const STAR := """
shader_type canvas_item;
uniform float radius = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.9, 0.23, 1.0);
float star(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.7778, -1.0);
	COLOR = vec4(color.rgb, step(star(p, radius, 0.45), 0.0));
}
"""

const TAPE := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float tear = 0.0;
uniform float seed = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float line = floor(uv.y * 480.0);
	float frame = floor(TIME * 30.0);
	uv.x += (hash(vec2(line, frame)) - 0.5) * 0.0016;
	float band_y = 0.96 + 0.015 * sin(TIME * 0.6);
	float band = smoothstep(0.03, 0.0, abs(uv.y - band_y));
	uv.x += band * (hash(vec2(line, frame + 7.0)) - 0.5) * 0.025;
	uv.x += tear * step(0.9, hash(vec2(floor(uv.y * 40.0), frame))) * (hash(vec2(line, 3.0)) - 0.3) * 0.06;
	vec3 c = texture(screen, uv).rgb;
	c = mix(c, vec3(hash(vec2(uv.x * 900.0, line + frame * 17.0))), band * 0.3 + tear * 0.08);
	COLOR = vec4(c, 1.0);
}
"""

const GLITCH := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float amount = 0.0;
uniform float seed = 0.0;
float hash(float n) { return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float band = floor(uv.y * 27.0);
	uv.x += step(0.65, hash(band)) * (hash(band + 3.7) - 0.5) * 0.09 * amount;
	float split = 0.012 * amount;
	vec3 c = vec3(texture(screen, uv + vec2(split, 0.0)).r, texture(screen, uv).g, texture(screen, uv - vec2(split, 0.0)).b);
	c = mix(c, vec3(0.0, 0.0, 0.66), step(0.92, hash(band + 9.1)) * amount);
	COLOR = vec4(c, 1.0);
}
"""

## The test cut with more Windows 95 (trailer_win95.tscn): after the before and after, the bench
## screen shows the desktop of a computer, with an error, the Start menu, Solitaire, a fix and the
## job offer, each in Win95's own windows on that screen. CompuFunDB's shot is left out.
@export var win95_cut: bool = false

var _tv: SubViewport
var _cards: CanvasLayer
var _card: Control
var _font: SystemFont
var _studio: SubViewport
var _turntable: Node3D
var _main: Node
var _shop_bus: int
var _music: AudioStreamPlayer
var _duck: Tween
var _tape: ShaderMaterial


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Impact", "Arial Black", "Helvetica Neue"])
	_build_tv()
	_cards = CanvasLayer.new()
	_cards.layer = 120
	_tv.add_child(_cards)
	_build_studio()
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	_tv.add_child(_main)
	_shop_bus = AudioServer.get_bus_index(&"Shop")
	AudioServer.set_bus_mute(_shop_bus, true)
	await get_tree().process_frame
	(_main.get_node("%ViewNav") as Control).hide()
	_play_sign()
	_silence_win95()
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)
	_music = _sound(MUSIC, MUSIC_DB)
	await _problems()
	await _angry_faces()
	await _parts()
	await _budget()
	await _repair()
	await _tested()
	if win95_cut:
		_skip_boot()
		await _before_after()
		await _win95_desktop()
	else:
		await _compufun_db()
		await _before_after()
	await _hiring()
	await _come_by()
	await _intro_and_glitch()
	get_tree().quit()


# Everything renders into a TV picture of 480 lines, in the 1920 x 1080 layout, and the window shows
# it through the strong CRT look.
func _build_tv() -> void:
	_tv = SubViewport.new()
	_tv.size = TV_LINES
	_tv.size_2d_override = Vector2i(SCREEN)
	_tv.size_2d_override_stretch = true
	_tv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_tv)
	var tape_layer := CanvasLayer.new()
	tape_layer.layer = 150
	_tv.add_child(tape_layer)
	var tape := ColorRect.new()
	tape.size = SCREEN
	_tape = ShaderMaterial.new()
	_tape.shader = Shader.new()
	_tape.shader.code = TAPE
	tape.material = _tape
	tape_layer.add_child(tape)
	_tear_now_and_then()
	var glass := CanvasLayer.new()
	glass.layer = 200
	add_child(glass)
	var screen := ColorRect.new()
	screen.size = SCREEN * TV_ZOOM
	screen.position = -SCREEN * (TV_ZOOM - 1.0) / 2.0
	var look := TV_LOOK.duplicate() as ShaderMaterial
	look.set_shader_parameter(&"screen_texture", _tv.get_texture())
	for uniform: StringName in TV_FLAT:
		look.set_shader_parameter(uniform, TV_FLAT[uniform])
	screen.material = look
	glass.add_child(screen)


# Every few seconds the tape tears for a few frames. Seeded, so each recording is the same.
func _tear_now_and_then() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 1995
	while is_inside_tree():
		await _wait(dice.randf_range(TEAR_EVERY.x, TEAR_EVERY.y))
		_tape.set_shader_parameter(&"seed", dice.randf() * 100.0)
		for i: int in dice.randi_range(2, 4):
			_tape.set_shader_parameter(&"tear", dice.randf_range(0.4, 1.0))
			await get_tree().process_frame
		_tape.set_shader_parameter(&"tear", 0.0)


# The VCR's PLAY on the TV, for the first moments, as when the tape starts.
func _play_sign() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 140
	_tv.add_child(layer)
	var sign := Label.new()
	sign.text = "PLAY >"
	var settings := LabelSettings.new()
	settings.font = VCR_FONT
	settings.font_size = 64
	settings.shadow_color = Color(0, 0, 0, 0.8)
	settings.shadow_offset = Vector2(4, 4)
	sign.label_settings = settings
	sign.position = Vector2(150, 110)
	layer.add_child(sign)
	get_tree().create_timer(1.6).timeout.connect(layer.queue_free)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# Says [param text] as the narrator; returns its length in seconds.
func _say(text: String) -> float:
	var line := DialogueLine.new()
	line.text = text
	line.mood = &"happy"
	var wav := Voices.say_live(line, NARRATOR, null)
	if wav == null:
		push_error("Trailer: the narrator can't say \"%s\"; build the voice with tools/build-voice.sh" % text)
		return 1.5
	_sound(wav)
	# The music steps back under the voice, and comes back after it.
	if _duck != null:
		_duck.kill()
	_duck = create_tween()
	_duck.tween_property(_music, "volume_db", MUSIC_UNDER_VOICE_DB, 0.15)
	_duck.tween_interval(wav.get_length())
	_duck.tween_property(_music, "volume_db", MUSIC_DB, 0.3)
	return wav.get_length()


func _sound(stream: AudioStream, volume_db: float = 0.0) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()
	return player


# A new full-screen card over everything, with moving 90s stripes from [param top] to [param bottom];
# a clear card for overlays when [param clear].
func _new_card(top: Color, bottom: Color, clear: bool = false) -> void:
	if _card != null:
		_card.queue_free()
	_card = Control.new()
	_card.size = SCREEN
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.add_child(_card)
	if clear:
		return
	var back := ColorRect.new()
	back.size = SCREEN
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = STRIPES
	material.set_shader_parameter(&"top", top)
	material.set_shader_parameter(&"bottom", bottom)
	back.material = material
	_card.add_child(back)


# A big cheesy caption centred on [param at], popping in after [param delay].
func _caption(text: String, size: int, at: Vector2, color: Color, tilt: float = -4.0, delay: float = 0.0) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var settings := LabelSettings.new()
	settings.font = _font
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = maxi(size / 7, 4)
	settings.outline_color = INK
	settings.shadow_color = Color(0, 0, 0, 0.55)
	settings.shadow_offset = Vector2.ONE * maxf(size / 16.0, 3.0)
	label.label_settings = settings
	_card.add_child(label)
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size / 2.0
	label.position = at - label.size / 2.0
	label.rotation_degrees = tilt
	label.scale = Vector2.ZERO
	var pop := create_tween()
	pop.tween_interval(delay)
	pop.tween_property(label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return label


# A portrait centred on [param x], standing on the bottom edge: its cut, at the chest or the waist,
# lies just below the frame. It scales from that edge, so a zoom never lifts the cut into view.
func _portrait(person: String, mood: StringName, x: float, height: float, flip: bool = false) -> TextureRect:
	var who: Person = load("res://people/%s/person.tres" % person)
	var picture: Texture2D = who.portraits.get(mood, who.portraits.get(&"neutral"))
	var cut := Finale.cut_to_person(picture)
	var rect := TextureRect.new()
	rect.texture = cut
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.flip_h = flip
	rect.size = Vector2(height * cut.get_width() / cut.get_height(), height)
	rect.pivot_offset = Vector2(rect.size.x / 2.0, rect.size.y)
	rect.position = Vector2(x - rect.size.x / 2.0, SCREEN.y + 30.0 - height)
	_card.add_child(rect)
	return rect


# A four-pointed sparkle at [param at] that twinkles.
func _sparkle(at: Vector2, size: float) -> void:
	var star := Polygon2D.new()
	var points := PackedVector2Array()
	for i: int in 8:
		var reach := size if i % 2 == 0 else size * 0.22
		points.append(Vector2.from_angle(TAU * i / 8.0 - PI / 2.0) * reach)
	star.polygon = points
	star.color = Color(1, 1, 0.85)
	star.position = at
	star.scale = Vector2.ZERO
	_card.add_child(star)
	var twinkle := create_tween().set_loops(3)
	twinkle.tween_property(star, "scale", Vector2.ONE, 0.18)
	twinkle.tween_property(star, "scale", Vector2.ONE * 0.3, 0.18)


func _build_studio() -> void:
	_studio = SubViewport.new()
	_studio.size = Vector2i(SCREEN)
	_studio.transparent_bg = true
	_studio.own_world_3d = true
	_studio.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_studio)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0, 0.12, 0.9)
	camera.look_at_from_position(camera.position, Vector3(0, 0.02, 0), Vector3.UP)
	_studio.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 30, 0)
	key.light_energy = 1.4
	_studio.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_color = Color(0.6, 0.8, 1.0)
	fill.light_energy = 0.7
	_studio.add_child(fill)
	var sky := WorldEnvironment.new()
	sky.environment = Environment.new()
	sky.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.environment.ambient_light_color = Color(0.7, 0.7, 0.8)
	sky.environment.ambient_light_energy = 0.6
	_studio.add_child(sky)
	_turntable = Node3D.new()
	_studio.add_child(_turntable)
	var spin := create_tween().set_loops()
	spin.tween_property(_turntable, "rotation:y", TAU, 3.0).from(0.0)


# Puts [param part] on the turntable, at a size that fills the shot.
func _show_part(part_id: StringName, broken: bool = false) -> void:
	for old: Node in _turntable.get_children():
		old.queue_free()
	var model := Piece.new(Part.named(part_id), broken).make_model()
	if model == null:
		push_error("Trailer: no model for the part %s" % part_id)
		return
	_turntable.add_child(model)
	var box := Part.bounds(model)
	var fit := 0.32 / maxf(box.size.x, maxf(box.size.y, box.size.z))
	model.scale = Vector3.ONE * fit
	model.position = -box.get_center() * fit
	model.rotation_degrees.x = 18.0


func _studio_card(top: Color, bottom: Color) -> void:
	_new_card(top, bottom)
	var view := TextureRect.new()
	view.texture = _studio.get_texture()
	view.size = SCREEN
	view.position.y = 80.0
	_card.add_child(view)


func _problems() -> void:
	_new_card(Color("#00c8d6"), Color("#7b2cbf"))
	_portrait("skater_bro", &"angry", 330.0, 820.0)
	_portrait("office_girl", &"angry", 1590.0, 820.0, true)
	_caption("DO YOU HAVE", 96, Vector2(960, 270), Color.WHITE, -3.0)
	_caption("COMPUTER\nPROBLEMS?", 176, Vector2(960, 560), YELLOW, -5.0, 0.25)
	await _wait(0.35)
	await _wait(maxf(_say(SAY_PROBLEMS), 1.6) + 0.35)


func _angry_faces() -> void:
	var faces := [["hat_guy", "ARGH!", Color("#ff3b6b"), Color("#ffb000")], ["young_entrepreneur", "?!?!", Color("#00b4d8"), Color("#3a0ca3")],
		["activist_guy", "#@%&!", Color("#80ff72"), Color("#00a6a6")]]
	for face: Array in faces:
		_new_card(face[2], face[3])
		var who := _portrait(face[0], &"angry", 960.0, 950.0)
		create_tween().tween_property(who, "scale", Vector2.ONE * 1.12, 0.45).from(Vector2.ONE * 0.92)
		_caption(face[1], 200, Vector2(1450, 300), Color.WHITE, 8.0)
		await _wait(0.45)


func _parts() -> void:
	_studio_card(Color("#ff006e"), Color("#3a0ca3"))
	_caption("THE LATEST PARTS!", 130, Vector2(960, 150), YELLOW, -3.0)
	_show_part(&"motherboard")
	var length := maxf(_say(SAY_PARTS), 3.0)
	var steps: Array = [[0.38, &"gpu", "GRAPHICS CARDS!"], [0.62, &"cpu", "PROCESSORS!"], [0.84, &"fan", "FANS!"]]
	var done := 0.0
	var shown: Label = null
	for step: Array in steps:
		await _wait(length * step[0] - done)
		done = length * step[0]
		_show_part(step[1])
		if shown != null:
			shown.queue_free()
		shown = _caption(step[2], 110, Vector2(960, 880), Color.WHITE, 3.0)
	await _wait(length - done + 0.3)


func _budget() -> void:
	_studio_card(Color("#ffd166"), Color("#ef476f"))
	_show_part(&"cpu")
	_caption("BUDGET OPTIONS TOO!", 120, Vector2(960, 150), Color.WHITE, -3.0)
	var stamp := _caption("KOREAN B", 120, Vector2(1420, 520), Color("#ff2d2d"), 14.0, 0.5)
	stamp.label_settings.outline_color = Color.WHITE
	_caption("*Results may vary.", 36, Vector2(1580, 960), Color.WHITE, 0.0, 0.9)
	await _wait(maxf(_say(SAY_BUDGET), 2.0) + 0.35)


# The repair, played with the game's own moves, so each one makes its own sound: the computer lies
# down, the screws come out, the case opens, the dusty fan goes in the trash, a new one goes in, and
# the computer closes, stands up, gets its cable and switches on. A clear card carries the captions.
func _repair() -> void:
	AudioServer.set_bus_mute(_shop_bus, false)
	AudioServer.set_bus_volume_db(_shop_bus, SFX_BOOST_DB)
	create_tween().tween_property(_music, "volume_db", MUSIC_UNDER_SFX_DB, 0.3)
	var job := {"customer": "res://customers/skater_bro.tres", "problem": "dust_overheat", "slot": 0, "order": 0}
	_restore({"day": 1, "phase": "OPEN", "jobs": [job], "focus_slot": 0, "view": "Workview"})
	var shop_job: Job = Game.jobs[0]
	_new_card(Color.BLACK, Color.BLACK, true)
	await _wait(0.3)
	await _move(func() -> bool: return Game.lay_down(shop_job), "", 0.45)
	for screw in shop_job.panel_screws.size():
		_sound(_ratchet(), RATCHET_DB)
		await _move(func() -> bool: return Game.turn_screw(shop_job, screw), "SCREWS!" if screw == 0 else "", 0.4)
	await _move(func() -> bool: return Game.open_case(shop_job, true), "FAST!", 0.55, YELLOW)
	await _move(func() -> bool: return Game.take_part(shop_job, FAN), "DUSTY?", 0.6)
	await _move(func() -> bool: return Game.trash_part(), "TRASH IT!", 0.45, Color("#ff3b6b"))
	await _move(func() -> bool: return Game.take_new_part(FAN), "BRAND NEW!", 0.5, Color("#80ff72"))
	await _move(func() -> bool: return Game.put_part(shop_job), "CLICK!", 0.6, YELLOW)
	_sparkle(Vector2(1300, 640), 70.0)
	_sound(DING, -4.0)
	await _move(func() -> bool: return Game.open_case(shop_job, false), "", 0.35)
	for screw in shop_job.panel_screws.size():
		_sound(_ratchet(), RATCHET_DB)
		await _move(func() -> bool: return Game.turn_screw(shop_job, screw), "TIGHT!" if screw == 0 else "", 0.35)
	await _move(func() -> bool: return Game.stand_up(shop_job), "", 0.4)
	Game.connect_cable(shop_job)
	var power := func() -> bool:
		Game.set_powered(shop_job, true)
		return shop_job.powered
	await _move(power, "", 0.3)


# One move of the repair: a mouse click, the move, and its caption on a new clear card, then a wait.
# A move that the game refuses is an error: the trailer's shot list broke a rule of the game.
func _move(move: Callable, caption: String, seconds: float, color: Color = Color.WHITE) -> void:
	_click()
	if not move.call():
		push_error("Trailer: the game refused a move of the repair, before \"%s\"" % caption)
	if caption != "":
		_new_card(Color.BLACK, Color.BLACK, true)
		_caption(caption, 160, Vector2(1480, 230), color, randf_range(-7.0, 7.0))
	await _wait(seconds)


func _click() -> void:
	_sfx(CLICK_DOWN)
	get_tree().create_timer(0.07).timeout.connect(_sfx.bind(CLICK_UP))


func _sfx(sounds: SoundSet) -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	sounds.play_on(player)
	player.volume_db += SFX_BOOST_DB
	get_tree().create_timer(3.0).timeout.connect(player.queue_free)


# The screwdriver's ratchet, made here: the game's screwdriver turns without a sound.
func _ratchet() -> AudioStreamWAV:
	var rate := 44100
	var samples := int(rate * 0.4)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var since := fmod(float(i) / rate, 1.0 / 24.0)
		var tick := exp(-since * 700.0) * (randf_range(-0.6, 0.6) + 0.5 * sin(TAU * 2900.0 * since))
		data.encode_s16(i * 2, int(clampf(tick, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


# The bench screen close up as the repaired computer starts, while the keys rattle.
func _tested() -> void:
	Game.go_to_view(&"Screen")
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, 0.6)
	_new_card(Color.BLACK, Color.BLACK, true)
	_caption("TESTED!", 150, Vector2(1560, 200), Color("#80ff72"), 5.0, 0.5)
	await _type(1.8)
	AudioServer.set_bus_mute(_shop_bus, true)


# Key presses at a typist's pace for [param seconds].
func _type(seconds: float) -> void:
	var done := 0.0
	while done < seconds:
		_sfx(KEYS)
		var gap := randf_range(0.06, 0.16)
		await _wait(gap)
		done += gap


func _compufun_db() -> void:
	AudioServer.set_bus_mute(_shop_bus, false)
	var job := {"customer": "res://customers/skater_bro.tres", "problem": "dust_overheat", "slot": 0, "order": 0}
	_restore({"day": 1, "phase": "OPEN", "jobs": [job], "db_day": 1, "view": "CompuFunDB"})
	_new_card(Color.BLACK, Color.BLACK, true)
	_caption("FUN!", 190, Vector2(1580, 220), YELLOW, -8.0, 0.3)
	await _type(1.3)
	AudioServer.set_bus_mute(_shop_bus, true)


# The Win95 sounds stay out of the trailer: they are Microsoft's. The desktop sets the Win95 bus's own
# mute, so the bus sends to a silent one instead.
func _silence_win95() -> void:
	var silent := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(silent, &"TrailerSilent")
	AudioServer.set_bus_mute(silent, true)
	AudioServer.set_bus_send(AudioServer.get_bus_index(Win95Desktop.SOUND_BUS), &"TrailerSilent")


# A key skips the boot of the repaired computer, as a player can, behind the next cards.
func _skip_boot() -> void:
	var win95 := _shown_desktop()
	var boot: Node = win95.get(&"_boot") if win95 != null else null
	if not is_instance_valid(boot):
		push_error("Trailer: the repaired computer is not booting on the bench screen")
		return
	boot.set(&"_skipped", true)


# The bench screen close up: the desktop shows an error, the Start menu, Solitaire and the fix, each in
# Win95's own windows. A clear card on top carries the captions.
func _win95_desktop() -> void:
	var win95 := _shown_desktop()
	if win95 == null:
		push_error("Trailer: no Windows 95 desktop on the bench screen")
		return
	var waited := 0.0
	while win95.get(&"pointer_visible") != true and waited < 8.0:
		await _wait(0.1)
		waited += 0.1
	AudioServer.set_bus_mute(_shop_bus, false)
	Game.go_to_view(&"Screen")
	var desktop := win95.get_node(^"Desktop") as Control
	var error := _desktop_box(desktop, "SKATE.EXE", "This program has performed an illegal\noperation and will be shut down.", [])
	_new_card(Color.BLACK, Color.BLACK, true)
	_caption("CRASHES?", 150, Vector2(1560, 200), Color.WHITE, 5.0, 0.4)
	await _wait(1.5)
	error.queue_free()
	var start := win95.get_node(^"TaskBar/HBoxContainer/StartButton") as Button
	start.button_pressed = true
	_new_card(Color.BLACK, Color.BLACK, true)
	_caption("EASY!", 160, Vector2(1560, 200), YELLOW, -6.0)
	await _wait(1.1)
	start.button_pressed = false
	desktop.call(&"open", SOLITAIRE)
	_new_card(Color.BLACK, Color.BLACK, true)
	_caption("GAMES!", 160, Vector2(1560, 200), Color("#80ff72"), 6.0)
	await _wait(1.2)
	_desktop_box(desktop, "CompuFun", "Your computer is fixed!", [])
	_new_card(Color.BLACK, Color.BLACK, true)
	_caption("FIXED!", 170, Vector2(1560, 200), YELLOW, -5.0)
	_sparkle(Vector2(1300, 500), 60.0)
	_sound(DING, -8.0)
	await _wait(1.3)


func _shown_desktop() -> Control:
	var bench := _main.find_child("BenchScreen", true, false)
	if bench == null:
		return null
	for child: Node in bench.get_children():
		if child.get_script() != null and (child.get_script() as Script).resource_path == WIN95_SCRIPT:
			return child as Control
	return null


# A Win95 message box in the middle of [param desktop]: a message with OK, or a question with
# [param buttons].
func _desktop_box(desktop: Control, title: String, text: String, buttons: Array[String]) -> Control:
	var box: Control = desktop.call(&"open", MESSAGE_BOX, false)
	if buttons.is_empty():
		box.call(&"show_message", title, text)
	else:
		box.call(&"ask", title, text, buttons)
	box.size = box.get_combined_minimum_size()
	box.position = ((desktop.size - box.size) / 2.0).round()
	return box


func _restore(state: Dictionary) -> void:
	var refused := Game.restore(state)
	if refused != "":
		push_error("Trailer: the shop refused a shot: %s" % refused)


func _before_after() -> void:
	for who: String in ["skater_bro", "office_girl"]:
		_new_card(Color("#4cc9f0"), Color("#7209b7"))
		_portrait(who, &"angry", 520.0, 880.0)
		_caption("BEFORE", 110, Vector2(520, 160), Color("#ff3b6b"), -6.0)
		await _wait(0.6)
		_portrait(who, &"happy", 1400.0, 880.0)
		_caption("AFTER", 110, Vector2(1400, 160), Color("#80ff72"), 6.0)
		_sparkle(Vector2(1640, 380), 60.0)
		_sparkle(Vector2(1180, 300), 40.0)
		_sound(DING, -8.0)
		await _wait(0.95)


# The job offer: on a card, or in the Win95 cut on the bench screen's desktop.
func _hiring() -> void:
	var win95 := _shown_desktop() if win95_cut else null
	if win95 != null:
		var desktop := win95.get_node(^"Desktop") as Control
		desktop.call(&"close_all")
		_desktop_box(desktop, "Help Wanted", "We're looking for employees!\nIt's a chill gig. The week will fly by!", ["Yes!", "No"])
		_new_card(Color.BLACK, Color.BLACK, true)
		_caption("NOW HIRING!", 150, Vector2(1500, 200), YELLOW, -5.0)
	else:
		_new_card(Color("#2ec4b6"), Color("#011627"))
		_caption("NOW HIRING!", 190, Vector2(960, 300), YELLOW, -4.0)
		_caption("It's a chill gig.\nThe week will fly by!", 84, Vector2(960, 680), Color.WHITE, 2.0, 0.4)
	await _wait(maxf(_say(SAY_HIRING), 3.0) + 0.3)
	AudioServer.set_bus_mute(_shop_bus, true)


func _come_by() -> void:
	_new_card(Color("#ffbe0b"), Color("#fb5607"))
	_caption("COME BY", 120, Vector2(960, 330), Color.WHITE, -4.0)
	_caption("COMPUFUN!", 230, Vector2(960, 560), YELLOW, -4.0, 0.2)
	_caption("It will be a lot of fun!", 64, Vector2(960, 820), Color.WHITE, 0.0, 0.8)
	await _wait(maxf(_say(SAY_COME), 2.2) + 0.2)
	var wipe := CanvasLayer.new()
	wipe.layer = 125
	_tv.add_child(wipe)
	var star := ColorRect.new()
	star.size = SCREEN
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = STAR
	star.material = material
	wipe.add_child(star)
	if _duck != null:
		_duck.kill()
	create_tween().tween_property(_music, "volume_db", -60.0, 0.6)  # out before our own jingle
	var grow := create_tween()
	grow.tween_method(func(r: float) -> void: material.set_shader_parameter(&"radius", r), 0.0, 2.6, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await grow.finished
	_card.queue_free()
	_card = null
	_main.queue_free()
	wipe.queue_free()


# The CompuFun intro with its jingle, and at its end one tiny glitch.
func _intro_and_glitch() -> void:
	var intro := (load("res://ui/loading_screen.tscn") as PackedScene).instantiate()
	intro.set(&"reveal_game", false)
	_tv.add_child(intro)
	await _wait(2.15 + 0.5 + 0.75 + 1.3)
	var layer := CanvasLayer.new()
	layer.layer = 130
	_tv.add_child(layer)
	var glitch := ColorRect.new()
	glitch.size = SCREEN
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = GLITCH
	glitch.material = material
	layer.add_child(glitch)
	var buzz := _sound(BUZZ, -10.0)
	for i: int in 6:
		material.set_shader_parameter(&"amount", 1.0 if i % 3 != 2 else 0.4)
		material.set_shader_parameter(&"seed", float(i) * 1.7)
		await get_tree().process_frame
	buzz.stop()
	layer.queue_free()
	await _wait(1.2)
