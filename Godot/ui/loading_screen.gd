extends CanvasLayer
## The loading screen: the CompuFun logo draws itself in while main.tscn loads, in step with the
## CompuFun jingle (the Jingle player), which plays from the first frame. Then the game starts
## underneath, the logo's letters turn into windows onto it, and the paper zooms in through the
## middle of the logo until the game fills the screen.

## The scene that the screen loads on a thread and starts under the logo. Set it before the screen
## enters the tree.
@export_file("*.tscn") var game_scene: String = "res://main.tscn"

## When the ink reaches each part of the logo, in step with the jingle's sung syllables: x is the
## seconds into the jingle, y how far the ink has drawn in (0 to 1, about the share of the logo's
## width). "Com" is sung from 0.10 s, "pu" from 0.77 s and "Fun" from 1.35 s to 2.15 s; in the logo,
## "pu" starts at 0.42 of the width and "Fun" at 0.64. Between two keys the ink eases out, so the
## letters fill early in their syllable. The last key is also the shortest draw-in, so the logo does
## not flash by. Keep the keys in order of time.
@export var draw_keys: PackedVector2Array = PackedVector2Array([Vector2(0.1, 0.0), Vector2(0.77, 0.42), Vector2(1.35, 0.64), Vector2(2.15, 1.0)])
## How far the outline runs ahead of the ink, in seconds of the jingle.
@export var outline_lead_seconds: float = 0.2
## The line that fades in under the logo once its ink is complete, and how long the fade takes, in
## seconds. A fade, not typing: the game warms up behind the logo meanwhile, and typing showed its stalls.
@export var byline: String = "a dubious potions game"
@export var byline_fade_seconds: float = 0.75
## How long after the logo is complete the byline starts to fade in, in seconds.
@export var byline_after_seconds: float = 0.5
## How long the byline shows, fully faded in, before the letters and it turn see-through, in seconds.
## The game comes in behind the logo once the byline is fully in: adding it and its shader warm-up stall
## frames, so they must not fall on the draw-in or the fade-in. The letters wait for the warm-up too, if
## that takes longer.
@export var byline_seconds: float = 1.5
## How long the letters take to turn see-through, in seconds.
@export var reveal_seconds: float = 1.6
## When the zoom starts, in seconds after the letters start to turn see-through (they are fully
## see-through after reveal_seconds).
@export var zoom_after_seconds: float = 1.73
## Where the zoom goes: a point inside the logo's ink, in pixels of the logo picture. It glides to the
## centre of the screen, and its hole grows until it covers the screen. The thickest stroke near the
## logo's middle (15 px deep): measure again if the logo changes.
@export var zoom_point: Vector2 = Vector2(342, 203)
## How far the paper zooms in, at least. It zooms deeper when the screen needs it: until the logo's
## ink around zoom_point covers every pixel of the screen, so no paper shows when it goes.
@export var zoom_scale: float = 80.0
## How long the zoom takes, in seconds. Then the paper goes, with no fade: the ink covers the screen.
@export var zoom_seconds: float = 2.55
## The zoom's speed at its start, as a share of its average speed; from there the speed grows
## steadily to (2 - this) at the end. 0 starts from still and rushes at the end; 1 keeps one speed.
## The speed is of the zoom as the eye sees it: on the log of the scale.
@export_range(0.0, 1.0, 0.01) var zoom_start_speed: float = 0.08
## From this share of the zoom's time, 0 to 1, its speed grows zoom_boost times as steeply: a last
## push into the logo.
@export_range(0.0, 1.0, 0.05) var zoom_boost_from: float = 0.7
@export var zoom_boost: float = 3.0

# Set on the first frame: the web build has no threads, so the load may block until then.
var _start_ms: int = -1
# True once the game has started to come in behind the logo.
var _game_started: bool = false
var _byline_shown: bool = false
# When the byline is fully faded in, in Time.get_ticks_msec.
var _byline_full_ms: int = 0

@onready var _logo: ShaderMaterial = %Logo.material
@onready var _status: Label = %Status
@onready var _paper: ColorRect = %Background


