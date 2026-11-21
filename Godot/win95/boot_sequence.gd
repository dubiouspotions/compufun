extends Control
## A 1995 PC booting: the BIOS power-on self test, "Starting Windows 95...", the splash screen,
## then the desktop beneath, with a sound for each stage. Any key or click skips to the desktop.
## Frees itself when the startup sound has played.

## The boot reached the desktop, or the player skipped it.
signal finished

## Starts as soon as the node is ready; turn off to start it with play().
@export var play_on_start: bool = true
## The power-on self test, one line at a time. %MEMORY% is the memory test, which counts up.
@export_multiline var post_lines: PackedStringArray = [
	"CompuFun Modular BIOS v4.51PG, An Energy Star Ally",
	"Copyright (C) 1984-95, CompuFun Ltd.",
	"",
	"PENTIUM-S CPU at 100MHz",
	"%MEMORY%",
	"",
	"CompuFun Plug and Play BIOS Extension v1.0A",
	"Copyright (C) 1995, CompuFun Ltd.",
	"  Detecting IDE Primary Master  ... QUANTUM FIREBALL1080A",
	"  Detecting IDE Primary Slave   ... None",
	"  Detecting IDE Secondary Master... CD-ROM 4X",
	"  Detecting IDE Secondary Slave ... None",
	"",
	"",
	"Press DEL to enter SETUP",
]
## Kilobytes of memory that the memory test counts up to.
@export var memory_kb: int = 16384
@export var memory_test_seconds: float = 1.5
## The pause after each POST line, in seconds.
@export var line_seconds: float = 0.15
@export var post_hold_seconds: float = 1.0
@export var starting_seconds: float = 1.5
@export var splash_seconds: float = 3.0
@export_group("Sounds")
## Plays as the POST starts: the switch and the fan spinning up.
@export var power_on_sound: AudioStream
## Plays when the memory test passes.
@export var post_beep_sound: AudioStream
## Plays from drive detection through "Starting Windows 95...".
@export var drive_sound: AudioStream
## Plays as the desktop appears, also after a skip.
@export var startup_sound: AudioStream
@export_group("")

## The colours of the bar that scrolls along the bottom of the splash screen, as Win95 cycled
## its palette there; the gradient repeats every bar_period pixels.
@export var bar_gradient: Gradient
@export var bar_period: float = 160.0
## How fast the bar scrolls, in pixels per second.
@export var bar_speed: float = 120.0

var _skipped: bool = false
var _playing: bool = false
var _bar_offset: float = 0.0
var _players: Array[AudioStreamPlayer] = []

@onready var _post: Label = %Post
@onready var _starting: Label = %Starting
@onready var _splash: Control = %Splash
@onready var _bar: Control = %Bar


func _ready() -> void:
	_bar.draw.connect(_draw_bar)
	set_process(false)
	hide()
	if play_on_start:
		play()


func _process(delta: float) -> void:
	_bar_offset += delta * bar_speed
	_bar.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		accept_event()
		_skipped = true


## Plays the boot from the start, then emits finished and frees the node.
func play() -> void:
	if _playing:
		return
	_playing = true
	_skipped = false
	show()
	focus_mode = Control.FOCUS_ALL
	grab_focus.call_deferred()
	await _run()
	for player in _players:
		player.stop()
	hide()
	set_process(false)
	finished.emit()
	if startup_sound:
		_sound(startup_sound)
		# The stream's length, not the player's finished: with no audio device that never fires.
		await get_tree().create_timer(startup_sound.get_length()).timeout
	queue_free()


func _run() -> void:
	_show_stage(_post)
	_post.text = ""
	_sound(power_on_sound)
	var drive_started := false
	for line in post_lines:
		if not drive_started and line.strip_edges().begins_with("Detecting"):
			drive_started = true
			_sound(drive_sound)
		if line == "%MEMORY%":
			if not await _count_memory():
				return
		else:
			_post.text += line + "\n"
			if not await _wait(line_seconds):
				return
	if not await _wait(post_hold_seconds):
		return
	_show_stage(_starting)
	if not await _wait(starting_seconds):
		return
	_show_stage(_splash)
	set_process(true)
	await _wait(splash_seconds)


## Counts the memory test up on the last line; false when the player skipped.
func _count_memory() -> bool:
	var before := _post.text
	var steps := 30
	for i in steps + 1:
		_post.text = before + "Memory Test :  %dK" % (memory_kb * i / steps)
		if not await _wait(memory_test_seconds / steps):
			return false
	_post.text += " OK\n"
	_sound(post_beep_sound)
	return true


## Waits [param seconds], and longer while the screen is out of the tree; false when the player
## skipped meanwhile.
func _wait(seconds: float) -> bool:
	if _skipped:
		return false
	await get_tree().create_timer(seconds).timeout
	if not is_inside_tree():
		await tree_entered
	return not _skipped


func _show_stage(stage: Control) -> void:
	for other: Control in [_post, _starting, _splash]:
		other.visible = other == stage


func _draw_bar() -> void:
	if bar_gradient == null:
		return
	var step := 2.0
	var x := 0.0
	while x < _bar.size.x:
		var at := fposmod((x + _bar_offset) / bar_period, 1.0)
		_bar.draw_rect(Rect2(x, 0, step, _bar.size.y), bar_gradient.sample(at))
		x += step


## Plays [param stream] on a new player and returns it; null plays nothing.
func _sound(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	_players.append(player)
	if stream:
		player.play()
	return player
