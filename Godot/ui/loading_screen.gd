extends Control
## The loading screen: the CompuFun logo draws itself in while main.tscn loads, then the game.

const GAME_SCENE: String = "res://main.tscn"

## The shortest time the logo takes to draw in, in seconds, so it does not flash by.
@export var min_seconds: float = 1.5
## How long the whole logo stays before the game starts, in seconds.
@export var hold_seconds: float = 0.3

# Set on the first frame: the web build has no threads, so the load may block until then.
var _start_ms: int = -1

@onready var _logo: ShaderMaterial = %Logo.material
@onready var _status: Label = %Status


func _ready() -> void:
	get_window().title = BuildInfo.title()
	_logo.set_shader_parameter("progress", 0.0)
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
				var err := get_tree().change_scene_to_packed(scene)
				if err != OK:
					_fail("cannot start %s: %s" % [GAME_SCENE, error_string(err)])
		_:
			_fail("cannot load %s" % GAME_SCENE)


func _fail(message: String) -> void:
	set_process(false)
	push_error("Loading screen: " + message)
	_status.text = "The game could not load: %s" % message