func _ready() -> void:
	get_window().title = BuildInfo.title()
	_draw(0.0, 0.0)
	for i: int in range(1, draw_keys.size()):
		if draw_keys[i].x < draw_keys[i - 1].x:
			push_error("LoadingScreen: draw_keys are not in order of time at key %d: %s" % [i, draw_keys])
	if Game.week == null:
		_fail("the story files have errors:\n" + "\n".join(Game.story_errors))
		return
	var err := ResourceLoader.load_threaded_request(game_scene)
	if err != OK:
		_fail("cannot start to load %s: %s" % [game_scene, error_string(err)])


func _process(_delta: float) -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(game_scene, progress)
	if _start_ms < 0:
		_start_ms = Time.get_ticks_msec()
		%Jingle.play()
	var seconds := _heard_seconds((Time.get_ticks_msec() - _start_ms) / 1000.0)
	if _game_started:
		_draw(seconds, 1.0)  # the load is taken; only the ink goes on
		return
	var drawn_in: float = draw_keys[draw_keys.size() - 1].x if not draw_keys.is_empty() else 0.0
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_draw(seconds, progress[0] if not progress.is_empty() else 0.0)
		ResourceLoader.THREAD_LOAD_LOADED:
			_draw(seconds, 1.0)
			if seconds >= drawn_in + byline_after_seconds and not _byline_shown:
				_show_byline()
			if _byline_shown and Time.get_ticks_msec() >= _byline_full_ms:
				_game_started = true
				var scene := ResourceLoader.load_threaded_get(game_scene) as PackedScene
				if scene == null:
					_fail("%s loaded, but it is not a scene" % game_scene)
					return
				_reveal(scene)
		_:
			_fail("cannot load %s" % game_scene)


## How far the ink has drawn in at [param seconds] into the jingle, from 0 to 1 (see [member draw_keys]).
func drawn_at(seconds: float) -> float:
	if draw_keys.is_empty():
		return 1.0
	if seconds <= draw_keys[0].x:
		return 0.0 if seconds < draw_keys[0].x else draw_keys[0].y
	for i: int in range(1, draw_keys.size()):
		var to := draw_keys[i]
		if seconds < to.x:
			var from := draw_keys[i - 1]
			var along := (seconds - from.x) / maxf(to.x - from.x, 0.001)
			return lerpf(from.y, to.y, sin(along * PI / 2.0))  # eases out
	return 1.0


# Draws the logo as far as the jingle has got, but never past [param loaded], the share of the game
# that has loaded.
func _draw(seconds: float, loaded: float) -> void:
	_logo.set_shader_parameter("ink_progress", minf(loaded, drawn_at(seconds)))
	_logo.set_shader_parameter("outline_progress", minf(loaded, drawn_at(seconds + outline_lead_seconds)))


# The seconds into the jingle that the player hears now: its playback position, corrected for the
# audio buffer and the output latency, so the ink follows the sound. While the jingle cannot be heard
# (no audio device, or a browser that holds sound until the first click), or its position strays from
# [param wall] (the seconds since the first frame), the frame clock leads, so the logo always draws in.
func _heard_seconds(wall: float) -> float:
	var jingle := %Jingle as AudioStreamPlayer
	if not jingle.playing:
		return wall
	var heard := jingle.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return heard if absf(heard - wall) < 0.5 else wall


