extends CanvasLayer
## The loading screen: the CompuFun logo draws itself in while main.tscn loads. Then the game starts
## underneath, the logo's letters turn into windows onto it, and the paper zooms in through the
## middle of the logo until the game fills the screen.

const GAME_SCENE: String = "res://main.tscn"

## The shortest time the logo takes to draw in, in seconds, so it does not flash by.
@export var min_seconds: float = 1.5
## How long the whole logo stays before the game shows through it, in seconds.
@export var hold_seconds: float = 0.3
## How long the letters take to turn see-through, in seconds.
@export var reveal_seconds: float = 0.6
## How long the cut-out logo then stays, before the zoom, in seconds.
@export var cutout_seconds: float = 1.2
## Where the zoom goes: a point inside the logo's ink, in pixels of the logo picture. It glides to the
## centre of the screen, and its hole grows until it covers the screen. The thickest stroke near the
## logo's middle (15 px deep): measure again if the logo changes.
@export var zoom_point: Vector2 = Vector2(342, 203)
## How far the paper zooms in. The hole around zoom_point must then cover the screen.
@export var zoom_scale: float = 80.0
## How long the zoom takes, in seconds. The paper also fades in the last 30 %.
@export var zoom_seconds: float = 1.0

# Set on the first frame: the web build has no threads, so the load may block until then.
var _start_ms: int = -1

@onready var _logo: ShaderMaterial = %Logo.material
@onready var _status: Label = %Status
@onready var _paper: ColorRect = %Background


func _ready() -> void:
	get_window().title = BuildInfo.title()
	_logo.set_shader_parameter("progress", 0.0)
	if Game.week == null:
		_fail("the story files have errors:\n" + "\n".join(Game.story_errors))
		return
	var err := ResourceLoader.load_threaded_request(GAME_SCENE)
	if err != OK:
		_fail("cannot start to load %s: %s" % [GAME_SCENE, error_string(err)])


func _process(_delta: float) -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE, progress)
	if _start_ms < 0:
		_start_ms = Time.get_ticks_msec()
	var seconds := (Time.get_ticks_msec() - _start_ms) / 1000.0
	var time_share := minf(seconds / maxf(min_seconds, 0.001), 1.0)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var loaded: float = progress[0] if not progress.is_empty() else 0.0
			_logo.set_shader_parameter("progress", minf(loaded, time_share))
		ResourceLoader.THREAD_LOAD_LOADED:
			_logo.set_shader_parameter("progress", time_share)
			if seconds >= min_seconds + hold_seconds:
				set_process(false)
				var scene := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
				if scene == null:
					_fail("%s loaded, but it is not a scene" % GAME_SCENE)
					return
				_reveal(scene)
		_:
			_fail("cannot load %s" % GAME_SCENE)


# The game starts under the loading screen, which stays on top (its layer) until the paper is gone.
func _reveal(scene: PackedScene) -> void:
	var game := scene.instantiate()
	if game == null:
		_fail("cannot create %s" % GAME_SCENE)
		return
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	# While the logo still covers it, the game shows each view once to compile its shaders.
	if game.has_method(&"warm_up"):
		await game.warm_up()
	var logo := (%Logo as Control).get_global_rect()
	var paper := _paper.material as ShaderMaterial
	paper.set_shader_parameter("logo_rect", Vector4(logo.position.x, logo.position.y, logo.size.x, logo.size.y))
	var fade := create_tween()
	fade.tween_method(func(hole: float) -> void: paper.set_shader_parameter("hole", hole), 0.0, 1.0, reveal_seconds)
	fade.parallel().tween_property(%Logo, "modulate:a", 0.0, reveal_seconds)
	fade.tween_interval(cutout_seconds)
	var picture := (%Logo as TextureRect).texture.get_size()
	_paper.pivot_offset = logo.position + zoom_point * logo.size / picture
	fade.tween_property(_paper, "scale", Vector2.ONE * zoom_scale, zoom_seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	# The scale keeps the pivot in place, so moving the paper moves the zoom point to the centre.
	var to_centre := _paper.size * 0.5 - _paper.pivot_offset
	fade.parallel().tween_property(_paper, "position", to_centre, zoom_seconds * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.parallel().tween_property(_paper, "modulate:a", 0.0, zoom_seconds * 0.3).set_delay(zoom_seconds * 0.7)
	fade.tween_callback(queue_free)


func _fail(message: String) -> void:
	set_process(false)
	push_error("Loading screen: " + message)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "The game could not load: %s" % message
