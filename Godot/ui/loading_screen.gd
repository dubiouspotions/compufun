extends Control
## The loading screen: the CompuFun logo and a progress bar while main.tscn loads, then the game.

const GAME_SCENE: String = "res://main.tscn"

## The shortest time the screen stays, in seconds, so the logo does not flash by.
@export var min_seconds: float = 1.5

var _start_ms: int = 0

@onready var _bar: ProgressBar = %Progress
@onready var _status: Label = %Status


func _ready() -> void:
	_start_ms = Time.get_ticks_msec()
	var err := ResourceLoader.load_threaded_request(GAME_SCENE)
	if err != OK:
		_fail("cannot start to load %s: %s" % [GAME_SCENE, error_string(err)])


func _process(_delta: float) -> void:
	var progress: Array = []
	match ResourceLoader.load_threaded_get_status(GAME_SCENE, progress):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_bar.value = float(progress[0]) * 100.0 if not progress.is_empty() else 0.0
		ResourceLoader.THREAD_LOAD_LOADED:
			_bar.value = 100.0
			if Time.get_ticks_msec() - _start_ms >= min_seconds * 1000.0:
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