# The game starts under the loading screen, which stays on top (its layer) until the paper is gone.
func _reveal(scene: PackedScene) -> void:
	var game := scene.instantiate()
	if game == null:
		_fail("cannot create %s" % game_scene)
		return
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	# While the logo still covers it, the game shows each view once to compile its shaders.
	if game.has_method(&"warm_up"):
		await game.warm_up()
	set_process(false)
	var shown_until := _byline_full_ms + int(byline_seconds * 1000.0)
	if Time.get_ticks_msec() < shown_until:
		await get_tree().create_timer((shown_until - Time.get_ticks_msec()) / 1000.0).timeout
	var logo := (%Logo as Control).get_global_rect()
	var paper := _paper.material as ShaderMaterial
	paper.set_shader_parameter("logo_rect", Vector4(logo.position.x, logo.position.y, logo.size.x, logo.size.y))
	var fade := create_tween()
	fade.tween_method(func(hole: float) -> void: paper.set_shader_parameter("hole", hole), 0.0, 1.0, reveal_seconds)
	fade.parallel().tween_property(%Logo, "modulate:a", 0.0, reveal_seconds)
	fade.parallel().tween_property(%Byline, "modulate:a", 0.0, reveal_seconds)
	var picture := (%Logo as TextureRect).texture.get_size()
	_paper.pivot_offset = logo.position + zoom_point * logo.size / picture
	# The zoom overlaps the end of the fade, so every part of it runs in parallel from zoom_at.
	var zoom_at := zoom_after_seconds
	var deepest := maxf(zoom_scale, _covering_scale(logo) * 1.05)
	fade.parallel().tween_method(_zoom.bind(deepest), 0.0, 1.0, zoom_seconds).set_delay(zoom_at)
	# The scale keeps the pivot in place, so moving the paper moves the zoom point to the centre.
	var to_centre := _paper.size * 0.5 - _paper.pivot_offset
	fade.parallel().tween_property(_paper, "position", to_centre, zoom_seconds * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(zoom_at)
	fade.tween_callback(queue_free)


# Fades the byline in under the complete logo.
func _show_byline() -> void:
	_byline_shown = true
	_byline_full_ms = Time.get_ticks_msec() + int(byline_fade_seconds * 1000.0)
	var label := %Byline as Label
	label.text = byline
	create_tween().tween_property(label, "modulate:a", 1.0, byline_fade_seconds).from(0.0)


# [param t] is the share of the zoom's time, and [param deepest] its last scale. The speed (of the log
# of the scale) starts at zoom_start_speed of its average and grows steadily, zoom_boost times as
# steeply from zoom_boost_from on; along is the distance covered, from 0 to 1.
func _zoom(t: float, deepest: float) -> void:
	var from := zoom_boost_from
	var rest := from * from / 2.0 + from * (1.0 - from) + zoom_boost * pow(1.0 - from, 2.0) / 2.0
	var start := zoom_start_speed * rest / maxf(1.0 - zoom_start_speed, 0.001)
	var covered := start * t + minf(t, from) * minf(t, from) / 2.0
	if t > from:
		covered += from * (t - from) + zoom_boost * pow(t - from, 2.0) / 2.0
	var along := covered / (start + rest)
	_paper.scale = Vector2.ONE * pow(deepest, along)


# The scale at which the logo's ink around zoom_point covers the whole screen, with the zoom point in
# its middle: the screen's half-diagonal against the distance from zoom_point to the nearest pixel of
# the logo that is not fully black, less one pixel for the texture's linear filter. [param logo] is
# where the logo lies on the screen.
func _covering_scale(logo: Rect2) -> float:
	var texture := (%Logo as TextureRect).texture
	var image := texture.get_image()
	if image == null or (image.is_compressed() and image.decompress() != OK):
		push_error("LoadingScreen: cannot read the logo %s; the zoom goes to zoom_scale only" % texture.resource_path)
		return zoom_scale
	var centre := Vector2i(zoom_point.round())
	var depth := INF
	var reach := 0
	while depth > reach and reach < 256:
		reach += 1
		for y: int in range(centre.y - reach, centre.y + reach + 1):
			for x: int in range(centre.x - reach, centre.x + reach + 1):
				if maxi(absi(x - centre.x), absi(y - centre.y)) != reach:
					continue
				var paper := x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height() or image.get_pixel(x, y).get_luminance() > 1.0 / 255.0
				if paper:
					depth = minf(depth, Vector2(x - centre.x, y - centre.y).length())
	var clean := maxf(depth - 1.0, 0.5) * logo.size.x / texture.get_width()
	return get_viewport().get_visible_rect().size.length() / 2.0 / clean


func _fail(message: String) -> void:
	set_process(false)
	push_error("Loading screen: " + message)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "The game could not load: %s" % message
